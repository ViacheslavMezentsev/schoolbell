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

## Instrumental resynthesis — 2026-10-31

At the owner's next request, three entirely synthesized variants were produced,
without mixing in the original recording or third-party samples. A shared score
was recovered from original 0.mp3 to avoid bias from earlier filtering.
16 notes: Eb5, E4, F4, Ab4, C5, Eb5, F5, F4, G4, Ab4, C5, Eb5, Ab5, F5, G5, Eb5.
This is automatic transcription, not an authenticated composer score.

| Variant | Synthesis and palette | LUFS-I | dBTP |
| --- | --- | ---: | ---: |
| 01-vibraphone | Synthetic vibraphone: decaying harmonics and subtle tremolo | -8.45 | -2.67 |
| 02-electric-piano | Synthetic electric piano: harmonic FM, soft attack, quiet lower octave | -8.45 | -1.51 |
| 03-horn-flute | Synthetic horn/flute: gradually developing harmonics and upper octave | -8.45 | -2.51 |

These are timbre models, not acoustic instrument recordings. Measured lead frequencies
are retained; additional octaves do not change the note sequence. All variants share
one note/timing list. Short 3–8 ms attacks and 12 ms releases preserve rests without
reverb tails. The final phrase fades. The source waveform is not used for synthesis.

Decoded final MP3 checks: all 16 lead pitches match MIDI notes; maximum measured
lead-frequency deviation from the source is <0.73 cents (100 cents = one semitone).
Silence-separated onsets differ by at most 1.66 ms at the envelope threshold;
the two near-legato transitions are independently checked by spectral pitch changes
(maximum difference 4.36 ms).
Each decoded file has 455040 samples at 44.1 kHz (10.318367 s), matching the original.
Final MP3 loudness is -8.45 LUFS-I, with no clipping. These are algorithmic measurements,
not listening-comfort evaluation or school PA audibility verification.

Local extract-notes.py, synthesize.py, validate.py, notes.json, results.json,
validation.json, MP3/WAV and time-reference.mid are preserved in ignored
`tests/manual/03-instrumental-audio/`; conditions/HISTORY in
`docs/research/03-instrumental-audio/`. MIDI retains note timing for further arranging;
JSON preserves measured frequencies, whereas MIDI rounds to semitone pitches.
Stock media, package payload, specification and devices remain unchanged.

This iteration: full `make all` — PASS; `git diff --check` — PASS.
Rebuilt IPK contents match accepted 5.1.28; stock MP3s are unchanged.

## Bright timbres: electric guitar and harmonica — 2026-10-31

The owner found the previous instruments too muffled. The new reference is 03-clear
from the first set. Two synthetic models were prepared:

- Electric guitar: plucked-string harmonics, overdrive, 12 ms doubling and 62 ms slap.
  Repeats are bounded by each note to preserve rests.
- Harmonica: harmonic-rich free-reed timbre and subtle tremolo.

Four-times oversampled synthesis followed by antialiasing downsampling, upper-mid
presence EQ, amplifier saturation and a limiter without time shift. No external
samples or original waveform are mixed in. The previous shared score is retained.
These are instrument models, not acoustic recordings.

| File | LUFS-I | dBTP | Energy 1.5–5 kHz, % of 0.2–8 kHz |
| --- | ---: | ---: | ---: |
| 03-clear reference | -8.45 | -0.97 | 9.88 |
| Previous horn/flute | -8.45 | -2.51 | 5.65 |
| Electric guitar | -8.45 | -2.76 | 10.05 |
| Harmonica | -8.44 | -3.20 | 10.03 |

Welch spectrum, 4096-sample window at 44.1 kHz, measured on decoded MP3s.
This is a measurable brightness reference, not proof of subjective clarity or PA
intelligibility. All 16 lead notes match; pitch deviation <1.46 cents;
silence-separated onset deviation <1.91 ms; both legato transitions checked separately.
Each file has 455040 decoded samples, matching the original. Final MP3s do not clip.

Scripts, score, results, MP3/WAV and MIDI remain locally ignored under
`tests/manual/04-bright-instruments/`; conditions/HISTORY under `docs/research/04-bright-instruments/`.
Initial gain-adjusted drafts overloaded; revised saturation/limiting corrected peaks
and final files were remeasured. Stock MP3s, package, devices and sound settings
remain unchanged. Listening evaluation is left to the owner.

Full `make all` and `git diff --check` for this iteration — PASS. Rebuilt IPK
control/metadata/payload match accepted 5.1.28. These are host checks.
