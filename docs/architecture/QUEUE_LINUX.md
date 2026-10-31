# Соединение очереди и Linux player

[English](QUEUE_LINUX.en.md) · [Очередь](PLAYBACK_QUEUE.md) · [Lua binding](LUA_PLAYER.md)

Изолированный слой `schoolbell.queue_player` соединяет Lua FIFO с Linux
адаптером. Владелец явно вызывает step; фонового потока, API ядра, UI,
аудиоустройства и включения в IPK нет.

## Сборка и host-проверки

```sh
sh packages/schoolbell/tests/test-lua-player.sh
make test-schoolbell
make ci-schoolbell
```

Те же зависимости Lua 5.1 dev/C99, что у привязки. Runner сначала выполняет
8 групп привязки, затем в отдельной VM 10 групп композиции TC-71.
Используется только fixture-child: обычный файл stdin и /dev/null для вывода.
C-хост проверяет баланс FD и отсутствие несобранных детей.

## Подключение

```lua
local bridge = assert(require("schoolbell.queue_player").new(
    native_player, -- отдельный пустой экземпляр schoolbell.player_linux
    function(media_id, revision)
        return trusted_fds[media_id][revision] -- точная заранее удержанная ревизия
    end,
    {"speaker"}))
local worker = assert(require("schoolbell.playback_queue").new(
    clock, bridge, {resources={"speaker"}}))
-- submit/status/cancel/forget unchanged; caller repeatedly invokes worker.step().
-- After all queued/active work has been cancelled or drained:
assert(bridge.close())
```

Ресурсы bridge, native и очереди должны совпадать. Экземпляр native принадлежит
только одному bridge; нельзя параллельно вызывать его begin/poll/release/close
или отдавать другой очереди. При создании непустой native отклоняется.
Функции backend фиксируются. Plain-table backend допускается для подмен отказов
в тестах; это доверенная граница, не API для недоверенных расширений.

Resolver получает media_id и media_revision, возвращает заимствованный regular
file FD либо отказ. В тесте файл открыт хостом заранее и сохраняется до конца.
Resolver не выбирает «последнюю» ревизию и не освобождает файл. При отмене/expiry
ожидающей заявки он не вызывается. Отсутствующий файл отклоняется без процесса.
Это не production admission: submit по-прежнему хранит лишь метки; атомарное
удержание ревизии при приёме, замена/удаление и recovery медиатеки впереди.

## Состояния и освобождение

- Native begin выдаёт handle: очередь остаётся starting, без события started.
- Подтверждённые running + exec confirmed дают playing и одно started.
- Завершение сначала наблюдается через poll, затем выполняется release.
  Пока cleanup не завершён, очередь имеет finishing и удерживает ресурс.
- Exit с confirmed exec и без ошибки наблюдения даёт finished/failed по коду.
  Signal даёт failed с reason=player_signal и отдельным signal, без exit_code.
  Not_started даёт player_not_started. Недостаточные доказательства exec либо
  ошибка наблюдения при terminal дают player_exec_unknown, не ложный успех.
- Неопределённый живой процесс сохраняет uncertain. Timeout, ошибка часов и
  истечение TTL не обрывают ребёнка и не освобождают его ресурс.

Queue backend сохраняет старые started/rejected и running/exited для fake-тестов;
добавлены launching, draining, failed и deferred. Deferred означает отсутствие
нового процесса: заявка возвращается в голову с исходными сроками. Для failed
разрешены player_signal (signal 1..127), player_not_started,
player_exec_unknown и player_begin_unknown; неприменимые поля отвергаются.
Новые signal/reason видны в status/events. Forget требует terminal, как прежде.

За шаг на ресурс — не более одного native poll и, при terminal, одного
release, а также одного begin следующей заявки после очистки предыдущей.
Итого при таком переходе до 8+8+64 backend-вызовов, а не общий лимит 8 на step.
Каждый native вызов сохраняет свой бюджет; время Lua, resolver и GC не ограничено
этими числами. Автоматических циклов ожидания, sleep или повторного запуска нет.

## Потерянные результаты

Bridge заранее сохраняет запись. Исключение begin не означает отказ запуска:
pending восстанавливает единственный неучтённый handle. Пока связь потеряна,
новые старты других ресурсов откладываются, но существующие обслуживаются.
Если при исключительном владении pending пуст, фиксируется failed с
player_begin_unknown; новая попытка этой заявки не создаётся. Несколько
неучтённых handles оставляют ресурс uncertain.

После исключения release сохранён терминальный снимок. Следующий release
может подтвердить успех либо stale_handle, если первый вызов успел освободить
запись. Stale принимается только в этом случае. Неоконченная очистка продолжает
poll/release; результат хранится до смены ticket, поэтому потеря ответа не
порождает повторное проигрывание. На ресурс хранится не более одной записи.

Close не отменяет заявки и не опрашивает ребёнка; он отказывает при активных
записях bridge. Владелец обязан также отменить/завершить queued-заявки перед close.
Восстановление после аварии VM/процесса и произвольного OOM всего queue.step
не реализовано; сохранённое native-владение само по себе не восстанавливает
состояние очереди. Нет durable событий, ack/replay и активного stop.

## Границы проверки

TC-71: FIFO/два ресурса, запуск только после exec, отмена/TTL/UTC, финальный
permit после подготовки, потеря UTC, завершение при сбое часов, коды/сигнал/exec
ошибка, задержка release, потеря результатов, неопределённое наблюдение,
отсутствующее медиа и exit=0 без подтверждения exec.
Прежние 24 группы очереди сохраняются. Это не аппаратная приёмка и не слышимость.

Следующий шаг — доверенное хранилище и атомарное удержание ревизии при submit,
затем отдельная проверка target ABI и свойств madplay по согласованию.


Следующий изолированный этап добавляет [удержание точной ревизии при submit](MEDIA_ADMISSION.md). Необязательный retained_userdata метода native begin удерживается вместе с handle. Старый API остаётся совместимым.
