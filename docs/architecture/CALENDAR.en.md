# Schoolbell schedule calculator

[Русский](CALENDAR.md) · [Specification 1.6](../requirements/TECHNICAL_SPECIFICATION.md) · [Lua module](../../src/lua/schoolbell/calendar.lua)

An isolated Lua 5.1 module validates and copies a model, calculating moments for
preview and future registration. It reads no clocks/files, starts no player,
changes no cron and calls no core API. It is not included in media-only IPK 0.0.1.
This is the first application calculation layer, not a replacement for the original.

## Accepted rules

- fixed repeats the selected schedule every day, independently of annual plans.
- annual selects an exact date in an explicitly identified year. Missing dates
  or years are quiet; plans never repeat automatically. Multiple distinct years
  can be supplied in advance. Weekly rules/exception priorities are not implemented.
- quiet, an empty schedule or one with no enabled rows denotes a fully quiet day,
  including incoming preliminary bells from the next day.
- Disabled rows remain stored but generate neither event. An enabled row with
  pre=true adds one preliminary bell using the shared melody and 1–10 minute offset.
- The offset is subtracted from local calendar time across hours/days. A preliminary
  bell retains its main bell's origin date. A quiet destination day suppresses only
  that preliminary bell. Calculation includes next-day lookahead for midnight crossings.
- Nonexistent local time (gap) or two UTC candidates (fold) rejects the entire
  requested window. No normalization, implicit choice or partial list. This is
  calculation policy, not runtime clock-correction/missed-bell policy.
- Coincident row events remain distinct, sorted by UTC then stable ID. Playback
  ordering and freshness belong to the future worker.

## Internal model and API

This Lua model is **not an approved settings.json/import/migration format or public
core API**. Fields are required except fixed_schedule in annual mode. Unknown
fields/metatables and sparse lists are rejected.

```lua
local calendar = require("schoolbell.calendar")
local model = assert(calendar.compile({
    revision = "draft1", mode = "annual", timezone = "UTC+05:00",
    pre_minutes = 2, pre_media = "pre", media = {"main", "pre"},
    schedules = {{id = "weekday", rows = {
        {id = "lesson1", time = "08:00", media = "main", enabled = true, pre = true}
    }}},
    plans = {{year = 2026, days = {["2026-10-26"] = "weekday"}}}
}))
local resolver = assert(calendar.fixed_offset("UTC+05:00", 300))
local result, err = model.calculate("2026-10-26", "2026-10-26", resolver)
-- 07:58/pre and 08:00/main; no hardware action.
```

fixed_schedule references an existing schedule or reserved quiet ID; a schedule
cannot itself use that ID. plans may be empty. Unused schedules/plans and disabled
rows are validated too. Media lists permitted IDs, not verified files/revisions.
Dates are strict YYYY-MM-DD, times HH:MM and flags are booleans, not "on" strings.
IDs/revision use 1–64 ASCII A–Z/a–z/0–9/_/- characters; row IDs are unique per schedule.

| Operation | Result |
| --- | --- |
| validate(config) | true or nil, error; no persistence |
| compile(config) | Independent snapshot with calculate, or nil, error |
| model.calculate(first, last, resolver) | Inclusive local-date window; result or nil, error |
| days_in_month(year, month) | Day count or nil, error |
| weekday(date) | ISO Monday=1 through Sunday=7 |
| add_days(date, delta) | Validated date shifted by integer days |
| fixed_offset(zone, minutes) | Explicit constant-offset resolver, no DST/tzdb |
| limits() | A copy of implementation guards |

result includes revision, timezone, days (date and selected schedule_id) and events.
Each event has id, revision, timezone, actual date/time, integer UTC seconds,
origin_date of the main bell, schedule_id, row_id, kind=main/pre and media.
The internal ID is revision/origin_date/schedule_id/row_id/kind, not an exactly-once
guarantee. The owner must change revision when editing the model. Adjacent windows
preserve IDs without boundary loss/duplication; overlapping windows intentionally
return the same IDs. Errors are {code,path} without a partial result. Input/result
mutations do not affect subsequent calculations from the compiled snapshot.

## Timezone boundary

A trusted bounded resolver(zone,date,time) returns a dense list of UTC candidates:
one integer means success, zero means nonexistent_time, two means ambiguous_time.
nil/exceptions signal resolver failure; malformed data fails validation. Candidates
must be within ±24 hours of the local wall time interpreted as UTC. The resolver
must be deterministic for the selected timezone-rule version and must not block.
Tests inject it; a production tzdb/system adapter is not implemented. fixed_offset
accepts integer minutes −840 to +840, including half/quarter-hour zones; it does
not interpret IANA names or load transition rules. No host timezone/os.time/os.date.
Arithmetic uses the proleptic Gregorian calendar 0001–9999; this does not promise
that range for OpenWrt time_t/scheduler. ABI/clock-quality integration remains pending.

## Bounds and verification

Current guards: 16 schedules, 8 distinct years, 64 media IDs,
at most 366 assignments per year. A query covers at most 31 days/512 events.
Overflow rejects the whole window; traverse a year using smaller windows such as
one day at a time. These are algorithm guards, not measured router RAM/CPU budgets
or final storage quotas. compile does not expand a year of events. Calendar-domain
edges never invent events outside 0001–9999. Total Lua allocation, temporary strings,
sorting and GC remain to be measured.

```sh
make test-schoolbell
make ci-schoolbell
make all
```

Lua 5.1 and Python 3.8+ are required. Schoolbell CI runs calculation tests and
verification of the unchanged media-only IPK; make all includes the same tests.
29 groups cover TC-36–38. TC-39 independently checks 14,404 Python datetime vectors
across a 400-year cycle and calendar edges. The full leap-year original fixture
is checked day by day: 366 × (15+6) = 7,686 events.

The [normalized fixture](../../tests/original_fixture.lua)
comes from schedules.json at schoolbell c4bbecd1bd5136051cc12858801fb9bed7222cc2:
all 15 times/flags/melodies are preserved; tests explicitly set original settings
preinterval=2 and premelody=0. It is not a legacy importer or installed user plan.
Tests include four working slots plus empty, five selectable melodies and test.
TC-14–16/31 have partial calculation coverage only. UI, persistence/activation,
registrations, clock sync, worker, sound and offline delivery are still pending.
Full specification appendix B parity remains required before replacing the original.
