# Schoolbell 5.x acceptance programme

[Русский](ACCEPTANCE.md) · [Specification (RU)](../requirements/TECHNICAL_SPECIFICATION.md) · [Packaging](../architecture/PACKAGING.en.md)

Revision 1.0, 2026-10-25. **Draft for agreement, not an acceptance certificate.**
Basis: the owner's product-readiness request, schoolbell specification 1.45 and
5.0.31. Method: observable installed-device properties and end-to-end user journeys
mapped to existing TC identifiers. The specification and its numbering are unchanged.
AC-01…AC-12 are stable scenario IDs within this programme, not new TC IDs.
A = analysis, T = test, I = inspection, D = hardware. New numerical targets and
release scope need owner agreement. Accepting this document does not authorize
sound, reboot, power cuts or changes to time.

## 1. Product boundary and release decision

Initial profile: TP-Link TL-MR3020 v3.30, OpenWrt 19.07.9 with the exact kernel ABI,
Lua 5.1, an agreed USB audio card/hub/power supply/speakers and local browser.
Record exact models and versions. Other hardware/firmware does not inherit PASS.
Internet may obtain the bundle, but prepared installation and operation are tested offline.

Two distinct operating boundaries:

- **Attended startup:** after power-on an operator checks time and explicitly enables
  the saved plan; subsequent operation does not require a browser. Test this first.
- **Unattended recovery:** after power loss the device obtains trustworthy time and
  resumes an authorized plan under an agreed policy. This future profile still needs
  a time source, waiting deadline, failure indication and resumption authorization.

The saved reference detects some rollback; it cannot measure time spent without
power or replace an RTC/external reference. Disabling the gate does not establish
accuracy. Rate correction cannot recover a lost date. Installation, upgrade,
downgrade and import leave automatic bells off in either profile.

Proposal: accept the current standalone executor against this programme without
first completing the universal core event API. This does **not cancel** P01–P05,
the production worker, revision retention or existing requirements. Until the owner
agrees this boundary and explicit deferrals, TC-33 and the full production profile
remain open. Changing executor requires end-to-end reacceptance despite an unchanged UI.

Release requires every mandatory AC for the chosen profile, resolved numerical
questions and no blocking defects. An untested mandatory property cannot be waived
by a README warning. Historical PASS retains its tested version/scope; changes to
a covered path require rerunning the affected checks.

## 2. End-to-end scenarios

All D checks require an approved fixture, verified backup/recovery, exact bundle
hashes, initial status, known time and a precomputed expected-event list. Automatic
bells stay off before authorized sound tests. Process-start logs do not prove audible output.

| ID / property | Actions and expected result | Specification / method |
| --- | --- | --- |
| AC-01 / complete delivery | Install the full bundle on a clean supported offline base. UI, six bundled files and native module are present. Wrong ABI/incomplete bundles cannot partially activate. Verify every payload hash and auto-off. | TC-12/13/30/134–136; A/T/I/D |
| AC-02 / predictable editing | Using normal login, create/copy/edit four working schedules and a quiet choice; delete an unused schedule and try deleting a referenced one. Switch tabs, save/reload. References and edits survive; viewing dates never erases them. Two editors get a visible conflict rather than data loss. | TC-19–21/25/26; T/D |
| AC-03 / correct calendar | Fixed mode on two dates; annual assigned/quiet/unassigned dates, month/year boundaries and leap day. Toggle enabled/pre, all 1…10 minute offsets and midnight preliminary bell landing on a quiet day. No annual repeat; preview matches execution for the same active revision. Local-time gaps/folds are rejected. | TC-14–16/31/36–39; T/D |
| AC-04 / draft versus active | Activate a saved plan, edit/save its draft: active revision stays unchanged. Explicitly apply, repeat/lose the response: confirmed state is visible and no duplicate bells appear. Invalid replacement preserves the former plan. Disable automation; reconnection cannot enable it. | TC-18–20/132; T/D |
| AC-05 / sound and controls | Verify main/pre/manual bells, next-start volume, both browser previews and router test. Mute stops current sound and blocks new starts; unmuting never catches up. Coincident events and busy/crashed/hung player cause no overlap or uncontrolled retry; outcome is visible. Resolve collision policy in Q4. | TC-06–10/18/26/32/132; T/D |
| AC-06 / time and startup | Fake-clock rollback/step/gap, lost reference, corrupt policy, stale confirmation and gate off/on. Separately authorized offline cold boot: clear block, retained data, confirming time does not enable bells. Browser synchronization from another zone and school TZ need a separate experiment after clock measurement finishes. | TC-13/17/132/133; T/D |
| AC-07 / media | Upload/name/replace/listen to all eight user slots within the total quota. Six bundled slots protected; empty slots visible; successful upload refreshes list. Bad MP3, size/duration excess, ENOSPC and disconnect preserve confirmed files; reconcile unknown outcomes by reading without repeating writes. Schedule references survive; missing referenced media blocks activation. | TC-22/23/131; T/D |
| AC-08 / backup and transfer | Export plan/settings/filled user slots, restore to empty storage/a compatible second unit, compare content and media SHA. Reject corrupt/incompatible archives. Device bindings/time trust are not cloned; auto-off after restore/login. Lost response never automatically repeats restore. | TC-24/34/35; T/D |
| AC-09 / updates and interrupted writes | Install/upgrade/downgrade agreed versions with data; compare payload/settings/media and auto-off. Interrupt each commit stage on host, then separately test physical power: coherent old/new data or visible blocking, never a corrupt active mixture; verified recovery must exist. | TC-24/73–92/134–136; T/D |
| AC-10 / usable secure UI | On desktop and touch, complete AC-02/04/07/08 without SSH/developer hints. Check themes, painting, time/TZ, mode, versions, next bell/block reason including future assigned days. Busy/timeout/logout/disconnect offer recovery, no endless waiting or false success. Unauthorized/forged requests perform no action. | TC-25–29/129/131/133; T/D |
| AC-11 / autonomy and coexistence | Close browser and remove Internet access in an approved experiment: expected bells continue with valid time. Compare core/demo/Modbus before/after load; no direct serial access or interference with other services. Missing audio is visible; reconnection never releases stale bells. | TC-03/13/27/28/32; T/D |
| AC-12 / endurance and operation | Agreed continuous run with normal load and authorized edits. Reconcile expected/suppressed/actual bells; measure RSS/CPU/FD/processes/flash/tmp/logs/latency. Bounded rotating journal distinguishes user/module/system events. Another operator can follow the startup/disable/backup/recovery instructions. | TC-27/31–33; A/T/D |

## 3. Oracle, accuracy and load

Prepare the oracle before execution, independently of the calculator under test:
date/TZ, schedule/row ID, main/pre, melody, local time and unambiguous UTC, expected
suppression reason. Include the original 15 main + 6 preliminary moments, disabled
rows, quiet dates, midnight, new year and leap day. Playing 21 events does not prove
the full calendar: test that range with injected clocks. A compressed test day must
not accidentally introduce overlaps; AC-05 tests them deliberately.

Candidate limits, **not measured guarantees or implicit specification changes**:

| Question | Proposal / agreement needed before PASS |
| --- | --- |
| Q1 / audible timing | No start before due time accounting for measurement uncertainty, and at most +1 s with trustworthy time; stop within 1 s of router acceptance of Mute. Record click→accept, dispatch→spawn, spawn→sound and uncertainty separately. An uncertainty interval crossing the limit is inconclusive and needs a better/repeated measurement. |
| Q2 / duration | One week on the fixture, followed by a school-owner pilot; agree pilot length, event count and permitted sound windows. No annual reliability guarantee follows. |
| Q3 / resources and clock accuracy | Agree RAM/flash/tmp reserves, growth/peak limits and permissible UTC error over the claimed autonomous duration before load acceptance. RAW slope, current adjtimex correction and residual UTC error are distinct; one day does not establish one year. Reference quality and temperature constrain conclusions. |
| Q4 / coincident requests | Agree priority/queue/drop rules for manual/test/main/pre, maximum request age and visible outcomes. Isolated FIFO tests do not establish installed-executor policy. |
| Q5 / release scope | Approve attended startup with explicit production-spec deferrals, or finish shared integration first. Unattended power recovery needs a separate time-source/resumption contract. |

Without Q1–Q3 limits, exploratory measurements are allowed, not acceptance PASS.
Eight user slots means eight files within the total quota, not eight maximum-size
files on internal flash. Use the shipped version's precise quotas and reserve.

## 4. Original Schoolbell-4 parity

Baseline: the [article](https://habr.com/ru/articles/228479/) and
[source c4bbecd](https://github.com/ViacheslavMezentsev/schoolbell/tree/c4bbecd1bd5136051cc12858801fb9bed7222cc2)
pinned in specification appendix B. Match user outcomes, not cron/CGI internals.
This grouping covers every appendix B row:

| Baseline capabilities / source | Acceptance |
| --- | --- |
| Fixed/date selection, quiet day, four working + empty schedules, 15+6; settings.json, schedules.json, sh/scheduler.cgi | AC-03/04/12 |
| Annual calendar, palette, weekends and clearing; plan.json, main.js | AC-02/03/10 |
| HH:MM rows, melody, enabled/pre, shared 1–10 interval and pre melody; main.js, sh/scheduler.cgi | AC-02/03/05 |
| Five melodies + test, two browser previews, speaker test while paused; melodies.json, main.js, sh/action.cgi | AC-01/05/07 |
| Stop/resume/apply, multiple schedule editing, read/save; main.js, sh/action.cgi | AC-02/04 |
| Router time, browser synchronization and time zone | AC-06/10 |
| Status, system/application logs, versions/dependencies | AC-10/12; system-event subscription is still a gap |
| Local desktop/mobile, closed-browser operation, ready delivery | AC-01/10/11 |

Setting time from the browser is distinct from confirming the displayed date; both
remain in acceptance. Replacing the shared crontab and the old midnight bug are
not compatibility goals. Old whole-schedule add/delete stubs are not proven legacy
features; the new editor, user MP3, backup and Mute are extensions.

## 5. Coverage and next branches

5.0.31 has separate engineering confirmations for editing/painting, an automatic
main bell, annual selection/Mute, user upload/listening, backup/restore, time
confirmation and real opkg with a local recovery downgrade. The owner confirmed
retained plan/media and auto-off after the last update. This is **not a complete
rerun of all AC**. Local recovery does not prove arbitrary release compatibility.

Remaining mandatory evidence: clean offline install/cold boot; physical power;
full executor calendar oracle; audible timing; collisions/player failures; all user
slots/resource peaks; mobile/time synchronization/system events/future countdown;
endurance. Historical appendices and older guides describe stages, not current
installed capability; audit the operator guide against AC before release.

One branch per stage:

1. Resolve Q1–Q5/scope; prepare oracle, startup/boot/TZ audit and AC-06 host tests
   without changing running clocks.
2. Once current clock measurement ends and separate authorization is obtained,
   test cold boot and fix blockers; never change clocks merely to accelerate a test.
3. Test the working day/sound AC-03–05, then failures/UI/media AC-02/07/10.
4. Test clean install, transfer and power AC-01/08/09/11 with verified recovery.
5. Close budgets, run AC-12, reconcile appendix B, deliver operator/installer/recovery
   instructions and accept an exact release bundle.

## 6. Evidence and release blockers

Keep a local record per AC: ID, build/commit/bundle SHA, fixture, date/TZ, initial
state/backup, exact steps, oracle/actual result, measurement method/uncertainty,
logs/hashes, defect, restored final state and tester. Hardware data and completed
records are not committed.

Outcomes: **PASS / FAIL / NOT TESTED**. Partial coverage is a subcase; the whole AC
remains NOT TESTED. A failed mandatory subcase makes the AC FAIL. CI, mock/demo or
presence of a button cannot replace D.

Blockers: extra/duplicate bell; missed expected bell with a healthy fixture and
allowed load; timing-limit violation; failed stop; lost/silently substituted data;
auto-enable after restore/update; authorization bypass; unrecoverable controls;
interference with unrelated services; false success. Stop the affected experiment,
preserve evidence and restore the agreed safe state. Finish authorized sound tests
by separately checking auto-off, retained plan/media, no owned player processes and
core/demo status.
