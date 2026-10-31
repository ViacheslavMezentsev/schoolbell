# Calendar plans — schoolbell 5.1.0

5.1.2: pagination is immediately above the months and repeated below them. Both controls share page and boundary states; bottom navigation scrolls to the calendar start. Pages is synchronized.

Viewing: range months are consecutive across years. Up to 12 months appear together; longer plans use previous/next pages. Navigation does not change draft data, assignments or bulk-fill boundaries.

[Русский](RANGE_PLANS.md)

The live UI and Pages share `ranges.js` and `schedules.js`; Lua validates the same
payload and resolves assignments. No router installation was performed.

A plan is `{id,name,start,end,schedule_ids,days}`. IDs survive rename/resize. Names
are 1–96 UTF-8 bytes; inclusive dates use YYYY-MM-DD, years 0001–9999. Ranges cannot
overlap even on quiet dates. `days` has one ASCII code per date: `.` quiet, A–P an
index into schedule IDs. December 31, 2026–January 1, 2028 is one 367-day plan.

There is no fixed duration/day quota. The actual draft budget is 12288 bytes,
8 plans, 16 schedules and 128 bell rows. Oversized documents fail before writing;
previous data and edits remain. Pages of 12 consecutive months bound rendered calendar cells, not plan
boundaries. Create/rename/resize, painting, bulk assignment, copy and delete operate
on the draft. Resize preserves by date, extends with quiet dates and confirms lost
assignments. Copy uses day offsets with an explicit weekday warning. Removing the
last annual plan explicitly changes the draft to Fixed/Quiet; schedules/media stay.

First install is empty. Only a fresh confirmed router date may propose September–May
when Create is clicked; otherwise boundaries remain blank. Proposals do not create
plans. Saving and activation remain separate. Pages clock confirmation is simulated.

Legacy `{year,schedule_ids,days}` is read without byte/checksum changes. The UI
converts its in-memory copy to `year-N`, January 1–December 31; merely opening never
writes. CAS/fsync/previous protections remain. Executor and `.sbb` accept both forms;
restoration preserves new plans and user MP3s with automatic bells disabled.
New range payloads require >=5.1.0; keep a pre-upgrade `.sbb` alongside the old IPK
for downgrade. The schema change warrants a minor version rather than a patch.

Pages supports device-free preparation/training, local browser storage and six
bundled melodies only. Unsupported user-media dependencies must fail visibly, never
be silently substituted. Authentication, clock, storage capacity and automation are
simulations, not equipment acceptance.

A future portable bundle (not implemented here) includes selected plans, referenced
schedules/colors, pre-bell settings, plan timezone and media dependency closure.
Bundled media use ID + SHA256; future user-media transfer is outside the initial
Pages scope. It must declare minimum compatibility, preview conflicts/dependencies,
and import as a draft with automatic bells off. Credentials, network, NTP, clock
trust and hardware settings are excluded; importing must not apply system timezone.
The archive format will be agreed separately from the complete device backup.

Checks cover Lua storage/execution/backup, editor journeys and exact Pages/Lua JSON
preview parity using `range-plan.json`. Civil preview is not DST/execution-readiness
validation. Hardware acceptance and long-term autonomy remain unproven.
