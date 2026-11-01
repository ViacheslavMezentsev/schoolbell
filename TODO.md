# План миграции / Migration checklist

## Приоритет: надёжная подача звонков / Priority: reliable playback

- [x] Прежняя AB13X напрямую/OHCI: 100 успехов подряд, −60 дБ, auto-off; без новых ошибок URB, одна запись cannot get freq / Original AB13X direct/OHCI: 100 consecutive successes, -60 dB, auto off; no new URB errors, one cannot get freq message.

- [x] 100 успешных запусков подряд при прямом подключении GeneralPlus/OHCI, −60 дБ, auto-off; без новых ошибок ядра / 100 consecutive successful direct GeneralPlus/OHCI launches at -60 dB, auto off, no new kernel errors.
- [x] Новый хаб (12 Мбит/с, OHCI) + C-Media: 100 успешных запусков подряд, без новых сообщений ядра; −60 дБ, auto-off / New hub (12 Mbit/s, OHCI) + C-Media: 100 consecutive successes, no new kernel messages; -60 dB, auto off.
- [ ] Локализовать причину отказов прежнего сочетания хаба/EHCI; успешная OHCI-серия не закрывает её / Isolate the earlier hub/EHCI failures; the successful OHCI series does not resolve them.

- [ ] Устранить воспроизведённый периодический отказ USB-аудио; сохранить причины ошибок, проверить повторные запуски и длительное расписание / Fix reproduced intermittent USB-audio failure, retain diagnostic reasons, verify repeated starts and endurance. [RU](docs/PLAYBACK_RELIABILITY.md) · [EN](docs/PLAYBACK_RELIABILITY.en.md).
- Лицензирование отложено владельцем; зелёные host-тесты не закрывают этот дефект / Owner deferred licensing; passing host tests do not close this defect.

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
