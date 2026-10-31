# Карта документов «Школьника»

[English](README.en.md) · [Проект](../README.md) · [План миграции](MIGRATION.md)

## Текущее состояние

Самостоятельный кандидат — **5.1.28**. Исходники и 81 документ перенесены из
зафиксированной базы 5.1.27. Host-сборка, тесты и целевой MIPS-комплект проверены; подтверждено обновление
стенда до 5.1.28. Приёмка опубликованных Pages, реальный откат и новая
аппаратная приёмка ещё не завершены.
Главная страница будущих Pages сразу открывает интерфейс звонка.

## Куда обратиться

| Задача | Документ |
| --- | --- |
| Собрать текущий репозиторий | [Сборка и тесты](BUILD.md) |
| Подготовить автономный комплект | [Текущая упаковка](PACKAGING.md) |
| Работать с расписаниями и мелодиями | [Руководство пользователя](user/USER_GUIDE.md) |
| Уточнить требования | [ТЗ, исходная ревизия 1.76](requirements/TECHNICAL_SPECIFICATION.md) |
| Проверить формат переноса | [.sbp](formats/PORTABLE_PLAN.md), [формат кадра](formats/PORTABLE_PLAN_WIRE.md) |
| Проверить резервное копирование | [.sbb](formats/BACKUP.md) |
| Разобраться с календарём | [Именованные диапазоны](architecture/RANGE_PLANS.md) |
| Разобраться со временем | [Контроль времени](architecture/CLOCK_TRUST.md), [интерфейс](architecture/CLOCK_UI.md) |
| Подготовить приёмку | [Программа AC](acceptance/ACCEPTANCE.md), [исходный шаблон прогона](acceptance/ACCEPTANCE_RUN.md) |
| Посмотреть историю до выделения | [История пакета](history/CHANGELOG.md), [исходный обзор](history/README.md) |
| Продолжать разработку | [Workflow](WORKFLOW.md), [TODO](../TODO.md) |

## Как читать перенесённые материалы

Файлы в requirements, architecture, formats, user, acceptance и history сохраняют
текст исходной базы. Менялись только назначения Markdown-ссылок. Номера требований,
TC и AC, история ревизий и отметки незавершённости не перенумеровывались.
Это перенос документов, а не повторное утверждение всего ТЗ или новая приёмка.

В них встречаются исторические версии (в том числе 5.1.22 в шаблоне прогона),
старые команды и пути `packages/schoolbell`, а также утверждения о состоянии
старого стенда и Pages. Они не описывают установку из нового репозитория.
Для текущей сборки используйте BUILD/PACKAGING выше. Соответствие путей и хешей
записано в [карте происхождения](source-map.json). Ссылки на ещё не перенесённые
материалы ведут на закреплённый коммит исходного проекта.

Для нового прогона создаётся отдельный протокол с фактическими версиями, SHA-256,
целевым устройством и результатами. Не отмечайте старые проверки как заново
пройденные. Рабочие бэкапы, ключи и аппаратные логи в Git не добавляются.

Руководство установки и обучение на Pages будут перенесены отдельным этапом;
эта ветка не публикует сайт и не меняет устройства.

## Полный каталог перенесённых документов

### Требования

| Документ | Языки |
| --- | --- |
| ТЕХНИЧЕСКОЕ ЗАДАНИЕ: пакет schoolbell | [RU](requirements/TECHNICAL_SPECIFICATION.md) |

### Пользователь

| Документ | Языки |
| --- | --- |
| Школьный звонок — руководство пользователя | [RU](user/USER_GUIDE.md) · [EN](user/USER_GUIDE.en.md) |

### Форматы и перенос данных

| Документ | Языки |
| --- | --- |
| Резервная копия schoolbell | [RU](formats/BACKUP.md) · [EN](formats/BACKUP.en.md) |
| Каталог, квоты и фиксация медиатеки | [RU](formats/MEDIA_FORMAT.md) · [EN](formats/MEDIA_FORMAT.en.md) |
| Переносимый календарный план .sbp | [RU](formats/PORTABLE_PLAN.md) · [EN](formats/PORTABLE_PLAN.en.md) |
| Изолированный кодек .sbp | [RU](formats/PORTABLE_PLAN_CODEC.md) · [EN](formats/PORTABLE_PLAN_CODEC.en.md) |
| Сборка экспортируемого .sbp | [RU](formats/PORTABLE_PLAN_EXPORT.md) · [EN](formats/PORTABLE_PLAN_EXPORT.en.md) |
| Экспорт выбранных планов с устройства | [RU](formats/PORTABLE_PLAN_EXPORT_DEVICE.md) · [EN](formats/PORTABLE_PLAN_EXPORT_DEVICE.en.md) |
| Импорт календарного плана на устройство | [RU](formats/PORTABLE_PLAN_IMPORT.md) · [EN](formats/PORTABLE_PLAN_IMPORT.en.md) |
| Pages: экспорт .sbp и предварительный импорт | [RU](formats/PORTABLE_PLAN_PAGES.md) · [EN](formats/PORTABLE_PLAN_PAGES.en.md) |
| Предварительный расчёт импорта .sbp | [RU](formats/PORTABLE_PLAN_PREVIEW.md) · [EN](formats/PORTABLE_PLAN_PREVIEW.en.md) |
| .sbp: байтовый формат и операция импорта | [RU](formats/PORTABLE_PLAN_WIRE.md) · [EN](formats/PORTABLE_PLAN_WIRE.en.md) |

### Устройство и реализация

| Документ | Языки |
| --- | --- |
| Годовой календарь и предпросмотр | [RU](architecture/ANNUAL_CALENDAR.md) · [EN](architecture/ANNUAL_CALENDAR.en.md) |
| Вычислитель расписаний schoolbell | [RU](architecture/CALENDAR.md) · [EN](architecture/CALENDAR.en.md) |
| Контроль времени в исполнителе | [RU](architecture/CLOCK_EXECUTOR.md) · [EN](architecture/CLOCK_EXECUTOR.en.md) |
| Системный адаптер опоры времени | [RU](architecture/CLOCK_SYSTEM.md) · [EN](architecture/CLOCK_SYSTEM.en.md) |
| Достоверность времени schoolbell | [RU](architecture/CLOCK_TRUST.md) · [EN](architecture/CLOCK_TRUST.en.md) |
| Изолированная модель доверия времени | [RU](architecture/CLOCK_TRUST_MODEL.md) · [EN](architecture/CLOCK_TRUST_MODEL.en.md) |
| Подтверждение времени и нативная зависимость | [RU](architecture/CLOCK_UI.md) · [EN](architecture/CLOCK_UI.en.md) |
| Изолированный Linux-адаптер schoolbell | [RU](architecture/LINUX_PLAYER.md) · [EN](architecture/LINUX_PLAYER.en.md) |
| Lua-привязка Linux-проигрывателя | [RU](architecture/LUA_PLAYER.md) · [EN](architecture/LUA_PLAYER.en.md) |
| Удержание ревизии при приёме заявки | [RU](architecture/MEDIA_ADMISSION.md) · [EN](architecture/MEDIA_ADMISSION.en.md) |
| Изолированный менеджер медиатеки | [RU](architecture/MEDIA_MANAGER.md) · [EN](architecture/MEDIA_MANAGER.en.md) |
| Постоянная медиатека schoolbell | [RU](architecture/MEDIA_PERSISTENCE.md) · [EN](architecture/MEDIA_PERSISTENCE.en.md) |
| Загрузка мелодий — инженерный профиль | [RU](architecture/MEDIA_UPLOAD.md) · [EN](architecture/MEDIA_UPLOAD.en.md) |
| IPK и автономный комплект schoolbell | [RU](architecture/PACKAGING.md) · [EN](architecture/PACKAGING.en.md) |
| Изолированная очередь schoolbell | [RU](architecture/PLAYBACK_QUEUE.md) · [EN](architecture/PLAYBACK_QUEUE.en.md) |
| Контракт адаптера проигрывателя schoolbell | [RU](architecture/PLAYER_ADAPTER.md) · [EN](architecture/PLAYER_ADAPTER.en.md) |
| Изолированные кодек и модель player | [RU](architecture/PLAYER_MODEL.md) · [EN](architecture/PLAYER_MODEL.en.md) |
| Результаты, ошибки и бюджеты player | [RU](architecture/PLAYER_RESULTS.md) · [EN](architecture/PLAYER_RESULTS.en.md) |
| Системные механизмы и асинхронный API player | [RU](architecture/PLAYER_SYSTEM_API.md) · [EN](architecture/PLAYER_SYSTEM_API.en.md) |
| Константы кадра, поколения и диапазоны player | [RU](architecture/PLAYER_WIRE.md) · [EN](architecture/PLAYER_WIRE.en.md) |
| Соединение очереди и Linux player | [RU](architecture/QUEUE_LINUX.md) · [EN](architecture/QUEUE_LINUX.en.md) |
| Календарные планы — schoolbell 5.1.0 | [RU](architecture/RANGE_PLANS.md) · [EN](architecture/RANGE_PLANS.en.md) |
| Редактор сохранённых расписаний | [RU](architecture/SCHEDULE_EDITOR.md) · [EN](architecture/SCHEDULE_EDITOR.en.md) |
| Аудит запуска schoolbell 5.0.31 | [RU](architecture/STARTUP_AUDIT.md) · [EN](architecture/STARTUP_AUDIT.en.md) |
| Целостность интерфейса и план доработок schoolbell | [RU](architecture/UI_COMPLETENESS.md) · [EN](architecture/UI_COMPLETENESS.en.md) |

### Приёмка

| Документ | Языки |
| --- | --- |
| Программа приёмки schoolbell 5.x | [RU](acceptance/ACCEPTANCE.md) · [EN](acceptance/ACCEPTANCE.en.md) |
| Сквозная приёмка «Школьника» на новом устройстве | [RU](acceptance/ACCEPTANCE_RUN.md) · [EN](acceptance/ACCEPTANCE_RUN.en.md) |

### История выделенного пакета

| Документ | Языки |
| --- | --- |
| История изменений | [RU](history/CHANGELOG.md) · [EN](history/CHANGELOG.en.md) |
| Пакет schoolbell | [RU](history/README.md) · [EN](history/README.en.md) |

[Архив старой реализации](archive/schoolbell-4/README.md) · [Инвентарь переноса](migration-inventory.json) · [Хеши и соответствие путей](source-map.json)

[Сборка и публикация Pages](../site/README.md)

[Аудит лицензий и происхождения](LICENSE_AUDIT.md)

[Лицензия MIT и область действия](LICENSING.md)

[Доставка лицензий и пробелы зависимостей](LICENSE_DELIVERY.md)

[Надёжность воспроизведения: открытый дефект](PLAYBACK_RELIABILITY.md)

[Дополнение ТЗ: строка аудиовыхода и цвет Flash](requirements/TECHNICAL_SPECIFICATION_AUDIO_STATUS.md)
