# Changelog

[Русский](CHANGELOG.md)

## Unreleased

- All 75 installed files match the IPKs. The owner confirmed version 5.1.28 and existing data in the UI.

- Verified 5.1.27 → 5.1.28 upgrade from the standalone repository and target native 1.0.0 loading on the separately authorized development bench. Backup and rollback files were checked first; backup contents were preserved, automatic bells stayed off, and system/NTP settings remained unchanged. Downgrade and full hardware acceptance remain untested.

- Full make all passed: host regressions, package lifecycle and Pages; pinned cache checks, ELF and MIPS Lua/QEMU checks also passed. This is not installation or hardware acceptance.

- Added standalone MIPS builds with pinned SDK/Lua sources and 33 dependencies. Verified offline rebuild, stable native IPK, ELF ABI and QEMU loading. Devices unchanged; hardware acceptance remains separate.

- Validation: full make all and Pages-specific tests passed; a local browser verified the root UI, calendar, guide/training navigation and return. No sound or device commands were executed. Publication remains unverified.

- Migrated Pages build: root bell UI, separate RU/EN guide/training and device pages. Added explicit legacy draft copy to a new localStorage key without overwriting existing data; old data remains intact. Issue forms target schoolbell. Deployment is owner-triggered only; devices and IPK version unchanged.

- Made README compact following stm32-gdbtest and added complete RU/EN document maps. Verified all 81 transferred texts, local links and 11 pinned core references. Full make all passed; this is host validation, not new hardware acceptance.

- Accepted the user-provided FUNDING.yml without changing its link. Transferred 81 documents, preserving prose, requirements and TC identifiers; added a bilingual index distinguishing historical evidence from the current build. M1 accepted by the owner; Pages, devices and the IPK version remain unchanged.

- A second `make all` passed in an isolated snapshot containing only staged Git files, without the sibling core checkout or build cache; the host SDK was supplied separately.

- Verified host regressions, payload parity with explained differences, and git land against a temporary local remote. Target MIPS build, real offline bundle and devices are not validated in this stage.

- Imported standalone sources/dependencies with 5.1.28 build and host regressions. Offline bundles no longer require core. No Pages publication or device changes.

- Renamed the default branch to main; updated CI, rules and merge instructions.

- Fixed CI checkout depth: fetch two commits for the HEAD^ to HEAD whitespace check.

- Prepared the standalone WSL repository; archived legacy implementation under
  docs/archive/schoolbell-4 without modifying its contents or rewriting history.
- Added collaboration rules, migration inventory and foundation CI checks.
- Production 5.1.27 remains in core; no IPK, Pages publication or device changes.
