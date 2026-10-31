# Schoolbell UI completeness and improvement plan

26.10.2026: 5.0.34 implements host-tested session/logout recovery, same-user recheck without command replay and a configurable browser idle timer. The server LuCI session policy remains unchanged; roles, TLS and live dispatcher/expiry acceptance are still pending. The shared guide now separates operator routes from non-obvious behavior notes. Next accepted feature: portable academic-plan bundle including all dependencies (years, schedules, dates and referenced media); import preview/conflict handling and draft-only, automatic-off result.

[Русский](UI_COMPLETENESS.md) · [User guide](../user/USER_GUIDE.en.md) · [Acceptance](../acceptance/ACCEPTANCE.en.md)

Draft 1.0, 2026-10-25, for agreement. Based on 5.0.31 UI/controller source, the guide
and host startup audit. Static journey review, not new hardware PASS, implementation
or an amendment of accepted contracts. Continues the guide branch; no router,
clock/NTP or network changes.

## 1. Complete journeys

Each action needs an initial state, visible result, inverse or explanation of
irreversibility, error and recovery path. Proposed changes need separate branches.
Viewing never edits; saving a draft does not apply it. Save/discard, assign/unassign
and enable/disable must be visible pairs. Deletion explains dependencies before
confirmation, never silently substitutes values. Settings and reconnect/login never
start sound or repeat writes. Unknown is not failed: reconcile operation/revision.
Symmetry does not mean undoing an audible bell, rolling back time or offering log
clearing. Disabled controls need a reason and next step rather than endless busy.

## 2. Journey inventory

| ID | Current behavior | Gap / proposed completion | Acceptance |
| --- | --- | --- | --- |
| UX-01 login/logout | LuCI login, link back to LuCI | Visible user/role and native logout; unsaved warning; distinguish expiry/network and return after normal login without repeating commands | AC-10; expiry during reads/writes |
| UX-02 schedules | Create/copy/name/color/delete; annual references block deletion | Unified references across years/fixed/saved/active copies. Rendering currently silently changes a deleted fixed ID to quiet: require explicit choice. Show references and navigation; replacement needs separate confirmation | AC-02/04; no silent mode change/dangling references |
| UX-03 rows | Add/delete/clear, enabled/pre and limits | Bounded in-memory undo; visible limit/collision reasons. Clear is not disable | AC-02/03; undo never saves/applies |
| UX-04 calendar | View/paint/eraser/range; clear year removes its draft record | Undo stroke/range, list stored years, distinguish viewing from creation. Clearing last year currently normalizes to fixed/quiet: explain/confirm. Future copy-year needs explicit leap-day policy, no annual repeat | AC-03/10; viewing never mutates |
| UX-05 save/discard | Save, reload with loss confirmation; unknown requires reread | Name discard clearly; compare local/saved data on conflict without sacrificing the only copy of edits | AC-02/04; two clients/lost response |
| UX-06 apply/disable | Separate active snapshot, explicit enable/disable | Active preview distinct from draft; compare dates/times/melodies/mode before apply. Previous-plan restore later via validated copy, not arbitrary undo | AC-04 |
| UX-07 manual/stop | Manual, Mute, browser pause; manual blocked while playing | Agree collisions/priorities; show current melody/refusal. Distinguish stop-current, if added, from persistent Mute; duplicate click never spawns twice | AC-05, lost response; Q4 open |
| UX-08 upload/delete | Upload/replace, title during upload, eight slots; no delete | Rename without reupload; clear user slot only after all references/retained revisions checked. Protect bundled/in-use files. Report space after safe GC, no promise of instant release | AC-07/09; generation conflict/ENOSPC/interruption |
| UX-09 clock/zone/trust | Zone choice, comparison/confirmation, gate off/on | Set time from this device with before/after/delta review, outcome check, no silent NTP change. Disable automation first, never enable afterwards; separate time confirmation. Unknown outcomes cannot auto-repeat | AC-06/10; fake clock first, real write requires permission |
| UX-10 backup/restore | .sbb, status/resume, auto-off, TZ check | Read-only archive summary: available date/version metadata, years/schedules/media/TZ/space/replaced data; do not invent old-format fields. Offer current backup. Preserve resume; cancellation after commit starts cannot promise rollback | AC-08/09 |
| UX-11 status/diagnostics | Today countdown, journal, space | Next assigned day, compact actionable errors, core system events, filtered/redacted log export. No need for clear-log symmetry | AC-10/12 |
| UX-12 onboarding/recovery | Multiple tabs/confirmations | Zone → correct time → media → schedule/year → review → enable, no automatic sound. After boot show retained data and required checks; reuse APIs/formats | AC-01/06/10; independent operator |

Inspected schedules.js (delete/render/save/reload/paint), automatic.js, controls.js,
media.js, backup.js, clock-trust.js, dashboard.js, live schoolbell_test.htm and the
Lua controller under router-page. Current means source evidence, not a new browser run.

## 3. Current security

Dynamic routes are under /admin/schoolbell using normal LuCI authentication. The
upstream 19.07 admin parent declares cookie sysauth/login in
[luci-base.json](https://github.com/openwrt/luci/blob/openwrt-19.07/modules/luci-base/root/usr/share/luci/menu.d/luci-base.json).
The exact installed build and direct URL access still need verification. Public
CSS/JS do not themselves authorize private reads or actions.

Form writes use test_post_security(). Binary MP3/SBB writes use Authorization Bearer
with the session CSRF token **and cookie session**, accommodating old CGI header
handling, not replacing login with a second password. Server validation covers
sizes/types/references/revisions/quotas/allowed actions. Bounded read retries are
not repeated writes. Clock command results are session-bound. Check every endpoint;
a common helper alone does not prove complete coverage.

Limitations: the current LuCI administrative account is normally root; no dedicated
schoolbell operator/editor roles exist. Hiding menus does not limit permissions.
HTTP does not encrypt passwords, cookies or backups; login/CSRF do not replace HTTPS.
TLS/certificate/interface setup needs separate installation/resource checks; this
branch changes neither uhttpd nor networking. The profile is a trusted LAN, not
Internet-exposed LuCI; school management access should be separated from student/
guest access. The journal is not a tamper-proof per-person audit, and shared root
cannot identify individual operators. SBB integrity checks are not encryption or
a digital signature.

## 4. Proposed access model

Reuse LuCI/rpcd sessions rather than storing custom schoolbell passwords. Prototype
19.07 ACL sufficiency: existing Lua controllers cannot be considered restricted just
because a role was named. Enforce capabilities server-side for every operation;
system actions need a narrow validated handler.

| Role | Proposed capabilities |
| --- | --- |
| Viewer | Status/active plan; media/log access needs separate agreement |
| Duty operator | View, manual bell, stop/Mute; no clock/import/network changes |
| Editor | Schedules/year/media, validation/apply; backup export as a separate permission |
| Administrator | Accounts/rights, time/TZ, gate policy, restore and maintenance |

Owner approval is required for the matrix. Do not hand out root solely for a bell
button. Extra confirmation is not MFA or authorization. Shared tablets need visible
logout, bounded sessions and clear login recovery; no credentials/CSRF in localStorage,
logs or public links. Logout invalidates the session; reconcile pending actions after
login instead of resubmitting.

SEC-01…06 are local plan IDs extending AC-10/TC-29:

1. Every dynamic URL rejects private access/actions without a valid session, after logout or expiry.
2. Missing/wrong/foreign CSRF, method/type rejected; Bearer without cookie cannot upload.
3. Direct requests enforce each role, even hidden actions; operator clock/restore denied.
4. Foreign operation IDs/revision conflicts/replays never bypass permission; login never repeats a bell.
5. Names/uploads tested for XSS, traversal, shell injection and quotas; tokens absent from export/logs.
6. Actual HTTPS/certificate/interface policy tested on target separately from mocks; login failures never trigger bypass.

## 5. Separate implementation branches

| Stage | Deliverable | Boundary |
| --- | --- | --- |
| C1 | UX-02/04/05 explicit deletion/mode dependencies, disabled reasons, safe save reconciliation | Fix silent changes first; host/UI tests, no new storage format |
| C2 | UX-09 UTC-setting contract and injected host implementation | Agree fields/permissions; real writes only after measurement and authorization |
| C3 | UX-06/11 active preview, apply comparison, next-day countdown | One calculator, distinct draft/active, no auto-enable |
| C4 | UX-08 independent rename/safe user deletion | References, GC/leases, quota/fault tests; preserve active/referenced data |
| C5 | UX-03/04 bounded draft undo/year list | Copy-year is a later separate decision |
| C6 | UX-07/10/12 collisions, sound/import/onboarding | Sound separately authorized; backup evolution preserves compatibility |
| S1 | Endpoint/session/CSRF audit, visible logout/expiry | Mandatory security track, no rights deployed here |
| S2 | Role/ACL prototype, server enforcement/UI, HTTPS/network profile | Before delegating to staff who must not have administrator rights; measure RAM/space |
| R1 | Updated guide and complete AC/SEC for chosen profile | Cold boot/power/endurance separately authorized; CI does not replace hardware |

Start with C1 and S1. C2 is the first new functional capability after ambiguity fixes.
This branch is a plan only: acceptance Q1–Q5, collision priority, roles and unattended
resumption remain unapproved.
