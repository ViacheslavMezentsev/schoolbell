# Задачи проекта / Project tasks

Актуализировано 26.11.2026 по результатам до 5.1.127 включительно. Выполненное отделено от оставшихся проверок. Старые версии в подтверждениях обозначают дату результата, а не версию для следующей проверки. Новые аппаратные проверки выполнять на согласованной текущей версии и отдельно разрешённом устройстве. / Reviewed on 2026-11-26 through 5.1.127. Historical results are not new hardware acceptance; use an agreed current version and authorized target for remaining checks.

## Артефакты GitHub / GitHub artifacts

- [x] Сопоставлены локальные CMake cache/Ninja и владельцы библиотек pacman; добавлено сохранение диагностики GitHub при отказе. / Audited local CMake/Ninja dependencies and pacman ownership; preserve failed build diagnostics.

- [x] WebP/TIFF: новый GitHub-запуск прошёл конфигурацию Qt и начал компиляцию. / The next GitHub run passed Qt configuration and started compilation.
- [x] Пользователь подтвердил успешную сборку артефактов GitHub после исправления OpenSSL. Предыдущий отказ: test-session-proof остановился на символах Winsock/BCrypt; зависимости исправлены на общей цели OpenSSL::Crypto. / Retry UCRT64 after fixing shared OpenSSL::Crypto dependencies: test-session-proof failed on Winsock/BCrypt symbols.


- [x] Подготовлены явный упаковщик мастера, инструкции RU/EN и ручной workflow целевого MIPS/Windows выпуска без публикации. / Added allowlisted packager, RU/EN instructions and manual MIPS/Windows artifact workflow without publishing.
- [x] Локально: make all, 7 тестов упаковщика и 6 тестов пары, целевая MIPS-сборка, статическая сборка EXE, распаковка в путь с пробелами/кириллицей, --check-firmware и импорты вложенного Python — PASS. Не проверка чистой Windows или GitHub runner. / Local checks passed; not clean-host or remote-runner acceptance.
- [x] Исправление окружения проверено локально: make all, статическая сборка MINGW64 и ZIP — PASS; все 18 UCRT64-пакетов найдены в актуальной базе MSYS2. Полная сборка UCRT64 на GitHub ещё не проверена. / Local checks passed; full UCRT64 GitHub build remains pending.
- [x] Предыдущая GitHub-сборка после исправлений принята пользователем; исторический отказ: запуск 45612351368 прошёл packages, но wizard остановился до компиляции (qt6-static отсутствует в MINGW64). / Repeat after UCRT64 fix: packages passed, wizard failed before compilation because MINGW64 qt6-static was unavailable.
- [ ] Проверка распакованной пары на чистой Windows 11, подпись сумм и публикация владельцем. / Clean Windows 11 acceptance, checksum signing and owner publication.
- [x] 25.11.2026: GUI возврат OEM, OpenWrt и свежая установка Школьника 5.1.127; DHCP восстановлен, пользователь подтвердил интерфейс. Смена SSH-ключа потребовала ручной помощи; OEM → OEM новым GUI отдельно не проверено. / Full cycle passed with manual host-key repair; OEM-to-OEM in this GUI remains untested.

- [x] Пошаговый экран обоих профилей и отдельные UUID результатов: статическая сборка, make all, 10 тестов transfer worker, 5 тестов UAC bridge, mock-тесты helper и валидатор ТЗ прошли; стартовые экраны осмотрены в обеих темах. / Sequential screens and scoped receipts passed local checks; start screens inspected in both themes.
- [x] Пользователь подтвердил успешное OEM-восстановление пошаговым GUI на отдельном стенде; замечания: лишняя кнопка подтверждения и отсутствие обратного отсчёта. / Owner confirmed successful OEM recovery with the sequential GUI; requested removal of confirmation and a countdown.
- [x] Пользователь подтвердил работу таймера и успешное восстановление без кнопки подтверждения загрузки. / Owner confirmed the countdown and successful recovery without the extra confirmation button.
- [x] Пользователь подтвердил работу сборки с 03:00 и сохранение лога; замечание — каждое нажатие создавало копию. / Owner confirmed the 03:00 build and log saving; repeated clicks created copies.
- [ ] Проверить открытие единственного текущего лога новой сборкой. / Accept opening the single live action log.

## GUI: замечания полного цикла 25.11.2026 / Full-cycle findings

- [x] Новый SSH-ключ явно принимается по отпечатку в форме; пользователь подтвердил успешный вход и установку после перепрошивки. / Explicit fingerprint acceptance in the form passed in the owner test after flashing.
- [x] Ошибка SSH до записи: разрешён повтор подготовки с сохранением выбранного ZIP, адаптера и пароля в текущей вкладке, сохраняя протокол попыток. / Retry pre-write SSH preparation failures without restarting the session or clearing the form.

## Следующая группа: два способа установки и выпуск / Next: installation methods and release

- [x] 25.11.2026: по решению владельца снята блокировка публикации из-за незавершённых материалов. Реальный ZIP 35 IPK собран без --candidate; 17 тестов упаковки, make all, PowerShell helper tests, валидатор ТЗ и diff-check — PASS. Ничего не опубликовано. / Owner-authorized prerelease packaging passed with a real 35-IPK archive, full host checks and helper tests; no publication.

- [x] 25.11.2026: GUI-подготовка выделенного USB–Ethernet; после исправления временного отсутствия IPv4 и адресного DHCP renew восстановление получило аренду, удалило журнал; остальные адаптеры не изменены. Повторное восстановление принято, новый полный цикл исправленной подготовки/восстановления и OEM-профиль отдельно не повторялись. / Network restoration passed after the fix, not a new full-cycle or factory-profile acceptance.
- [x] Единое руководство GUI/CLI и порядок Draft/Pre-release: [RU](docs/INSTALLATION.md), [EN](docs/INSTALLATION.en.md), [выпуски](docs/RELEASING.md). / Shared installation and release guides.
- [x] Оба закреплённых образа встроены; GUI выполняет передачу, ожидание и восстановление сети. / Both pinned images are embedded; GUI transfer, wait and network restoration are implemented.
- [ ] Отдельно принять точную GUI-сборку: OEM → OpenWrt, OpenWrt → OEM, OEM → OEM, затем чистая прошивка → полный ZIP. / Accept exact-build firmware routes and clean package provisioning.
- [ ] Переносимый GUI ZIP по явному списку файлов, чистая Windows, точная совместимая пара, подпись сумм; приложить имеющиеся материалы и первый предварительный выпуск владельцем. Незавершённый аудит материалов по решению владельца от 25.11.2026 не блокирует выпуск. / Portable GUI archive, clean Windows, accepted pair, signed checksums and available materials; incomplete review does not block publication under the owner decision.

## Осталось: надёжность / Remaining: reliability

- [ ] TC-234: повторно проверить достоверность NTP после исправления обработки periodic. 08.11.2026 отключение сети на 18 минут и возврат Интернета подтверждены; periodic ошибочно продлевал синхронизацию без сети. 09.11.2026 установлена 5.1.121: при отключении 10:08–10:26 ложного подтверждения нет, метка не обновляется; исходный и конечный статус waiting. Переход свежего stratum через истечение к новому подтверждению остаётся непроверенным. / Recheck NTP confidence after the periodic-event fix. Physical 18-minute network loss/recovery passed; periodic falsely renewed synchronization. 5.1.121 deployed and retested on 2026-11-09: no false confirmation during 10:08–10:26 outage; initial/final waiting. Fresh stratum expiry/reconfirmation remains untested.

- [ ] Локализовать периодические отказы прежнего сочетания хаба/EHCI и проверить исправление на нём. Успешные OHCI-серии и учебный день не доказывают исправление этого сочетания. [RU](docs/PLAYBACK_RELIABILITY.md) · [EN](docs/PLAYBACK_RELIABILITY.en.md). / Diagnose the earlier hub/EHCI failures and verify a fix on that combination; OHCI success does not close this defect.
- [ ] Установить причину оставшегося пустого замка медиатеки после завершения запросов. Безопасное восстановление выполнено; автоматическое снятие не добавлялось. / Find the cause of the orphan empty media gate; recovery was performed, automatic removal was not added.
- [ ] Измерить задержку от нажатия ручного звонка до слышимого звука. Замер до запуска процесса не учитывает браузер и USB. / Measure click-to-audible latency, including the browser and USB path.

## Осталось: сценарии и сохранность данных / Remaining: workflows and data

- [ ] Сверить полноту TC-207–TC-210 с существующими тестами и аппаратными результатами; актуализировать матрицу приёмки. Выбор плана и штатные звонки уже работают, но это не закрывает все граничные сценарии. / Reconcile TC-207–TC-210 with existing tests and bench evidence; working plan selection and scheduled bells do not cover every boundary case.
- [ ] Подтвердить недостающие сценарии TC-207–TC-209: выбор среди нескольких планов, границы/полночь, сохранённый и применённый снимки, конкурирующее применение, отсутствующий план, переименование, импорт и восстановление. / Verify any uncovered multi-plan, boundary, applied-snapshot, concurrency and recovery cases.
- [ ] Для TC-210 отдельно подтвердить ещё не зафиксированные условия: пустой праздничный день, отсутствие прироста счётчика от ручного звонка. Ошибка отсутствия аудиокарты исключена из счётчика в проверке 08.11.2026. Успешные пары и полный учебный день уже зафиксированы ниже. / Complete unrecorded TC-210 conditions: empty holiday, no counter increment for manual playback. Audio-unavailable failure exclusion was verified on 2026-11-08.
- [ ] Проверить реальные перезагрузку и сброс из раздела «Система», включая сохранение пользовательских мелодий и журнала при сбросе. Внешний вид раздела уже принят. / Verify actual reboot and reset, including retention of uploaded melodies and journal; UI review is complete.
- [ ] Завершить TC-195: сохранность встроенных цветов/ID при импорте и восстановлении, темы и остальные шаги полного сценария. Внешний вид и порядок палитры подтверждены. / Complete palette persistence and remaining TC-195 cases; appearance and ordering are approved.

## Осталось: интерфейс и Pages / Remaining: UI and Pages

- [x] Мастер: увеличены шрифт и стрелка выбора сетевого подключения, раскрытый список оформлен в обеих темах Школьника. Qt Test и `make all` пройдены, статический EXE пересобран; без операций на устройствах. / Wizard: larger connection-picker text and chevron, Schoolbell-themed popup; QML tests, full checks and static build passed without device operations.

- [x] 5.1.126: условная панель сохранения с сохранением отмены/сверки и повтора чтения, компактные заголовки, сворачиваемая справка медиатеки. make all пройден; на стенде проверены переходы вкладок, появление панели при временной правке и скрытие после отмены без сохранения. Автозвонки выключены, громкость сохранена. / Conditional save actions with cancellation/reconciliation/read recovery, compact headings and collapsible media help.

- [x] 5.1.125: обновлены общие пояснения и Шпаргалка устройства/Pages без изменения поведения. make all пройден; 5.1.125 установлена на рабочий стенд, тексты проверены в браузере, автозвонки выключены и громкость сохранена. Pages собраны локально, публикация не выполнялась. / Updated shared UI explanations and help without behavior changes. make all passed; working bench upgraded and browser text checked with automation off and volume retained. Pages built locally, not published.
- [x] Третий этап ревью 5.1.127: сетка кнопок, листание, обе темы и узкий экран проверены в Pages и на устройстве. / Third review stage: button grid, pagination, both themes and narrow viewport checked in Pages and on device.


- [ ] Подтвердить на реальном телефоне панель сохранения и отсутствие горизонтального выхода страницы за экран. / Confirm the save bar and absence of horizontal overflow on a real phone.
- [ ] Завершить TC-197 для текущего UI: обе темы, узкий экран, фокус клавиатуры, disabled, размеры и отступы одинаковых элементов. Ранее проверенные 64 сочетания относятся к 5.1.69, а не ко всем последующим изменениям. / Complete current UI consistency checks; the earlier 64 combinations cover 5.1.69 only.
- [ ] Дополнить проверку опубликованных Pages: режим «По расписанию», остальные скорости имитатора, прямое редактирование даты, отмена диалога времени и реальный телефон. Подтверждённые сценарии 5.1.120 перечислены ниже; это не полное закрытие TC-235/TC-236. / Extend published Pages coverage to fixed-schedule mode, other speeds, direct date editing, time-dialog cancellation and a real phone; the checks below do not fully close TC-235/TC-236.

## Выполнено: Setup.cmd / Completed: Setup.cmd

- [x] 23.11.2026: цикл RestoreFactory → OpenWrt → 5.1.123 доведён до входа в UI с выключенными автозвонками. После OEM понадобился RestoreNetwork; после смены SSH-ключа — сверка устройства, сохранение старой базы и InstallOnly. Последний запуск завершился кодом 0, DHCP восстановился автоматически с первой попытки. Это успех конечного состояния, а не непрерывного цикла. [RU](docs/acceptance/ACCEPTANCE_RUN.md) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md). / Final state and login passed, with automation off and automatic DHCP after InstallOnly; OEM cleanup and changed-key recovery required intervention.
- [x] Добавлены ограниченные повторные попытки DHCP и видимая диагностика SSH; 11 локальных DHCP-сценариев на PowerShell 5.1/7, DryRun, семь Python-тестов и CheckOnly пройдены. / Added bounded DHCP retries and visible SSH diagnostics; local checks passed.

- [x] 22.11.2026: исправленный Setup.cmd -RestoreNetwork восстановил DHCP после временного адреса установщика без ручного обновления аренды; код 0, файл состояния удалён, страница LuCI открылась, адреса остальных адаптеров не изменились. / Fixed RestoreNetwork acquired DHCP automatically, exited 0, removed state and restored LuCI access without changing other adapters.

- [x] 22.11.2026: реальная установка OEM → OpenWrt 19.07.9 → Школьник 5.1.123 через Setup.cmd / PowerShell 7.6.9 на отдельном EU v3.30. Код завершения 0, вход в LuCI и выключенные автозвонки подтверждены. DHCP включился, но адрес получен только после дополнительного обновления аренды; этот дефект отделён от успешной установки. ПК не отключался от Интернета. [RU](docs/acceptance/ACCEPTANCE_RUN.md) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md). / Actual Setup.cmd installation and authenticated UI access passed, with automation off. DHCP was enabled but required an extra renewal; network recovery remains a separate follow-up.

## OEM: архив и границы / OEM archive and limits

- [x] Локально разобраны проверки веб-обновления Build250625; подпись OEM воспроизведена, изменённая полезная нагрузка отвергается. Сохранены официальные EU V3.30 1.9.0/1.10.0. [RU](tools/setup/vendor/oem-firmware.md) · [EN](tools/setup/vendor/oem-firmware.en.md). / Analyzed Build250625 web validation and reproduced OEM signature verification; preserved official EU V3.30 archives.
- [ ] До поддержки восстановления исходных 1.9.0/1.10.0 отдельно исследовать контейнеры и загрузчики, подготовить профили и провести разрешённую аппаратную приёмку. Для 1.10.0 учесть запрет понижения производителя. Само наличие архивов эту проверку не закрывает. / Before supporting recovery of 1.9.0/1.10.0, analyze containers/bootloaders and perform authorized hardware acceptance; account for the vendor downgrade restriction.

## Осталось: установка, выпуск и завершение миграции / Remaining: installation and release

- [ ] Проверить UI и свежую установку комплекта 5.1.124: зависимость от slide-switch и /tmp/switch_position устранена в исходниках, все три физических положения подтверждены кандидатом из RAM на отдельном EU v3.30 23.11.2026. На отдельном стенде пакет обновлён до 5.1.124: AP, выключенный автомат и неизменный звук подтверждены; Владелец подтвердил AP → WISP → 3G/4G → AP в UI без обновления страницы; остаётся свежая установка полного комплекта. / Verify fresh installation of kit 5.1.124: the independent reader passed all three positions in RAM; the separate bench was upgraded with automation off and sound settings unchanged; the owner confirmed all UI transitions without refreshing.


- [ ] Повторить непрерывный цикл RestoreFactory → установка через Setup.cmd после исправлений: отдельно подтвердить позднюю готовность DHCP в OEM и понятное восстановление после смены SSH-ключа. 23.11.2026 установка завершена через InstallOnly, DHCP после OpenWrt и InstallOnly получен автоматически; исходный тайм-аут OEM и ручная замена записи ключа не закрыты как бесшовный сценарий. / Repeat the uninterrupted cycle, including late OEM DHCP readiness and clear changed-key recovery; final installation passed with interventions on 2026-11-23.
- [ ] Проверить реальный откат версии пакета с сохранением данных отдельно. Новая установка 5.1.123 подтверждена; наличие пакета отката не является выполненным откатом. / Verify an actual data-preserving package downgrade; fresh installation passed, but a rollback package alone is not a rollback test.
- [ ] Актуализировать команды и отдельный протокол аппаратной приёмки под окончательные артефакты. / Update commands and the hardware acceptance protocol for final artifacts.
- [ ] L2/L4: завершить материалы зависимостей, разобраться с правами на аудио и проверить окончательный релизный набор. Лицензирование ранее отложено владельцем; решение об MIT не распространяется автоматически на штатные записи. [Аудит / Audit](docs/LICENSE_AUDIT.md). / Complete dependency materials, audio rights and final release review; MIT does not automatically cover bundled recordings.
- [ ] Проверить актуальность ссылок из core и готовность публикации окончательного выпуска. / Verify core redirects and final release publication readiness.
- [ ] Проверить оставшееся дублирование с core; удалять только после проверки. Отдельный репозиторий и рабочее пространство уже используются. / Review remaining duplication with core before removal; the standalone repository/workspace is already in use.

## Выполнено и подтверждено / Completed and confirmed

- [x] 09.11.2026: OEM → OEM Build250625 через RestoreFactory в PowerShell 7 на отдельном EU v3.30 — передача, загрузка, вход прежним паролем без сброса, версия и очистка сети подтверждены. Интернет/VPN ПК сохранены; рабочее устройство не использовалось. [RU](docs/acceptance/ACCEPTANCE_RUN.md) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md). / OEM-to-OEM passed: transfer, boot, retained-password login without reset, version and network cleanup; PC Internet/VPN retained, working device untouched.

- [x] 09.11.2026: RestoreFactory через Setup.ps1 в PowerShell 7 на отдельном EU v3.30 — OpenWrt → OEM Build250625. Копии конфигурации и семи MTD проверены; передача, загрузка, вход без дополнительного сброса и версия подтверждены. DHCP восстановлен, временные адреса/правило firewall/сервер/файл состояния удалены. Интернет и VPN ПК сохранены. [RU](docs/acceptance/ACCEPTANCE_RUN.md) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md). / RestoreFactory passed on a spare EU v3.30: verified backups, transfer, OEM boot/login/version and network cleanup; no additional reset, PC Internet/VPN retained.

- [x] 09.11.2026: отдельный EU v3.30, Windows 11 / PowerShell 7: OEM → OpenWrt 19.07.9 через Reset/TFTP, установка 5.1.123 из локального комплекта, проверка служб и вход в LuCI подтверждены. После отмены первого INSTALL установка продолжена через InstallOnly без повторной прошивки. VPN оставлен включённым; проверены прямые маршруты выделенного кабеля. Владелец подтвердил версию и выключенный автомат. [RU](docs/acceptance/ACCEPTANCE_RUN.md) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md). / OEM-to-OpenWrt and local package installation passed on a spare EU v3.30 using PowerShell 7; InstallOnly resumed after cancellation, VPN retained, owner confirmed UI version and auto-off.

- [x] Владелец визуально принял строку модели в Ресурсах на стенде 5.1.122. Установка и системное значение в ответе controls проверены 09.11.2026; точная подревизия не предполагается. / Owner visual review accepted; deployment and model reporting verified on 2026-11-09.
- [x] 09.11.2026: 5.1.122 установлена после `make all`; сверены 86 файлов, содержимое резервной копии и защищённые настройки. Автозвонки выключены, громкость 50 % сохранена; перезагрузки и воспроизведения не выполнялись. / Verified deployment, backup and configuration preservation; automatic bells off, unchanged 50% volume, no reboot or playback.
- [x] 09.11.2026: установлена 5.1.123 с группировкой текстовых строк Ресурсов; 86 файлов сверены, данные сохранены, автомат выключен, громкость 50 %. UI/Pages и пакет проверены локально; модель и новая компоновка приняты владельцем. / Deployed 5.1.123, verified payload/data preservation and unchanged volume; model and layout accepted by the owner.

- [x] 09.11.2026: возврат OpenWrt → OEM на отдельном EU v3.30: исправлено смещение 512 байт, передача и загрузка подтверждены; после отдельного сброса проверены вход и Build250625 Rel.56805n. Последующая проверка RestoreFactory приведена выше. [RU](docs/SETUP_RECOVERY.md) · [EN](docs/SETUP_RECOVERY.en.md). / Accepted the aligned recovery image and stock boot/login/version; see the subsequent RestoreFactory acceptance above.
- [x] 09.11.2026: локальная проверка DryRun установки и возврата OEM — Windows PowerShell 5.1 (оба маршрута и блокирующие условия), 5 Python-тестов профилей/упаковки, TFTP loopback, побайтовое совпадение преобразованного OEM с проверенным кандидатом, валидатор ТЗ и `make all` — PASS. Обращений к стендам и прошивки в этой проверке не было; сквозная аппаратная приёмка нового мастера остаётся выше.

### 5.1.120: интерфейс и имитатор / UI and simulator

- [x] 08.11.2026: опубликованные Pages **5.1.120**, `ce2e3fa28c20`: сводка Метрик, смена Интернет/NTP, календарный предзвонок/основной, установка времени, отказ/восстановление виртуального аудио и сохранение после обновления страницы проверены в браузере. Карта: 2 успешных события, затем 3 после восстановления; ошибка исключена. Стенд не использовался. [Протокол RU](docs/acceptance/ACCEPTANCE_RUN.md#08112026--опубликованные-pages-51120) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md#2026-11-08--published-pages-51120). / Published Pages browser check passed for the listed scenarios; see the protocol for untested cases.

- [x] 08.11.2026: локальный имитатор Pages, оба режима с основным и предварительным звонком, ошибки/возврат аудио, откат виртуальных часов, журнал и карта проверены host-тестами. В браузере проверены сводки, установка времени и отсутствие мигания; результат принят владельцем. Это не аппаратная приёмка. / Local simulator scenarios passed host tests; browser UI, time setting and stable status were checked and accepted, without claiming hardware acceptance.
- [x] Общий диалог установки времени и сводка «Метрик» (Flash, громкость, Интернет), единая пометка «Демо», перенос локальных действий в имитатор и сохранение ссылок руководства/обучения реализованы. / Implemented the shared time confirmation dialog, resource summary, single demo badge and relocated local actions with guide links preserved.
- [x] 08.11.2026: полный `make all` для 5.1.120 пройден. При установке проверены резервная копия, пакет отката, все 86 файлов пакета, неизменность содержимого .sbb, громкости 50 %, защищённых настроек сети/времени и выключенное состояние автоматики. Внешний вид принят владельцем. / Full checks and upgrade verification passed; backup contents, volume, protected settings and auto-off state preserved; owner accepted the UI.

- [x] 09.11.2026: сохранены фотографии TP-Link обеих ревизий (3.30 — 4, включая упаковку; 3.20 — 3), добавлены в каталог Pages. Питание USB Type-C отмечено для 3.30; поддержка восстановления 3.20 не заявляется. / Archived both revision galleries and documented Type-C power on 3.30; 3.20 recovery remains unsupported.

- [x] 09.11.2026: сохранены официальные OEM/Python ZIP, HTML EN и русскоязычный KZ, русская MD-выжимка переведена с EN; URL/хеши и список поддержки EU Ver. 3.30 опубликованы. Автономный OEM ZIP собран в Windows из локальных архивов, штатный CheckOnly пройден без устройств. / Archived vendor sources and offline stock kit verified on Windows; complete hardware wizard acceptance remains pending.

### Работа звонков / Bell execution

- [x] 09.11.2026, 5.1.123: холодная загрузка, автомат выключен, одна запись загрузки; после явного включения предзвонок 13:25 и основной 13:26 слышны, журнал и карта согласованы (0 → 2). Учебный план восстановлен, автомат выключен, громкость 50 % и данные сохранены. TC-217–TC-220: проверка слышимых звонков после загрузки завершена. / Cold boot followed by explicit enable and two audible successful bells passed; journal/counts match, original plan/data/volume restored, automation off.


- [x] 08.11.2026, 5.1.120: сеть отключена 19:41–19:59, все страницы закрыты по подтверждению владельца. Предзвонок 19:42 и основной 19:43 слышны, журнал подтвердил оба успеха, карта 4 → 6. Интернет восстановился, учебный план возвращён, автомат выключен, громкость 50 % и данные сохранены. Индикация NTP имела отдельный дефект, TC-234 полностью не закрыт. / Both automatic bells audible offline with all browser pages closed; journal/counts matched, original plan/data/volume restored, automation off. NTP indication defect remains a separate acceptance item.

- [x] 08.11.2026, 5.1.120: горячая замена AB13X → C-Media USB PnP Sound Device через OHCI прошла без перезапуска службы. Оба автоматических звонка слышны, журнал подтвердил два успеха, карта дня 2 → 3 → 4. Учебный план восстановлен, автоматика выключена, громкость 50 % и содержимое .sbb сохранены. При замене изменился порт хаба; EHCI остаётся отдельной проверкой. [Протокол RU](docs/acceptance/ACCEPTANCE_RUN.md#08112026--горячая-замена-на-другую-аудиокарту-51120) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md#2026-11-08--hot-substitution-with-another-audio-card-51120). / AB13X-to-C-Media OHCI substitution passed with two owner-confirmed audible successes and correct counts; plan/data/volume restored, automation off. Hub port changed; EHCI remains untested.

- [x] 08.11.2026, 5.1.120: горячее переподключение AB13X через OHCI. Три автоматические попытки: два успешных слышимых звонка и одна ошибка без карты; автомат не остановился, карта дня учла только 2 успеха, пропущенный звонок не повторился. Учебный план восстановлен, автоматика выключена, громкость 50 % и содержимое .sbb сохранены. [Протокол RU](docs/acceptance/ACCEPTANCE_RUN.md#08112026--горячее-переподключение-usb-аудиокарты-51120) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md#2026-11-08--usb-audio-hot-reconnection-51120). / Same-card OHCI reconnection passed: two owner-confirmed audible successes, one logged failure excluded from counts, scheduling continued; original plan restored, automation off and volume/data unchanged.

- [x] 08.11.2026, стенд 5.1.118: загрузка без сети, затем подключение примерно через минуту по подтверждению владельца. Автозвонки остались выключенными, громкость 50 %, настройки, планы, карта и старый журнал сохранены; одна запись загрузки №431. Перед опытом часы 10:12:02, запись загрузки 10:08:27, первое чтение после подключения 10:14:25 (uptime 86 с). Откат и последующая коррекция подтверждены; точный момент коррекции не наблюдался. / Offline boot followed by owner-confirmed network reconnection: automatic bells stayed off; volume and data preserved, one boot event. Boot-time rollback and subsequent forward correction observed; exact correction time was not captured.

- [x] 08.11.2026, стенд 5.1.118: после первой холодной загрузки текущий учебный план вручную включён штатной командой (№429). После повторного отключения питания автоматика стала выключенной в сохранённых данных и исполнителе; ровно одна новая запись загрузки №430, 10:08:04 по времени устройства, без автоматических запросов звука. План, черновик, журнал и громкость 50 % сохранены. Прежние счётчики карты неизменны; включение добавило текущий день с нулём звонков. / Current plan manually enabled after the first cold boot; the second power cycle disabled automation in persistent/runtime state and logged one boot event, with no automatic playback requests. Plan, draft, journal, volume and prior daily counts preserved; enabling added a zero-count day.

- [x] 08.11.2026, стенд 5.1.118: после подтверждённого владельцем отключения и подачи питания сменился boot ID; в журнале ровно одна новая запись загрузки (№428, 10:03:13 по времени устройства). Автозвонки были и остались выключены, громкость 50 % не изменилась. Старые записи журнала, настройки, планы и карта автозвонков сохранены. / Owner-confirmed power cycle: new boot ID, exactly one boot event, automation stayed off, volume remained 50%; journal history, settings, plans and daily counts preserved.

- [x] 04.11.2026, стенд 5.1.108: предзвонок и основной звонок в обоих режимах подтверждены пользователем на слух. По расписанию — 20:47/20:48; по плану — 20:51/20:52. / Owner heard both pairs in fixed-schedule and calendar-plan modes.
- [x] Для четырёх звонков сверены источник, тип и назначенное местное время с запросами и успешными завершениями в журнале. Карта дня: 0 → 2 → 4. / Matched all four events against the journal; daily count increased from 0 to 2 to 4.
- [x] 05.11.2026: полный день «Будни» учебного плана — 15 основных и 6 предварительных звонков. Все 21 запуска и завершения совпали с журналом; карта дня — 21. Это подтверждение журнала и счётчика, а не прослушивание каждого из 21 звонка. / Full weekday: all 21 starts and completions matched the journal and daily count; this is not an audible confirmation of every bell.
- [x] По 100 успешных запусков: AB13X напрямую/OHCI, GeneralPlus напрямую/OHCI, новый хаб/OHCI + C-Media; −60 дБ, auto-off. Новых URB-ошибок не было; у AB13X отмечено одно cannot get freq. / Three successful 100-run OHCI series; no new URB errors, one cannot get freq observation for AB13X.
- [x] Реализованы явный выбор активного плана, разделение применения и включения автоматики, статус исполняемого источника. Полная приёмка граничных сценариев остаётся выше. / Explicit active-plan selection, separate apply/enable and execution-source status implemented; remaining boundary acceptance is listed above.
- [x] С 5.1.75 ведётся постоянный учёт успешных автоматических звонков. Синтетическое табло заменено реальной статистикой, позднее сверенной с журналом. / Persistent successful automatic-bell counts replaced the synthetic heatmap and were reconciled with the journal.

### Интерфейс / Interface

- [x] Старые ожидания осмотра 5.1.31/5.1.32 закрыты последующим просмотром и принятыми исправлениями иконок. / Historical 5.1.31/5.1.32 visual review requests were superseded by reviewed icon fixes.
- [x] После осмотра 5.1.44 владелец принял цикл UI, медиатеки, «Системы» и CI; сюда входят лимит 64 КиБ, инструкция и удаление неиспользуемых мелодий. Реальные сброс/перезагрузка остаются отдельной проверкой. / The reviewed 5.1.44 cycle includes media limits/deletion, System UI and CI; actual reset/reboot remain separate checks.
- [x] Базовая CSS-палитра и её порядок приняты на стенде 5.1.44, закреплены в ТЗ; нейтральное тихое расписание сохранено. / The baseline palette and ordering were approved and specified, with neutral quiet days preserved.
- [x] Приняты шапка, редактирование строк, группы действий, компактная навигация и формы в цикле до 5.1.69. Проверены 64 сочетания ширины/темы/вкладки; телефонная приёмка остаётся выше. / Header, list editing, actions, navigation and forms reviewed through 5.1.69; 64 combinations checked, phone acceptance still pending.
- [x] Приняты расширенное табло 5.1.71 и сворачиваемая область «Метрики» 5.1.72; требования согласования синтетического макета больше не являются открытыми задачами. / Expanded heatmap and collapsible Metrics were approved; synthetic mockup review is complete.
- [x] Приняты 5.1.109–5.1.118: исправление предпросмотра, сравнение часов, плашка черновика, сводки настроек, медиатека и пояснения. `make all` пройден; при установках сохранены данные и громкость, автозвонки оставлены выключенными. / Preview, clocks, draft banner, settings summaries, media library and help reviewed; host checks passed, bench data/volume preserved and automatic bells left off.
- [x] Настроены Issues и ссылки на руководства; общие исходники UI устройства и Pages проверяются вместе. / Issue forms and guide links configured; device and Pages share UI sources and checks.
- [x] Эксперименты с новыми тембрами закрыты: штатные мелодии оставлены по решению владельца. / Timbre experiments closed; stock melodies retained by owner decision.

### Миграция и инструменты / Migration and tools

- [x] M0–M1: исторический архив с SHA-256, правила/workflow, инвентарь, перенос runtime/UI/требований/руководств, скриптовый и целевой MIPS IPK, автономный комплект; CI и принятие владельцем зафиксированы. / Archive, workflow, inventory, runtime/UI/docs transfer, script and target MIPS packages and offline bundle completed; M0–M1 accepted.
- [x] Отдельный репозиторий и рабочее пространство используются; основная ветка main. / Standalone repository/workspace in use; main is the default branch.
- [x] Исходники Pages: корневой UI, guide/training/devices и явный перенос localStorage. / Pages sources include root UI, guide/training/devices and explicit localStorage migration.
- [x] Аудит происхождения кода, 33 IPK и аудио; MIT собственного кода/документации с исключениями; закреплены данные LuCI и доставка MIT/NOTICE в артефакты (L1/L3/L5). / Provenance audit and L1/L3/L5 completed; dependency/audio gaps remain above.
- [x] Обновления разрешённого стенда проверялись с резервной копией и пакетом отката, сверкой файлов и сохранности данных. Это не заменяет новую установку и настоящий downgrade. / Authorized bench upgrades checked with backups, rollback packages, file and data verification; fresh installation and actual downgrade remain separate.
- [x] Подготовлены btop для MR3020, инструкция PowerShell/SCP/SSH и автономный мастер установки Windows 11. Установка из OEM проверена на 5.1.123, ограничения перечислены выше. / btop, PowerShell/SCP/SSH instructions and Windows setup wizard prepared; OEM installation accepted on 5.1.123 within the limits above.

Подробная история изменений: [RU](CHANGELOG.md) · [EN](CHANGELOG.en.md). Эта ревизия TODO не изменяет требования или состояние стенда. / See changelogs for detailed history; this TODO review changes neither requirements nor bench state.

## Выполнено: наблюдение сети / Completed: network observation

- [x] 09.11.2026: установлена 5.1.121, проверены 86 файлов, резервная копия и сохранность настроек. Повторный обрыв 10:08–10:26: 21 снимок без ложного synced, метка NTP неизменна; Интернет восстановился. Автомат выключен, громкость 50 %, планы/журнал/карта сохранены. Свежий stratum и восстановление подтверждения не наблюдались — TC-234 остаётся частичным. / Verified upgrade and offline regression without false confirmation; full fresh-confirmation recovery remains untested.

- [x] 5.1.119: добавлена строка Интернет/NTP в Ресурсы, фоновая ограниченная проба, кэш RAM, независимое наблюдение NTP, отключение/адрес проверки в Интерфейсе; общие исходники Pages без настоящих проб. ТЗ 1.119, TC-234. На стенде подтверждены доступность Интернета, сохранение переключателя и штатное событие NTP 08.11.2026: кэш и браузер показывают синхронизацию, служба времени не перезапускалась. / Added independent Internet/NTP resources, a bounded cached background probe, Interface settings and a shared Pages UI without real probes. A native NTP event was observed on 2026-11-08; cache and browser confirm synchronization without restarting the time service.

### UI 5.1.127

- [x] Согласовать сетку действий с кнопками 48 × 48, сохранить группу листания на узком экране и единый фокус в обеих темах.
- [x] Проверка 5.1.127: `make all`; Pages и устройство, обе темы, вкладки при ширине 320/390/1280 CSS px. Переполнения страницы нет; листание и кнопки 48 × 48 проверены на устройстве. Автозвонки выключены, громкость сохранена. Это проверка браузерной компоновки, не испытание на физических телефонах.

## GUI установщика / Setup GUI

- [x] Первый QML/C++-макет и статический Windows EXE; исправлена внешняя зависимость HarfBuzz, запуск с очищенным PATH подтверждён. / Initial prototype and static EXE; HarfBuzz dependency fixed, clean-PATH launch verified.
- [x] Раздельные маршруты OpenWrt / пакеты / OEM, собственные подсказки и фото EU v3.30 с указателем Reset; модель проверена локально. / Separate routes and hints, EU v3.30 Reset photo; local model tests.
- [ ] Чистая VM, автоматизация нативных GUI-взаимодействий и аудит лицензий перед распространением. Первый реальный режим обновления проверен ниже; остальные сценарии ещё не подключены. / Clean VM, native GUI interaction automation and distribution license audit. The initial real upgrade is verified below; other backends remain pending.
- [x] Макет GUI: перенесены цвета Школьника, обе темы и системный режим; выбор сохраняется через Qt Settings. Статический EXE собран, сторонних DLL в импортах нет. / Shared colors and persistent system/light/dark themes; static EXE built without third-party DLL imports.

- [x] 23.11.2026: устранена отсутствующая зависимость Lua 5.1 в WSL; полный `make all` для текущих изменений пройден (runtime, UI, IPK, Pages). Lua требуется тестам Школьника, не GUI мастера. Стенды не использовались. / Installed missing WSL Lua 5.1 dependencies; full make all passed for the current changes. Lua is a Schoolbell test dependency, not a GUI runtime dependency. No devices accessed.

- [x] Макет: простой и экспертный режимы, обязательный первый шаг оборудования с USB–Ethernet, основной объединённый маршрут «Установить Школьник», отдельные действия Reset и понятные ошибки. / Guided/expert modes, shared equipment-first screen, mandatory USB–Ethernet, combined Schoolbell route and stepwise recovery hints.
- [ ] Проверить понятность простого режима с пользователем без опыта прошивки, без устных подсказок. / Usability-test guided mode with a first-time user without verbal coaching.

- [x] Общая модель переходов GUI и тестов: подтверждения, отмена/закрытие, повтор без новой записи, защита от старых событий и отдельная итоговая проверка. Тесты модели включены в make all. / Shared UI/test state machine covers confirmations, cancel/close, retry without restart, stale events and a separate verification gate; included in make all.

- [x] 24.11.2026: через GUI на отдельном MR3020 v3 выполнено обновление 5.1.124 → 5.1.127 поверх OpenWrt 19.07.9. BACKUP VERIFIED и UPGRADE VERIFIED получены; SHA256 копии/отката сверены, автомат выключен, звук/черновик/ревизия активного плана сохранены, службы работают. Пароль введён в форме без всплывающих окон; результат виден после автопрокрутки. / GUI upgrade passed on a separate device with verified backup, automation off and sound/plan preserved; inline password and visible result verified.
- [ ] GUI: новая установка с зависимостями, firmware backend, настройка подключения, восстановление после реального обрыва записи и аппаратная проверка последующих независимых сеансов обновления. Первый пилот ограничен переходом 5.1.124 → 5.1.127 и известным SSH-ключом; это не приёмка всего установщика. / Fresh dependencies, firmware, connection configuration, actual interrupted-write recovery and hardware acceptance of independent upgrade sessions remain pending.

- [x] GUI: поле пароля проверено при аппаратной установке из ZIP 24.11.2026; пароль сохранён между подготовкой и установкой, без повторного ввода. / Inline password retention accepted during GUI ZIP installation.

- [x] GUI: общий PasswordField, память текущей вкладки и глазок; проверены Qt Test и визуально в статическом EXE, без SSH. / Shared field and tab-scoped retention passed local Qt and EXE checks without SSH.

- [x] GUI: локальный список Ethernet по имени/IP, явный выбор и архивирование предыдущего сеанса с копиями. Неизвестный исход, повреждение и занятость блокируют архивирование. Локальные проверки не являются аппаратной приёмкой. / Named Ethernet selection and guarded session archival implemented; hardware acceptance remains pending.

- [x] GUI: исправлены отступы кнопок диалога закрытия/отмены; статическая сборка и визуальная проверка обоих режимов. / Inset close/cancel actions verified in the static build in both modes.

- [x] 24.11.2026: на отдельном устройстве повторная проверка GUI подтвердила установленную 5.1.127, выключенные автозвонки и сохранённые звук/план. После проверки пароль остался скрытым в форме; «Новый сеанс» сохранил архив и очистил пароль/выбор подключения. Повторная установка не выполнялась. / On a separate device, GUI re-verification confirmed 5.1.127, automation off and unchanged sound/plan. The masked password remained in the form; New session archived evidence and cleared password/connection. No reinstallation occurred.

- [ ] GUI, третий этап: интеграция Reset/TFTP с возвратом сети и отдельной проверкой загрузки. / GUI stage three: Reset/TFTP, network restoration and boot verification.

- [x] 24.11.2026: владелец подтвердил GUI ALREADY CURRENT на отдельном устройстве; службы/выключенный автомат проверены без записи. / Owner confirmed already-current verification without writing.
- [ ] GUI: аппаратно проверить свежую установку из полного bundle; локальные тесты реализованы. Копия MTD/overlay подтверждена отдельно ниже. / Fresh-install hardware acceptance remains pending; pre-flash backup passed separately below.

- [x] 24.11.2026: GUI сохранил проверенную копию семи MTD и overlay отдельного устройства перед прошивкой; все SHA256 повторно совпали на ПК. / GUI pre-flash backup verified for seven MTD partitions and overlay; all local hashes independently matched.

- [x] GUI: справка отделена от рабочей формы; локальный Qt-тест проверяет доступность нижних действий прокруткой при 800 × 450 в обеих темах и сохранение пароля между вкладками. / Help separated; local Qt test verifies scroll access to bottom actions at 800 × 450 in both themes and password retention.

## Выпуск комплектов / Release bundles

- [x] Имена Schoolbell Setup Wizard 0.1.0, отдельная версия EXE; контракт ZIP формата 1 и docs/releases/v5.1.127.md. / Independent wizard naming/version, ZIP v1 contract and release-note draft.
- [x] Локальный детерминированный ZIP-кандидат из закреплённого офлайн-комплекта; проверки ABI, состава, метаданных и SHA256. Публичный выпуск заблокирован. / Deterministic local candidate builder with identity/integrity checks; public release blocked.
- [x] Host install.py: свежая установка из ZIP, проверенная копия вне устройства, привязка сеанса, подтверждение и проверка после неизвестного исхода; локальные тесты без устройств. / Host fresh ZIP transaction implemented and tested locally without devices.
- [ ] Принять установку всех зависимостей ZIP на чистую OpenWrt и восстановление копии; добавить обновление с проверенным IPK отката. GUI ZIP при сохранённых зависимостях принят 24.11.2026, см. ниже. / Accept full ZIP dependency provisioning, backup restoration and rollback-backed upgrades; retained-dependency GUI installation passed on 2026-11-24.
- [x] 24.11.2026: предварительный план по снимку устройства в ZIP; локальные проверки состава, ABI, зависимостей и места. Сам по себе план не разрешает запись; подготовка и запись теперь выделены в install.py. / A preliminary plan never authorizes a write; install.py now provides separate preparation and write commands.
- [x] GUI 0.2.0: обнаружение ZIP рядом с EXE, локальная проверка, версия из manifest, фиксация комплекта/подключения и общая транзакция prepare/install/verify; локальные проверки без устройств. / GUI local ZIP discovery/validation and pinned fresh-install transaction implemented and locally tested.
- [x] Все выпадающие списки мастера используют общий StyledComboBox: одинаковая стрелка, шрифт и обе темы. / All wizard dropdowns share their chevron, typography and themed styling.
- [ ] GitHub Releases, кэш, подписи артефактов и обработка недоступности сети. / Release download, cache, signatures and offline handling.
- [ ] Подготовить переносимый ZIP мастера с runtime/лицензиями; проверить без среды разработки. Закрыть лицензии/исходники зависимостей и права аудио до публикации. / Portable wizard/runtime/license delivery and clean-host checks; clear dependency/source/audio distribution gates.

- [x] Заголовок мастера 0.2.1 и три маршрута визуально проверены в обеих темах. / Wizard 0.2.1 title and three routes visually checked in both themes.
- [ ] Проверить масштабирование 100/150/200 % на чистой Windows. / Verify 100/150/200% scaling on clean Windows.

## Текущая проверка GUI ZIP / Current GUI ZIP check

- [x] 0.2.1: только внешние ZIP, отдельная полная копия без установочного комплекта. / External bundles only, independent full backup.
- [x] 24.11.2026: GUI ZIP после разрешённого удаления приложения, с сохранёнными зависимостями: полная копия, подготовка, FRESH VERIFIED, вход в 5.1.127, автозвонки выключены, громкость 100 %. Первый SSH 255 устранён сокращением команды; исходное состояние подтверждено перед новым сеансом. / GUI ZIP app installation passed with retained dependencies after fixing Dropbear command length; backups, services, UI and unchanged volume/automation confirmed.
- [ ] Установка всех зависимостей из ZIP на чистую заводскую OpenWrt и восстановление копии остаются отдельными проверками. / Full dependency provisioning on stock OpenWrt and backup restoration remain separate acceptance tests.

- [x] GUI: общий заголовок «OpenWrt · Комплект», русское название окна; локальное восстановление результата ZIP по связанной квитанции, без обращения к устройству. / Generic bundle heading, Russian window title and bound local ZIP result restoration.

- [x] Стартовый выбор трёх маршрутов с оборудованием и пояснениями: OpenWrt, комплект, заводское восстановление; без имитации. / Three-route navigation and preparation guidance without simulation.
- [ ] Подключить к GUI отдельную прошивку OpenWrt без установки пакетов и RestoreFactory: повышение прав, выбор адаптера, READY, передача, ожидание загрузки и восстановление DHCP. / Implement GUI firmware-only and factory-recovery operations and acceptance.

## План трёх маршрутов / Three-route plan

- [ ] Выполнить этапы 0–8 [плана мастера](docs/SETUP_WIZARD_PLAN.md): общие операции → сеть/профили → OpenWrt → встроенный OEM → комплекты/копии → релизы и поставка. / Follow [stages 0–8](docs/SETUP_WIZARD_PLAN.en.md).
- [ ] Встроить проверенный OEM EU v3.30 Build250625 и обеспечить автономный возврат без Интернета; заводской сброс настроек остаётся отдельным действием. / Embed verified OEM for offline recovery; keep settings reset separate.

- [x] Общий локальный канал операций: типизированные итоги, ID/последовательность, этапы, кооперативная отмена чтений; host-проверки без устройств. / Structured local operation results, IDs, phases and cooperative read cancellation.
- [ ] Принять новый протокол и отмену в GUI на отдельном устройстве; проверить восстановление аварийных lock/guard на устройстве. / Hardware acceptance and device crash-lock recovery acceptance remain pending.

- [x] GUI: локальные тесты блокировки ОС, гибели worker, восстановления маркеров, сохранности копий и отказа для legacy/corrupt lock. / Local OS lease, worker crash, recovery and evidence preservation tests. Проверено в WSL и упакованном Python Windows: 5 тестов; Qt: 15 PASS; make all и статическая сборка PASS. Аппаратная проверка не выполнялась. / WSL and packaged Windows Python: 5 tests; Qt: 15 PASS; make all and static build PASS; no hardware test.

- [x] Сеть мастера: чистый планировщик по снимку; 10 локальных тестов обоих профилей, DHCP/линка, конфликтов/VPN, портов и идентичности адаптера. / Pure snapshot planner: 10 local tests for both profiles and network blockers.
- [ ] Принять реальную настройку/восстановление сети; подключить firewall/TFTP и встроенный OEM. DryRun-план не заменяет аппаратную проверку. / Accept real network preparation/restoration; connect firewall/TFTP and embedded OEM; planner tests are not hardware acceptance.

- [x] Windows-снимок и GUI предварительной проверки: адаптер без IP, подтверждение модели, новый снимок на каждую проверку, сброс старого итога. / Windows inventory and GUI preflight: no-IP adapter selection, model confirmation, fresh snapshot and stale-result clearing.

- Локальная проверка сетевого GUI: make all PASS; 16 Qt-тестов PASS; 10 тестов планировщика в WSL/Windows и 3 теста адаптера worker PASS. Упакованный worker прочитал настройки Windows и построил планы обоих профилей; сеть и стенды не изменялись. Статический EXE пересобран. / Network GUI validation: make all, 16 Qt tests, 10 planner tests on WSL/Windows and 3 worker tests passed; packaged inventory and both profiles passed without network mutation or device access; static EXE rebuilt.

- [x] Сетевой UAC-helper подключён к GUI: журнал до добавления адреса, прямой маршрут, возврат DHCP, защита от конкуренции и неизвестной принадлежности адреса. Локальные mock-тесты; реальные сетевые изменения не выполнялись. / GUI UAC helper connected with journal, route check, DHCP restore and ownership/concurrency guards; mocked tests only.
- [ ] Отдельно принять UAC (включая отмену), временный адрес и восстановление DHCP на выделенном USB–Ethernet; проверить повтор после закрытия мастера, отсутствующий адаптер и позднюю аренду. / Accept real UAC/cancel, temporary address, DHCP restoration, restart, unplugged adapter and late lease separately.

- Проверки группы UAC-helper: make all PASS, 17 Qt-тестов PASS, 4 теста моста UAC PASS, PowerShell mock-сценарии PASS; статический EXE собран. Настоящее повышение прав и сетевые команды не запускались. / UAC-helper group: make all, 17 Qt tests, 4 bridge tests and PowerShell mocked scenarios passed; static EXE built. No real elevation or network mutation was run.

## Повторяемая установка GUI / Repeatable GUI installation

- [x] Пользователь подтвердил новую установку OpenWrt; выявлено наследование старого пакетного сеанса и SSH-ключа. / Owner confirmed OpenWrt installation; stale package state and host key identified.
- [x] Пользователь подтвердил новую установку из ZIP и установку поверх той же версии 5.1.127, открытие Школьника по кнопке и текстовой ссылке. / Owner confirmed fresh ZIP installation, same-version 5.1.127 reinstall, and opening Schoolbell via both button and text link.
- [ ] Отдельно проверить повтор после ошибки записи, неверный пароль и сохранение пользовательского плана/громкости при повторной установке. / Separately accept retry after a write failure, invalid password, and preservation of a populated plan/volume on reinstall.

- [x] Пользователь подтвердил новую установку 5.1.127 через GUI с принятием нового SSH-ключа: INSTALL VERIFIED, службы работают, автомат выключен; сетевые/системные файлы сверены. Повтор поверх той же версии затем подтверждён пользователем 26.11.2026. / Owner confirmed fresh GUI installation and explicit host-key acceptance; same-version reinstall was subsequently confirmed on 2026-11-26.

## Кандидат мастера 0.3.1 / Wizard 0.3.1 candidate

- [x] Локально: 20 Qt-проверок, 24 проверки worker, 23 сценария ZIP с подменённым транспортом; ТЗ 1.26 без замечаний. / Local Qt, worker, injected ZIP transport and specification checks passed.
- [ ] Собрать на GitHub точный принятый HEAD, скачать пару 0.3.1/5.1.127, проверить суммы, запуск и все заявленные маршруты из скачанной поставки. Локальная сборка не заменяет эту проверку. / Build accepted HEAD on GitHub and accept the downloaded exact pair.
- [ ] После проверки пары оформить первый предварительный релиз владельцем; не заменять старые опубликованные артефакты. / Owner publishes the first preview after pair acceptance; do not replace existing published assets.
