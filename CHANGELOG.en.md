# Changelog

[Русский](CHANGELOG.md)

## Unreleased

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
