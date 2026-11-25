# Preparing releases

[Русский](RELEASING.md) · [Installation](INSTALLATION.en.md) · [Format](formats/release-bundle-v1.md)

Use a GitHub **Pre-release** with explicit supported features and limitations.
A Draft is an unpublished preparation state, not hardware acceptance. The owner
has authorized as-is publication on 2026-11-25: incomplete distribution materials
do not block packaging or publication. Integrity and compatibility checks remain.
Audit status stays separate from permission to publish; no script uploads automatically.

## Assets

- `schoolbell-setup-wizard-v0.3.0-windows-x86_64.zip`: portable GUI with both pinned images.
- `schoolbell-v5.1.127-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip`: application and dependencies.
- `modbus-schoolbell_5.1.127_all.ipk`: expert application-only asset.
- `target-build.json`, `release-pair.json`, `SHA256SUMS`: provenance, format pairing and hashes.
- Checksum signature from the existing project key and available distribution materials.

GitHub automatic Source code archives do not replace these installable assets.
Wizard and application versions are independent. The package-format minimum wizard
version does not prove acceptance of every future binary pair. In-app downloading
from GitHub is not implemented; users download both ZIPs manually.

## Owner release procedure

1. Commit/sign the reviewed work, push and verify CI for that exact HEAD; land it.
2. Run the artifact workflow on the accepted commit. Review the complete job result.
3. Download the artifact and check its checksums. Test the extracted exact pair on
   clean Windows 11 without development Qt/MSYS2/Python. Record limitations honestly.
4. Update the release note with accepted versions/hashes and available source/license
   materials. Open audit items do not block owner-authorized publication.
5. Sign SHA256SUMS with the existing key. A signed Git commit is not a file signature;
   do not create a new key just to release. Create a signed tag and a draft prerelease.
6. Attach the checked files, download/compare them and publish manually. Never replace
   an already published tag/assets; changed bytes require a new version.

Example only after completing the checks and ensuring the tag is unused:

```sh
git switch main
git pull --ff-only origin main
git status --short
git tag -s v5.1.127 -m "Schoolbell v5.1.127 preview"
git verify-tag v5.1.127
git push origin v5.1.127
gh release create v5.1.127 --verify-tag --draft --prerelease --latest=false --title "Schoolbell 5.1.127 preview" --notes-file docs/releases/v5.1.127.md
```

Upload exact filenames through the Release UI or `gh release upload`; no --clobber
or broad workspace globs. Retain old compatible versions for recovery.

## GitHub Actions artifact preparation — current status

Wizard 0.3.0 embeds both pinned images. On 2026-11-25 OEM recovery and OpenWrt plus
fresh Schoolbell installation passed; SSH host-key rotation required manual repair.
This supersedes earlier pending-transfer statements, not clean-host acceptance.

Run **Schoolbell release artifacts** (`release-artifacts.yml`) manually on the intended
branch. It runs make all, builds the actual MIPS clock and 35 IPKs, static Windows GUI,
checks embedded images and the extracted executable in a path with a space. The
Windows runner is Server 2022, not Windows 11 hardware acceptance.

Download `schoolbell-windows-preview-<commit>` and extract its outer Actions ZIP.
Attach the contained wizard ZIP, package ZIP, application IPK, target-build.json,
release-pair.json and SHA256SUMS to the Release. Actions retention is 30 days;
Releases are the distribution channel. No tags/releases are created, contents:write
is absent, and no signing key is used. Sign checksums separately with the existing
key. The first remote workflow run remains unverified until push.

Local GUI packaging: `python3 scripts/build-wizard-release.py --build out/setup-gui-external --out out/wizard-preview`.
After push: `gh workflow run release-artifacts.yml --ref codex/setup-network-acceptance`.
MSYS2/Qt versions follow upstream packages: EXE reproducibility across toolchain
versions is not claimed. ZIP packaging is deterministic for identical inputs.
[MSYS2 Action](https://github.com/msys2/setup-msys2) ·
[GitHub artifacts](https://github.com/actions/upload-artifact).
