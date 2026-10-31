# Изолированные кодек и модель player

[English](PLAYER_MODEL.en.md) · [ТЗ 1.12](../requirements/TECHNICAL_SPECIFICATION.md)

`packages/schoolbell/lua/schoolbell/player_codec.lua` и `player_model.lua`
— чистые Lua 5.1 модули без стандартного backend. Они не открывают файлы,
не запускают процессы, не вызывают ядро и не подключены к playback_queue.lua.
В media-only IPK их нет. `make test-schoolbell` запускает 32 группы TC-66/67
в `packages/schoolbell/tests/test_player_model.lua`.

## Кодек

`encode(stage, errno)` возвращает 16 байт или nil/error.
`decode(bytes)` возвращает {stage, errno} или nil/error.
Допустимы stdio/exec/cleanup и errno 1..4095; остальные поля кадра фиксированы.
`decoder().feed(chunk, eof)` накапливает максимум 16 байт и возвращает
{frame=..., eof=...}; frame отсутствует до полного кадра. Ошибка необратима.
Повторный feed после EOF, лишний байт, оборванный/невалидный кадр отвергаются.
Полный кадр виден до EOF, но последующие лишние байты отменяют доверие к нему.

## Модель

`model.new(sys, options)` требует resources и допускает max_records,
launch_timeout_ms по [диапазонам](PLAYER_WIRE.md). Функции sys и конфигурация
фиксируются при создании. Нет fallback системного источника случайности.

Begin принимает только {resource=...}, доверенный media_handle и чистый permit().
Handle — таблица с приватной идентичностью; это имитация native userdata.
Поля таблицы не управляют внутренним состоянием. Чужой handle отвергается;
после release он stale. Строковое поколение не служит авторизацией.

```lua
local model = require("schoolbell.player_model")
local player = assert(model.new(fake_sys, {
    resources={"speaker"}, max_records=128, launch_timeout_ms=2000
}))
local handle, err = player.begin({resource="speaker"}, fake_media, permit)
local snapshot, poll_err, stats = player.poll(handle)
local ok, release_err, cleanup_stats = player.release(handle)
```

Stats — только диагностическое расширение модели: calls. Native API им не
объявляется. Все реальные результаты по [контракту](PLAYER_RESULTS.md).

## Граница подмен

| Функция sys | Подменяемый результат |
| --- | --- |
| random(16) | Строка ровно 16 байт; исключение/иная длина отклоняют создание |
| prepare(call, token, media, resource) | {dev, ino} ожидаемого executable либо отказ |
| fork(token) | Положительный PID; false, errno — доказанный отказ; исключение/неверный результат — possible/uncertain |
| clock() | Монотонные целые миллисекунды |
| read(token, 16) | Строка; пустая — EOF; nil, "again" — нет данных |
| open_exe(token, pid) | Временный FD или отсутствие результата |
| fstat(fd) | {dev, ino} |
| wait(pid) | "running", {kind="exit",code=N}, {kind="signal",signal=N}; иное — ошибка наблюдения |
| close(fd) | Один вызов закрытия |
| cleanup(call, token) | true только после всей очистки; false сохраняет запись |
| valid_signal(n) | Чистый предикат допустимости сигнала на моделируемой платформе |

Prepare и cleanup — доверенные тестовые процедуры: все моделируемые системные
операции они вызывают через call(name,...). Prepare разрешены open/fstat/flock/
pipe/fcntl/dup/close; cleanup — close. Внутренний token создаётся до подготовки,
поэтому backend может учитывать частично полученные ресурсы. Временные FD
open_exe тоже учитываются backend через token для последующей очистки.
Нельзя скрывать несколько вызовов или реальные побочные действия в одном
примитиве. Модель проверяет число обращений, не внутренности callback.

Prepare получает не более 62 операций, оставляя clock/fork в бюджете begin=64.
При отказе очистка использует только остаток этого бюджета, максимум 8.
Неоконченная очистка возвращает terminal handle с not_started вместо потери
ресурсов. Следующие release делают до 8 операций. Нет автоматического kill.
Исключение fork удерживает запись даже без известного PID; модель не умеет
восстанавливать такой потерянный результат.

Poll делает один read и наблюдение executable перед wait; после неопределённого
wait больше не проверяет /proc по PID. Подтверждённый exec повторно не проверяется.
После reap кадр может ещё дочитываться: release ждёт EOF или ошибки протокола.
Окончательный снимок после завершения и закрытия протокола стабилен, дальнейший
poll не вызывает sys. Ошибки канала/часов не разрешают повторный запуск.

`model.child_setup(sys, routine, token)` отдельно моделирует бюджет 64 для
dup/fcntl/close/exec/write/exit; не создаёт ребёнка и не вызывается из begin.
`model.counter(last)` — чистый счётчик для проверки исчерпания UINT32 без
миллиардов запусков. Он не позволяет менять счётчик существующего экземпляра.
Переданные call становятся недействительными после возврата процедуры.
Повторный вход в begin/poll/release во время callback возвращает busy.

## Ограничения

32 группы проверяют модель, не Linux. Нативное владение FD, flock, fork/exec,
поведение madplay, источники часов/random, media pinning/recovery и работу
после reboot предстоит реализовать и проверить отдельно. Model handle не
является защитой от произвольного Lua с доступом к debug; callbacks доверенные.
Зависший callback модель не прерывает. Ожидание звука, real-time и RAM target
не измерялись. Native-специфичные части TC-50–65 остаются плановыми.
