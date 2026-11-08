# Задачи проекта / Project tasks

Актуализировано 08.11.2026 по результатам до 5.1.120 включительно. Выполненное отделено от оставшихся проверок. Старые версии в подтверждениях обозначают дату результата, а не версию для следующей проверки. Новые аппаратные проверки выполнять на согласованной текущей версии и отдельно разрешённом устройстве. / Reviewed on 2026-11-08 through 5.1.120. Historical results are not new hardware acceptance; use an agreed current version and authorized target for remaining checks.

## Осталось: надёжность / Remaining: reliability

- [ ] TC-234: проверить реальные отключение сети и длительную потерю NTP с возвратом связи. В 5.1.119 проверены host-модели кэша/таймаутов и установка без изменения сети; эти модели не заменяют аппаратный разрыв. / Verify physical network loss and prolonged NTP loss/recovery; host models do not replace these hardware scenarios.

- [ ] После холодной загрузки проверить следующий автоматический звонок на слух после ручного включения (TC-217–TC-220). Оба исходных состояния автоматики и ручное включение текущего плана уже проверены 08.11.2026; в тихий день звонков не ожидалось. / Verify the next audible scheduled bell after manual enablement following a cold boot; both prior automation states and manual enablement were checked on 2026-11-08, a quiet day.
- [ ] Дополнить проверку USB-аудио заменой на другую карту. Отключение и повторное подключение той же AB13X через OHCI проверены 08.11.2026; прежний хаб/EHCI остаётся отдельным сценарием. / Extend USB audio coverage to substitution with a different card. Same-card AB13X reconnection over OHCI passed on 2026-11-08; the former hub/EHCI remains a separate scenario.
- [ ] Локализовать периодические отказы прежнего сочетания хаба/EHCI и проверить исправление на нём. Успешные OHCI-серии и учебный день не доказывают исправление этого сочетания. [RU](docs/PLAYBACK_RELIABILITY.md) · [EN](docs/PLAYBACK_RELIABILITY.en.md). / Diagnose the earlier hub/EHCI failures and verify a fix on that combination; OHCI success does not close this defect.
- [ ] Установить причину оставшегося пустого замка медиатеки после завершения запросов. Безопасное восстановление выполнено; автоматическое снятие не добавлялось. / Find the cause of the orphan empty media gate; recovery was performed, automatic removal was not added.
- [ ] Измерить задержку от нажатия ручного звонка до слышимого звука. Замер до запуска процесса не учитывает браузер и USB. / Measure click-to-audible latency, including the browser and USB path.

## Осталось: сценарии и сохранность данных / Remaining: workflows and data

- [ ] Сверить полноту TC-207–TC-210 с существующими тестами и аппаратными результатами; актуализировать матрицу приёмки. Выбор плана и штатные звонки уже работают, но это не закрывает все граничные сценарии. / Reconcile TC-207–TC-210 with existing tests and bench evidence; working plan selection and scheduled bells do not cover every boundary case.
- [ ] Подтвердить недостающие сценарии TC-207–TC-209: выбор среди нескольких планов, границы/полночь, сохранённый и применённый снимки, конкурирующее применение, отсутствующий план, переименование, импорт и восстановление. / Verify any uncovered multi-plan, boundary, applied-snapshot, concurrency and recovery cases.
- [ ] Для TC-210 отдельно подтвердить ещё не зафиксированные условия: закрытый браузер, пустой праздничный день, отсутствие прироста счётчика от ручного звонка. Ошибка отсутствия аудиокарты исключена из счётчика в проверке 08.11.2026. Успешные пары и полный учебный день уже зафиксированы ниже. / Complete unrecorded TC-210 conditions: closed browser, empty holiday, no counter increment for manual playback. Audio-unavailable failure exclusion was verified on 2026-11-08.
- [ ] Проверить реальные перезагрузку и сброс из раздела «Система», включая сохранение пользовательских мелодий и журнала при сбросе. Внешний вид раздела уже принят. / Verify actual reboot and reset, including retention of uploaded melodies and journal; UI review is complete.
- [ ] Завершить TC-195: сохранность встроенных цветов/ID при импорте и восстановлении, темы и остальные шаги полного сценария. Внешний вид и порядок палитры подтверждены. / Complete palette persistence and remaining TC-195 cases; appearance and ordering are approved.

## Осталось: интерфейс и Pages / Remaining: UI and Pages



- [ ] Подтвердить на реальном телефоне панель сохранения и отсутствие горизонтального выхода страницы за экран. / Confirm the save bar and absence of horizontal overflow on a real phone.
- [ ] Завершить TC-197 для текущего UI: обе темы, узкий экран, фокус клавиатуры, disabled, размеры и отступы одинаковых элементов. Ранее проверенные 64 сочетания относятся к 5.1.69, а не ко всем последующим изменениям. / Complete current UI consistency checks; the earlier 64 combinations cover 5.1.69 only.
- [ ] Дополнить проверку опубликованных Pages: режим «По расписанию», остальные скорости имитатора, прямое редактирование даты, отмена диалога времени и реальный телефон. Подтверждённые сценарии 5.1.120 перечислены ниже; это не полное закрытие TC-235/TC-236. / Extend published Pages coverage to fixed-schedule mode, other speeds, direct date editing, time-dialog cancellation and a real phone; the checks below do not fully close TC-235/TC-236.

## Осталось: установка, выпуск и завершение миграции / Remaining: installation and release

- [ ] Проверить полный путь Setup.cmd на отдельном заводском TL-MR3020 EU v3.30 с Windows 11 без интернета. / Verify offline setup end to end on a spare factory router.
- [ ] Проверить новую установку и реальный откат с сохранением данных отдельно. Наличие проверенного пакета отката не является выполненным откатом. / Verify fresh installation and actual data-preserving downgrade; a rollback package alone is not a rollback test.
- [ ] Актуализировать команды и отдельный протокол аппаратной приёмки под окончательные артефакты. / Update commands and the hardware acceptance protocol for final artifacts.
- [ ] L2/L4: завершить материалы зависимостей, разобраться с правами на аудио и проверить окончательный релизный набор. Лицензирование ранее отложено владельцем; решение об MIT не распространяется автоматически на штатные записи. [Аудит / Audit](docs/LICENSE_AUDIT.md). / Complete dependency materials, audio rights and final release review; MIT does not automatically cover bundled recordings.
- [ ] Проверить актуальность ссылок из core и готовность публикации окончательного выпуска. / Verify core redirects and final release publication readiness.
- [ ] Проверить оставшееся дублирование с core; удалять только после проверки. Отдельный репозиторий и рабочее пространство уже используются. / Review remaining duplication with core before removal; the standalone repository/workspace is already in use.

## Выполнено и подтверждено / Completed and confirmed

### 5.1.120: интерфейс и имитатор / UI and simulator

- [x] 08.11.2026: опубликованные Pages **5.1.120**, `ce2e3fa28c20`: сводка Метрик, смена Интернет/NTP, календарный предзвонок/основной, установка времени, отказ/восстановление виртуального аудио и сохранение после обновления страницы проверены в браузере. Карта: 2 успешных события, затем 3 после восстановления; ошибка исключена. Стенд не использовался. [Протокол RU](docs/acceptance/ACCEPTANCE_RUN.md#08112026--опубликованные-pages-51120) · [EN](docs/acceptance/ACCEPTANCE_RUN.en.md#2026-11-08--published-pages-51120). / Published Pages browser check passed for the listed scenarios; see the protocol for untested cases.

- [x] 08.11.2026: локальный имитатор Pages, оба режима с основным и предварительным звонком, ошибки/возврат аудио, откат виртуальных часов, журнал и карта проверены host-тестами. В браузере проверены сводки, установка времени и отсутствие мигания; результат принят владельцем. Это не аппаратная приёмка. / Local simulator scenarios passed host tests; browser UI, time setting and stable status were checked and accepted, without claiming hardware acceptance.
- [x] Общий диалог установки времени и сводка «Метрик» (Flash, громкость, Интернет), единая пометка «Демо», перенос локальных действий в имитатор и сохранение ссылок руководства/обучения реализованы. / Implemented the shared time confirmation dialog, resource summary, single demo badge and relocated local actions with guide links preserved.
- [x] 08.11.2026: полный `make all` для 5.1.120 пройден. При установке проверены резервная копия, пакет отката, все 86 файлов пакета, неизменность содержимого .sbb, громкости 50 %, защищённых настроек сети/времени и выключенное состояние автоматики. Внешний вид принят владельцем. / Full checks and upgrade verification passed; backup contents, volume, protected settings and auto-off state preserved; owner accepted the UI.


### Работа звонков / Bell execution

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
- [x] Подготовлены btop для MR3020, инструкция PowerShell/SCP/SSH и автономный мастер установки Windows 11. Сквозная проверка мастера на заводском устройстве ещё предстоит. / btop, PowerShell/SCP/SSH instructions and Windows setup wizard prepared; factory-device acceptance is pending.

Подробная история изменений: [RU](CHANGELOG.md) · [EN](CHANGELOG.en.md). Эта ревизия TODO не изменяет требования или состояние стенда. / See changelogs for detailed history; this TODO review changes neither requirements nor bench state.

## Выполнено: наблюдение сети / Completed: network observation

- [x] 5.1.119: добавлена строка Интернет/NTP в Ресурсы, фоновая ограниченная проба, кэш RAM, независимое наблюдение NTP, отключение/адрес проверки в Интерфейсе; общие исходники Pages без настоящих проб. ТЗ 1.119, TC-234. На стенде подтверждены доступность Интернета, сохранение переключателя и штатное событие NTP 08.11.2026: кэш и браузер показывают синхронизацию, служба времени не перезапускалась. / Added independent Internet/NTP resources, a bounded cached background probe, Interface settings and a shared Pages UI without real probes. A native NTP event was observed on 2026-11-08; cache and browser confirm synchronization without restarting the time service.
