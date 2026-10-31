# Admission-time media revision retention

The isolated Linux/Lua 5.1 `schoolbell.media_linux` module owns trusted immutable
regular files; it is not an upload service or persistent library. TC-72 runs on
the host without core integration, sound, router changes or IPK changes.

## API

- `Media.new()` creates a store userdata.
- `store:publish(id, revision, source_fd)` opens its own read-only reference to
  the same regular inode via `/proc/self/fd`, with an independent file position.
  The caller may close its original FD afterwards.
- `store:acquire(id, revision)` returns a private lease or `nil, {code=...}`;
  allocations precede reference retention.
- `lease:fd()` borrows the catalog FD; never close or modify it.
- `store:release(lease)` idempotently drops the reference without system calls.
- `store:remove(id, revision)` rejects referenced entries with `busy`, otherwise
  closes the catalog FD. It does not unlink files. Identity reuse is rejected.
- `store:close()` requires zero leases, closes entries and is idempotent.

Identifiers are 1–64 ASCII `[A-Za-z0-9_-]` characters. Each instance allows
16 lifetime publications (including removed entries) and 128 simultaneous
leases. These are bounded host-prototype limits, not a production library
budget or router RAM measurement. Instance rollover requires explicit live-state
migration and is not implemented.
Errors: `closed`, `invalid_argument`, `exists`, `limit`, `media_invalid`,
`missing`, `busy`, `invalid_handle`, `stale_handle`, `close_failed`, optionally
with system `errno`. A failed close still consumes FD ownership on Linux.

## Queue composition

`Queue.new(clock, bridge, options, store)` enables admission. Validation,
capacity, receipt allocation and queue slots precede acquire. A receipt is
returned only after exact revision retention. Failure rolls back the reservation
and returns `media_unavailable`; ticket-number gaps are allowed. Omitting the
fourth argument preserves the original model API.

The bridge uses the private lease FD instead of its resolver.
`native:begin(request, fd, permit, retained_userdata)` pins the optional fourth
method argument together with its registry-pinned handle, even if callers lose
Lua references. Public receipts/events never expose leases.
Queued cancellation/expiry drops references without launching. Active requests
retain through uncertain/finishing until native cleanup is confirmed. Lease GC
drops counters; callers must drain handles and close stores before VM shutdown.
Explicit release belongs to the trusted owner, not an untrusted client.

## Limits and tests

The publisher must keep inode contents immutable: a read-only FD cannot prevent
external in-place writes. Path replacement and original-FD closure do not retarget
accepted requests. This is not a sandbox; debug/registry and arbitrary FD
interference are excluded. General Lua step OOM recovery, VM/power-failure recovery,
schedule references, upload/MP3 validation and durable publication remain future work.

Nine host groups cover rejection, shared references, cancellation/TTL, replacement,
cleanup/uncertainty, signal/exec errors, quotas/OOM, GC and pathname replacement.
The fixture reads text instead of MP3; FD balance and child reaping are checked.
Run `make ci-schoolbell` with Lua 5.1 development headers/library and a C compiler.

OOM during Lua submit preparation can leave the queue instance blocked; neither a receipt nor a native lease has been issued. Continued operation is not guaranteed; automatic restart/replay is not permitted.
