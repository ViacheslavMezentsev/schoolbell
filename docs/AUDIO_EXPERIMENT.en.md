# 0.mp3 timbre trials — 2026-10-31

[Русский](AUDIO_EXPERIMENT.md)

Goal: compare three less harsh treatments of the same «[Короткая] Время» recording.
Source: `assets/melodies/0.mp3`, SHA-256
`3821035954269a1ba9bacd0a5ab528c61817acb6d623de835f1936ebaebc7d5c`.
These are filtering/loudness treatments, not newly instrumented arrangements.
No note recognition/resynthesis, pitch shifting or time stretching was performed.
Filters affect spectrum/attack; loudnorm may limit peaks.

| Variant | Treatment | MP3 LUFS-I | True peak dBTP |
| --- | --- | ---: | ---: |
| Original | MP3 22.05 kHz, mono, 32 kbit/s | -8.45 | -0.96 |
| 01-warm | HP 120 Hz, LP 1500 Hz, 3 kHz attenuation | -8.46 | -1.02 |
| 02-rounded | HP 180 Hz, LP 2600 Hz, 1100 Hz boost, 3300 Hz cut | -8.45 | -0.97 |
| 03-clear | HP 250 Hz, LP 4200 Hz, 1900 Hz boost, 3600 Hz cut | -8.45 | -0.97 |

Two-pole LP; bell EQ: 01 — 3000 Hz/Q0.8/-6 dB;
02 — 1100 Hz/Q0.8/+3 dB and 3300 Hz/Q1/-7 dB;
03 — 1900 Hz/Q1/+2 dB and 3600 Hz/Q1/-5 dB.
Pipeline: EQ → loudnorm measurement → I=-8.45, TP=-1.3, LRA=11 normalization
with measured parameters → 24-bit/44.1 kHz mono WAV → 192 kbit/s MP3 → measure →
gain correction to source LUFS → re-encode and verify. Values above describe final
MP3s; intermediate WAV levels differ because of encoding. FFmpeg 4.2.2-static,
provided locally by imageio-ffmpeg 0.5.1.

Verified decoding, final LUFS/true peak, no samples exceeding 0 dBFS, equal decoded
signal length and unchanged original MP3 hashes. No listening assessment or PA
hardware test was performed. Equal LUFS does not establish equal SPL/intelligibility
at distant loudspeakers. Removing high harmonics can reduce both harshness and
perceived reach; 03 retains more upper midrange, 01 attenuates it more. Comfort
requires listener evaluation.

Reproduction script, measurements and audio remain locally ignored under
`tests/manual/02-license-audio/`; conditions/history under `docs/research/02-license-audio/`.
Stock files are unchanged; variants are not included in IPK or Pages. Composition
rights/provenance remain open in the [audit](LICENSE_AUDIT.en.md). A future instrument
resynthesis experiment could recover notes/envelopes, with separate melody-fidelity checks.
