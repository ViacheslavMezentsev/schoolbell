# Сборка и проверки на хосте

[English](BUILD.en.md) · [IPK и зависимости](PACKAGING.md)

Linux/WSL, Python 3.8+, Node.js 18+, make, GCC, libc headers, Lua 5.1 и
liblua5.1-0-dev. На Ubuntu: `sudo apt-get install lua5.1 liblua5.1-0-dev gcc libc6-dev make python3 nodejs`.
Версию Node проверить: `node --version`. Для неподходящей версии использовать
поддерживаемую установку Node 18+; не устанавливать инструменты на устройство.

```sh
make all
```

Команда выполняет проверку архива/документов, сборку скриптового IPK, проверку
состава, C/Lua/player child, календарь, медиатеку, .sbb/.sbp, HTTP/UI,
clock fault injection и package lifecycle. Реального звука, доступа к устройствам,
изменения host-часов и NTP нет. Тесты используют временные каталоги и подмену
команд; native player запускает только тестовый child. Нет зависимости от core.

LUA_CFLAGS и LUA_LIBS позволяют указать отдельно установленный Lua SDK.
Lua5.1 должен быть в PATH; LD_LIBRARY_PATH нужен для локальной shared library.
Не копировать SDK в Git. `make build verify` не требует компилятора или Lua.

`make all` не делает целевой MIPS IPK часов, загрузку реальных offline-зависимостей,
публикацию Pages или аппаратную приёмку. Сборка и проверки Pages входят в make all. Native clock проверяется на хосте;
целевая сборка и ABI — отдельная команда, описанная в PACKAGING.
Offline-тесты используют синтетические IPK для ошибок замыкания/хешей/архитектуры,
не выдают их за пригодные к установке зависимости.

Исходники: src/lua, src/native, src/portable-plan; интерфейс ui/root;
системные файлы packaging/openwrt/root; метаданные packaging/openwrt/package;
vendor/modbus содержит strict JSON. site хранит демо, руководство и обучение; публикация Pages выполняется владельцем отдельно.

CI Schoolbell CI запускает make all. Перед land проверять успешный ci-gate
для отправленного SHA. Наличие собранного IPK не означает разрешение установки.
