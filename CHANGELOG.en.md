# Changelog

[Русский](CHANGELOG.md)

## Unreleased

- A second `make all` passed in an isolated snapshot containing only staged Git files, without the sibling core checkout or build cache; the host SDK was supplied separately.

- Verified host regressions, payload parity with explained differences, and git land against a temporary local remote. Target MIPS build, real offline bundle and devices are not validated in this stage.

- Imported standalone sources/dependencies with 5.1.28 build and host regressions. Offline bundles no longer require core. No Pages publication or device changes.

- Renamed the default branch to main; updated CI, rules and merge instructions.

- Fixed CI checkout depth: fetch two commits for the HEAD^ to HEAD whitespace check.

- Prepared the standalone WSL repository; archived legacy implementation under
  docs/archive/schoolbell-4 without modifying its contents or rewriting history.
- Added collaboration rules, migration inventory and foundation CI checks.
- Production 5.1.27 remains in core; no IPK, Pages publication or device changes.
