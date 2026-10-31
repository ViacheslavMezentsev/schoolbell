# Schoolbell native adapter

[Русский](README.md)

Schoolbell specification 1.13: isolated Linux C player adapter and a test child without an audio device; 13 host process/fault groups, FD checks and inherited flock after owner death. No Lua binding, core, madplay/audio or router changes; IPK unchanged.

[API and limits](../../docs/architecture/LINUX_PLAYER.en.md).

`make -C packages/schoolbell/native` · `make test-schoolbell`

Schoolbell spec 1.14: isolated Lua 5.1 Linux player binding, userdata and eight host groups with a fixture process, GC/OOM and recoverable handles. No queue/core, audio device, sound or router/IPK changes.

[Lua binding](../../docs/architecture/LUA_PLAYER.en.md) · `make -C packages/schoolbell/native lua`

[System clock/reference adapter](../../docs/architecture/CLOCK_SYSTEM.en.md): isolated host ports, no router deployment.
