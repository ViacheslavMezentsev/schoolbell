# Shkolnik

[![CI](https://img.shields.io/github/actions/workflow/status/ViacheslavMezentsev/schoolbell/ci.yml?branch=main&label=CI&style=flat-square)](https://github.com/ViacheslavMezentsev/schoolbell/actions/workflows/ci.yml)

[Русский](README.md)

**Shkolnik is a configurable musical school bell for OpenWrt, managed in a browser.**
Schedules and calendar plans run on the device without an open browser page.

## Features

- Named date-range plans, calendar painting and preview.
- Built-in and user MP3 melodies, pre-bells, manual ringing and muting.
- Clock comparison and setting, event journal, `.sbb` backups and `.sbp` plan transfer.

## Build and test

After preparing the [host dependencies](docs/BUILD.en.md):

```sh
make all
```

Builds the IPK and runs host tests without accessing a device.
The [offline dependency bundle](docs/PACKAGING.en.md) is prepared separately.

## Status

Package **5.1.121** targets OpenWrt 19.07.9 on the TL-MR3020 v3.

Resources show independent Internet and NTP states. Settings → Interface lets you disable the Internet probe for offline operation or change its target. An unconfirmed result means no reply from that target, not proof of an outage. NTP requires an explicit stratum event from the current service within 15 minutes. Periodic notifications do not renew confirmation. No fresh confirmation does not imply incorrect time: BusyBox does not report every successful exchange, so a stable stratum can leave synchronization unconfirmed even when it works. These indicators do not control automatic bells. Probe settings are separate from portable .sbb backups.

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

[btop for MR3020](tools/btop/README.md) · [Offline Windows 11 setup](tools/setup/README.md)

Pages includes a Device simulator below Metrics. Apply a saved plan in Settings, enable ▶, then use Next bell or accelerated time. Silent simulated events appear in the journal and activity map; audio, Internet and NTP are modeled. Reopening the page disables automation. This does not test hardware.

Collapsed Metrics shows free flash, saved volume and Internet status on the right. The summary reuses the expanded panel’s cached readings without extra network probes.
