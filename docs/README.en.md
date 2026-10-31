# Shkolnik document map

[Русский](README.md) · [Project](../README.en.md) · [Migration](MIGRATION.md)

## Current state

The standalone candidate is **5.1.28**. Sources and 81 documents were transferred
from pinned 5.1.27. Host checks and the target MIPS bundle passed; a bench upgrade to 5.1.28
was verified. Published Pages acceptance, actual downgrade and fresh hardware
acceptance remain pending. The future Pages root opens
the bell interface directly.

## Find a document

| Task | Document |
| --- | --- |
| Build this repository | [Build and tests](BUILD.en.md) |
| Prepare an offline bundle | [Current packaging](PACKAGING.en.md) |
| Use schedules and melodies | [User guide](user/USER_GUIDE.en.md) |
| Check requirements | [Specification, original revision 1.76 (Russian)](requirements/TECHNICAL_SPECIFICATION.md) |
| Transfer plans | [.sbp](formats/PORTABLE_PLAN.en.md), [wire format](formats/PORTABLE_PLAN_WIRE.en.md) |
| Back up data | [.sbb](formats/BACKUP.en.md) |
| Understand the calendar | [Named ranges](architecture/RANGE_PLANS.en.md) |
| Understand time | [Time trust](architecture/CLOCK_TRUST.en.md), [UI](architecture/CLOCK_UI.en.md) |
| Prepare acceptance | [AC programme](acceptance/ACCEPTANCE.en.md), [original run template](acceptance/ACCEPTANCE_RUN.en.md) |
| Read pre-extraction history | [Package history](history/CHANGELOG.en.md), [original overview](history/README.en.md) |
| Continue development | [Workflow](WORKFLOW.en.md), [TODO](../TODO.md) |

## Reading the transferred material

Files in requirements, architecture, formats, user, acceptance and history retain
the original prose. Only Markdown link destinations changed. Requirement, TC and
AC identifiers, revision history and incomplete statuses were preserved.
Importing a document does not approve the entire specification or repeat acceptance.

Historical versions (including 5.1.22 in the run template), old commands and
`packages/schoolbell` paths, old bench results and Pages status do not describe an
installation from this repository. Use the current BUILD/PACKAGING documents above.
The [source map](source-map.json) records path mappings and hashes. References to
material not yet transferred point at the pinned source commit.

A new run needs its own protocol with actual versions, SHA-256 hashes, target and
results. Do not count historical checks as newly passed. Backups, keys and hardware
logs must not enter Git. The Pages installation guide and training will be migrated
separately; this branch neither publishes the site nor changes devices.

## Complete transferred document catalogue

### Requirements

| Document | Languages |
| --- | --- |
| ТЕХНИЧЕСКОЕ ЗАДАНИЕ: пакет schoolbell | [RU](requirements/TECHNICAL_SPECIFICATION.md) |

### User

| Document | Languages |
| --- | --- |
| Schoolbell user guide | [RU](user/USER_GUIDE.md) · [EN](user/USER_GUIDE.en.md) |

### Formats and data transfer

| Document | Languages |
| --- | --- |
| Schoolbell backup | [RU](formats/BACKUP.md) · [EN](formats/BACKUP.en.md) |
| Media catalog, quotas and commit protocol | [RU](formats/MEDIA_FORMAT.md) · [EN](formats/MEDIA_FORMAT.en.md) |
| Portable calendar plan .sbp | [RU](formats/PORTABLE_PLAN.md) · [EN](formats/PORTABLE_PLAN.en.md) |
| Isolated .sbp codec | [RU](formats/PORTABLE_PLAN_CODEC.md) · [EN](formats/PORTABLE_PLAN_CODEC.en.md) |
| Assembling an exported .sbp | [RU](formats/PORTABLE_PLAN_EXPORT.md) · [EN](formats/PORTABLE_PLAN_EXPORT.en.md) |
| Selected-plan export from the device | [RU](formats/PORTABLE_PLAN_EXPORT_DEVICE.md) · [EN](formats/PORTABLE_PLAN_EXPORT_DEVICE.en.md) |
| Import a calendar plan on a device | [RU](formats/PORTABLE_PLAN_IMPORT.md) · [EN](formats/PORTABLE_PLAN_IMPORT.en.md) |
| Pages: .sbp export and import preview | [RU](formats/PORTABLE_PLAN_PAGES.md) · [EN](formats/PORTABLE_PLAN_PAGES.en.md) |
| .sbp import preview model | [RU](formats/PORTABLE_PLAN_PREVIEW.md) · [EN](formats/PORTABLE_PLAN_PREVIEW.en.md) |
| .sbp wire format and import operation | [RU](formats/PORTABLE_PLAN_WIRE.md) · [EN](formats/PORTABLE_PLAN_WIRE.en.md) |

### Architecture and implementation

| Document | Languages |
| --- | --- |
| Annual calendar and preview | [RU](architecture/ANNUAL_CALENDAR.md) · [EN](architecture/ANNUAL_CALENDAR.en.md) |
| Schoolbell schedule calculator | [RU](architecture/CALENDAR.md) · [EN](architecture/CALENDAR.en.md) |
| Clock control in the executor | [RU](architecture/CLOCK_EXECUTOR.md) · [EN](architecture/CLOCK_EXECUTOR.en.md) |
| System clock reference adapter | [RU](architecture/CLOCK_SYSTEM.md) · [EN](architecture/CLOCK_SYSTEM.en.md) |
| Schoolbell clock trust | [RU](architecture/CLOCK_TRUST.md) · [EN](architecture/CLOCK_TRUST.en.md) |
| Isolated clock trust model | [RU](architecture/CLOCK_TRUST_MODEL.md) · [EN](architecture/CLOCK_TRUST_MODEL.en.md) |
| Time confirmation and native dependency | [RU](architecture/CLOCK_UI.md) · [EN](architecture/CLOCK_UI.en.md) |
| Isolated Linux schoolbell player adapter | [RU](architecture/LINUX_PLAYER.md) · [EN](architecture/LINUX_PLAYER.en.md) |
| Linux player Lua binding | [RU](architecture/LUA_PLAYER.md) · [EN](architecture/LUA_PLAYER.en.md) |
| Admission-time media revision retention | [RU](architecture/MEDIA_ADMISSION.md) · [EN](architecture/MEDIA_ADMISSION.en.md) |
| Isolated media manager | [RU](architecture/MEDIA_MANAGER.md) · [EN](architecture/MEDIA_MANAGER.en.md) |
| Persistent schoolbell media library | [RU](architecture/MEDIA_PERSISTENCE.md) · [EN](architecture/MEDIA_PERSISTENCE.en.md) |
| Melody uploads (engineering profile) | [RU](architecture/MEDIA_UPLOAD.md) · [EN](architecture/MEDIA_UPLOAD.en.md) |
| Schoolbell IPK and offline bundle | [RU](architecture/PACKAGING.md) · [EN](architecture/PACKAGING.en.md) |
| Isolated schoolbell queue | [RU](architecture/PLAYBACK_QUEUE.md) · [EN](architecture/PLAYBACK_QUEUE.en.md) |
| Schoolbell player adapter contract | [RU](architecture/PLAYER_ADAPTER.md) · [EN](architecture/PLAYER_ADAPTER.en.md) |
| Isolated player codec and API model | [RU](architecture/PLAYER_MODEL.md) · [EN](architecture/PLAYER_MODEL.en.md) |
| Player results, errors and budgets | [RU](architecture/PLAYER_RESULTS.md) · [EN](architecture/PLAYER_RESULTS.en.md) |
| Player system mechanisms and asynchronous API | [RU](architecture/PLAYER_SYSTEM_API.md) · [EN](architecture/PLAYER_SYSTEM_API.en.md) |
| Player frame constants, generations and parameter ranges | [RU](architecture/PLAYER_WIRE.md) · [EN](architecture/PLAYER_WIRE.en.md) |
| Queue and Linux player composition | [RU](architecture/QUEUE_LINUX.md) · [EN](architecture/QUEUE_LINUX.en.md) |
| Calendar plans — schoolbell 5.1.0 | [RU](architecture/RANGE_PLANS.md) · [EN](architecture/RANGE_PLANS.en.md) |
| Saved schedule editor | [RU](architecture/SCHEDULE_EDITOR.md) · [EN](architecture/SCHEDULE_EDITOR.en.md) |
| Schoolbell 5.0.31 startup audit | [RU](architecture/STARTUP_AUDIT.md) · [EN](architecture/STARTUP_AUDIT.en.md) |
| Schoolbell UI completeness and improvement plan | [RU](architecture/UI_COMPLETENESS.md) · [EN](architecture/UI_COMPLETENESS.en.md) |

### Acceptance

| Document | Languages |
| --- | --- |
| Schoolbell 5.x acceptance programme | [RU](acceptance/ACCEPTANCE.md) · [EN](acceptance/ACCEPTANCE.en.md) |
| Shkolnik end-to-end acceptance on a new device | [RU](acceptance/ACCEPTANCE_RUN.md) · [EN](acceptance/ACCEPTANCE_RUN.en.md) |

### Extracted package history

| Document | Languages |
| --- | --- |
| Changelog | [RU](history/CHANGELOG.md) · [EN](history/CHANGELOG.en.md) |
| Schoolbell package | [RU](history/README.md) · [EN](history/README.en.md) |

[Legacy implementation archive](archive/schoolbell-4/README.en.md) · [Source inventory](migration-inventory.json) · [Source hashes and path map](source-map.json)

[Pages build and publication](../site/README.en.md)

[License and provenance audit](LICENSE_AUDIT.en.md)

[MIT license and scope](LICENSING.en.md)
