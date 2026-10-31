# Annual calendar and preview

Since 5.1.0 the working calendar uses named ranges. This document describes the original year format; see [Calendar plans](RANGE_PLANS.en.md) for current UI, compatibility and migration.

[Русский](ANNUAL_CALENDAR.md) · [Editor](SCHEDULE_EDITOR.en.md)

Select a year and schedule, then assign individual dates or a range filtered
to all days, Monday–Friday or weekends. Quiet day removes an assignment;
clearing a year requires confirmation. The grid starts on Monday, underlines
weekends and uses named colors. Narrow screens show one month per row.

Save draft stores schedules and plans as one revision, retaining conflict
protection. Unassigned dates and absent years are quiet; no annual repeat.
Up to eight explicit years share the existing 12 KiB total JSON limit.
Schedules referenced by any assigned date cannot be deleted.

Preview calculates the current browser draft, including unsaved changes,
through the existing Lua calendar. It shows main and preliminary bells,
including the original main-bell date for a preliminary bell across midnight.
Quiet days suppress crossing preliminary bells.

**These are civil wall times, not UTC.** Preview does not validate the router
timezone, DST transitions or readiness for execution. It performs no save,
event registration or playback. Automatic bells remain disabled.

## Format and compatibility

Optional plans contains objects with unique integer year (1–9999),
schedule_ids (up to 16 unique existing schedule IDs), and days.
days is an ASCII string of exactly 365/366 characters starting January 1:
dot means quiet; A–P reference palette positions 1–16.
This avoids repeating long IDs for every date. The server validates all fields
and expands the compact representation into the existing calendar map.
Unknown fields, duplicate years, fractions, invalid codes and dangling references
are rejected. This remains an inactive editor format, not a production snapshot
or import API.

Legacy drafts without plans retain their original bytes/checksum on read; no
migration write occurs. fsync/previous/revision handling is unchanged.
Old code cannot read a newly saved annual draft. Do not silently discard plans
for a downgrade: compare the backup first; restoring old user data is a separate
deliberate action.

Authenticated, CSRF-protected POST preview takes token, draft and date
(YYYY-MM-DD), within existing form limits. The response contains ok,
active=false, clock_basis=civil, date, selected_schedule and events.
Events expose date/time/origin_date/schedule_id/row_id/kind/media; no UTC or
execution promise. The one-day calculation includes next-day preliminary bells.

## Evidence

Twelve host groups cover leap/century years, 0001/9999 boundaries, midnight/year
crossings, quiet days, disabled rows, references and legacy compatibility.
Native crash tests now use full-year data. A local browser with the actual Lua
backend verified assignment, saving, reload and 07:58/08:00 preview.
Target evidence is recorded separately; this is not reboot, power-loss, DST
or automatic execution testing.

The same 12 calendar groups and eight storage interruption points on each filesystem passed on MR3020. Deployed files and preserved user data were verified with SHA256; core/demo and live topics remained healthy. The owner confirmed painting and persistence after reload through LuCI. Target-page preview confirmation remains a separate check.

The primary assignment method is a colored schedule brush: hold the left mouse button and paint dates, or tap dates on touch screens. The quiet-day eraser removes assignments. Range tools are collapsed under Advanced. Save explicitly indicates when there are no changes; requests time out after 15 seconds. A lost save response requires reconciliation and is never retried automatically.

The duty panel shows draft state, preparation mode, no active next bell, the engineering UI revision and installed package versions from opkg. This is not live executor monitoring: no automatic executor is connected. A countdown requires an active plan; absent package metadata is explicit.

Module versions start at 5.0.0, using major.minor.patch; subsequent small fixes increment patch. The source is pkg-schoolbell/CONTROL/control; the engineering payload carries it separately from installed core metadata. Tabs preserve edits. Status collapses; clocks are compared by epoch, with time zones shown separately. A difference over 5 seconds offers the standard LuCI time page, without automatic clock changes. The journal distinguishes user/module/system and retains up to 16 KiB, or 24 KiB including temporary data. It records server operations rather than mouse movements; power loss may lose records. It is not full syslog.

Schoolbell 5.0.1: persistent per-schedule colors from 16 muted shades, automatic assignment and manual selection, consistent across the list, calendar and preview. Journal text is left-aligned; time-zone settings are offered independently of clock synchronization. Reading a legacy draft does not rewrite it; colors are persisted only on explicit save. Equal offsets do not prove equal geographical zones or DST rules.

Downgrading to 5.0.0 after saving color is incompatible with its strict schema. Rollback commands require the original draft to remain unchanged; new user data is never discarded automatically.

In5.0.2, the time zone is configured inside Settings with explicit confirmation. It affects the router globally but never sets the UTC clock epoch. Earlier-stage LuCI links are no longer used. The palette changed while saved numeric color IDs remain stable.

Version 5.0.3 fixes UCI persistence: target UCI disables commit with `-P`, so commit uses `-p`. Success requires a changed system file SHA256. The isolated `packages/schoolbell/tests/test_timezone_target.lua` regression reads the file after closing staging and then opens fresh staging; it does not reload system or change the live configuration.

## Quick controls in 5.0.4

Mute persists separately from drafts and blocks manual/test router audio. The active owner checks cancellation every 100 ms; network and OS scheduling prevent a hard latency guarantee. The UI waits for lock release before confirming the player stopped. Unmuting never replays missed bells. Manual playback uses saved media, test by default, from test/0–4. Pre-bell media and fixed/annual mode save with the draft. Fixed means one daily schedule, quiet by default; annual uses date assignments and missing years stay quiet. The automatic executor remains disconnected. Public demo mute is local and never starts router playback.
