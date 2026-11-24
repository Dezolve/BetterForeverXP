"""Offline regression tests: no network, author token, or release upload."""
import http.client
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
import zipfile

import publish_curseforge as cf


class PublisherTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "dist").mkdir()
        self.notes = "# Better Forever XP 2.8.1\n\nCommunity feedback • test\n"
        (self.root / "CURSEFORGE_RELEASE_NOTES.md").write_text(self.notes, encoding="utf-8")
        self.archive = self.root / "dist/BetterForeverXP-2.8.1.zip"
        with zipfile.ZipFile(self.archive, "w") as z:
            z.writestr("BetterForeverXP/BetterForeverXP.toc",
                       "## Interface: 16001\n## Version: 2.8.1\n")

    def test_version_lookup(self):
        valid = {"name": "1.60.1", "id": 123}
        self.assertEqual(cf.resolve_version([{"name": "1.60.10", "id": 456}, valid]), 123)
        for data in ([], [valid, valid], {"id": 123},
                     [{"name": "1.60.1", "id": True}], [{"name": "1.60.1", "id": 0}]):
            with self.subTest(data=data), self.assertRaises(cf.ReleaseError):
                cf.resolve_version(data)

    def test_release_identity(self):
        self.assertEqual(cf.load_release("2.8.1", self.root), (self.archive, self.notes))
        for version in ("2.8.2", "2.6.2", "../2.8.1", "2.8.1-beta"):
            with self.subTest(version=version), self.assertRaises(cf.ReleaseError):
                cf.load_release(version, self.root)
        with zipfile.ZipFile(self.archive, "w") as z:
            z.writestr("BetterForeverXP/BetterForeverXP.toc", "## Interface: 16001\n## Version: 2.8.0\n")
        with self.assertRaises(cf.ReleaseError):
            cf.load_release("2.8.1", self.root)

    def test_multipart_and_receipt(self):
        transport = Mock(return_value={"id": 123456})
        self.assertEqual(cf.publish("2.8.1", 123, self.archive, self.notes, "fake-token", transport), 123456)
        transport.assert_called_once()
        method, path, token, body, content_type = transport.call_args.args
        self.assertEqual((method, path, token), ("POST", "/api/projects/1731462/upload-file", "fake-token"))
        boundary = content_type.split("boundary=")[1].encode()
        parts = body.split(b"--" + boundary)
        metadata = json.loads(parts[1].split(b"\r\n\r\n", 1)[1])
        self.assertEqual(metadata, {
            "displayName": "Better Forever XP 2.8.1",
            "changelog": self.notes, "changelogType": "markdown",
            "gameVersions": [123], "releaseType": "release"})
        self.assertIn(b'filename="BetterForeverXP-2.8.1.zip"', parts[2])
        self.assertEqual(parts[2].split(b"\r\n\r\n", 1)[1][:-2], self.archive.read_bytes())
        self.assertNotIn(b"fake-token", body)

    def test_no_retry_on_uncertain_upload(self):
        for result in ({}, {"id": 0}, {"id": True}, {"id": "42"}, [], None):
            transport = Mock(return_value=result)
            with self.subTest(result=result), self.assertRaisesRegex(cf.ReleaseError, "do not retry"):
                cf.publish("2.8.1", 123, self.archive, self.notes, "fake-token", transport)
            transport.assert_called_once()
        transport = Mock(side_effect=cf.ReleaseError("transport failed"))
        with self.assertRaisesRegex(cf.ReleaseError, "do not retry"):
            cf.publish("2.8.1", 123, self.archive, self.notes, "fake-token", transport)
        transport.assert_called_once()

    def test_invalid_game_id_never_posts(self):
        transport = Mock()
        for game_id in (None, 0, -1, True, "123"):
            with self.assertRaises(cf.ReleaseError):
                cf.publish("2.8.1", game_id, self.archive, self.notes, "fake-token", transport)
        transport.assert_not_called()

    def test_https_errors_do_not_redirect_retry_or_disclose_body(self):
        for status in (302, 400, 401, 429, 500):
            with self.subTest(status=status), patch.object(http.client, "HTTPSConnection") as factory:
                conn = factory.return_value
                conn.getresponse.return_value.status = status
                with self.assertRaisesRegex(cf.ReleaseError, f"HTTP {status}"):
                    cf.request_json("POST", cf.UPLOAD_ENDPOINT, "fake-token", b"archive", "multipart/form-data")
                factory.assert_called_once_with(cf.HOST, timeout=60)
                conn.request.assert_called_once()
                conn.getresponse.return_value.read.assert_not_called()
                conn.close.assert_called_once()

    def test_bad_json(self):
        with patch.object(http.client, "HTTPSConnection") as factory:
            response = factory.return_value.getresponse.return_value
            response.status = 200
            response.read.return_value = b"not JSON secret"
            with self.assertRaisesRegex(cf.ReleaseError, "invalid JSON"):
                cf.request_json("GET", cf.VERSION_ENDPOINT, "fake-token")

    def test_context(self):
        env = {"GITHUB_ACTIONS": "true", "GITHUB_REPOSITORY": "Dezolve/BetterForeverXP",
               "GITHUB_EVENT_NAME": "push", "GITHUB_RUN_ATTEMPT": "1", "GITHUB_REF": "refs/heads/main"}
        cf.require_publish_context("2.8.1", env)
        cf.require_publish_context("2.8.1", dict(env, GITHUB_REF="refs/tags/v2.8.1"))
        for override in ({"GITHUB_RUN_ATTEMPT": "2"}, {"GITHUB_EVENT_NAME": "pull_request"},
                         {"GITHUB_REF": "refs/heads/feature"}, {"GITHUB_REF": "refs/tags/v2.8.0"},
                         {"GITHUB_REPOSITORY": "other/repo"}):
            with self.assertRaises(cf.ReleaseError):
                cf.require_publish_context("2.8.1", dict(env, **override))


if __name__ == "__main__":
    unittest.main()
