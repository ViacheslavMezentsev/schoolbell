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
