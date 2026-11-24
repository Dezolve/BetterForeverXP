"""Better Forever XP: direct CurseForge Author API uploader (stdlib only).

The workflow owns release authorization. This client fixes the project/target,
uses an authenticated read-only version preflight, and makes one POST at most.
Never retry an uncertain upload; reconcile it in the author dashboard.
"""
import argparse
import http.client
import json
import os
from pathlib import Path
import re
import secrets
import sys
import zipfile

HOST = "wow.curseforge.com"
PROJECT_ID = 1731462
GAME_VERSION = "1.60.1"
VERSION_ENDPOINT = "/api/game/versions"
UPLOAD_ENDPOINT = f"/api/projects/{PROJECT_ID}/upload-file"
MAX_RESPONSE = 8 * 1024 * 1024
MAX_ARCHIVE = 20 * 1024 * 1024
ROOT = Path(__file__).resolve().parents[1]


class ReleaseError(Exception):
    pass


def positive_id(value):
    return type(value) is int and value > 0


def request_json(method, path, token, body=None, content_type=None):
    """Fixed HTTPS host, no redirects/retries, never log secrets or raw bodies."""
    if (method, path) not in {("GET", VERSION_ENDPOINT), ("POST", UPLOAD_ENDPOINT)}:
        raise ReleaseError("Unexpected CurseForge API operation.")
    if not token or "\r" in token or "\n" in token:
        raise ReleaseError("Missing or invalid CurseForge author token.")
    headers = {"X-Api-Token": token, "Accept": "application/json"}
    if content_type:
        headers["Content-Type"] = content_type
    conn = http.client.HTTPSConnection(HOST, timeout=60)
    try:
        conn.request(method, path, body=body, headers=headers)
        response = conn.getresponse()
        if response.status not in (200, 201):
            raise ReleaseError(f"CurseForge {method} returned HTTP {response.status}.")
        raw = response.read(MAX_RESPONSE + 1)
        if len(raw) > MAX_RESPONSE:
            raise ReleaseError("CurseForge response exceeded the size limit.")
        try:
            return json.loads(raw)
        except (ValueError, UnicodeError):
            raise ReleaseError("CurseForge returned invalid JSON.") from None
    except (OSError, http.client.HTTPException, ValueError):
        raise ReleaseError(f"CurseForge {method} transport failed.") from None
    finally:
        conn.close()


def resolve_version(versions):
    if not isinstance(versions, list):
        raise ReleaseError("Unexpected CurseForge game version response.")
    matches = [v for v in versions if isinstance(v, dict)
               and v.get("name") == GAME_VERSION]
    if len(matches) != 1 or not positive_id(matches[0].get("id")):
        raise ReleaseError(f"Expected exactly one valid game version named {GAME_VERSION}.")
    return matches[0]["id"]


def load_release(version, root=ROOT):
    if not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version):
        raise ReleaseError("Expected a stable release version.")
    if tuple(map(int, version.split("."))) <= (2, 6, 2):
        raise ReleaseError("Historical release is blocked.")
    archive = root / "dist" / f"BetterForeverXP-{version}.zip"
    notes = (root / "CURSEFORGE_RELEASE_NOTES.md").read_text(encoding="utf-8-sig")
    heading = f"# Better Forever XP {version}"
    if not notes.splitlines() or notes.splitlines()[0].strip() != heading:
        raise ReleaseError("Release notes do not match version.")
    if not archive.is_file() or not 0 < archive.stat().st_size <= MAX_ARCHIVE:
        raise ReleaseError("Expected exact versioned ZIP within size limit.")
    with zipfile.ZipFile(archive) as z:
        toc = z.read("BetterForeverXP/BetterForeverXP.toc").decode("utf-8-sig")
        if not re.search(r"(?m)^## Version:\s*" + re.escape(version) + r"\s*$", toc):
            raise ReleaseError("Packaged TOC version mismatch.")
        if not re.search(r"(?m)^## Interface:\s*16001\s*$", toc):
            raise ReleaseError("Packaged TOC interface mismatch.")
    return archive, notes


def build_upload(version, game_id, archive, notes):
    if not positive_id(game_id):
        raise ReleaseError("Invalid resolved game version ID.")
    metadata = {
        "displayName": f"Better Forever XP {version}",
        "changelog": notes,
        "changelogType": "markdown",
        "gameVersions": [game_id],
        "releaseType": "release",
    }
    # Only the known local versioned ZIP and JSON metadata enter the form.
    file_bytes = archive.read_bytes()
    if not 0 < len(file_bytes) <= MAX_ARCHIVE:
        raise ReleaseError("Archive exceeded size limit.")
    metadata_bytes = json.dumps(metadata, ensure_ascii=False).encode("utf-8")
    boundary = "bfxp-" + secrets.token_hex(24)
    while boundary.encode() in file_bytes or boundary.encode() in metadata_bytes:
        boundary = "bfxp-" + secrets.token_hex(24)
    b = boundary.encode("ascii")
    body = (
        b"--" + b + b'\r\nContent-Disposition: form-data; name="metadata"\r\n'
        b"Content-Type: application/json; charset=utf-8\r\n\r\n" + metadata_bytes
        + b"\r\n--" + b + b'\r\nContent-Disposition: form-data; name="file"; filename="'
        + archive.name.encode("ascii") + b'"\r\nContent-Type: application/zip\r\n\r\n'
        + file_bytes + b"\r\n--" + b + b"--\r\n"
    )
    return body, f"multipart/form-data; boundary={boundary}"


def require_publish_context(version, env):
    if (env.get("GITHUB_ACTIONS") != "true"
            or env.get("GITHUB_REPOSITORY") != "Dezolve/BetterForeverXP"
            or env.get("GITHUB_EVENT_NAME") != "push"
            or env.get("GITHUB_RUN_ATTEMPT") != "1"
            or env.get("GITHUB_REF") not in ("refs/heads/main", f"refs/tags/v{version}")):
        raise ReleaseError("Publishing requires a first-attempt protected release workflow.")


def publish(version, game_id, archive, notes, token, request=request_json):
    body, content_type = build_upload(version, game_id, archive, notes)
    # Exactly one POST. Network failure, unexpected status or missing ID is
    # uncertain; do not resend the file or move the protected tag.
    try:
        result = request("POST", UPLOAD_ENDPOINT, token, body, content_type)
        if not isinstance(result, dict) or not positive_id(result.get("id")):
            raise ReleaseError("No valid CurseForge file ID returned.")
    except ReleaseError as exc:
        raise ReleaseError(str(exc) + " Reconcile the author dashboard before any recovery; do not retry.") from None
    return result["id"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("preflight", "publish"))
    parser.add_argument("--version", required=True)
    parser.add_argument("--game-version-id", type=int)
    args = parser.parse_args()
    try:
        require_publish_context(args.version, os.environ)
        archive, notes = load_release(args.version)
        token = os.environ.get("CURSEFORGE_TOKEN", "")
        if not token:
            raise ReleaseError("Missing CURSEFORGE_TOKEN.")
        if args.mode == "preflight":
            if args.game_version_id is not None:
                raise ReleaseError("Preflight resolves the game version itself.")
            game_id = resolve_version(request_json("GET", VERSION_ENDPOINT, token))
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                output.write(f"game_version_id={game_id}\n")
            print(f"CurseForge preflight PASS: project {PROJECT_ID}, {GAME_VERSION} (ID {game_id}); no upload.")
        else:
            file_id = publish(args.version, args.game_version_id, archive, notes, token)
            # The remote upload is already done. Receipt is printed first so
            # a subsequent local IO failure cannot obscure the accepted ID.
            url = f"https://www.curseforge.com/wow/addons/better-forever-xp/files/{file_id}"
            print(f"CurseForge accepted file ID {file_id}: {url}", flush=True)
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
                output.write(f"file_id={file_id}\nfile_url={url}\n")
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
                summary.write(f"### CurseForge upload accepted\n\n"
                              f"Version: {args.version} | File ID: {file_id}\n\n"
                              f"[CurseForge file]({url}) (public visibility may be pending).\n")
        return 0
    except ReleaseError as exc:
        print(f"::error::{exc}", file=sys.stderr)
    except (OSError, KeyError, ValueError, zipfile.BadZipFile):
        print("::error::Release file or workflow output error; if upload started, reconcile before recovery.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
