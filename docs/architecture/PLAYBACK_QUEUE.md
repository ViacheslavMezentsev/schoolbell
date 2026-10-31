# Изолированная очередь schoolbell

[English](PLAYBACK_QUEUE.en.md) · [ТЗ](../requirements/TECHNICAL_SPECIFICATION.md)

`packages/schoolbell/lua/schoolbell/playback_queue.lua` — внутренняя модель
Lua 5.1. Она не запускает процессы, не читает файлы и не вызывает ядро.
В media-only IPK не включена. Тесты: `make test-schoolbell`, TC-40–42,
24 группы с подменяемыми часами/player. Это не подтверждение слышимого звука.

## API

```lua
local queue = require("schoolbell.playback_queue")
local worker = assert(queue.new(clock, player, {
    resources = {"speaker"}, max_records = 128, max_pending = 32
}))
local receipt = assert(worker.submit("schoolbell", {
    resource = "speaker", media_id = "bell", media_revision = "v1",
    ttl_ms = 5000, expires_utc_ms = 1800000005000,
    source_id = "schedule-event-1"
}))
local result = assert(worker.step())
local current = assert(worker.status("schoolbell", receipt.id))
-- Only while queued:
-- worker.cancel("schoolbell", receipt.id)
-- Only after finished/failed/expired/cancelled:
-- worker.forget("schoolbell", receipt.id)
```

## Входы и результаты

`clock()` возвращает `{mono_ms=N, utc_valid=boolean, utc_ms=N}`.
UTC обязателен только при utc_valid=true; монотонное время не убывает.
Все времена — целые миллисекунды в точном диапазоне Lua number ±(2^53−1);
монотонное время неотрицательно. TTL положителен; переполнение дедлайна отвергается.
UTC календарного вычислителя в секундах: будущий клиент явно преобразует
единицы и выбирает допустимое опоздание. Этот пример не задаёт такую политику.

`submit(owner, request)` только принимает заявку, не запускает player.
Обязательны resource/media_id/media_revision/ttl_ms; expires_utc_ms и source_id
необязательны. Owner, ресурсы, media ID/revision — 1–64 ASCII символа
`[A-Za-z0-9_-]`; source_id — до 256 байт. Неизвестные поля и metatable отвергаются.
Media revision сохраняется как метка; реальное существование/удержание файла
ещё не проверяется. Заявки и результаты копируются, функции backend фиксируются
при создании. Owner передаёт доверенный клиент: это не механизм аутентификации.

`submit/status/cancel` возвращают снимок с id, owner, resource, media_id,
media_revision, source_id, state, accepted_mono_ms, deadline_mono_ms,
expires_utc_ms и при наличии reason/exit_code. Ошибки — `nil, {code=...}`.
`cancel` добавляет changed=true при первой отмене, false при повторной.
Отменить можно свою queued-заявку; active/uncertain отклоняются.
`forget` возвращает true и удаляет только свою терминальную квитанцию;
после него status/cancel возвращают unknown. Идемпотентность отмены действует
до явного forget. ID не переиспользуется в экземпляре, но не уникален после
создания нового экземпляра; durable state и повторная доставка не реализованы.

Состояния: queued → starting → playing → finished/failed.
Неопределённый результат start/poll даёт uncertain и удерживает ресурс.
Подтверждённый running возвращает playing; подтверждённый exit освобождает.
Queued может перейти в cancelled/expired/failed (явный отказ запуска).
Finished означает exit_code=0, а не подтверждение звука.

## FIFO, сроки и шаг

Каждый ресурс имеет отдельный FIFO и не более одного активного запроса.
TTL считается от приёма по монотонным часам; календарной заявке дополнительно
нужен UTC строго раньше expires_utc_ms. Равенство означает expiry.
Недостоверный UTC удерживает календарную голову без обгона; её TTL продолжает
идти. Просроченные заявки, включая хвост, удаляются из ожидания. Другой ресурс
может работать. Сроки никогда не обрывают уже активное проигрывание.

`step()` возвращает `{events={...}, clock_error=...}` (поле ошибки необязательно).
За шаг — максимум один poll и один start на ресурс; очередь просматривается
в пределах квоты. Каждое событие — снимок плюс kind: started, uncertain,
finished, failed, expired. Отмена сообщается результатом cancel, а не event.
Повторные неопределённые poll не создают поток одинаковых событий: uncertain
сообщается один раз на заявку. Status остаётся текущим. Нет фонового потока,
постоянной очереди результатов, ack или replay: клиент забирает события шага.
После ошибки часов возможна обработка подтверждённого exit, но новые старты
блокируются. Следующий step может восстановить работу при корректных часах.

## Контракт подменяемого проигрывателя

- `player.start(resource, ticket, snapshot, permit)` возвращает
  `{ticket=ticket, state="started"}` либо `state="rejected"`.
  Непосредственно перед побочным действием он обязан вызвать permit().
  При false запуск запрещён. Rejected гарантирует отсутствие player для ticket.
- Permit повторно проверяет часы и оба срока; после возврата start он недействителен.
  Утрата UTC/ошибка часов при подтверждённом rejected возвращает ту же заявку
  в голову с исходным TTL; expiry завершает её. Простой rejected даёт failed.
- `player.poll(resource, ticket)` возвращает `{ticket=ticket,state="running"}`
  или `{ticket=ticket,state="exited",exit_code=0..255}`.
  Только соответствующий ticket с подтверждённым exit освобождает ресурс.
- Исключение, неверные поля/ticket и started без permit означают uncertain:
  нельзя доказать отсутствие запущенного player. Автоматического повторного
  start, kill или освобождения по времени нет. Доверенный backend не должен
  лгать о running/exit/rejected или запускать после запрещающего permit.

Callbacks должны быть ограниченными по времени и неблокирующими по смыслу
worker; модель не умеет прерывать зависший callback. Повторный вход в
submit/cancel/forget/step внутри callback возвращает busy, status допускается.
До подключения ОС нужны отдельные правила владения процессом, наблюдения exit,
источника времени, IPC и восстановления. Снятие подписки не связано с очередью;
pause/перерегистрация/активный stop ещё не реализованы.

## Защитные пределы и ошибки

Options: 1–4 уникальных ресурса плотным массивом; max_records=1..128
(по умолчанию 128), max_pending=1..32 на ресурс (по умолчанию 32).
В records входят ожидающие, активные и терминальные записи; pending — только
ожидающие. Автоматического вытеснения нет. Это пределы модели, не замеры RAM.
Клиент должен забирать/освобождать квитанции, иначе получает full.

Коды: backend/options/resources — неверное создание; request — неверный запрос;
full/id_exhausted/deadline_overflow — отказ допуска; clock/clock_regressed —
недопустимые часы; unknown/not_owner — обращение к квитанции;
active/terminal/not_terminal — недопустимая операция; busy — повторный вход.
Причины событий: ttl/utc, player_rejected/player_exit,
start_result/start_unknown/poll_result/poll_unknown; отмена — owner_cancelled.
Будущий слой интеграции определит отображение этих внутренних кодов в публичный API.

Контракт системного адаптера принят в ТЗ 1.8, но API и код этой модели не изменены. Асинхронный launching, сигнальное завершение и удержание файла предстоит реализовать: [Player adapter](PLAYER_ADAPTER.md).

ТЗ schoolbell 1.15: соединены Lua-очередь и Linux player через изолированный bridge; launching/finishing, сигнальный исход и очистка до следующего старта. 10 host-групп с тестовым ребёнком; без ядра, аудиоустройства, звука, изменений роутера/IPK. [Queue/Linux bridge](QUEUE_LINUX.md).


Следующий изолированный этап добавляет [удержание точной ревизии при submit](MEDIA_ADMISSION.md). Необязательный retained_userdata метода native begin удерживается вместе с handle. Старый API остаётся совместимым.
