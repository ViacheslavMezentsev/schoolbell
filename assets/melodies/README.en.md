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

All six MP3s decoded locally with FFmpeg without errors or audio output.
Durations are ffprobe estimates; router playback has not been tested.
The shortest file, `test.mp3`, is bundled in `pkg-schoolbell`; the other files
stay here and do not occupy storage in the installed minimal package.
The six source MP3s total 337993 bytes.

Source and IPK verification: `scripts/verify-schoolbell.py`, invoked by
`make all`; Python 3.8+ is required on the build host, not on the router.
