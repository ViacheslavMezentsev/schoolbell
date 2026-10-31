# Selected-plan export from the device

[Русский](PORTABLE_PLAN_EXPORT_DEVICE.md) · [Import](PORTABLE_PLAN_IMPORT.en.md)

Candidate5.1.21, host-tested; not installed on the device.

Calendar → Export calendar plans .sbp: select saved plans and download. Save or
explicitly discard local edits first; automatic bells must be off. The bundle
includes ranges, assignments, referenced schedules/colors, disabled rows and
pre-bell dependencies. Bundled audio uses exact hashes/sizes; user audio is
included and deduplicated. Manual-bell settings, volume/mute, session, network
and clocks are excluded. Source draft/applied plan remain unchanged; .sbb is
still the full backup format.

POST plan-export accepts strict JSON {selected:[id,...],revision:SHA256}, up to
4096bytes and1–8plans, with LuCI administrator session and Bearer CSRF before body
parsing. GET and stale revisions are refused. A complete validated private /tmp
file is prepared under player→editor→media locks; locks are released before HTTP
download. Only selected dependencies are opened. Stream chunks≤16KiB; hashes use
bounded temporary files instead of concatenating audio in Lua memory.

Container≤2125906bytes; tmp admission reserves twice its size +128KiB plus
max(1MiB,10% tmp). Normal/error cleanup removes the owned temporary directory.
SIGKILL/power loss can leave a directory until /tmp cleanup; no permanent data
is affected and no background cleanup service is introduced.

Browser download timeout180s, MIME/length/magic checks and unchanged local
snapshot/session guards; controls recover after failure without automatic retry.
The importer verifies every internal SHA. Pages remains bundled-only and rejects
user-audio bundles explicitly during preview.

TC-181 covers actual host files/MP3 export→admission→import into an empty store,
source preservation, free-slot remapping, revision/selection/space/write failures,
HTTP CSRF, lock release before response, disconnected receiver cleanup, and UI
truncation/stale draft handling. Target LuCI, peak RSS, large files and slow clients
remain unverified. Next: separately authorized installation after backup and
user-audio transfer validation, without enabling bells or changing clocks/NTP.
