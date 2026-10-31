# Playback reliability: open defect

[Русский](PLAYBACK_RELIABILITY.md)

2026-10-31, candidate 5.1.28. Intermittent manual playback failure is reproduced
on the development bench. Operational bell reliability is not accepted; the owner
has deferred licensing work.

## Actual route

LuCI `manual()` / `play()` call installed `schoolbell.sound_test.run(system(media))`.
The automatic executor uses the same adapter. It starts a separate `madplay`
process using OSS `/dev/dsp`, 48000 Hz and saved gain. Isolated native player/queue
host tests do not validate this deployed path.

The controller records `play_failed` for every `ok=false`, including stops caused
by sound-control changes. The journal stores action, source, level, sequence and
time only, losing reason and exit status. madplay stderr is sent to `/dev/null`.
Historical failures cannot be precisely reclassified retroactively.

## Device trial

The owner authorized consecutive playback, then requested minimum volume. Gain
was set to -60 dB; automatic playback remained disabled. The trial calls the same
installed adapter directly, without browser, HTTP or controller audit writes.
Attempts are separated by 0.5 s and wait for the prior child and lock release.

Measured series: **100 attempts, 96 exits with code 0, 4 failures with code 4**
(attempts 7, 24, 53, 100), over 411 seconds. Four new URB -27 error groups appeared
in the kernel log with matching intervals between failures. printk and /proc/uptime
show an approximately two-second offset; exact timestamp equality is not claimed.
Gain was reduced during the series; failures continued at -60 dB. This is not
a uniform-gain sample or acoustic acceptance.

USB-audio `cannot submit urb ... error -27` messages predate the trial. The trial
also produced `URB ... submitted while active` and `-16`. This is evidence of a
USB-audio path failure, not yet proof of a specific device, hub, power or kernel
fix. EFBIG is described in the [kernel documentation](https://www.kernel.org/doc/html/v4.18/driver-api/usb/error-codes.html).
Do not hide failures, equate exit zero with audible output, or blindly replay an
attempt whose audible outcome is unknown.

The initial instrumentation attempt failed to serialize fractional timing after
playback; its outcome is excluded from the measured series, not counted as PASS.
Timing was changed to integer milliseconds. Raw logs, bench identifiers and
research scripts remain local and excluded from Git.

## Work before closing the defect

- Retain bounded reason, exit/signal and manual/automatic context in the journal;
  distinguish user stops from actual failures.
- Capture bounded failure stderr and correlate kernel monotonic time. Isolate OSS,
  USB driver and connection topology by changing one factor at a time.
- Verify the correction with repeated launches and a long-running schedule:
  expected events, actual launch and audible output, day boundaries, idle periods,
  manual actions, audio device loss/recovery. A short 100-launch series is not
  endurance acceptance.
- Check skips after slow operations: the executor checks the admission deadline
  after durable claim, journal writes and media resolution. Do not widen the
  deadline or replay missed events without reviewing requirements.

This iteration does not replace runtime, packages or firmware and does not claim
the failure fixed. Existing requirements and TC identifiers remain unchanged.

Documentation iteration checks: full `make all`, local links and
`git diff --check` — PASS. This does not override the four device-trial failures.

## Replacement card and direct connection — 2026-10-31

Replacing AB13X with GeneralPlus while retaining the hub did not remove the defect:
six normal completions, then attempt 7 failed (exit=4) with new URB -27 errors.
The series stopped on its first failure. A separate stderr-preserving series had
13 completions followed by `unavailable` when the owner physically unplugged the
card; this is not a spontaneous failure or completed acceptance.

The owner connected GeneralPlus directly. `/proc/asound` changed from EHCI through
the hub to direct OHCI. The installed Lua adapter matches repository bytes; madplay,
the test MP3 and 48000 Hz output are unchanged. The new series checks -60 dB and
disabled automatic playback before each attempt, without hidden retries.

**Direct connection: 100 consecutive successful launches, 0 failures**, in 417.93 s.
Every attempt returned `completed`, `waitpid: exited`, exit=0, without hidden retries.
No new kernel messages appeared. At completion no madplay process or playback lock
remained; -60 dB was retained and automatic playback was disabled. The same test MP3
was used; acoustic output was not measured. Installed code, packages, drivers and
firmware were unchanged. Direct connection is a verified workaround for this setup;
the requested 100-success criterion is met. `make all` and document checks — PASS.

This comparison localizes the issue to the USB topology and controller/driver
combination; it does not distinguish the particular hub, power/cable or EHCI split
transactions. Replacing the card alone was insufficient. Direct connection does
not validate the original hub or replace schedule endurance acceptance. If a hub
is required, its compatibility needs a separate trial; this experiment does not
claim a software USB-driver fix.
