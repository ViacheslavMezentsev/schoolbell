# Shkolnik

[Русский](README.md) · [Start installation](docs/GETTING_STARTED.en.md) · [User guide](docs/user/USER_GUIDE.en.md)

**Shkolnik is a musical school bell running on a small router.** It plays melodies according to schedules and a calendar plan. Manage it in a computer or phone browser; the browser does not need to remain open for bells to run.

Set regular days and holidays, pre-bells and custom melodies, ring manually or mute the output. Once configured, bells can run without Internet access; check the device clock before enabling them.

## What the project includes

- **Shkolnik** — browser-based schedules, calendar, melodies and bell journal.
- **Setup Wizard for Windows** — install OpenWrt, install a Shkolnik bundle or restore stock firmware.
- **Installation bundle** — a separate ZIP containing Shkolnik, required packages and instructions.
- **Demo and guides** — explore the interface and assemble your system.

## What you need

| Equipment | Recommendation |
| --- | --- |
| Router and power supply | Tested wizard profile: **TP-Link TL-MR3020 (EU) Ver. 3.30**. This revision has USB Type-C power; check the label for the exact revision. |
| USB audio adapter | Tested devices identify as **AB13X USB Audio** and **C-Media USB PnP Sound Device**. |
| USB hub, if needed | For now use a connection where the audio adapter shows **OHCI** under Metrics → Resources. The tested hub/EHCI combination had playback startup failures. |
| Speakers | Powered speakers, or an amplifier and speakers, with a cable to the audio adapter. |
| Installation equipment | Windows 11 x64 PC, dedicated **USB–Ethernet adapter**, Ethernet cable and router power supply. |

OHCI identifies the connection controller, not a hub brand. The label alone does not guarantee compatibility: check audible scheduled bells before use. [Tested connections and limits](docs/HARDWARE.en.md).

## Get started

1. Prepare the equipment above.
2. Follow [the release download guide](docs/GETTING_STARTED.en.md) to choose the files and wizard scenario.
3. Configure the calendar, schedule and sound using the [user guide](docs/user/USER_GUIDE.en.md).

[Releases and installers](https://github.com/ViacheslavMezentsev/schoolbell/releases) · [Interface demo](https://viacheslavmezentsev.github.io/schoolbell/)

## For contributors

[Documentation](docs/README.en.md) · [Build](docs/BUILD.en.md) · [Developer memo](TODO.md) · [Changelog](CHANGELOG.en.md)

Author: Viacheslav Mezentsev. Modern implementation co-author: Codex (OpenAI).
Own code and documentation: [MIT](LICENSE); audio and third-party components have separate terms: [licensing](docs/LICENSING.en.md), [NOTICE](NOTICE).
