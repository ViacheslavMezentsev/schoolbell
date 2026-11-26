# Preparing releases

[Русский](RELEASING.md) · [Installation](INSTALLATION.en.md) · [Format](formats/release-bundle-v1.md)

Use a GitHub **Pre-release** with explicit supported features and limitations.
A Draft is an unpublished preparation state, not hardware acceptance. The owner
has authorized as-is publication on 2026-11-25: incomplete distribution materials
do not block packaging or publication. Integrity and compatibility checks remain.
Audit status stays separate from permission to publish; no script uploads automatically.

## Public release: four assets

The public preview contains only the wizard ZIP, package ZIP, SHA256SUMS and SHA256SUMS.sig. The standalone IPK is already inside the package ZIP. Build/pair JSON files remain in Actions and local verification evidence, not in the public asset list. Link the public key, allowed-signers and VERIFY.md to the pinned repository revision from the release description.

Actions still produces the complete technical set described below. Before publication, copy only the two ZIPs into a new staging directory, generate SHA256SUMS for those ZIPs and sign that new list. Do not reuse the eight-file Actions checksum list after removing files. Do not rebuild the ZIPs or silently replace published assets. Draft simplification is permitted before publication; retain the original download as evidence. See [signing](RELEASE_SIGNATURES.en.md).

## Assets

- `schoolbell-setup-wizard-v0.3.2-windows-x86_64.zip`: portable GUI with both pinned images.
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

Run **Windows PowerShell 7 / Windows Git** from the repository directory for signing: this project uses the existing SSH key, not WSL GPG. The per-command safe.directory trusts only that checkout. Confirm `ssh` and the configured public key first; replace the tag and build SHA placeholders. If signing fails, stop; never disable signing. **v5.1.127 already exists: do not recreate it.**

```powershell
$releaseRepo = (Get-Item .).FullName.Replace('\', '/')
$releaseTag = 'vX.Y.Z'
$releaseCommit = '<full-build-commit-SHA>'
$releaseGitArgs = @('-c', "safe.directory=$releaseRepo", '-C', $releaseRepo)
git @releaseGitArgs config --get gpg.format
git @releaseGitArgs config --get user.signingkey
git @releaseGitArgs tag -s $releaseTag $releaseCommit -m "Schoolbell $releaseTag preview"
if ($LASTEXITCODE) { throw 'Tag signing failed' }
git @releaseGitArgs verify-tag $releaseTag
if ($LASTEXITCODE) { throw 'Tag verification failed' }
git @releaseGitArgs rev-list -n 1 $releaseTag
```

After successful verification, WSL can push the tag and create a draft with `gh release create --verify-tag --draft --prerelease --latest=false`. Upload the four public assets, review the draft, then publish with `gh release edit TAG --draft=false --prerelease --latest=false`. Check public access without authentication. An `untagged-…` draft URL is not proof of publication; inspect `draft` and `tag_name`.


Upload exact filenames through the Release UI or `gh release upload`; no --clobber
or broad workspace globs. Retain old compatible versions for recovery.

## GitHub Actions artifact preparation — current status

The downloaded 0.3.1 / 5.1.127 pair passed the three core routes and reinstall; see the acceptance report below. Later ZIP-picker/icon changes need a new wizard version before release. Preparation version is 0.3.2; final files still require verification. User entry point: [release guide](GETTING_STARTED.en.md).

Run **Schoolbell release artifacts** (`release-artifacts.yml`) manually on the intended
branch. It runs make all, builds the actual MIPS clock and 35 IPKs, static Windows GUI,
checks embedded images and the extracted executable in a path with a space. The
Windows runner is Server 2022, not Windows 11 hardware acceptance.

Download `schoolbell-v5.1.127-wizard-v0.3.2-windows-x86_64` and extract its outer Actions ZIP.
Attach the contained wizard ZIP, package ZIP, application IPK, target-build.json,
release-pair.json and SHA256SUMS to the Release. Actions retention is 30 days;
Releases are the distribution channel. No tags/releases are created, contents:write
is absent, and no signing key is used. Sign checksums separately with the existing
key. Remote assembly and downloaded pair 0.3.1 passed; a new version needs its own run and HEAD verification.

Local GUI packaging: `python3 scripts/build-wizard-release.py --build out/setup-gui-external --out out/wizard-preview`.
After push: `gh workflow run release-artifacts.yml --ref main`.
MSYS2/Qt versions follow upstream packages: EXE reproducibility across toolchain
versions is not claimed. ZIP packaging is deterministic for identical inputs.
[MSYS2 Action](https://github.com/msys2/setup-msys2) ·
[GitHub artifacts](https://github.com/actions/upload-artifact).

### Windows build environment

GitHub uses UCRT64 and `mingw-w64-ucrt-x86_64-qt6-static`. Pass
`-MsysEnvironment UCRT64`: compiler, Qt and libraries use the same prefix.
Existing local MINGW64 remains available explicitly. Static link dependencies are
listed separately; qt6-static does not install all its build dependencies.
The system-DLL-only check remains. Run 45612351368 passed packages but wizard failed
before compilation: `target not found: mingw-w64-x86_64-qt6-static`.
Rerunning that old run does not update its code; start a new workflow on main after landing.
[UCRT64 package](https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-qt6-static).

2026-11-25 follow-up: UCRT64 and helper tests passed. Qt 6.12 loaded graphics
plugin metadata during find_package and failed on WrapWebP; TIFF was also absent.
Added libwebp and libtiff. Excluding imageformats at link time does not prevent
configuration-time dependency discovery. The Graphs2DImpl warning was not the
terminal error and has not been separately fixed. Full success requires a new
GitHub run after landing.

Local audit covered configure output, CMakeCache.txt, build.ninja and pacman file
owners. WebP/TIFF existed on the development PC but were missing in CI. Other
external libraries are covered; vulkan-loader comes through qt6-static. Comparing
Qt 6.11.2/MINGW64 with the Qt 6.12/UCRT64 log is not full local UCRT64 acceptance.
The workflow preserves wizard-build-diagnostics on failure: configuration, verbose
link/build output, Ninja graph, CMake configuration log/cache and package versions.
These diagnostics are excluded from the public wizard ZIP.

Successful local linking uses Brotli, OpenSSL, JPEG, PNG, HarfBuzz, Graphite2,
FreeType, bzip2, zlib, libb2 and PCRE2. TIFF, WebP and Vulkan also participate in
component discovery; excluding a plugin from the EXE does not remove Qt's
configuration-time requirements. Tools: GCC/binutils, CMake, Ninja and pkgconf;
GCC pulls in binutils. Post-fix make all, fresh static MINGW64 build and six-file
diagnostic capture passed. Full UCRT64 compilation remains a GitHub check.

The next log passed configuration and failed linking test-session-proof: all undefined symbols belong to Winsock and BCrypt. Replacing .dll.a with .a is insufficient: static archives need transitive system dependencies. OPENSSL_USE_STATIC_LIBS is now set before find_package(Qt6); OpenSSL::Crypto propagates crypt32, ws2_32 and bcrypt to every consumer, including QtCore tests. This repairs linking rather than adding packages. A new GitHub run must confirm the complete current UCRT64/Qt 6.12 build.

Post-fix local checks passed: make all, static MINGW64 build, both C++ tests, embedded-image verification and system-only DLL imports. This does not certify the GitHub UCRT64 build.

## Updated artifact acceptance: 0.3.1 / 5.1.127

After push/CI/land, the owner dispatches `release-artifacts.yml` on main. Match the
run headSha to the accepted HEAD, download `schoolbell-v5.1.127-wizard-v0.3.2-windows-x86_64`, and
verify SHA256SUMS and release-pair.json. Extract the wizard into a new folder and
place bundle 5.1.127 beside it; do not mix in locally built workers.

First check EXE startup without MSYS2 on PATH, embedded firmware (`--check-firmware`),
ZIP selection and both themes. Then separately accept OEM restore, OpenWrt,
fresh package installation and reinstall on the test device. Record archive hashes,
source commit, results and limitations before signing sums and preparing the first
release from that exact pair. Local EXE acceptance is not downloaded artifact
acceptance; this does not impose a publication block on the owner.

## Downloaded pair check — 2026-11-26

The downloaded wizard 0.3.1 / Schoolbell 5.1.127 pair passed hash checks, same-version reinstall and the OpenWrt → OEM → OpenWrt → fresh Schoolbell installation cycle. DHCP recovered automatically and the final UI was verified. Clean Windows and exact-build OEM-to-OEM remain separate checks. [Протокол / Report](acceptance/wizard-0.3.1-github.md).

## Next release group

Accept the current GUI/docs changes and assign the next wizard version; unchanged Shkolnik package bytes do not require a version bump. Build the accepted HEAD, download and check the exact archives, and record acceptance limits. Sign the common SHA256SUMS with the existing key; supply the public key, fingerprint and verification commands for that signature format, never the private key. This is separate from Authenticode.

Keep Russian release notes visible and all English text inside `<details>`. Replace filename placeholders and convert relative document links to full URLs pinned to the release tag before copying notes to GitHub. The owner publishes the prerelease; in-app release downloading follows separately.

[Checksum signing and verification](RELEASE_SIGNATURES.en.md). Artifact filenames contain versions, while full commit provenance stays in `release-pair.json` and manifests.
