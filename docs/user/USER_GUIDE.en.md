# Schoolbell user guide

In 5.1.27, Media → Add melody creates an entry; selecting an existing entry replaces its file while preserving references. New MP3 files are limited to 64 KiB. Free space appears in the header and Media. From 5.1.31, the journal is bounded only by 32 KiB; age and clock changes do not remove entries.


5.1.22 (host): device local time HH:MM is right-aligned above the CPU bar; uptime is below (page age in Pages). Reuses existing clock polling and hides stale time. Default idle logout is 30 minutes; existing choices are preserved. Major section gaps are aligned and the bell-delete cross enlarged. Pages synchronized; this version is not installed on the device.

5.1.14: Journal → Statistics → HTTP requests now includes an API-method table (for example, GET automatic and POST test). Each row shows starts, completions, HTTP/network errors, pending responses and mean/maximum latency to response headers. The same twelve 5-second start-time bins apply; requests pending beyond that window remain visible. URL parameters, tokens and bodies are not retained; different arguments to the same POST method are grouped. HTTP 200 with an operation refusal is not an HTTP error; melody duration and command execution are not separately measured. Collection is passive across module tabs, without additional requests or device writes. Pages shares the code over its local model; no device installation.

5.1.13: compact sound-status/diagnostics row removes the empty header gap. Status and draft notices are grouped above the tabs, both with a Details hint. Only lower CPU tick labels were removed; percentage and colors remain. Feedback credits author Vyacheslav Mezentsev and co-author Codex (OpenAI). Pages shares the layout; no device installation.

5.1.12: automatic status reads no longer revalidate an unchanged plan. After full validation, the worker publishes a private RAM snapshot bound to the exact active-file bytes and current boot. GET compares bytes; a mismatch, age over 40 s, damaged snapshot or installation/restore operation cannot confirm readiness. Validation on changes/application and playback admission remains. No additional HTTP requests or flash writes. Pages keeps the shared interface and does not simulate hardware latency. This stage does not update the installed package.

5.1.11 (host only, not installed): collapsed Statistics switches between executor mailbox and HTTP views. The real single-slot time/enable command mailbox reports waiting depth, running state, wait times and completions in twelve 5-second bins across clients, in /tmp only; telemetry faults cannot block commands. Stop, audio and HTTP reads bypass this mailbox. Pages models its own training commands with zero wait. A thin whole-device CPU line below the title uses existing polls (idle+iowait excluded; green through 75%, yellow above 75%, red above 90%, unknown grey). Resolve problem is above the status panel on the right. No extra HTTP polling.

5.1.9: the collapsed draft panel matches the upper status panel: theme background and a yellow left border. The heading reads “Музыкальный настраиваемый звонок”. The 5.1.8 traffic chart is retained; Pages shares the UI.

5.1.8 (host only): Journal shows passive, tab-local module API traffic in twelve 5-second bins, split into reads/commands, with HTTP/network failures, pending requests and mean/maximum time to HTTP headers. This does not measure internal worker exchanges, bytes or command execution latency. Memory only, no additional requests or device writes; Pages measures its local model. Not installed.

The Draft panel starts collapsed. Click its summary to see the active-plan comparison and save/apply controls. Yellow reminds you that saving does not enable bells. Browser playback uses the viewing computer/phone; Shkolnik speaker playback uses the speakers connected to Shkolnik.

## When a problem occurs

Use Resolve problem in the header. The panel explains the latest confirmed state. Read status again never repeats commands or replaces edits. Suggested actions open the relevant section; time confirmation, saving and enabling remain separate actions. An expired session offers sign-in.

No fresh data means no current module response, not a confirmed Wi-Fi failure. Technical details contain draft and applied-copy identifiers for version comparison; these are not error codes. For recurring problems, open the journal and feedback. Time protection and locks are never automatically cleared.

Calendar months run consecutively across year boundaries. Longer plans use pages of 12 months with previous/next buttons. Navigation does not require saving.


After session loss, sound and automation controls are disabled and the status panel requests login. This does not mean the service stopped. An unconfirmed logout does not prove the server session ended: sign in normally and retry logout after connectivity returns.

The header contains compact Login/Logout controls, with no visible countdown. Idle duration is under Settings → Login and automatic logout (1–120 minutes, default 15); it is a running-page timer, not LuCI server policy. Polling does not renew it. Logout does not stop automatic bells.
Login uses the same tab. Before navigation, the unsaved draft is temporarily stored in this tab’s sessionStorage (32768 characters, up to 8 hours, no password/token); storage failure cancels navigation. The same user gets the edits back automatically, without writing them to the router. A changed server revision requires reconciliation. This is not a backup: closing the tab, clearing browser storage, expiry or another user can lose edits; selected upload files are not transferred.


The first **Cheat sheet** tab offers short operator journeys. It opens by default; the last tab is remembered within the same session.

[Русский](USER_GUIDE.md)

For **schoolbell 5.1.0** (host checks, no installation), dated 2026-10-26.
not the public mockup. Supported fixture: OpenWrt 19.07.9, TL-MR3020 v3.30 and USB
audio. An administrator installs the equipment and [package](../architecture/PACKAGING.en.md).
Individual functions have been tested; full endurance, cold-start and power-loss
acceptance remains pending. See the [acceptance programme](../acceptance/ACCEPTANCE.en.md).
Russian button labels below match the current UI.

The + button in a bell row inserts a new bell immediately after it and focuses its time. The ▲/▼ arrows move the entire row without changing bell times. Delete all bells clears the selected schedule after confirmation while retaining the schedule itself. These actions edit the draft; saving is explicit and the active plan does not change automatically.

## 1. Open the module

Join a network that can reach the router. Obtain its address and login from the
administrator. Open `http://<router-address>/cgi-bin/luci/admin/schoolbell` and use
normal LuCI login. Use HTTPS only when configured. Never enter router credentials
into the public Pages demo; it does not control your device.

Top controls are «Без звука» (Mute), «Подать звонок» (manual bell) and theme.
Click the status header to collapse details. It shows mode, versions, router/browser
time and executor countdown, not unsaved changes. The countdown currently covers
only today; a dash says nothing about tomorrow's assignments.

Tabs: «Календарь» assigns dates; «Расписания» edits rows; «Предпросмотр» previews
the draft; «Мелодии» manages audio; «Настройки» controls time/mode/backup;
«Журнал» shows recorded events; «Обратная связь» explains reporting issues.

## 2. First test

1. In Settings, check school timezone and router date/time. Ask the administrator
   to correct wrong time before continuing.
2. Under time verification, click «Проверить и подтвердить время», review and click
   «Время верно — подтвердить».
3. Create a schedule with an enabled test-melody row a few minutes after current
   router time. Disable preliminary ringing for this test.
4. In Settings select «По расписанию» and that schedule, then «Сохранить настройки и черновик».
5. Preview today and check there are no unsaved changes.
6. Click «Применить сохранённый план и включить», review/confirm, ensure Mute is off
   and the executor permits ringing. Use a short melody and low speaker volume.
7. After the test click «Отключить автозвонки». The schedule remains saved.

Fixed mode repeats daily, including weekends. Use the annual plan for differing days.

## 3. Edit schedules

Select a schedule or «+ Создать», set a name and palette color. «+ Добавить звонок»
adds a row: local school time HH:MM, main melody, enabled flag and preliminary flag.
The preliminary melody and common offset of 1–10 minutes are in Settings.
An empty schedule is silent. «Копировать» makes a variant. Remove calendar/fixed
references before deleting a used schedule. Annual and fixed references block deletion until explicitly replaced. Draft edits do not alter the active copy. «Очистить строки» clears draft rows.

Avoid two events at the same minute, including preliminary bells: the current
executor rejects such a day, rather than queuing melodies. Save edits, then separately
apply them if they should change working bells.

## 4. Paint the calendar

Choose a plan or Create Plan in Calendar. Enter its name and inclusive start/end dates,
then apply them to the draft. Ranges cannot overlap; new dates are quiet. Paint with
schedule colors; View Day never edits. Previous/next month pages navigate within the plan without
changing boundaries. Save the draft, select Calendar Plan mode in Settings and save;
activation remains separate. Resize preserves assignments by date and confirms loss.
Copy requires new dates and warns that day-offset copying may change weekdays.
Delete preserves schedules/media; removing the last annual plan explicitly switches
the draft to Fixed/Quiet. Unassigned dates/gaps are quiet, with no annual repeats.

Preview includes unsaved draft edits. It is not the active plan or proof of valid
time/audio; it does not check timezone transitions or execution readiness.

## 5. Save versus enable

| Action | Meaning |
| --- | --- |
| Editing | Changes remain in the browser |
| «Сохранить черновик» / «Сохранить черновик на роутере» | Persist the draft without replacing the active copy |
| «Загрузить сохранённое» | Reload saved data; unsaved work may be lost |
| «Применить сохранённый план и включить» | Explicitly activate the saved copy after confirmation |
| «Отключить автозвонки» | Disable automatic bells without deleting the plan |

Read the separate draft and active-plan lines. For conflicts or unknown save outcomes,
click «Сверить с роутером». Local edits remain; read the two summaries and expand full
fields as needed. «Оставить локальные правки» prepares a separate future save against
the inspected revision; «Взять копию роутера» discards local edits only after confirmation.
Matching copies after a lost reply need no repeated write. Editing invalidates the
comparison. Failed reads preserve edits and require another comparison. Choosing a
copy never activates bells. Once enabled, bells work with the browser
closed. Missed bells are not replayed. Use Mute for urgently stopping current sound;
disabling automatic bells alone does not prohibit manual ringing.

## 6. Manual sound and volume

«Подать звонок» plays one manual bell through router speakers, using the melody
selected and saved in Settings. It is unavailable while Mute is enabled.
Mute blocks router output and requests stopping the current player. Wait for
confirmation; a lost response does not establish that sound stopped. Unmute never
catches up. Stop browser audio through its own player controls.

The two test routes in «Мелодии → Ручная проверка звука» both use the bundled test
file immediately, independently of draft rows. The browser route sounds on your
computer/phone/tablet; the router route sounds through USB audio and school speakers.
For another melody use «В браузере» in its table row.

Select router volume and «Применить громкость». Volume uses whole percentages, for example 25% or 100%. Rounded 0% means minimum; use «Без звука» to mute. It affects the next manual/test/automatic bell,
not the one already playing. Browser volume belongs to your device. Successful
player completion does not prove that speakers/amplifier have power.

## 7. Upload melodies and check space

Bundled melodies cannot be replaced or deleted. New user MP3 files are limited to
**64 KiB (65,536 bytes) and 60 seconds**. Existing files and backups remain readable.

1. Disable automatic bells.
2. Open Melodies and choose Add melody or an existing melody to replace.
3. Select an MP3 and enter its title.
4. Click Upload or Upload and replace, confirm, and wait for the result.

Replacement preserves schedule references. The × button in the Delete column is
available only for unused user melodies. Remove references from schedules, manual
bell and pre-bell settings and save; the applied plan must also stop referencing it.
Unsaved changes block deletion. Bundled melodies have no delete button.
A previous copy may remain temporarily for recovery after deletion.

The list and free space refresh when opening the tab and after upload/deletion.
Refresh list retries after a connection error or changes from another browser.
The persistent storage bar is blue up to 75%, yellow above 75%, red above 90%.
Actual usage is separate from the required system reserve and temporary copy space.
Uploads are rejected when space is insufficient.

## 8. Timezone and verification

School timezone is first in Settings. For Yekaterinburg select Asia/Yekaterinburg and
«Применить часовой пояс», wait for confirmation and check the status panel. Copy the
browser zone only when it matches the school's location. The setting affects all
router applications, does not fix wrong date/minutes, and does not rewrite schedule
HH:MM entries. Recheck/confirm time and apply the plan separately after changing zone.

Trust confirmation does not set the clock. From 5.1.25, Settings → Date and time contains the complete workflow. Verify your computer/phone clock, choose Set time from browser, compare both dates and the difference, then confirm within one minute or cancel. The device reading in the confirmation is UTC to avoid mixing zones.

Setting time disables automatic bells and revokes prior trust. After verified readback, check local readings and confirm trust separately; enabling the plan remains a separate action. Playback blocks setting: wait for completion or stop sound. After an uncertain outcome, refresh readings; commands are never automatically replayed. NTP, services and timezone are unchanged; running NTP may subsequently adjust time. Pages only simulates the operation. This is neither an accuracy guarantee nor a retained date after power loss. Clock changes during drift measurements need separate agreement. This version has only been tested on the host.

Request verification, check the displayed date and confirm within 15 seconds; request
again if expired. Acknowledging intentional time earlier than the saved reference
requires careful review with the administrator; it does not repair the clock.

The gate may be disabled with confirmation, removing part of the wrong-date protection
without establishing accuracy. Toggling the gate or confirming time disables automatic
bells; enable separately. The approximate browser comparison within five seconds is
neither an accuracy certificate nor executor confirmation.

## 9. Backup, restore and transfer

Before major edits, upgrades or replacement: disable automatic bells, save the draft,
then Settings → Backup → «Скачать резервную копию». Verify the .sbb download and keep
dated copies on your computer.

The archive contains saved settings/schedules/year assignments, named user MP3,
Mute and volume. It excludes unsaved changes, automatic authorization, journal,
network/passwords, clocks/NTP and time trust. Bundled melodies belong to the package.
Timezone is checked on restore, not automatically installed from the archive.

Choose a trusted .sbb, click «Восстановить» and confirm. This replaces the whole saved
plan and user library; it is not a merge. After reload automatic bells remain off.
Review dates/schedules/files/volume/time before enabling.

A new device needs a compatible module, dependencies/bundled melodies and the same
school timezone. Independently verify its time and audio after import. Network and
credentials are not cloned. If the response is lost, «Проверить состояние» first;
use «Продолжить прерванное восстановление» when offered. Do not blindly repeat the
import or delete service files yourself.

## 10. After power loss

Do not assume correct time survives without RTC/external synchronization; the saved
calendar cannot tell the current date. After power-on inspect time/TZ, plan and media.
Confirm correct time, then explicitly enable the saved plan. Downtime bells are skipped.

With the gate enabled, even a same-boot service restart needs renewed confirmation.
With explicit bypass, a service restart in the same boot/TZ may resume future bells
of an enabled plan. A new boot or TZ mismatch still blocks it. Install/update/downgrade/
restore leave bells off. Unattended recovery after power loss is not yet promised.

## 11. Troubleshooting

| Symptom | Action |
| --- | --- |
| Save disabled | Wait for data and check there are edits; read the adjacent message |
| Enable disabled | Save/reconcile the draft; the public demo cannot enable a real router |
| Unknown Mute / disconnected | Wait for refresh, check router reachability and LuCI login; do not assume the last action succeeded |
| Busy | Wait, stop browser listening and reread state. Persistent busy needs administrator help, not lock deletion |
| Unknown outcome | Inspect state/list/title/revision before retrying upload, restore or ringing |
| No sound | Distinguish browser/router, check Mute, volume, speaker power/cable; for automatic bells also time, active plan/date and enabled row |
| No next bell | Check mode/today/active copy; countdown currently covers today only |
| Time verification needed | Review and confirm correct time, then enable separately |
| MP3 will not fit | Use a shorter/more compact MP3; allow for reserve and temporary copies |
| Bad backup/storage error | Keep bells off; check archive, compatibility and timezone; contact administrator for storage failures |
| Old UI after upgrade | Save needed edits, then Ctrl+F5; reload normally on mobile |

## 12. Journal and feedback

Use «Обновить журнал». Table times are UTC; rotation discards older entries, so this
is not permanent history. Full core system-event subscription is still pending.
Player success does not confirm audible sound.

In Feedback, search [schoolbell Issues](https://github.com/ViacheslavMezentsev/schoolbell/issues) or use the bug/feature forms, which also link to the RU/EN guides. Include the Schoolbell version,
equipment, steps, expected/actual result and exact error/operation ID. Attach a
screenshot or short log only after removing credentials/tokens/personal data.
GitHub submission requires Internet/account and is performed by you, not automatically.

## Auto bells in the header (5.1.3)

The button stops or resumes the **previously applied plan**, without applying saved or unsaved draft changes. First apply a checked, saved draft in Settings. With no applied plan the header takes you there. Stop retains that plan; missed bells are not replayed. It also stops an automatic bell already playing; manual sound is controlled separately by the sound-mute button. The worker stays running for status reporting.

The badge below the button is green for confirmed operation, yellow for off/muted/waiting, red for blocked/error/no connection. Text accompanies every color. A command acknowledgement is not a running-status confirmation. After a connection loss, wait for status rather than clicking repeatedly. Time checks and media admission still apply. Pages shows “Демо” and does not play scheduled audio.


The Journal shows 20 entries per page. Errors toggles red error records; Copy copies all loaded history regardless of filter or page. Timestamps use Shkolnik’s current timezone and UTC offset, not the phone’s timezone. History is bounded by 16 KiB and 7 days: old records are hidden on reads and physically pruned on append. This is not a guaranteed week-long archive: size rotation may remove records sooner. Incorrect clocks affect age calculation. The mute button keeps a compact label; color and icon indicate the enabled state.

## Temporary contention and backup time

Draft reads retry temporary contention a bounded number of times. After failure use Retry read; for an open draft use Compare with device to retain local edits. Saves never replay automatically. Do not remove locks manually.

A separately powered Modbus RTC board is proposed for future post-reboot time recovery; it is not implemented. Discovery does not establish trust. Freshness/health checks, explicit trusted-source selection and separate permission to resume the previously applied plan are required. A backup battery/UPS can power the device and speakers, but has finite capacity; it neither verifies clock accuracy nor replaces an RTC after full power loss. Power compatibility and runtime need validation on the actual setup.

## Moving selected calendar plans

5.1.21 adds [device .sbp export with all dependencies](../formats/PORTABLE_PLAN_EXPORT_DEVICE.en.md). On the destination, use [preview and add-only draft import](../formats/PORTABLE_PLAN_IMPORT.en.md). This does not replace a full .sbb backup or enable automatic bells.

In Schedules, Preview offers 🔊 browser playback and 🔔 Shkolnik speaker playback of the melody currently selected in that row, even before saving the draft. Speaker playback requires confirmation and respects mute; it does not enable automatic bells. Pages provides browser playback of bundled melodies only. The red × in Delete removes the draft row.

In 5.1.31, click each settings heading to expand its section. Enabled/pre-bell switches are off on the left and on on the right. The automatic bell icon shows the applied mode, not the unsaved draft.

## System

Expand System in Settings. The first click prepares confirmation; only Confirm
starts the operation. Cancel leaves settings unchanged.

- **Reboot device:** the interface becomes temporarily unavailable. Data is retained,
  automatic bells are disabled. Wait about a minute and reload the page.
- **Reset Schoolbell settings:** schedules and plans are removed; manual/pre-bell
  sounds return to the test melody, pre-bell to 2 minutes, volume to 100%, time
  checks on and automatic bells off. User melodies and the journal are retained.
  Network, OpenWrt password, clocks/NTP and timezone remain unchanged. Reload after
  success; unsaved edits in this browser are discarded and idle logout returns to 30 minutes.

If a response is lost, check state before repeating. Commands are never replayed
automatically. An interrupted reset can be completed by explicitly confirming
reset again. Both hardware operations are disabled in the demo.

In Melodies, + below the table opens the add form. The 🖉 button on a user melody opens replacement for that entry, retaining schedule references. Choose an MP3, review its title and confirm the upload. Bundled melodies cannot be replaced; deletion restrictions are unchanged.

To rename a user melody, select 🖉, edit the title and select ✓ Save title without choosing an MP3. Automatic bells must be off. The file and schedule references remain unchanged. To replace the audio, choose an MP3 and use the separate upload button.

Below Audio, the header shows the physical switch position and current device IP. Position updates on the next poll, usually within 15–16 seconds; it does not mean that the corresponding network profile is applied. The display does not change network settings.

The blue bar below the audio row shows saved volume, not signal level; mute does not change its fill.
