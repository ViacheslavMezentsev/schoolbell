# Мастер установки / Setup wizard

[Единое руководство установки](../../../docs/INSTALLATION.md) · [Installation guide](../../../docs/INSTALLATION.en.md) · [Релизы / Releases](../../../docs/RELEASING.md)

[План трёх маршрутов](../../../docs/SETUP_WIZARD_PLAN.md) · [Implementation plan](../../../docs/SETUP_WIZARD_PLAN.en.md)

## Русский

Текущая версия мастера — **0.2.1**, независимо от версии пакета Школьника.
Стартовый экран предлагает три маршрута: установить OpenWrt на новый роутер,
установить комплект Школьника из внешнего ZIP, восстановить заводскую прошивку.
Реальная запись из GUI доступна только для комплекта; два маршрута прошивки
показывают подготовку и инструкции к консольному комплекту, без запуска сервера. Макет, имитация
прошивки, тестовые исходы и переключение простого/экспертного макета удалены.
Прошивка OpenWrt и возврат OEM через GUI пока не реализованы; используйте отдельно
документированный [консольный комплект](../README.md).

### Что понадобится

Windows 11, отдельный USB–Ethernet-адаптер, кабель RJ45, питание роутера и пароль
root. Пилот ограничен отдельным MR3020 v3 / OpenWrt 19.07.9. Поддержка других
профилей и ОС не подтверждена. Автозвонки перед подготовкой должны быть выключены.

### Установка

1. Положите `schoolbell-v…-openwrt-….zip` рядом с EXE, нажмите ↻ и выберите комплект.
   До обращения к роутеру проверяются формат, профиль, версия мастера и SHA256.
   Встроенных IPK в сборке больше нет. GitHub-загрузка пока не подключена.
2. Выберите выделенный USB–Ethernet и введите пароль. Глазок показывает/скрывает
   пароль; он хранится только в памяти текущей формы. Между операциями и при чтении
   справки пароль сохраняется; новый сеанс, смена подключения/комплекта и закрытие
   очищают его.
3. «Сохранить полную копию» независимо от ZIP сохраняет overlay и MTD на ПК,
   сверяет размер и SHA256, не меняет пакеты. Копии содержат частные настройки.
4. «Проверить устройство» подготавливает установку: проверяет профиль, свободное
   место и состав пакетов, сохраняет копию и образ восстановления, закрепляет ZIP
   и подключение за сеансом. Прямой маршрут проверяется перед каждым SSH.
5. После BACKUP VERIFIED нажмите «Установить» и подтвердите. Пока ZIP поддерживает
   установку при отсутствии Школьника и его данных; обновление не реализовано.
   Не отключайте питание и кабель. Мастер не регулирует громкость, сеть или часы;
   автозвонки остаются выключенными.
6. FRESH VERIFIED означает успешную проверку пакета и служб. Проверьте интерфейс
   кнопкой «Открыть Школьник». При обрыве используйте «Проверить результат»;
   повторная установка блокируется.

UNCHANGED VERIFIED — отдельный результат: пакет не установлен, идентичность и
загрузка устройства, состав пакетов и защищённые настройки совпали с подготовкой,
данные приложения отсутствуют. Только связанное с конкретной попыткой доказательство
разрешает архивировать неудачный сеанс через «Новый сеанс». Это не успех установки.
Материалы сохраняются в архиве сеансов; после начала записи нельзя просто стереть
маркер и повторить установку.

После перезапуска связанная квитанция восстанавливает прошлый результат установки или подтверждённого отсутствия изменений. Проверяются версия и SHA256 подготовки и попытки; повреждённая или устаревшая квитанция оставляет исход неизвестным. Это сохранённый результат, не новая проверка роутера.

⧉ копирует весь протокол. «Установка» и «Справка» используют общий заголовок;
форма прокручивается на небольшом экране. Все списки имеют общий стиль. Доступны
системная, светлая и тёмная темы с сохранением выбора. Закрытие во время операции
блокируется; в покое требуется подтверждение с сохранением копий/журнала.

### Операции и отмена

Результаты GUI передаются отдельным локальным JSON-каналом, не распознаются по
тексту SSH/журнала. Каждая операция имеет новый идентификатор и привязку к каталогу
сеанса; GUI проверяет схему, этап, последовательность и результат для данного
действия. Успех требует подтверждения worker и штатного exit 0. Отсутствие или
повреждение подтверждения не разрешает повторную запись.

«Отменить операцию» доступна для проверки архива, подготовки, копии и проверки
результата. Запрос обрабатывается между чтениями; текущий SSH-запрос не убивается.
Установка и архивирование сеанса не прерываются. Частичные копии сохраняются,
отмена не означает откат; после возможной записи остаётся отдельная проверка.
После сбоя нажмите «Восстановить незавершённый сеанс». Блокировка ОС не позволит
вмешаться в работающий worker. Маркеры новой версии сохранятся в recovery-history;
копии и признаки записи не меняются. После записи сначала проверьте результат.
Блокировки старой версии и повреждённые маркеры требуют ручной диагностики. JSON-файлы операций хранятся рядом с сеансами в operations;
они не содержат пароль или текст удалённого вывода. Это локальный протокол,
не защита от вредоносной программы с правами того же пользователя.

### Сборка и проверки

В PowerShell: `./build-windows.ps1`. Требуются MSYS2 MinGW64, CMake, Ninja, GCC и
Qt6 static; альтернативный путь задаётся `-MsysRoot`. `-RecoveryImage` задаёт
закреплённый образ восстановления (проверяется SHA256). Результат —
`out/setup-gui-external/schoolbell-setup-wizard.exe` от корня репозитория. Рядом
нужны поставляемые сборкой Python runtime, worker-скрипты и образ восстановления;
одного EXE для реальных операций недостаточно. Qt/QML статические, сторонних DLL
в импортах нет. EXE без Authenticode; распространение требует завершения лицензий
и чистой VM-проверки. Lua нужен тестам Школьника в WSL, не GUI.

`make all` — host-проверки; Qt Quick Test: `qmltestrunner -platform offscreen
-input tools/setup/gui/tests`. При проблемах UNC скопируйте qml/ и tests/ вместе
во временный локальный каталог. Host-тесты не заменяют приёмку на роутере.

24.11.2026: внешний ZIP принят на отдельном устройстве после разрешённого удаления
Школьника при сохранённых зависимостях. Первая попытка SSH 255: команда 9708 байт
превысила MAX_CMD_LEN=9000 Dropbear 2019.78. Исправлены хеш-сравнение состава и цикл
проверки версий; добавлен предел 8000 байт. После UNCHANGED VERIFIED и нового сеанса
получен FRESH VERIFIED. Владелец подтвердил UI 5.1.127, автозвонки выключены и
громкость 100 %. Полная установка зависимостей на чистую прошивку и восстановление
копии остаются отдельными проверками. [Протокол](../../../docs/acceptance/ACCEPTANCE_RUN.md).

## English

Wizard **0.2.1** starts with three routes: OpenWrt installation, a Schoolbell ZIP
bundle, and factory recovery. Firmware routes currently provide preparation and
console-kit instructions; only the package route performs real GUI operations. Prototype
routes, simulated outcomes and mock simple/expert modes have been removed. GUI
firmware/OEM flashing is not implemented; use the separately documented console kit.

Requires Windows 11, dedicated USB–Ethernet/RJ45, router power and root password.
The pilot targets MR3020 v3 / OpenWrt 19.07.9 only, with automatic bells off.
Place a compatible ZIP beside the EXE, refresh and select it. Validation is local.
No embedded packages or GitHub download are offered. Full MTD/overlay backup is
independent of ZIP selection. Prepare pins the validated bundle and connection,
saves recovery evidence and checks the direct route before each SSH operation.
Install requires confirmation; ZIP upgrades are not supported yet. Keep power
and Ethernet connected. Password stays in the form between operations/help,
with a shared reveal icon; closing or changing session/connection/bundle clears it.

FRESH VERIFIED confirms installation. After an uncertain outcome, Verify reads
state without repeating writes. UNCHANGED VERIFIED separately proves the original
identity/boot, inventory and protected settings with no app/data; its bound receipt
permits archival and a new session, not a claim of successful installation.
Restart restores the previous result only from a receipt bound to the version and preparation/attempt hashes. Missing or stale receipts keep the outcome uncertain; this is not a fresh device check.
Backups contain private settings and must not be published. Logs can be copied;
the scrollable form and shared dropdowns support light/dark/system themes.
Closing is blocked while busy and confirmed otherwise.

GUI results now use a separate local JSON channel, bound to operation/session IDs
and action-specific outcomes. Log text cannot signal success. Exit 0 and a valid
completed record are both required. Read-only operations support cooperative
cancellation between requests; SSH is not killed. Installation and archival cannot
be cancelled. Partial evidence stays on disk, cancellation is not rollback, and
the explicit recovery action archives new-format crash markers only while holding an OS lease.
Backups and write evidence remain intact; legacy or corrupt markers require manual diagnosis. Local operations records contain
no passwords or remote output; this is not a security boundary against the same OS user.

Build with `./build-windows.ps1` using MSYS2 static Qt6/MinGW64. Output directory:
`out/setup-gui-external`. Real operations require the adjacent Python/runtime
scripts and pinned recovery image, not just the static EXE. No Authenticode;
clean-host and distribution/licensing acceptance remains pending. Lua is a WSL
Schoolbell test dependency, not a GUI runtime requirement. Run `make all` and
Qt Quick tests (copy qml/tests together locally if UNC resolution fails).

2026-11-24: GUI ZIP app installation passed after authorized app removal with
dependencies retained. Initial SSH 255 was caused by a 9708-byte command exceeding
Dropbear's 9000-byte limit. Inventory hashing/compact version checks and an
8000-byte guard fixed it. The failed session was archived after unchanged-state
proof; a new attempt passed. Owner confirmed UI 5.1.127, automation off, volume
100%. Full dependency provisioning and restoration remain separate tests.
[Acceptance](../../../docs/acceptance/ACCEPTANCE_RUN.en.md) ·
[Dropbear source](https://raw.githubusercontent.com/mkj/dropbear/DROPBEAR_2019.78/sysoptions.h).

The executable/artifact name remains `schoolbell-setup-wizard`; display name is
«Мастер установки». The internal RouterSetupPrototype data directory is retained
to preserve old sessions and backups. Source [requirements](../../../docs/requirements/TECHNICAL_SPECIFICATION_SETUP_GUI.md).

Сетевой этап: [предварительный план RU/EN](../NETWORK_PREFLIGHT.md). Кнопка ↻ в маршрутах прошивки читает адаптеры; после выбора и подтверждения модели выполняется предварительная проверка. Сеть не меняется, Reset пока не нужен.

Network stage: [preflight plan RU/EN](../NETWORK_PREFLIGHT.md). Firmware routes now collect local Windows inventory and check a fresh snapshot after adapter/model selection. No network mutation, probes or TFTP; do not press Reset yet.

Сетевой помощник: после предварительной проверки можно подтвердить подготовку
временного адреса через UAC; отдельная кнопка восстанавливает DHCP по сохранённому
GUID. Это не запуск TFTP. Реальные операции с адаптером ещё не приняты; выполнены
только тесты с подменой команд. См. границы и восстановление в NETWORK_PREFLIGHT.

Network helper: explicit UAC-confirmed temporary addressing and GUID-bound DHCP
restoration are connected. This is not TFTP. Actual adapter operations remain
unaccepted; mocked-command tests only. See NETWORK_PREFLIGHT for recovery limits.

### Резервная копия перед перепрошивкой / Backup before flashing

В обоих вариантах прошивки резервная копия необязательна и не блокирует запуск. В форме нет отдельного выбора о копии; остаётся одно подтверждение перед запуском. Полная копия из OpenWrt остаётся отдельным действием; после завершённой ZIP-установки для новой копии начните новый сеанс.

Both firmware operations can run without a backup. No separate backup choice blocks the form; one start confirmation remains. A full OpenWrt backup remains a separate action; start a new session to create one after a completed ZIP installation.

Заводская система: копия настроек сохраняется вручную через TP-Link → System Tools → Backup & Restore; это не копия всех разделов flash и не перенос настроек в OpenWrt. Полная копия кнопкой мастера доступна только на работающей OpenWrt через SSH. Выбор способа зависит от текущей системы, а не только от целевой прошивки (возврат OEM возможен также из OEM).

OEM: save configuration manually through TP-Link → System Tools → Backup & Restore. This is neither a full flash backup nor an OpenWrt configuration migration. The wizard full-backup action requires running OpenWrt with SSH. The method depends on the current OS, not merely the destination firmware (OEM-to-OEM is also possible).

### Текущее состояние 25.11.2026 / Current status

Мастер 0.3.0 встроил оба образа и реальную GUI-передачу с ожиданием загрузки и DHCP.
Возврат OEM и установка OpenWrt + свежего Школьника проверены на отдельном устройстве;
старый SSH-ключ перед ZIP заменён вручную после сверки. Прежние записи «без TFTP»
выше описывают ранние этапы. Новый portable ZIP и чистая Windows требуют своей приёмки.
Упаковка: `python3 scripts/build-wizard-release.py --build out/setup-gui-external --out out/wizard-preview`.

Wizard 0.3.0 embeds both images and connects actual transfer, boot wait and DHCP.
OEM recovery and OpenWrt plus fresh Schoolbell passed on a separate device with
manual verified SSH-key replacement before ZIP installation. Earlier no-TFTP notes
above describe previous stages. The new portable ZIP and clean Windows still need
separate acceptance. See [release procedure](../../../docs/RELEASING.en.md).

### Источник ZIP / ZIP source

Кнопка «Выбрать файл…» открывает ZIP из любого каталога; отмена не меняет выбор. Под списком показан полный путь выбранного архива. Строки списка содержат имя и каталог; сохранённый внешний архив остаётся в списке, даже если рядом с EXE есть одноимённый ZIP. Обновление списка не меняет выбор. Отсутствующий файл отмечен в списке.

“Выбрать файл…” opens a ZIP from any directory; cancellation preserves the selection. The full selected archive path appears below the picker. Rows include the name and directory; a restored external archive remains listed alongside same-named local ZIPs. Refresh preserves the selection; missing files are marked.

Кнопка со списком из трёх строк возвращает к выбору задачи; открытая папка выбирает ZIP. Справа вверху — выход с подтверждением. Во время операции сначала дождитесь завершения или используйте остановку. Все значки имеют подсказки.

The three-row list returns to task selection; the open folder selects a ZIP. Top-right exit asks for confirmation. During an operation, wait for completion or use Stop first. All icons have tooltips.
