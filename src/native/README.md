# Нативный адаптер schoolbell

[English](README.en.md)

ТЗ schoolbell 1.13: изолированный Linux C-адаптер проигрывателя и тестовый ребёнок без аудиоустройства; 13 host-групп процессов/отказов, FD и наследование flock после аварии владельца. Без Lua binding, ядра, madplay/звука и изменений роутера; IPK прежний.

[API и ограничения](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/docs/packages/schoolbell/LINUX_PLAYER.md).

`make -C packages/schoolbell/native` · `make test-schoolbell`

ТЗ schoolbell 1.14: изолированная Lua 5.1-привязка Linux player, userdata и восемь host-групп с тестовым процессом, GC/OOM и восстановлением handles. Без очереди/ядра, аудиоустройства, звука и изменений роутера/IPK.

[Lua binding](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/docs/packages/schoolbell/LUA_PLAYER.md) · `make -C packages/schoolbell/native lua`

[Системный адаптер часов и опоры](https://github.com/ViacheslavMezentsev/openwrt-modbus-core/blob/243a7ccad6aeb2499d3efd5d0c4cef9e822d393e/docs/packages/schoolbell/CLOCK_SYSTEM.md): изолированные host-порты, без установки на роутер.
