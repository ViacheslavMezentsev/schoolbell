# btop для TP-Link TL-MR3020 v3

Готовая статическая сборка btop 1.4.8 для OpenWrt 19.07.9, ramips/mt76x8, MIPS32r2 little-endian, soft-float. Каталог содержит архив `.tar.xz` с программой и лицензиями, файл `.sha256` для проверки и скрипт пересборки `build-linux.sh`.

## Windows 11 · PowerShell

Откройте PowerShell в каталоге `tools/btop` (или в папке с архивом и его файлом `.sha256`). Используется SSH-псевдоним `openwrt` из конфигурации Windows OpenSSH.

```powershell
$archive = 'btop-1.4.8-openwrt-19.07.9-mipsel_24kc.tar.xz'
$expected = ((Get-Content -LiteralPath "$archive.sha256" -Raw).Trim() -split '\s+')[0]
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) { throw 'Ошибка SHA-256 архива' }

tar.exe -xf $archive -C $env:TEMP btop/bin/btop
if ($LASTEXITCODE -ne 0) { throw 'Ошибка распаковки' }
scp.exe -O "$env:TEMP/btop/bin/btop" openwrt:/tmp/btop.new
if ($LASTEXITCODE -ne 0) { throw 'Ошибка копирования' }
ssh.exe -t openwrt 'chmod 700 /tmp/btop.new && mv -f /tmp/btop.new /tmp/btop && HOME=/tmp XDG_CONFIG_HOME=/tmp/btop-config /tmp/btop --force-utf'
```

`-O` — заглавная латинская O. Windows OpenSSH 9.5 по умолчанию использует SFTP, а на данном OpenWrt доступен SCP. Ключ `-t` нужен для интерактивного экрана. Выход — клавиша `q`. До перезагрузки роутера монитор можно запускать повторно:

```powershell
ssh.exe -t openwrt 'HOME=/tmp XDG_CONFIG_HOME=/tmp/btop-config /tmp/btop --force-utf'
```

## Linux / WSL · запуск через SSH

Выполните команды **на ПК в Linux или WSL** из каталога `tools/btop`. В примере `openwrt` — настроенный SSH-псевдоним вашего роутера. При необходимости замените его на `root@адрес-роутера`.

```sh
archive=btop-1.4.8-openwrt-19.07.9-mipsel_24kc.tar.xz
sha256sum -c "$archive.sha256" && tar -xJf "$archive" && \
    ssh openwrt 'umask 077; p=$(mktemp /tmp/btop.XXXXXX) && cat > "$p" && chmod 700 "$p" && mv "$p" /tmp/btop' < btop/bin/btop
```

Затем откройте монитор:

```sh
ssh -t openwrt 'HOME=/tmp XDG_CONFIG_HOME=/tmp/btop-config /tmp/btop --force-utf'
```

`-t` выделяет терминал. Используйте терминал с UTF-8. Для выхода нажмите `q`. Программа и настройки находятся в RAM до перезагрузки. Распаковка выполняется на ПК, поэтому роутеру не требуется поддержка xz.

## Состав и проверка

- `btop/bin/btop` — проверенный на MR3020 v3 бинарник UPX, **502 664 байта**. SHA-256: `1fccb12109d5804b7a6677f01c52839737a74d3306a0b7ac5eca55042bd84c86`.
- `btop/share/doc/btop/` — лицензионные тексты btop, fmt, musl, среды выполнения GCC и UPX.
- На OpenWrt с ядром 4.14.267 проверены вывод версии, обновление показателей CPU, памяти и процессов и выход по `q`. RSS при проверке составил 2 200 КиБ. Упакованный вариант в использованном QEMU user-mode завершился с SIGSEGV, поэтому окончательная проверка проводилась на самом роутере.

## Пересборка

Запустите `./build-linux.sh` в Ubuntu 22.04 amd64 с установленными Git, curl, GNU Make, GNU tar, coreutils и xz-utils. Скрипт скачивает исходники и инструменты, проверяет их версии и записывает новый архив и контрольную сумму рядом с собой.

Исходники btop соответствуют тегу [v1.4.8](https://github.com/aristocratos/btop/tree/cf1da5900b1e9eaa1c20fd7148dd812b43340b8a). Использованы GCC 15.2.0, `-Os`, LTO, удаление неиспользуемых секций и UPX 5.3.0 с `--best --lzma`. Перед упаковкой размер ELF составлял 1 791 256 байт. [Кросс-компилятор](https://github.com/cross-tools/musl-cross/releases/tag/20260430) · [UPX](https://github.com/upx/upx/releases/tag/v5.3.0).

## English

Prebuilt btop 1.4.8 for the TL-MR3020 v3, tested on OpenWrt 19.07.9. Use the PowerShell block on Windows 11 or the shell block on Linux/WSL. On Windows, use legacy SCP mode (capital `-O`) and allocate a terminal with `ssh.exe -t`. Replace `openwrt` with your SSH alias or `root@router-address`. Press `q` to exit. Both the executable and settings reside in RAM. To rebuild the archive and checksum on Ubuntu 22.04 amd64, run `./build-linux.sh`.
