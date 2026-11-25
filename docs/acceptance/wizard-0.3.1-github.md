# Проверка скачанного мастера 0.3.1 / Downloaded wizard acceptance

Дата / Date: 26.11.2026. Статус / Status: частичная аппаратная приёмка / partial hardware acceptance.

## Источник / Provenance

[GitHub Actions run 45686516264](https://github.com/ViacheslavMezentsev/schoolbell/actions/runs/45686516264), commit `0df760fc70e1f9d9d6f689eb5ee0ae1c3338406f`, artifact `15057351646`.

| Файл / File | SHA-256 |
| --- | --- |
| GitHub artifact ZIP | `d6b719eed9fa4711472f5389864dcb583fba5acf38892525b44f8b63ba5a43e8` |
| schoolbell-setup-wizard-v0.3.1-windows-x86_64.zip | `632f9358f6e250dbc403cc3a95e564e54519bf3975c9d20f8f410e6540085447` |
| schoolbell-v5.1.127-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip | `4f81d05f66271fb1fd3bded83ccab789147942ab0e79d379edf0dc43148641a6` |

## Подтверждено

- Сборка UCRT64 на GitHub успешна; HEAD совпал с принятым main. Сверены внешний digest, SHA256SUMS, файлы manifest мастера и метаданные пары. Исходное дерево сборки чистое.
- После отдельной распаковки EXE запускается, --check-firmware и импорты вложенного Python проходят без MSYS2 в PATH. ZIP комплекта проверен и распознан. Это существующий Windows 11 хост, не чистая машина.
- На отдельном TL-MR3020 EU v3.30 / OpenWrt 19.07.9 сохранены overlay и семь MTD-разделов; локальные хеши повторно сверены. Копии и аппаратные журналы не публикуются.
- Скачанным мастером выполнена установка поверх 5.1.127. Квитанция INSTALL VERIFIED содержит версию 5.1.127 и SHA-256 именно скачанного ZIP. Проверены службы, выключенный автомат и сохранность сетевых/system/shadow файлов.
- После входа в LuCI: версия 5.1.127, автозвонки выключены, план не применён, черновик не сохранён, громкость 100 % (как ранее подтверждено), C-Media определяется, переключатель AP. Звук не запускался; рабочее устройство не затронуто.
- Интернет не подтверждён, свежего NTP-подтверждения нет, дата устройства 16.02.2022. Сеть и часы не исправлялись в рамках установки.

Замечание: восстановленный выбор ZIP указывал на старую локальную сборку с тем же именем. Перед установкой архив явно выбран заново из каталога скачанного мастера и проверен по хешу. После выбора подключения потребовалось повторить ввод пароля. Этот недостаток интерфейса остаётся в TODO.

## Полный цикл скачанным мастером

1. **OpenWrt → OEM — PASS.** Переданы все 8 126 464 байта; после ожидания загрузки DHCP восстановлен автоматически. Пользователь вошёл с прежним паролем TP-Link без сброса. В заводском интерфейсе проверены Firmware Version `1.8.0 0.9.1 v0001.0 Build 250625 Rel.56805n` и Hardware Version `TL-MR3020 v3 00000003`. Успех подтверждён интерфейсом после загрузки, а не только передачей файла.
2. **OEM → OpenWrt — PASS.** Тем же скачанным мастером переданы все 8 126 464 байта, DHCP восстановлен автоматически. В LuCI проверены OpenWrt `19.07.9 r11405-2a3558b0de`, kernel `4.14.267`, модель TL-MR3020 v3. Пользователь самостоятельно задал пароль root.
3. **Свежая установка Школьника — PASS.** Установка из указанного выше скачанного ZIP завершилась INSTALL VERIFIED; квитанция содержит версию 5.1.127 и тот же SHA-256 комплекта. Проверены службы, выключенные автозвонки и сохранность network/wireless/system/dhcp/firewall/dropbear/shadow при установке пакетов.
4. **Итоговый интерфейс — PASS.** После входа проверены версия 5.1.127, выключенные автозвонки, неприменённый план, несохранённый черновик, громкость 100 %, C-Media и AP. Громкость 100 % после свежей установки не является доказательством переноса настроек через перепрошивку. Звук не запускался. Интернет не подтверждён, свежего подтверждения NTP нет, часы показывают 16.02.2022; настройки времени не менялись.

Основные три маршрута этой скачанной пары и установка поверх проверены на отдельном устройстве. Остались OEM → OEM именно этой поставкой, чистая Windows, ручной CLI-сценарий, повторное открытие одного файла лога обоих маршрутов и оформление выпуска владельцем. Публикация не выполнялась; рабочее устройство не затронуто. Это приёмка перечисленных сценариев, а не всех возможных отказов и условий эксплуатации.

## English

The exact GitHub pair above passed archive/manifest checks, clean-source metadata, portable EXE firmware checks and bundled Python imports without MSYS2 PATH on an existing Windows 11 host. This is not clean-host acceptance.

On a separate TL-MR3020 EU v3.30 running OpenWrt 19.07.9, overlay and seven MTD backups were verified. Same-version 5.1.127 installation passed; its receipt binds the downloaded bundle hash. Services, automatic-off and protected network/system/shadow files passed. LuCI showed 5.1.127, automatic bells off, no applied plan or saved draft, volume 100% matching the earlier confirmed level, C-Media audio and switch AP. No sound or working-device operations occurred. Unconfirmed Internet/NTP and the device's 2022 date were left unchanged.

The restored ZIP selection referenced an older local archive with the same filename. Explicit selection and hash verification corrected the test input before installation; source visibility remains an open UI issue. Selecting the adapter cleared the password.

The same downloaded wizard completed OpenWrt-to-OEM recovery: all 8,126,464 bytes transferred, DHCP restored automatically, and authenticated TP-Link UI confirmed `1.8.0 0.9.1 v0001.0 Build 250625 Rel.56805n` / `TL-MR3020 v3 00000003`. The previous TP-Link password worked without resetting settings. Boot success was verified separately from transfer completion.

OEM-to-OpenWrt also passed with automatic DHCP recovery. LuCI confirmed OpenWrt `19.07.9 r11405-2a3558b0de`, kernel `4.14.267` and TL-MR3020 v3. The owner set root in LuCI, then installed the downloaded package ZIP on the fresh system. INSTALL VERIFIED bound version 5.1.127 to the archive hash above; services, automatic-off and protected configuration files passed. Authenticated Schoolbell UI confirmed version 5.1.127, automatic bells off, no applied plan or saved draft, volume 100%, C-Media and AP. This fresh-install volume does not prove settings survived flashing. Internet/NTP remained unconfirmed and the device date remained 2022-02-16. No sound was played or clock settings changed.

The three main routes and same-version reinstall passed on this separate device. Exact-build OEM-to-OEM, clean Windows, manual CLI, repeated opening of the same action log for both firmware routes and owner publication remain pending. This is acceptance of the listed scenarios, not every failure mode or operating condition. The working device was not touched.
