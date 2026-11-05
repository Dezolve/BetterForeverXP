# Better Forever XP — Release Runbook

This is the permanent release procedure for [Better Forever XP](https://www.curseforge.com/wow/addons/better-forever-xp) (CurseForge project **1731462**).

**Release signal:** Push a new version tag such as `v2.6.1` or `v2.7.0` to an already-reviewed commit on `main`. GitHub Actions validates, packages, and publishes the corresponding ZIP through the existing `CURSEFORGE_API_TOKEN` secret.

**Do not tag 2.6.0 again.** Version 2.6.0 was published using our old, one-time main-branch workflow. This process accepts only versions **newer than 2.6.0**.

## One-time protection setup (required before the first new release tag)

The publishing job **fails closed** until this configuration exists.

1. Go to [repository Settings → Rules → Rulesets](https://github.com/Dezolve/BetterForeverXP/settings/rules), then **New ruleset → New tag ruleset**.
2. Set **Ruleset name** to the exact string `BFXP Release Tags`.
3. Set **Enforcement** to **Active**.
4. Under **Target tags**, add a pattern matching `v*` (version tags).
5. Turn on **Restrict updates** and **Restrict deletions**. The workflow verifies that both restrictions exist.
6. Optionally also enable **Restrict creations** if you configure an explicit admin bypass that still allows the owner to create new release tags. Do not lock out the release operator.
7. Save the ruleset. Double-check that a normal collaborator cannot move or delete a version tag. Keep bypass access minimal.

The workflow checks for an active repository tag ruleset called `BFXP Release Tags` with update and deletion restrictions. A matching name alone is insufficient. The Ruleset lives in GitHub repository settings, not source control. **As of 2026-11-04, repository rulesets were empty; this step had not been completed through our connected GitHub tools.**

The existing repository secret `CURSEFORGE_API_TOKEN` should remain stored in **Settings → Secrets and variables → Actions**. Do not copy the key into files, chat, or logs.

For additional protection, enable a `main` branch ruleset requiring pull requests and the `Validate and package` status check. This prevents unreviewed release files from reaching the main branch.

## For each future release

1. Develop and test the change on a feature branch. Verify the actual addon in-game when possible.
2. Update these files together in the release PR:
   - `BetterForeverXP/BetterForeverXP.toc` → `## Version: X.Y.Z`
   - `CURSEFORGE_RELEASE_NOTES.md` → first heading `# Better Forever XP X.Y.Z`
   - `BetterForeverXP/CHANGELOG.md` → add `# Better Forever XP X.Y.Z` as the first heading, retaining history
   - `README.md` and `CURSEFORGE_DESCRIPTION.md` when user-facing features change
3. Run the local checks (PowerShell):

   ```powershell
   ./scripts/Test-Release.ps1
   ./scripts/Test-Addon.ps1
   ./scripts/Package-Addon.ps1
   ```

4. Open and merge the reviewed PR into `main` after **Validate and package** passes. **The merge does not publish.**
5. Create **one new annotated release tag**, pointing at the merged `main` commit:

   ```powershell
   git switch main
   git pull --ff-only origin main
   git status --short
   git tag -a v2.7.0 -m "Better Forever XP 2.7.0"
   git push origin v2.7.0
   ```

   Replace `2.7.0` with the **exact version in the TOC and release notes**. Do not tag an unmerged feature-branch commit. Before pushing, check that the version tag does not already exist: `git ls-remote --tags origin v2.7.0` should show no match.

6. The tag push automatically starts [Publish Better Forever XP to CurseForge](https://github.com/Dezolve/BetterForeverXP/actions/workflows/publish-curseforge.yml).
7. Verify that **Validate tagged release and publish** succeeds, including the **Upload to CurseForge** step. A passing GitHub upload step confirms the API action succeeded, but CurseForge may take additional time to list/review the file.
8. Verify the version under [CurseForge Files](https://www.curseforge.com/wow/addons/better-forever-xp/files). The release ZIP is also attached as an artifact to the GitHub Actions run for audit. Update the public CurseForge description separately if needed.

### Checks automatically enforced on every tag publish

- The event must be a tag push matching a stable `vMAJOR.MINOR.PATCH` version (no `-beta` or `+build` suffix).
- The tag must point at a commit already merged into `main`. The workflow checks out that **tagged commit**, not a moving branch head.
- `Test-Release.ps1 -Tag ...` requires exact agreement between the tag, TOC version, first heading of release notes, and first heading of the changelog. It also checks WoW Forever Interface `16001`.
- Versions up to and including `2.6.0` are rejected to avoid reposting old releases.
- An active `BFXP Release Tags` ruleset must restrict changes and deletions of version tags.
- Addon syntax, existing assertions, and packaging all run before API upload.
- The release type is fixed as `release`; the CurseForge project ID and target game version are fixed.
- `CURSEFORGE_API_TOKEN` remains a GitHub Actions secret. Normal pushes, PRs, and CI runs cannot upload.
- Publishing runs are serialized. **Rerunning the same workflow is rejected** to reduce the risk of duplicate uploads.

## Troubleshooting and recovery

- **No publish workflow appears:** Check that the pushed tag is new, is spelled `vX.Y.Z`, and points to a commit containing the publishing workflow. Pushing a tag from a workflow using the default `GITHUB_TOKEN` may not trigger another workflow; push from your authenticated Git client instead.
- **Tag ruleset guard fails:** Configure the one-time ruleset *before* cutting a release tag. Do not disable the guard to publish.
- **Version or notes mismatch:** Fix the files through a new PR, merge, and cut a **new** version tag. Do not move or force-push an existing release tag.
- **Missing API token:** Check the GitHub Actions repository secret `CURSEFORGE_API_TOKEN` (do not print its value).
- **Job failed after starting the upload:** Check the [CurseForge Files](https://www.curseforge.com/wow/addons/better-forever-xp/files) page before doing anything else. The external upload may have succeeded even if the workflow later failed.
- **Do not click Re-run to publish again.** The workflow explicitly refuses a second attempt for the same run. If recovery is needed, determine whether CurseForge accepted the upload, reconcile the release state, then prepare a new reviewed version and tag.
- **CurseForge file not visible immediately:** Confirm the Upload step succeeded, then check the site's processing/review status. Never infer public availability from the GitHub job alone.

## Why this replaces the older process

In October and November 2026, releases 2.5.0 and 2.6.0 used **temporary, version-specific main-branch push triggers**, followed by restoration to manual-only mode. This worked but required workflow edits for every release.

Version tags are now the release approval signal. Future releases require no workflow edits, no manual GitHub workflow dispatch, and no local CurseForge ZIP upload. The remaining intentional actions are to approve/merge the release PR and create a protected version tag.

**Security note:** Tag ruleset configuration is external repository administration and cannot be installed by committing this file. The publisher will remain blocked until the administrator completes the one-time rule setup.
