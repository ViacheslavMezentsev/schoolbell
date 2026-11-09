# «Школьник» с заводской прошивки — Windows 11 x64

Автономный мастер для **TP-Link TL-MR3020 (EU) Ver. 3.30**. Первичный переход на OpenWrt 19.07.9 заменяет заводскую ОС и настройки. Для обновления работающего «Школьника» используйте отдельную процедуру обновления IPK. Ветка OpenWrt 19.07 завершила поддержку безопасности.

## Автономный возврат из репозитория / Offline recovery from repository

[Инструкция и список поддерживаемых устройств](RECOVERY.md). Исходный OEM ZIP, Python и страницы производителя сохранены в [vendor](vendor/README.md); запустите Prepare-Recovery.ps1, чтобы собрать отдельный ZIP возврата без сети и установленных зависимостей. / Follow RECOVERY.md to build a stock-only kit offline from the archived inputs.

## Запуск

1. Полностью распакуйте ZIP на локальный диск. В терминале из папки комплекта выполните `Setup.cmd -CheckOnly`. Для установки нужен стандартный компонент Windows «Клиент OpenSSH». Подготовьте его заранее. Образ OpenWrt, 35 IPK и Python входят в ZIP.
2. Отключите роутер от питания и от обычной сети. Соедините его кабелем с выделенным физическим Ethernet-адаптером ПК. Требуется автоматическая настройка IPv4 (DHCP) без ручных адресов. Устраните конфликтующие прямые или более узкие маршруты; VPN без такого конфликта можно оставить включённым.
3. Запустите **Setup.cmd от имени администратора**, выберите номер Ethernet-адаптера и сверьте регион и ревизию с наклейкой. После **READY** зажмите Reset и подайте питание. После начала передачи отпустите кнопку. Не прерывайте питание при записи и перезагрузке.
4. После последнего ACK мастер ждёт SSH на 192.168.1.1, отдельно проверяет модель, релиз, архитектуру, ABI ядра и libc. Подтверждайте первый ключ SSH только при прямом кабельном соединении с нужным устройством. Проверьте список недостающих пакетов и подтвердите установку. В конце задайте пароль root через SSH.
5. После возврата адаптера на DHCP откройте [Школьник](http://192.168.1.1/cgi-bin/luci/admin/schoolbell) и войдите как root. Автомат выключен. Сверьте часы, проверьте звук и затем выберите план.

## DryRun — план без выполнения

```powershell
Setup.cmd -DryRun
Setup.cmd -RestoreFactory -DryRun
# Необязательно: выбрать адаптер без вопроса (42 — пример, не готовый номер)
Setup.cmd -DryRun -InterfaceIndex 42
Setup.cmd -RestoreFactory -DryRun -InterfaceIndex 42
```

DryRun проверяет SHA256 комплекта и выбранного образа, локальные пакеты для установки, наличие SSH-клиента, физический Ethernet-адаптер, DHCP/ручные адреса, link, конкурирующие прямые маршруты и более узкие маршруты (включая VPN /32), занятость UDP69/1069 и незавершённый предыдущий сеанс. Показывает профиль, адаптер, образ и SHA256, временные адреса, правило firewall, этапы, пути журнала и состояния, порядок восстановления DHCP. При препятствии завершает работу с ошибкой. Администратор для DryRun не требуется; если Windows запрещает чтение инвентаря, это ошибка проверки, а не разрешение пропустить её.

DryRun не создаёт network.json, не меняет адреса/firewall/DHCP, не запускает TFTP/SSH, не опрашивает устройство и не пишет во flash. Reset нажимать не нужно. Это не проверка модели, доступности роутера, его памяти или загрузки. Точный список недостающих IPK определяется только при настоящей установке.

`-CheckOnly` — более короткая проверка файлов и TFTP-самотеста на loopback, без выбора адаптера. Для OEM: `Setup.cmd -RestoreFactory -CheckOnly`. `-DryRun` несовместим с `-CheckOnly` и `-RestoreNetwork`; `-RestoreFactory` несовместим с `-InstallOnly` и `-RestoreNetwork`. `-InstallOnly -DryRun` показывает план установки IPK без прошивки. DryRun и CheckOnly не повышают права автоматически.

## Возврат заводской прошивки

```powershell
Setup.cmd -RestoreFactory -DryRun
# После проверки, из окна администратора:
Setup.cmd -RestoreFactory
```

Нужен комплект, собранный с `--oem`: без `firmware/oem-recovery.bin` мастер остановится до изменения сети. Поддержан только проверенный **TL-MR3020 EU v3.30 / Build250625**. Это не универсальный способ обработки любых OEM-файлов. Исходный `up_boot` не переименовывайте в recovery: он имеет несовместимое смещение заголовка. Мастер использует отдельный проверенный образ, подготовленный сборщиком.

1. Сохраните конфигурацию OpenWrt, данные Школьника и необходимые копии flash отдельно. Возврат удаляет OpenWrt и Школьник; OEM не читает `.sbb`. Мастер сам не делает резервную копию.
2. Используйте выделенный Ethernet/DHCP как при установке. Подтвердите `RESTORE FACTORY` и модель `MR3020 EU V3.30`.
3. Только после READY зажмите Reset и подайте питание. После начала передачи отпустите кнопку. Дождитесь записи и загрузки, не отключая питание.
4. После передачи мастер удаляет своё правило firewall и возвращает адаптер на DHCP. Он **не запускает SSH и не устанавливает IPK**. ACK подтверждает передачу, не загрузку OEM.
5. Откройте заводской интерфейс (в проверенном опыте `http://192.168.1.1`), войдите и сверьте TL-MR3020 и **1.8.0 0.9.1 v0001.0 Build 250625 Rel.56805n**. При сохранённых настройках/AP адрес может отличаться; смотрите DHCP/адрес устройства в изолированной сети.

**Пароль и сброс:** recovery оставляет config вне области записи. Прежний пароль администратора TP-Link и настройки могут сохраниться. Wi-Fi-ключ с наклейки не является паролем администратора, если вы сами не установили его как такой пароль. При забытом пароле на **уже включённом и загрузившемся** роутере удерживайте WPS/Reset около 10 секунд до реакции индикаторов, отпустите и дождитесь загрузки. Этот отдельный сброс удаляет настройки; после него задайте новый пароль в New Password / Confirm Password. Мастер не выполняет сброс. Reset при подаче питания — другой режим, TFTP-recovery.

Работа recovery определяется загрузчиком, а не текущей ОС. На EU v3.30 подтверждены OpenWrt → OEM и OEM → OEM Build250625 через RestoreFactory в PowerShell 7. Recovery-файл не предназначен для веб-формы обновления.

## Если установка прервалась

- ACK означает получение файла загрузчиком. Загрузку ОС подтверждает последующая проверка по SSH. Если OpenWrt уже загрузилась, используйте **Setup.cmd -InstallOnly** без повторной прошивки.
- После аварийного закрытия окна используйте **Setup.cmd -RestoreNetwork** от имени того же администратора и с тем же Ethernet-адаптером. Мастер использует временные адреса 192.168.0.225 и 192.168.1.2 и ограниченное правило входящего UDP. При штатном завершении или ошибке удаляет своё правило и возвращает DHCP.
- Установка IPK не атомарна. При ошибке изучите вывод opkg. Повтор учитывает установленные версии, а маркер сеанса в /tmp сохраняется до перезагрузки. При неподходящих версиях или наличии чужой конфигурации мастер останавливается.
- Ключ роутера хранится в отдельном файле known_hosts в каталоге SchoolbellSetup профиля Windows. Если после новой прошивки ключ изменился, проверьте физическое подключение, затем удалите только устаревшую запись для 192.168.1.1 с помощью ssh-keygen -R и параметра -f для этого файла.

## Происхождение и сборка ZIP

Основа сервера — tftp-readonly.py от 31.10.2026, SHA-256 исходника `feca2cb4d6baf91c6462473f53f77dbb9ea58cd24301671e5baca01a10e45675`. В опыте зафиксированы последний ACK 15873, 8 126 464 полученных байта и последующее чтение OpenWrt 19.07.9 на MR3020. Сохранены RRQ только для tp_recovery.bin/octet от 192.168.0.2, порт 69, отдельный порт 1069 для DATA, блок 512, отсутствие OACK и повторы при потере ACK. Аппаратная проверка установки 5.1.123 описана ниже; RestoreFactory в PowerShell 7 также принят 09.11.2026.

Сборщик принимает готовую папку bundle из scripts/build-schoolbell-bundle.py (пакет 5.1.123, native 1.0.0), [официальный recovery-образ](https://downloads.openwrt.org/releases/19.07.9/targets/ramips/mt76x8/openwrt-19.07.9-ramips-mt76x8-tplink_tl-mr3020-v3-squashfs-tftp-recovery.bin) и [Windows embedded Python x64](https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip).

```sh
python3 tools/setup/build.py --bundle /path/to/bundle --image /path/to/recovery.bin --runtime /path/to/python-3.11.9-embed-amd64.zip --oem /path/to/original-oem-build250625.bin
```

`--oem` необязателен; без него остаётся только путь OpenWrt. При его наличии сборщик принимает оригинальный OEM BIN с SHA256 `1141467bd4b7b8292e2a50811a388eb999f4cbf207365e1be47718ebc6143d2f`, формирует 128 КиБ нулей + неизменный внутренний образ от смещения 0x20200 и требует SHA256 результата `2b0d85b1c7f5e6c65930e117ada0afe60a29a35882ecac65610191876b6b0665` (8 126 464 байта). OEM-загрузчик не включается. См. [разбор и приёмку](../../docs/SETUP_RECOVERY.md), [требования](../../docs/requirements/SETUP_RECOVERY_SPEC.md).

ZIP и SHA-256 создаются в dist/. Для локальной приёмки; публичное распространение комплекта зависит от открытых пунктов аудита зависимостей и аудио.

## English

Offline setup candidate for a factory TL-MR3020 EU v3.30 on Windows 11 x64. Extract the ZIP to a local drive. Use Setup.cmd -CheckOnly for a local check, then run Setup.cmd as Administrator with the router directly attached to a dedicated DHCP Ethernet adapter. Hold Reset at power-on after READY. Leave power connected until OpenWrt boots. Use -InstallOnly to resume package installation or -RestoreNetwork after interruption. The operator sets a root password and automatic bells remain off. End-to-end acceptance on a spare factory router is pending.

### English: dry run and factory recovery

Use `Setup.cmd -DryRun` or `Setup.cmd -RestoreFactory -DryRun`; optional `-InterfaceIndex 42` selects an adapter without prompting (42 is only an example). DryRun validates local files/profile, installation packages/SSH client where relevant, Ethernet/DHCP/link, overlapping routes including VPN /32, UDP ports and leftover state. It prints the exact intended stages and cleanup without network probes, TFTP/SSH, state writes or network changes. Blockers return an error. It does not prove device identity, available memory or boot success. `-CheckOnly` checks files and runs a loopback TFTP self-test instead; these two switches cannot be combined.

Build with optional `--oem /path/to/original-oem-build250625.bin` to include factory recovery. Only the pinned EU v3.30 Build250625 source and resulting hashes above are accepted. The old ZIP without this profile cannot restore stock firmware. Existing bundle version remains 5.1.123; no runtime/IPK version bump is implied.

After a successful dry run, run `Setup.cmd -RestoreFactory` as Administrator. Back up OpenWrt, Schoolbell data and required flash partitions first: the wizard does not back them up. Confirm RESTORE FACTORY and the model, then hold Reset at power-on only after READY. Leave power connected during writing/boot. The wizard restores the adapter to DHCP and does not wait for SSH or install Schoolbell. Verify the stock interface/model/Build250625 yourself; the final ACK only proves transfer. The management IP may differ with retained settings/AP mode.

Factory recovery may retain the old TP-Link administrator password/configuration. The Wi-Fi key on the label is separate unless you intentionally chose it as the administrator password. If forgotten, separately hold WPS/Reset for about 10 seconds on the already powered-on, booted router until LEDs react, release, wait for reboot and create a new administrator password. This erases settings. The wizard never performs that reset. Recovery depends on the bootloader; OpenWrt → OEM was verified, RestoreFactory passed in PowerShell 7; OEM → OEM Build250625 also passed, including login without reset and network cleanup. Do not use the recovery image in the stock web-upgrade form.

[Recovery findings and acceptance](../../docs/SETUP_RECOVERY.en.md).

## Локальная проверка / Local verification

Проверено 09.11.2026: оба DryRun на Windows PowerShell 5.1 с подменённой сетевой инвентаризацией и запретом изменений; отрицательные случаи ручного IP, VPN /32, занятого UDP и повреждённого образа. Семь Python-тестов проверяют профили, упаковку и отказ до открытия сокета. Преобразование настоящего OEM побайтно совпало с принятым recovery-кандидатом. `make all`, TFTP loopback и строгий валидатор ТЗ прошли. Стенды не использовались. Последующая аппаратная проверка установки описана ниже.

Verified on 2026-11-09: both Windows PowerShell 5.1 DryRun paths with mocked inventory and mutation guards, negative preflight cases, seven Python profile/package/archive tests, real OEM transformation against the accepted candidate, loopback TFTP, strict specification validation and `make all`. No devices were accessed. The subsequent installation hardware check is described below.

Из корня репозитория / From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/test-setup-dryrun.ps1
```

```sh
python3 tests/test_setup_firmware.py
python3 tools/setup/tftp_server.py --self-test
make all
```

Фоновый маршрут через шлюз с префиксом /24 или короче не требует отключать VPN. Перед TFTP и SSH мастер проверяет фактический прямой путь от своего временного адреса через выделенный Ethernet; ошибочный путь блокирует передачу. Чужие маршруты не удаляются. / Gateway fallback routes do not require disabling VPN; the actual direct cable route is verified before TFTP/SSH, without deleting other routes.

## Аппаратная проверка 09.11.2026 / Hardware check

На отдельном EU v3.30 пройдены переход OEM → OpenWrt, установка 5.1.123 из локального ZIP через PowerShell 7 и вход в LuCI с выключенными автозвонками. После отмены INSTALL продолжение InstallOnly не потребовало повторной прошивки. VPN оставался включённым; прямые пути TFTP/SSH проверены. ПК не отключался от Интернета. Позднее RestoreFactory в PowerShell 7 также прошёл проверку: загрузка OEM, вход без дополнительного сброса, версия и очистка сети подтверждены. [Протокол и ограничения](../../docs/acceptance/ACCEPTANCE_RUN.md).

A spare EU v3.30 passed OEM → OpenWrt, local ZIP installation of 5.1.123 through PowerShell 7 and LuCI login with automation off. InstallOnly resumed after INSTALL cancellation without reflashing. VPN remained enabled and direct TFTP/SSH routes passed. The PC was not physically offline. A later RestoreFactory run in PowerShell 7 passed OEM boot, login without another reset, version and network cleanup. [Record and limits](../../docs/acceptance/ACCEPTANCE_RUN.en.md).
