# Schoolbell player adapter contract

[Русский](PLAYER_ADAPTER.md) · [Specification 1.8](../requirements/TECHNICAL_SPECIFICATION.md)

The contract is accepted; the system adapter is not implemented. This note does
not change the [isolated queue API](PLAYBACK_QUEUE.en.md). Normative references:
3.2.3, 3.5.2/3.5.7–3.5.9 and 3.6.1–3.6.10; TC-43–49 are planned.

## Process and outcome

One schoolbell owner manages the queue and child processes for a resource.
The first backend is madplay with `--no-tty-control -a 0 -R 48000 -o /dev/dsp`.
Use a trusted executable and separate arguments, never a shell command built
from user strings. This describes a profile, not a command to run a sound test.

| Phase | Meaning |
| --- | --- |
| Admitted | Queued, with a specific media revision retained |
| launching | Launch permitted, confirmation pending, resource occupied |
| Launch confirmed | Program started; audibility not confirmed |
| Completed | Own child's status obtained: ordinary exit code or signal |
| Unknown | Resource and file retained; automatic replay prohibited |

A PID does not prove successful exec. Launch confirmation is asynchronous;
waitpid with WNOHANG observes completion without waiting in the worker loop.
Fast exit must not be lost between launch confirmation and observation.
A foreign/missing PID or log line cannot prove completion of our attempt.
Exit 0 means successful program termination, not audible sound.

After file preparation, TTL and applicable UTC are rechecked immediately before
launch authorization. Preparation never extends TTL. Authorization is the
deadline boundary, not exact exec/audible time; OS delays require measurements.
Expiry does not interrupt an already authorized launch. Active stop remains
outside the first version.

Launch-confirmation timeout is separate from request TTL. Expiry means unknown,
not resource release or automatic retry. stdout/stderr storage and work per pass
are bounded; a full output channel must not block the player.

## Media ownership

Admission confirmation requires retaining a specific existing media revision.
Missing revision means rejection, without substituting another one. Admission
failure releases temporary retention. Replacement creates a new immutable
revision; pending and active requests keep the previous one. Launch receives a
validated file protected against substitution.

The request releases its reference after cancellation/expiry, proven rejection
with no process, or confirmed completion. A terminal receipt may remain in
memory without retaining media. Unknown outcomes retain the file. Plans, other
requests, backups and rollback hold independent references: releasing one does
not authorize deleting the revision.

Open-file handoff through stdin is accepted in revision 1.9 subject to madplay
verification. Storage format and atomic media publication remain undecided.
The current Lua model's media_revision string does not provide these guarantees.

## Failure and next stage

After an owner crash, a new executor must not start sound until the old player
has been excluded. A PID file alone is insufficient. A lost result does not
prove that playback never happened; unknown requests are not automatically
replayed. This contract adds no durable queue, exactly-once, stop or paused
policy after reboot. Uncertainty preserves the block and diagnostics.

Mechanisms and API shape are accepted in specification 1.9: [System API](PLAYER_SYSTEM_API.en.md). Implementation is absent; fields, executable observation and budgets are defined in [revision 1.10](PLAYER_RESULTS.en.md); actual madplay checks remain pending.

Planned host tests: argv/exec/fast exit (TC-43), deadlines (TC-44), exit/signal/
PID (TC-45), lost confirmation (TC-46), media replacement/deletion (TC-47),
output overflow (TC-48), owner crash/replacement (TC-49). A substitute process
uses no audio device. Actual sound and target validation remain separate.
