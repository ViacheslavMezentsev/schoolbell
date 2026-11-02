# Shkolnik

[![CI](https://img.shields.io/github/actions/workflow/status/ViacheslavMezentsev/schoolbell/ci.yml?branch=main&label=CI&style=flat-square)](https://github.com/ViacheslavMezentsev/schoolbell/actions/workflows/ci.yml)

[Русский](README.md)

**Shkolnik is a configurable musical school bell for OpenWrt, managed in a browser.**
Schedules and calendar plans run on the device without an open browser page.

## Features

- Named date-range plans, calendar painting and preview.
- Built-in and user MP3 melodies, pre-bells, manual ringing and muting.
- Time trust checks, event journal, `.sbb` backups and `.sbp` plan transfer.

## Build and test

After preparing the [host dependencies](docs/BUILD.en.md):

```sh
make all
```

Builds the IPK and runs host tests without accessing a device.
The [offline dependency bundle](docs/PACKAGING.en.md) is prepared separately.

## Status

Extraction from openwrt-modbus-core is in progress: candidate **5.1.79**, baseline
OpenWrt 19.07.9 / TL-MR3020 v3. Host checks and the target MIPS bundle are ready;
published Pages verification and new hardware acceptance remain pending. [Migration plan](docs/MIGRATION.md).

## Documentation

[Document map](docs/README.en.md) · [User guide](docs/user/USER_GUIDE.en.md) ·
[Specification (Russian)](docs/requirements/TECHNICAL_SPECIFICATION.md) · [Acceptance](docs/acceptance/ACCEPTANCE.en.md) ·
[TODO](TODO.md) · [Changelog](CHANGELOG.en.md) · [Workflow](docs/WORKFLOW.en.md)

Author: Viacheslav Mezentsev. Modern implementation co-author: Codex (OpenAI).
[Project rules](AGENTS.md) · [Schoolbell-4 historical archive](docs/archive/schoolbell-4/README.en.md).

[License and provenance audit](docs/LICENSE_AUDIT.en.md)

## License

Own code and documentation: [MIT](LICENSE). Audio, historical archive and
third-party components are excluded; see [scope](docs/LICENSING.en.md) and [NOTICE](NOTICE).

Below Flash, saved volume is on the left and the default `/dev/dsp` controller/card name is on the right, followed by the volume bar. Missing output is explicit; other cards are not selected automatically. Volume steps from 0 to 100 % in increments of 10 map to the nearest supported gain, not measured loudness. Flash uses MiB (1024² bytes), with blue fill up to 75 %.
