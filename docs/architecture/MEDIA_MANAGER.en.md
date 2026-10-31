# Isolated media manager

[Русский](MEDIA_MANAGER.md). Specification 1.19 implementation, partial coverage
of 1.17/1.18. A library for prepared objects and an isolated fixture, not an
installed service, public web API or arbitrary MP3 uploader.

## Components and use

`schoolbell.media_codec` provides strict JSON and small-metadata SHA-256;
`media_fs` uses nixio and installed sha256sum, with a host-only C syscall shim;
`media_manager` implements snapshots, commit, lookup, fallback and cleanup.
Run `make ci-schoolbell` or `sh packages/schoolbell/tests/test-media-manager.sh`
with Lua 5.1/development headers, a C compiler and python3. No automatic SSH.

Create `media_fs.new(private_existing_root)` and `media_manager.new(fs, options)`.
Methods: recover(), commit(operation_id, expected_generation, documents, imports,
initialize), lookup(operation_id), cleanup(), hold(hash), close(). The
ownership_safe callback defaults to false. Only return true when exclusive
ownership and absence of an old player are established; the isolated fixture
has no player. Production orphan-process discovery is not implemented.
The existing root must be private (0700). A stable .lock is held with POSIX lockf
until close; a second in-process owner is rejected too. Never remove the lock or
replace the trusted root/ancestors. This is not a hostile-root sandbox.

## Prepared bundle

Documents maps four fixed filenames to JSON strings. Catalog envelope:
`{"melodies": [...]}` with MEDIA_FORMAT fields; only source=user is supported.
Names are at most 256 bytes; IDs use 1–64 `[A-Za-z0-9_-]` characters. Imports maps
SHA-256 to trusted absolute regular-file paths. Size/hash/numeric audio fields
are checked; the caller supplies validated MP3/audio metadata. Known repository
MP3s are used without playback. This module is not an MP3 validator.

Settings is prepared valid JSON. Schedules/plans are dependency manifests
`{"references": [{"id": "bell", "revision": "..."}]}`, checked against the
catalog. They are not calendar data or a replacement user-settings schema.
Real calendar validation/migration remains separate; actual plans cannot be
smuggled through these manifests with hidden references.
Objects stream in at most 16 KiB chunks, are hashed and synchronized, never
overwritten. Snapshot ID equals caller-supplied 32 lowercase hex operation ID;
existing directories are never reused. ID generation is outside this module.

## Commit and recovery

Current/recovery fields: generation, current, previous, checksum. References have
snapshot and sha256; previous may be JSON null. Generation is 1..2147483647,
without wrap. Checksum hashes LF-terminated lines: schoolbell-pointer, decimal
generation, current ID/hash, previous ID/hash (two '-' lines when absent).
It detects corruption, not forgery. Snapshot.json has storage_version=1,
operation_id, generation and exactly four files entries (name/size_bytes/sha256).
Hash exact bytes; the pointer authenticates descriptor integrity by its hash.

Order: object → snapshot → durable old-current copy in recovery → temporary
current → rename → directory fsync. Synchronize both source/destination directories
when moving from staging. Saved follows all barriers. Ambiguous publication errors
return needs_recovery; earlier errors rejected; stale generation conflict.
Initialization explicitly requires initialize=true, generation zero and empty
object/snapshot stores without pointers. Failed first initialization with leftover
files requires administrative inspection, never blind reinitialization.

Recover returns ready, empty, paused or recovery_required. It validates current
and the complete bundle, then its previous reference, then verified recovery
current/previous references. Fallback stays paused. Never choose by filename/mtime
or replay playback requests. Lookup returns retained or unknown; retained means
a checked snapshot referenced by a pointer, not proof that a saved reply was
historically delivered. Unknown does not mean rejection. Automatic pointer repair
following fallback and UI confirmation are not implemented.

Cleanup validates current/previous, durably converges recovery to current, then
removes unreferenced snapshots/objects and owned staging files. Cleanup failure
does not undo commit. Hold(hash) returns an idempotent release function protecting
an object from GC; close rejects live holds. This is local GC retention, not queue
or media_linux FD-lease integration. Production must account for all plan, backup
and process owners.

## Limits and evidence

The existing strict decoder caps each JSON at 16 KiB, so this implementation also
caps catalog at 16 KiB despite the future 64 KiB contract ceiling. Other size,
duration, count and reserve checks are present; actual space may be lower.
Directory traversal caps at 512 entries. These are not whole-service RAM or
multi-year-plan capacity guarantees.
TC-91 covers 25 real host process-crash checkpoints plus hash/JSON, locks,
conflicts, corrupt objects/pointers, references, limits, space, fsync, GC/holds
and unknown ownership. TC-92 exercises the same manager in router tmpfs and an
isolated persistent directory; isolated PASS: 25 checkpoints on each filesystem plus negative tests; fixtures removed. Process
termination is not a power-loss test or proof of flash durability. No core,
queue/service, arbitrary upload, bundled resolver, browser API, sound or IPK install.

MR3020 testing exposed nixio mode=700/600 and 32-bit Lua uint32 formatting differences; both were corrected. Fixture VmHWM was 1200–1544 KiB, not a future service budget. Core/demo were not restarted and installed-file checksums were preserved.
