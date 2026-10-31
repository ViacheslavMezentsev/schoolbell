# Lua-привязка Linux-проигрывателя

[English](LUA_PLAYER.en.md) · [C backend](LINUX_PLAYER.md) · [ТЗ 1.14](../requirements/TECHNICAL_SPECIFICATION.md)

Изолированный модуль Lua 5.1 `schoolbell.player_linux` связывает Lua с
`native/player.c`. Он не подключён к очереди, ядру, UI или IPK.
Host-тесты запускают только собственный дочерний процесс: без madplay и аудиоустройства.

## Сборка и тесты

Нужны Linux, /proc, Lua 5.1, заголовки/библиотека Lua 5.1
(`liblua5.1-0-dev` на Ubuntu), C99-компилятор, make и timeout.

```sh
make -C packages/schoolbell/native lua
sh packages/schoolbell/tests/test-lua-player.sh
make test-schoolbell
make ci-schoolbell
```

Модуль: `out/native-schoolbell-player/schoolbell/player_linux.so`.
Для нестандартного расположения Lua задаются `LUA_CFLAGS` (заголовки)
и `LUA_LIBS` (линковка тестового хоста). Отсутствующие зависимости дают
FAIL, не пропуск. CI устанавливает dev-пакет только на хосте.

## Доверенная граница

```lua
local native = require("schoolbell.player_linux")
local player = assert(native.new({
    executable_fd = trusted_executable_fd,
    lock_directory_fd = trusted_private_directory_fd,
    argv = {"fixture", "ok"},
    resources = {"speaker"},
    launch_timeout_ms = 2000, -- default; 100..60000
    max_records = 128,       -- default; 1..128
}))
local handle, err, stats = player:begin(
    {resource="speaker"}, trusted_regular_media_fd,
    function() return true end) -- pure bounded permit, no I/O/yield
local snapshot, poll_err, poll_stats = player:poll(handle)
-- Repeat poll from the owner's loop; no hidden waiting or active stop.
-- Release only after terminal and the control channel has been drained.
local ok, release_err, cleanup_stats = player:release(handle)
-- After every handle was released:
assert(player:close())
```

Методы вызываются через двоеточие. Это отдельная нативная граница, не прямая
подмена `player_model.new(sys,...)` или текущего интерфейса очереди.
FD передаются доверенным host bootstrap; публичного открытия пользовательских
путей и shell-команд нет. Владение исходными FD остаётся у caller, C backend
создаёт свои ссылки. За неизменяемость executable/медиа и lock-inode отвечает
владелец; полноценные media handles и менеджер ревизий ещё не подключены.

Конфигурация/заявка — обычные таблицы без metatable и неизвестных полей.
Ресурсы — плотный массив 1..4, argv — 1..16 непустых строк без NUL
в пределах 2048 байт C-профиля. Числовые строки/дроби/NaN отвергаются.
Файловые дескрипторы — целые 0..INT_MAX, а не учётные данные безопасности.
Применяются однопоточность, SIGCHLD/reaper/FD-условия C backend.
Нельзя использовать недоверенный Lua с debug/доступом к registry как sandbox.

## Результаты и владение

Handle и player — userdata с закрытым metatable. Чужие/поддельные handles
отвергаются, после release handle устарел. Снимок — новая таблица по
[контракту результатов](PLAYER_RESULTS.md): отсутствуют неприменимые поля
outcome/exit_code/signal/error. Дополнительный третий результат stats.calls
считает вызовы C backend: begin ≤64, poll/release ≤8. Работа Lua/GC/callback
этим счётчиком не ограничена. Нет гарантии real-time.

Ошибки вызова дают nil и таблицу code/stage/необязательный errno.
Ошибка/не-true результат permit дают permit_denied до fork; повторный вход
из permit даёт busy. Callback не должен менять FD, блокироваться или yield.
Дочерний процесс после fork не возвращается в Lua.

До fork registry удерживает handle и его владельца. Потеря Lua-ссылки,
collectgarbage или ошибка выделения Lua-памяти после fork не освобождают
ресурс и не теряют учёт процесса. `player:pending()` возвращает новый список
этих handles для продолжения poll/release; список не управляет состоянием.
Явный release снимает удержание. Close отказывает при незавершённых записях;
GC пустого владельца закрывает C backend.

Это намеренное удержание, а не автоматическое reap/kill. Владелец обязан
сохранить player, обслужить pending и вызвать close до lua_close.
Принудительное закрытие VM с живыми записями не является поддержанным recovery:
backend не освобождает неопределённые ресурсы, они остаются до выхода процесса.
ECHILD, как и раньше, требует отдельного административного восстановления.

## Проверки и следующий шаг

TC-70: восемь host-групп — exec/exit/signal/stdout flood, снимки/квоты,
чужие/stale handles, permit/повторный вход, GC и восстановление handles,
Lua OOM после fork, ошибка exec, строгая валидация, повторные циклы.
Тестовый C-хост после завершения VM проверяет FD и отсутствие несобранных детей.
Это не проверка target ABI, madplay, звука, ресурсов MR3020 или media recovery.

Следующий отдельный шаг — композиция Lua-очереди с привязкой на тестовом
процессе и доверенном хранилище файлов, без подключения ядра и звука.

ТЗ schoolbell 1.15: соединены Lua-очередь и Linux player через изолированный bridge; launching/finishing, сигнальный исход и очистка до следующего старта. 10 host-групп с тестовым ребёнком; без ядра, аудиоустройства, звука, изменений роутера/IPK. [Queue/Linux bridge](QUEUE_LINUX.md).


Следующий изолированный этап добавляет [удержание точной ревизии при submit](MEDIA_ADMISSION.md). Необязательный retained_userdata метода native begin удерживается вместе с handle. Старый API остаётся совместимым.
