# Задачи проекта / Project tasks

Актуализировано 08.11.2026 по результатам до 5.1.118 включительно. Выполненное отделено от оставшихся проверок. Старые версии в подтверждениях обозначают дату результата, а не версию для следующей проверки. Новые аппаратные проверки выполнять на согласованной текущей версии и отдельно разрешённом устройстве. / Reviewed on 2026-11-08 through 5.1.118. Historical results are not new hardware acceptance; use an agreed current version and authorized target for remaining checks.

## Осталось: надёжность / Remaining: reliability

- [ ] Проверить холодную загрузку: запись загрузки в журнале, автозвонки остаются выключенными, последующий ручной запуск автоматики (TC-217–TC-220). / Verify boot logging, automatic bells staying off after a cold boot and subsequent manual enablement.
- [ ] Проверить отключение и горячую замену USB-аудиокарты: автомат продолжает работу, попытки и ошибки видны в журнале, следующий звонок после восстановления слышен. / Verify continued scheduling, logged failures and the next audible bell after hot replacement.
- [ ] Локализовать периодические отказы прежнего сочетания хаба/EHCI и проверить исправление на нём. Успешные OHCI-серии и учебный день не доказывают исправление этого сочетания. [RU](docs/PLAYBACK_RELIABILITY.md) · [EN](docs/PLAYBACK_RELIABILITY.en.md). / Diagnose the earlier hub/EHCI failures and verify a fix on that combination; OHCI success does not close this defect.
- [ ] Установить причину оставшегося пустого замка медиатеки после завершения запросов. Безопасное восстановление выполнено; автоматическое снятие не добавлялось. / Find the cause of the orphan empty media gate; recovery was performed, automatic removal was not added.
- [ ] Измерить задержку от нажатия ручного звонка до слышимого звука. Замер до запуска процесса не учитывает браузер и USB. / Measure click-to-audible latency, including the browser and USB path.

## Осталось: сценарии и сохранность данных / Remaining: workflows and data

- [ ] Сверить полноту TC-207–TC-210 с существующими тестами и аппаратными результатами; актуализировать матрицу приёмки. Выбор плана и штатные звонки уже работают, но это не закрывает все граничные сценарии. / Reconcile TC-207–TC-210 with existing tests and bench evidence; working plan selection and scheduled bells do not cover every boundary case.
- [ ] Подтвердить недостающие сценарии TC-207–TC-209: выбор среди нескольких планов, границы/полночь, сохранённый и применённый снимки, конкурирующее применение, отсутствующий план, переименование, импорт и восстановление. / Verify any uncovered multi-plan, boundary, applied-snapshot, concurrency and recovery cases.
- [ ] Для TC-210 отдельно подтвердить ещё не зафиксированные условия: закрытый браузер, пустой праздничный день, отсутствие прироста счётчика от ручного звонка и ошибки. Успешные пары и полный учебный день уже зафиксированы ниже. / Complete unrecorded TC-210 conditions: closed browser, empty holiday, no counter increment for manual playback or failure.
- [ ] Проверить реальные перезагрузку и сброс из раздела «Система», включая сохранение пользовательских мелодий и журнала при сбросе. Внешний вид раздела уже принят. / Verify actual reboot and reset, including retention of uploaded melodies and journal; UI review is complete.
- [ ] Завершить TC-195: сохранность встроенных цветов/ID при импорте и восстановлении, темы и остальные шаги полного сценария. Внешний вид и порядок палитры подтверждены. / Complete palette persistence and remaining TC-195 cases; appearance and ordering are approved.

## Осталось: интерфейс и Pages / Remaining: UI and Pages

- [ ] Подтвердить на реальном телефоне панель сохранения и отсутствие горизонтального выхода страницы за экран. / Confirm the save bar and absence of horizontal overflow on a real phone.
- [ ] Завершить TC-197 для текущего UI: обе темы, узкий экран, фокус клавиатуры, disabled, размеры и отступы одинаковых элементов. Ранее проверенные 64 сочетания относятся к 5.1.69, а не ко всем последующим изменениям. / Complete current UI consistency checks; the earlier 64 combinations cover 5.1.69 only.
- [ ] Проверить опубликованные Pages владельцем на актуальной версии. Сборка и тесты общих исходников не заменяют проверку опубликованного сайта. / Review the current published Pages; source checks do not prove the deployed site.

## Осталось: установка, выпуск и завершение миграции / Remaining: installation and release

- [ ] Проверить полный путь Setup.cmd на отдельном заводском TL-MR3020 EU v3.30 с Windows 11 без интернета. / Verify offline setup end to end on a spare factory router.
- [ ] Проверить новую установку и реальный откат с сохранением данных отдельно. Наличие проверенного пакета отката не является выполненным откатом. / Verify fresh installation and actual data-preserving downgrade; a rollback package alone is not a rollback test.
- [ ] Актуализировать команды и отдельный протокол аппаратной приёмки под окончательные артефакты. / Update commands and the hardware acceptance protocol for final artifacts.
- [ ] L2/L4: завершить материалы зависимостей, разобраться с правами на аудио и проверить окончательный релизный набор. Лицензирование ранее отложено владельцем; решение об MIT не распространяется автоматически на штатные записи. [Аудит / Audit](docs/LICENSE_AUDIT.md). / Complete dependency materials, audio rights and final release review; MIT does not automatically cover bundled recordings.
- [ ] Проверить актуальность ссылок из core и готовность публикации окончательного выпуска. / Verify core redirects and final release publication readiness.
- [ ] Проверить оставшееся дублирование с core; удалять только после проверки. Отдельный репозиторий и рабочее пространство уже используются. / Review remaining duplication with core before removal; the standalone repository/workspace is already in use.

## Выполнено и подтверждено / Completed and confirmed

### Работа звонков / Bell execution

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
