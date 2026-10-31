# Schoolbell 5.0.31 startup audit

[Русский](STARTUP_AUDIT.md) · [Acceptance programme](../acceptance/ACCEPTANCE.en.md)

2026-10-25. AC-06, additional host coverage for TC-132; no application contract or
IPK version change. The actual schoolbell-auto worker runs with injected clocks,
storage, boot/TZ, mailbox, journal and player. This does not test physical cold boot,
procd, flash or sound. AC-06 as a whole remains open.

| Initial state | Verified behavior |
| --- | --- |
| Service restart, same boot/TZ, enforced gate, saved reference | Reference does not transfer trust between instances; clock_untrusted, no new claims/reference writes/sound |
| Clock behind reference | before_reference blocks playback |
| Reference unavailable | reference_unavailable blocks playback |
| New boot ID, including explicit bypass | confirm_clock; old plan is not authorized |
| Stored TZ mismatch, including bypass | timezone_changed, no sound |
| Confirmed time but plan boot/TZ mismatch | Confirmation does not replace explicit plan application |
| Disabled plan with confirmed time | Plan remains disabled |
| Invalid calendar date with bypass | clock_invalid, no sound |
| Same-boot/TZ restart with explicit bypass and enabled plan | Future bells may resume; this is neither cold boot nor import/update |
| Durable watermark ahead of current time | backward_hold; no old bell replay |

A live TZ change causes process exit so procd can restart with a new libc TZ.
This is code inspection, not a verified hardware respawn/UI journey. Init calls
schoolbell-package initialize; absence of package.pending and successful process
startup do not mean automatic bells are authorized. Existing gate/trust/command
tests also cover native/policy failures, stale tokens and reference write errors.

Eleven new scenarios extend the previous seventeen in test_automatic_service.lua.
They test the worker, not HTTP or physical write durability. Time confirmation and
plan application remain separate. Instructions must not claim that bypass authorizes
bells after reboot or that every service restart unconditionally disables a plan.

The independent test_automatic_oracle.lua uses a literal list of 21 moments:
15 main bells and six preliminary bells two minutes earlier, plus a disabled row.
It checks fixed mode on two dates, annual mode on an assigned date, quiet neighbors
and no following-year repeat. Real automatic.events/step run second by second;
the expected list is not produced by the preview being tested. This is partial
AC-03/TC-31 evidence, not audible output, a full-year run or every pre interval.

Next: after clock measurement completes and separate authorization, test cold boot
with automatic bells off, retained data, blocking and confirmation without activation.
This branch authorizes no sound, power interruption or clock change.
