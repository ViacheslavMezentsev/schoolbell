# Самостоятельная сборка IPK

[English](PACKAGING.en.md)

`make build verify` собирает Lua/UI IPK и проверяет payload без сети и устройства.
Нативная зависимость — отдельный modbus-schoolbell-clock 1.0.0; её host-тесты
не являются MIPS-сборкой. Для целевого IPK:

```sh
python3 scripts/build-schoolbell-clock.py --cc /path/to/mipsel-openwrt-linux-musl-gcc --include /path/to/lua51/include --out out/native
python3 scripts/build-schoolbell-bundle.py --schoolbell out/modbus-schoolbell_5.1.28_all.ipk --native out/native/modbus-schoolbell-clock_1.0.0_mipsel_24kc.ipk --cache out/offline-cache --out out/release
```

В cache заранее нужны IPK из packaging/offline/openwrt-19.07.9-mipsel_24kc.json.
Только явный --download разрешает загрузку недостающих файлов с downloads.openwrt.org;
размеры и SHA-256 проверяются. --core необязателен для совместного комплекта.
Нужны OpenWrt 19.07.9, ramips/mt76x8, mipsel_24kc, musl, Lua 5.1; kernel ABI
и libc проверяются по lock. Нельзя заменять toolchain произвольным MIPS GCC.
Сборщик проверяет ELF архитектуру, но это не полная проверка ABI: использовать
toolchain целевой прошивки и проверить на стенде отдельно.

Комплект содержит manifest, SHA256SUMS и read-only check.sh, но не подписанный
release manifest. Релиз собирается из принятого чистого SHA. Сборка не устанавливает
пакеты, не меняет часы/NTP и не включает звонки. Архив docs/archive не входит в IPK.
Кандидат переноса — 5.1.28 на базе 5.1.27. Проверяется отличие payload;
релиз и установка пока не предлагаются.

## Целевой комплект из самостоятельного репозитория

На Linux x86_64 нужны Python 3.8+, tar с xz, patch и средства запуска SDK.
SDK содержит GCC 7.5.0/musl для mipsel_24kc. Заголовки берутся из Lua 5.1.5
со всеми target-патчами OpenWrt v19.07.9, а не из host Lua. Исходные архивы,
их размеры, URL и SHA-256 закреплены в `packaging/offline/toolchain-19.07.9.json`.
SDK-хэш сверен с официальным sha256sums; Lua-хэш — с Makefile OpenWrt.
Хэш исходного архива OpenWrt фиксирует полученные байты, не является подписью издателя.

```sh
python3 scripts/build-target.py --download --out out/mips-first
# Повторная сборка без сети из тех же кешей:
python3 scripts/build-target.py --out out/mips-offline
# Дополнительно: загрузка модуля настоящим MIPS Lua под QEMU на хосте:
python3 scripts/build-target.py --out out/mips-smoke --qemu qemu-mipsel
```

`--download` разрешает только получение отсутствующих архивов и IPK. Повреждённый
кеш отклоняется, не заменяется молча. Каталог результата должен быть новым.
`--cache` задаёт кеш SDK/исходников, `--dependencies` — кеш 33 сторонних IPK.
Для работы без сети заранее перенесите оба кеша; соседний core не требуется.
Сборщик не подключается к устройствам и ничего не устанавливает.

Результат: `script/` (5.1.28), `native/` (1.0.0, manifest и ELF-аудит),
`bundle/` (35 IPK, manifest, SHA256SUMS, зависимости, read-only check.sh и
инструкции), `build-provenance.json` (SDK, заголовки и результат QEMU).
Библиотека проверяется как ELF32 LE MIPS32r2/o32 soft-float; ожидаются libc.so
и libgcc_s.so.1. QEMU проверяет загрузку, не аппаратную работу часов/flash.

Проверено локально: две сборки в разных временных каталогах дали одинаковый
нативный IPK `24c07345de6409a89a3c74469e767c8fec440c73c70ed0ef008706d7bf48331b`;
библиотека — 17 924 байта. Все закреплённые зависимости скачаны и проверены,
замыкание зависимостей и SHA256SUMS прошли. IPK вместе занимают 1 427 456 байт,
суммарные распакованные файлы — 2 988 309 байт. Оценка с округлением файлов
до 4 КиБ — 3 670 016 байт: это не требуемое дополнительное место на устройстве
(часть зависимостей уже в firmware), не гарантия сжатия JFFS2 и не проверка RAM.
Нативный gzip имеет фиксированную дату, чтобы повторная упаковка была стабильной.

Комплект рассчитан только на закреплённый профиль и kernel ABI. libc/kernel
остаются требованиями firmware; не включаются для принудительной замены.
Для релиза используйте чистый подписанный HEAD; manifest сообщает dirty-состояние.
Полный SDK/архивы/IPK остаются в ignored out, не в Git. Публикация, лицензии
распространяемого комплекта и установка/обновление/откат на стенде — отдельные этапы.
