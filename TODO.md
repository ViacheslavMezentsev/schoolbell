# План миграции / Migration checklist

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
- [ ] Закрыть L1–L5 аудита: права, лицензии, исходники и доставка NOTICE / Close audit L1–L5: rights, licenses, sources and NOTICE delivery. См. / See [audit](docs/LICENSE_AUDIT.md).
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

- [x] Три локальных инструментальных пробы 0.mp3 с проверкой нот/ритма/громкости / Three local instrumental 0.mp3 trials with pitch/timing/loudness checks.
- [ ] Выбор тембра владельцем; штатные файлы пока сохранены / Owner timbre selection; stock media retained.
- MIT — намерение владельца для собственного кода; область действия и права уточняются в L1 / MIT is the owner's own-code preference; scope and rights remain under L1.

- [x] Яркие пробы электрогитары/гармошки по замечанию владельца / Bright guitar/harmonica trials following owner feedback.
