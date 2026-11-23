# Мастер установки — интерактивный макет / Setup wizard prototype

QML + небольшой C++-запускатель. Сеть, SSH, TFTP, прошивка, установка пакетов и изменение настроек **не реализованы**. Всё на экране — имитация. Не подключайте роутер для проверки макета.

## Windows

Из PowerShell: `./build-windows.ps1`. Нужны установленные MSYS2 MinGW64, CMake, Ninja, GCC и Qt6 static. Путь MSYS2 можно передать через `-MsysRoot`. Компиляторы работают с временной локальной копией: UNC-путь WSL не подходит для CMD/Ninja. Исходники остаются в репозитории.

Результат: `out/setup-gui/router-setup.exe` от корня репозитория. Qt/QML и сторонние библиотеки встроены; системные DLL Windows остаются необходимыми. Скрипт отклоняет импорты отсутствующих в System32 DLL. Проверено на текущем Windows с очищенным PATH; чистая VM ещё не проверялась. Первая проба выявила зависимость HarfBuzz, исправленная сборка её устраняет. EXE около 52 МиБ, без Authenticode-подписи. Это локальный макет, не релиз для распространения.

Откройте CMakeLists.txt в Qt Creator для редактирования. Комплект Qt должен соответствовать компилятору. Python/PySide6 и Lua для запуска этой статической версии не нужны. Lua 5.1 и liblua5.1-0-dev устанавливаются только в среду разработки WSL для общего make all, который проверяет Lua-код Школьника; они не являются зависимостями GUI. Linux/macOS пока не собраны и не проверены.

Первый шаг обоих режимов — список оборудования с обязательным USB–Ethernet-адаптером. Простой режим по умолчанию предлагает «Установить Школьник» (OpenWrt и приложение одним маршрутом, 10 шагов после выбора задачи) и возврат TP-Link с пошаговыми подсказками. Экспертный режим дополнительно открывает отдельные маршруты OpenWrt (7 шагов), пакетов (6 шагов) и возврата TP-Link (7 шагов). У каждого свои подготовка, резервная копия, выбор комплекта, проверка и результат. Пакеты не используют Reset и прошивку; возврат OEM не использует SSH и пакеты. Ошибки сценария моделируются без обращения к сети; повтор продолжает остановленный этап, сброс возвращает к подготовке оборудования. Состояние сценария не сохраняется между запусками.

На шагах с Reset справа показана [сохранённая фотография TP-Link EU v3.30](../vendor/photos.md) с указателем на WPS/RESET. Оригинал не изменяется, указатель рисуется QML; фото встраивается в EXE из vendor, права TP-Link сохраняются. Это макет подсказок, а не разрешение на физические действия.

Проверка модели: `node tools/setup/gui/test-flow.cjs` из корня. Публичная упаковка потребует перечня лицензий, соответствующих исходников и выполнения условий статической линковки Qt и зависимостей.

## English

Interactive QML/C++ prototype only: no networking, SSH, TFTP, flashing or package installation. Build with PowerShell `./build-windows.ps1`; optional `-MsysRoot` selects MSYS2. Requires MinGW64 GCC, CMake, Ninja and static Qt6. The GUI needs no Lua runtime; Lua 5.1 and its development package are WSL dependencies for the repository-wide Schoolbell tests only. Sources are copied to a local temporary directory to avoid UNC limitations. Output: `out/setup-gui/router-setup.exe` at repository root. Third-party runtimes are linked in; Windows system DLLs are still required. Build checks DLL imports. Tested locally with a clean PATH, not in a clean VM. Unsigned local prototype, approximately 52 MiB; Linux/macOS untested. Distribution requires dependency notices, corresponding sources and applicable static-linking license compliance. Simplified simulated routes are not real installation instructions.

## Темы / Themes

Кнопка в шапке переключает системную → тёмную → светлую тему. Выбор хранится локально через Qt Settings (Schoolbell/RouterSetupPrototype), независимо от сброса сценария. Системная тема следует настройке ОС. Палитра Theme.qml повторяет CSS Школьника; кнопки высотой 48 px, скругления, фокус и состояния общие. / The header cycles system → dark → light. Qt Settings persists the selection independently of scenario reset. System mode follows OS appearance. Theme.qml mirrors Schoolbell CSS tokens; action buttons share 48 px height, rounded borders and focus states.

## Локальная проверка / Local verification

Проверен запуск статического EXE без MSYS2 в PATH, переключение светлой и тёмной тем и сохранение выбора после перезапуска. В сценарии ошибки DHCP выполнение остановилось на 90 %, после «Повторить этап» достигнут экран результата. При проверке исправлены контраст текста на акцентном фоне, делегат списка и отступы экрана подключения. Смена темы ОС во время работы и чистая Windows VM пока не проверялись.

Verified static EXE startup without MSYS2 on PATH, light/dark switching and persistence across restart. The simulated DHCP failure stopped at 90%; retry reached the result screen. Fixed accent text contrast, combo delegate and connection-screen spacing. Live OS theme changes and a clean Windows VM remain untested.

## Разделение маршрутов / Separate routes

Both modes begin with the equipment checklist, including a mandatory USB–Ethernet adapter. Default guided mode offers combined Schoolbell installation (10 steps after task selection) and guided factory recovery. Expert mode additionally exposes standalone OpenWrt (7 steps), packages (6) and factory recovery (7). Each has its own backup, bundle, checks, progress and result. Packages never enter recovery; OEM recovery never runs SSH/package stages. Selected bundles are shown in the simulated result. Errors/retry/reset remain local simulation. State is not persisted between launches. The original archived TP-Link EU v3.30 photo is embedded with a QML WPS/RESET overlay; TP-Link retains image rights. Model checks: `node tools/setup/gui/test-flow.cjs`.

23.11.2026: статическая сборка и тест маршрутов в WSL пройдены. Первоначальная остановка общего `make all` устранена установкой отсутствовавших пакетов Ubuntu `lua5.1` и `liblua5.1-0-dev` (5.1.5). Повторный полный `make all` пройден, включая runtime, UI, IPK и Pages. Это локальные проверки, не аппаратная приёмка. / Static build and WSL route tests passed. The initial full-suite blocker was resolved by installing the missing Ubuntu lua5.1 and liblua5.1-0-dev packages (5.1.5). The complete make all then passed, including runtime, UI, IPK and Pages. These are host checks, not hardware acceptance.

В Windows визуально пройдены три маршрута до результата; в OEM проверены остановка на ошибке DHCP и повтор. Фото WPS/RESET проверено в статическом EXE. / All three routes were visually completed in Windows; OEM DHCP failure and retry were exercised. The WPS/RESET image was checked in the static EXE.

## Простой режим / Guided mode

Режим выбирается на первом экране оборудования; во время сценария он заблокирован, чтобы не менять уже начатые шаги. «Сброс макета» возвращает на подготовку. Оборудование: Windows 11, USB–Ethernet, RJ45-кабель, MR3020 EU v3.30 и его питание Type-C. Аудиокарта, при необходимости хаб и активные колонки перечислены отдельно для последующей работы звонков. Сверка наклейки и копирование представлены подтверждениями имитации, не аппаратными результатами. Работа с Reset разделена на отключение питания, удержание кнопки, подачу питания и отпускание после смоделированного начала передачи. Ошибки объясняют следующий шаг и не предлагают повторно прошивать при проблеме связи. Автоопределение оборудования, запись копий и открытие настоящего интерфейса ещё не реализованы.

Select guided/expert mode on the initial equipment screen; mode changes are blocked during a route. Reset returns to preparation. Required equipment includes Windows 11, USB–Ethernet, RJ45 cable, MR3020 EU v3.30 and Type-C power. Audio hardware is listed separately for later bell playback. Label and backup confirmations simulate preparation, not hardware evidence. Reset instructions are split into power-off, hold, power-on and release after simulated transfer starts. Friendly failures explain the next action without reflashing for a connectivity error. Device discovery, real backups and opening the actual device UI remain unimplemented.

Проверка 23.11.2026: статический EXE собран, тесты модели режимов и полный make all пройдены. В GUI пройден основной маршрут, проверены первый экран обоих режимов и набор задач эксперта. Проверка понятности с новичком ещё предстоит. / Verified static build, mode-model tests and full make all; visually completed the guided Schoolbell route and checked equipment-first screens and expert choices. Novice usability acceptance remains pending.
