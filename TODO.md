# Задачи проекта / Project tasks

- [ ] Проверить полный путь Setup.cmd на отдельном заводском TL-MR3020 EU v3.30 с Windows 11 без интернета. / Verify the offline Windows 11 setup end to end on a spare factory TL-MR3020 EU v3.30.

## Приоритет: надёжная подача звонков / Priority: reliable playback

- [ ] При аппаратной приёмке измерить время от нажатия ручной кнопки до слышимого звука; серверный замер до запуска процесса не учитывает браузер и USB. / Measure click-to-audible latency on hardware; handler-to-fork timing excludes the browser and USB output.

- [ ] Аппаратная приёмка 5.1.80: проверить холодную загрузку и горячую замену карты с прослушиванием следующего автоматического звонка (TC-217–TC-220). / Hardware acceptance: verify a cold boot and replace the audio card before the next audible automatic bell.

- [x] 04.11.2026, стенд 5.1.108: после отдельного запуска по расписанию (20:47, 20:48) и по плану (20:51, 20:52) предзвонок и основной звонок в обоих режимах подтверждены на слух. / Both pre-bells and main bells were heard after separately starting each applied source.
- [x] Для этих четырёх звонков сверены источник, тип и назначенное местное время с запросами и успешными завершениями в журнале. Счётчик дня на карте изменился с 0 до 2 и затем до 4. / Verified source, kind and local due time against journal requests and completions. The daily count rose from 0 to 2 to 4.
- [ ] Явный выбор исполняемого календарного плана, статус применённого снимка и сквозная приёмка TC-207–TC-210 / Explicit calendar plan selection, applied status and end-to-end acceptance.

- [ ] Установить причину оставшегося пустого замка медиатеки после завершения запросов; безопасное восстановление выполнено, автоматическое снятие не добавлялось / Identify the cause of the orphan empty media gate; safe recovery performed, no automatic gate removal added.

- [x] Прежняя AB13X напрямую/OHCI: 100 успехов подряд, −60 дБ, auto-off; без новых ошибок URB, одна запись cannot get freq / Original AB13X direct/OHCI: 100 consecutive successes, -60 dB, auto off; no new URB errors, one cannot get freq message.

- [x] 100 успешных запусков подряд при прямом подключении GeneralPlus/OHCI, −60 дБ, auto-off; без новых ошибок ядра / 100 consecutive successful direct GeneralPlus/OHCI launches at -60 dB, auto off, no new kernel errors.
- [x] Новый хаб (12 Мбит/с, OHCI) + C-Media: 100 успешных запусков подряд, без новых сообщений ядра; −60 дБ, auto-off / New hub (12 Mbit/s, OHCI) + C-Media: 100 consecutive successes, no new kernel messages; -60 dB, auto off.
- [ ] Локализовать причину отказов прежнего сочетания хаба/EHCI; успешная OHCI-серия не закрывает её / Isolate the earlier hub/EHCI failures; the successful OHCI series does not resolve them.

- [ ] Устранить воспроизведённый периодический отказ USB-аудио; сохранить причины ошибок, проверить повторные запуски и длительное расписание / Fix reproduced intermittent USB-audio failure, retain diagnostic reasons, verify repeated starts and endurance. [RU](docs/PLAYBACK_RELIABILITY.md) · [EN](docs/PLAYBACK_RELIABILITY.en.md).
- Лицензирование отложено владельцем; зелёные host-тесты не закрывают этот дефект / Owner deferred licensing; passing host tests do not close this defect.

## На согласовании / Pending review

- [x] Владелец поручил проверку целостности и фиксацию цикла 5.1.61–5.1.69 в ветке; 64 сочетания ширины/темы/вкладки проверены локально / Owner authorized consistency review and grouped commits for 5.1.61–5.1.69; 64 local viewport/theme/tab combinations checked.
- [ ] Подтвердить на телефоне исправления 5.1.69: панель сохранения в потоке и отсутствие выхода страницы за экран / Confirm 5.1.69 phone layout: in-flow save toolbar and no page overflow.

- [x] Принято: панели сохранения черновика/настроек 5.1.68 / Reviewed draft/settings save panels in 5.1.68.

- [x] Принято: компактный предпросмотр и ручную проверку звука 5.1.67 / Reviewed compact preview and manual sound controls in 5.1.67.

- [x] Принято: группировку действий плана и компактные формы 5.1.66 / Reviewed grouped plan actions and compact forms in 5.1.66.

- [x] Принято: ✓/× инструментов диапазона 5.1.65 / Reviewed range tool ✓/× buttons in 5.1.65.

- [x] Принято: кнопки +/⧉ календарного плана 5.1.64 / Reviewed calendar plan +/⧉ buttons in 5.1.64.

- [x] Принято: компактную навигацию календаря 5.1.63 / Reviewed compact calendar pagination in 5.1.63.

- [x] Принято: слайдер громкости и компактные инструменты расписания/журнала 5.1.62 / Reviewed the volume slider and compact schedule/journal tools in 5.1.62.

- [x] Принято: совместимые значки 5.1.61: * для правки, автозвонки без значка режима / Reviewed 5.1.61 compatible symbols: * for editing, no automatic-mode icon.

- [x] Владелец принял компактную шапку 5.1.60 и разрешил фиксацию текущего цикла в ветке / Owner accepted the compact 5.1.60 header and authorized committing the current cycle on a branch.

- [ ] Принять интерфейс «Система» в 5.1.38; реальную перезагрузку/сброс проверять отдельно по разрешению владельца / Review System UI in 5.1.38; actual reboot/reset requires separate owner authorization.

- [ ] Принять лимит 64 КиБ, инструкцию и удаление неиспользуемых мелодий в 5.1.36 / Review the 64 KiB limit, instructions and unused melody deletion in 5.1.36.

- [x] Владелец разрешил сгруппированные коммиты правок UI, медиатеки, системы и CI после осмотра 5.1.44 / Owner authorized grouped UI, media, system and CI commits after reviewing 5.1.44.

## Миграция / Migration

- [x] Архив старых 20 файлов с SHA-256 / Archive the 20 legacy files with SHA-256.
- [x] Правила, workflow и инвентарь / Rules, workflow and inventory.
- [x] Проверка каркаса на хосте / Host foundation verification.
- [x] M0: CI отправленного HEAD и принятие владельцем / Exact pushed HEAD CI and owner acceptance.
- [x] Перенести runtime, UI и явные зависимости / Transfer runtime, UI and explicit dependencies.
- [x] Скриптовый IPK и host-тесты, offline-builder без обязательного core / Script IPK, host tests, optional-core bundle builder.
- [x] Целевой MIPS IPK и реальный полный комплект / Target MIPS IPK and real complete bundle.
- [x] M1: CI точного HEAD и принятие владельцем / Exact-HEAD CI and owner acceptance.
- [x] Перенесены требования, история, руководства и программа приёмки / Requirements, history, guides and acceptance programme transferred.
- [ ] Актуализировать команды и отдельный протокол под будущие артефакты приёмки / Update commands and create a separate protocol for future acceptance artifacts.
- [x] Исходники Pages: корневой UI, guide/training/devices, явный перенос localStorage / Pages sources and explicit localStorage transfer.
- [ ] Приёмка опубликованных Pages владельцем / Owner acceptance of published Pages.
- [x] Аудит происхождения кода, 33 IPK и аудио / Audit code, 33 IPKs and audio provenance.
- [x] L1: MIT собственного кода и документации с явными исключениями / MIT for own code/documentation with explicit exclusions.
- [x] L3: закреплённые данные LuCI; L5: доставка собственного MIT/NOTICE во все артефакты / Pinned LuCI data and own MIT/NOTICE delivery in all artifacts.
- [ ] L2/L4: полные материалы зависимостей и права на аудио; повторная проверка окончательного релизного набора / Complete dependency materials and audio rights; final release review. См. / See [audit](docs/LICENSE_AUDIT.md).
- [x] Обновление 5.1.27 → 5.1.28 на разрешённом стенде: бэкап, сохранность данных, native и auto-off / Authorized bench upgrade: backup, data preservation, native and auto-off.
- [x] Подтверждение интерфейса владельцем после миграции / Owner UI confirmation after migration.
- [ ] Проверить реальный откат с данными и новую установку отдельно / Separately verify actual data-preserving downgrade and fresh installation.
- [ ] Публикация владельцем и ссылки из core / Owner publication and core redirects.
- [ ] Отдельное рабочее пространство; удалить дублирование после проверки / Separate workspace; remove duplication only after verification.

5.1.27: владелец подтвердил отображение Flash/uptime и динамической медиатеки
на стенде разработки. Это не подтверждение загрузки/замены новой мелодии или
полной сквозной приёмки. / Owner confirmed the Flash/uptime and dynamic collection
UI on the development bench, not new upload/replacement or full acceptance.

Pages: корень /schoolbell/ сразу открывает интерфейс звонка; руководство и обучение отдельно. / Pages root opens the bell UI directly; guide and training stay separate.

MIT собственного кода оформлена: [область действия](docs/LICENSING.md). / Own-code MIT is formalized: [scope](docs/LICENSING.en.md).

Штатные мелодии оставлены без изменений по решению владельца; подбор новых тембров закрыт. / Owner retained stock melodies unchanged; timbre exploration is closed.

2026-10-31: по сообщению владельца настройка времени из браузера, похоже, работает.
На приложенном скриншоте UI сообщает об успешной установке/проверке, разница около
1 с, автозвонки выключены; достоверность времени ещё не подтверждена. Версия и
целевое устройство в этом наблюдении не зафиксированы; это не новый протокол
аппаратной приёмки. / Owner reports browser time setting appears to work. Screenshot
shows successful setting/verification, about 1 s difference, automatic bells off and
time trust still unconfirmed. Version/target are not recorded; this is not a new
hardware acceptance protocol.

- [x] Строка аудио /dev/dsp под Flash, имя карты и сохранённое усиление; синий Flash до 75% — исходники 5.1.29 / Default audio status, card name and saved gain; blue Flash up to 75% — 5.1.29 sources.
- [x] 5.1.29 установлена на разрешённый стенд: 78 файлов, бэкап, GET-контроллер шапки и форматирование живого ответа проверены; −60 дБ, auto-off / 5.1.29 installed on the authorized bench: 78 files, backup, header GET controller and live-response formatting verified; -60 dB, auto off.
- [x] Владелец подтвердил внешний вид шапки 5.1.30 / Owner confirmed the 5.1.30 header appearance.

- [x] Расширить линии шапки и обновить ключ кеша CSS (5.1.30) / Widen header bars and update the CSS cache key (5.1.30).
- [x] Постоянная высота аудиостроки без сдвига интерфейса при переносе / Fixed-height audio status prevents layout shifts when text wraps.

- [x] Установка 5.1.30 на стенд: данные и −12 дБ сохранены, auto-off, новый CSS проверен по HTTP / Bench upgrade to 5.1.30: data and -12 dB preserved, auto off, new CSS verified over HTTP.

- [x] Правки общего UI и журнал только по размеру, кандидат 5.1.31 / Shared UI refinements and size-only journal retention, candidate 5.1.31.
- [x] Установка 5.1.31 на стенд: файлы, данные, 187 записей журнала и HTTP-ресурсы проверены; громкость сохранена, auto-off / Bench upgrade to 5.1.31: files, data, 187 journal entries and HTTP assets verified; gain preserved, auto off.
- [ ] Визуальное подтверждение интерфейса 5.1.31 владельцем / Owner visual confirmation of the 5.1.31 interface.

- [x] Уточнение иконок: действия 🔊/🔔, узлы цепочек — окно/устройство (5.1.32) / Correct action icons to 🔊/🔔, keep window/device chain nodes (5.1.32).

- [x] Установка 5.1.32: файлы, данные и 194 записи журнала проверены, громкость сохранена, auto-off / 5.1.32 installed: files, data and 194 journal entries verified, gain preserved, auto off.
- [ ] Визуальное подтверждение исправленных иконок 5.1.32 владельцем / Owner visual confirmation of corrected 5.1.32 icons.

- [x] 5.1.39: проверка резервной копии только при открытии раздела; исключена конкуренция закрытого блока со списком мелодий после F5. Проверить субъективную задержку в браузере владельца после установки.

- [x] 5.1.41: повторные F5 в реальном Chrome — расписания готовы за 1,36–1,48 с; первая загрузка после обновления 2,66 с. Полный список мелодий остаётся 2,32–2,91 с / Real Chrome repeat reloads: draft ready in 1.36–1.48 s; first after upgrade 2.66 s. Full melody list still takes 2.32–2.91 s.

- [x] 5.1.42: вдвое уменьшен отступ перед удалением в обеих таблицах / Halved the gap before deletion in both tables.

- [x] 5.1.43: увеличены значки прослушивания в обеих таблицах / Enlarged playback icons in both tables.

- [x] 5.1.44: встроенная CSS-палитра по ТЗ 1.81, стабильные номера 1–16 / Built-in CSS palette per specification 1.81, stable IDs 1–16.

- [x] ТЗ 1.81: закрепить согласованные CSS-имена/HEX и встроенный порядок 1–16 / Record approved CSS names/HEX and built-in order 1–16.
- [x] Внедрить базовую CSS-палитру по ТЗ 4.6.64–4.6.66 в общий UI и иллюстрации / Implement the baseline CSS palette in shared UI and illustrations.
- [ ] TC-195: подтвердить новую палитру на стенде; полный цикл импорта/восстановления отдельно / Confirm the new palette on the bench; full import/restore cycle separately.

- [x] 5.1.44 установлена на разрешённый стенд; бэкап, файлы/HTTP, журнал и сохранность громкости/auto-off проверены / 5.1.44 installed on the authorized bench; backup, files/HTTP, journal and preserved volume/auto-off verified.

- [x] Владелец подтвердил внешний вид базовой CSS-палитры на стенде 5.1.44 / Owner confirmed the baseline CSS palette appearance on the 5.1.44 bench.

- [x] 5.1.45: общий маршрут обратной связи в Issues schoolbell, собственные формы и ссылки на руководства RU/EN / Shared schoolbell Issues feedback links, tailored forms and RU/EN guide links.

- [x] 5.1.46: местная дата и день недели в часах шапки / Device-local date and weekday in the header clock.

- [x] Единые крестики удаления и центрирование заголовков переключателей/действий / Consistent delete icons and centered switch/action headings.
- [x] 5.1.48: вставка после строки, фокус времени, перестановка вверх/вниз и явная очистка / Insert after a row, focus time, reorder up/down and explicit clear.

- [x] Общий стандарт UI в ТЗ 1.83 и крупные плюс/стрелки/копирование / Shared UI conventions and larger add/move/copy icons.
- [ ] TC-197: полный визуальный аудит общего стиля в обеих темах и на узком экране / Full shared-style visual audit in both themes and narrow layouts.

- [x] 5.1.52: добавление/замена мелодий из таблицы без перестановки и массового удаления / Add/replace melodies from the table without reordering or bulk deletion.

- [x] 5.1.53: отдельное сохранение названия пользовательской мелодии, 🖉/✓ и упрощённая таблица / Title-only melody editing, 🖉/✓ and a simplified table.

- [x] 5.1.54: пробелы и настоящие плюсы при переименовании, проверка query-декодера LuCI / Preserve spaces and literal plus signs on rename; LuCI query-decoder regression.

- [x] 💾 для загрузки MP3, динамическая подсказка добавления/замены / MP3 upload icon with add/replace tooltip.

- [x] 5.1.56: переключатель и текущий IP в существующем опросе шапки / Physical switch and current IP through existing header polling.

- [ ] Согласовать синтетическое табло 5.1.70 на стенде; источник и сохранение реальной дневной статистики определить отдельно / Review the synthetic 5.1.70 bench heatmap; define real daily statistics and persistence separately.
- [x] 5.1.70 установлена на разрешённый стенд: проверены бэкап/откат, 82 файла, 12 HTTP-ресурсов, сохранение журнала, громкости и auto-off / 5.1.70 installed on the authorized bench: backup/rollback, 82 files, 12 HTTP assets, preserved journal, volume and auto-off verified.

- [ ] Согласовать расширенное табло 5.1.71 (33 недели) и поднятые кнопки шапки / Review the expanded 5.1.71 heatmap (33 weeks) and raised header controls.
- [x] Стенд обновлён до 5.1.71: бэкап, файлы и HTTP проверены, настройки и журнал сохранены / Bench updated to 5.1.71: backup, files and HTTP verified; settings and journal preserved.

- [ ] Согласовать область «Метрики» 5.1.72: показатели и синтетическое табло под шапкой, сворачивание и равные отступы / Review 5.1.72 collapsible Metrics below the header, grouping indicators and the synthetic heatmap with equal padding.
- [x] Стенд обновлён до 5.1.72; бэкап, файлы, HTTP и сохранность настроек/журнала проверены / Bench updated to 5.1.72; backup, files, HTTP and preserved settings/journal verified.

- [x] 5.1.75: постоянный учёт всех успешных автозвонков, «Ресурсы», реальное табло; проверены ротация/перезапуск/повтор, сбои записи и чтение без замка редактора. Стенд обновлён, сохранены два исторических завершения, громкость и auto-off / Persistent automatic completion counters, Resources and live grid; rotation/restart/replay, write failures and lock-free reads tested. Bench updated, two historical completions, gain and auto-off preserved.
- [ ] 05.11.2026: сверить полный день «Будни» учебного плана 2026–2027 с журналом и картой после 14:35. Ожидается 15 основных и 6 предварительных звонков, первый в 07:55. / Reconcile all 21 weekday bells with the journal and daily count after the last bell.
