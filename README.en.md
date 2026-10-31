# Shkolnik

[Русский](README.md) · [Workflow](docs/WORKFLOW.en.md) · [Migration](docs/MIGRATION.md)

Configurable musical school bell. Author: Viacheslav Mezentsev.
Modern implementation development co-author: Codex (OpenAI).

**Standalone repository preparation; production code has not been transferred.**
Version 5.1.27 remains in
[openwrt-modbus-core](https://github.com/ViacheslavMezentsev/openwrt-modbus-core).
The previous implementation is preserved in the [archive](docs/archive/schoolbell-4/README.en.md).
This stage builds no IPK, publishes no Pages and changes no devices.

Run `python3 scripts/check-foundation.py` for this stage. See [TODO](TODO.md).
The eventual standalone build must require no sibling core checkout. Until the
migration is complete, core remains the only production source.
