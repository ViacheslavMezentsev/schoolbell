# Original schoolbell melodies

[Русский](README.md)

Copied unchanged at the owner's request from
[schoolbell](https://github.com/ViacheslavMezentsev/schoolbell/tree/c4bbecd1bd5136051cc12858801fb9bed7222cc2).
The source revision and checksums are recorded in [manifest.json](manifest.json).
Upstream has no explicit license; this import assigns no new license and makes
no audio authorship claim. `melodies.json` is preserved unchanged.

| File | Original title | Duration, s (ffprobe) | Bytes |
| --- | --- | ---: | ---: |
| 0.mp3 | [Короткая] Время | 10.318 | 41273 |
| 1.mp3 | Шутка Баха | 15.830 | 63321 |
| 2.mp3 | Гостья из XXI | 17.476 | 69904 |
| 3.mp3 | Князь Игорь | 17.006 | 68023 |
| 4.mp3 | Усатый нянь | 20.592 | 82368 |
| test.mp3 | Separate test sound, not in melodies.json | 3.276 | 13104 |

The durations above are historical measurements. The current complete 5.1.28
IPK and Pages include all six MP3s; the old minimal pkg-schoolbell description
with test.mp3 alone no longer describes this build. Total original MP3 size: 337993 bytes.

Per owner testimony on 2026-10-31, 0–3.mp3 were recorded from the discrete output
of the Schoolbell-2 microcontroller and have not changed since. This establishes
reported recording provenance, not composition authorship. 4.mp3 and test.mp3
were explicitly excluded; their recording sources remain unknown.
See the [audit](../../docs/LICENSE_AUDIT.en.md) for evidence and gaps.
[Audio trials](../../docs/AUDIO_EXPERIMENT.en.md) do not replace stock files.

Source and IPK checks: `make all` (host-only).
