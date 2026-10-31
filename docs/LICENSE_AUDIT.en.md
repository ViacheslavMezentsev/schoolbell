# License and provenance audit

[Русский](LICENSE_AUDIT.md)

Date: 2026-10-31. Audit baseline: `47975263ce48b15c6f4c4378b14d51a8bba0165a`.
Inspected the local 5.1.28/1.0.0 bundle built from `5ab216e5f9e099fa12499b029f9c7c352eba2846`.
This records evidence and gaps; it neither grants a license nor completes distribution
compliance. Specification, runtime, IPK payload and stock audio remain unchanged.

## Sources and embedded materials

| Group | Evidence | Status |
| --- | --- | --- |
| Lua/C/JS, UI, packaging, tests and migrated documentation | core `243a7ccad6aeb2499d3efd5d0c4cef9e822d393e`; paths/hashes in [source map](source-map.json); adaptations in schoolbell history | No overall license in that core tree or current schoolbell root. Platform choice does not assign MIT/GPL |
| strict JSON | Same core revision, `pkg/usr/lib/modbus/json_strict.lua` → `vendor/modbus/json_strict.lua` | Provenance recorded; no explicit distribution grant in the file |
| Pages time zones | LuCI openwrt-19.07; URL/date/hash in `site/portable-zones.NOTICE` | NOTICE states Apache-2.0, text in `site/LUCI-LICENSE`; builder copies both. Mutable branch URL still needs a pinned revision and attribution review |
| Schoolbell-4 archive | schoolbell `c4bbecd1bd5136051cc12858801fb9bed7222cc2`, 20 hashed files | Immutable history, not a license grant for all contents |
| SDK, Lua headers, patches | URLs/hashes in `packaging/offline/toolchain-19.07.9.json` | Build-time inputs, not an SDK distributed in Git/the 35 IPKs; these archives are not complete corresponding sources for all dependencies |

## 33 third-party dependencies

The [complete version/license table](LICENSE_DEPENDENCIES.md) records actual IPK
control fields. All 33 hashes match the lock; 32 License fields match verbatim.
`luci-lib-jsonc` has no License field; the lock records `unspecified`.
[jsonc.c at 712bc8e](https://github.com/openwrt/luci/blob/712bc8e/libs/luci-lib-jsonc/src/jsonc.c)
contains Copyright 2015 Jo-Philipp Wich and Apache-2.0; the corresponding Makefile
also states Apache-2.0. Retrieved jsonc.c SHA-256:
`c884f135b9f214713d38c3fa087e9a412bbe09b5ea2f0f2b651970a4e67fa1a0`.
This supplements, rather than rewrites, binary metadata. Reproducing the exact binary
from this source was not established by this audit.

None of the 33 payloads contains separate files whose names include license/copying/
notice/copyright. This filename search does not prove absence of inline notices.
The bundle root has IPKs, READMEs, manifest, lock, check.sh and SHA256SUMS, but no
separate collection of license texts, attributions and corresponding sources.
Binary URLs and license labels alone do not satisfy all license conditions.
libc/kernel are firmware requirements, not extra bundle IPKs; review them separately
when distributing firmware. OEM firmware is outside this audit; a Pages link does
not authorize mirroring the OEM archive.

Before release, map each binary to exact sources, patches, configuration and build
recipes; collect license texts and notices. Establish and fulfill the applicable
GPL/LGPL source-delivery route and other terms; do not treat binary-feed URLs as
sufficient. Verify precise editions/exceptions, particularly `GPL-2`, `GPLv2`,
`LGPL-2.1` and GCC exception. Primary references:
[GPLv2 section 3](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html) and
[Apache-2.0 section 4](https://www.apache.org/licenses/LICENSE-2.0).
MIT/ISC/Zlib also require applicable original notices; a label is not a license text.

## Stock melodies and NOTICE

All six MP3s have original-commit and SHA-256 records in the
[manifest](../assets/melodies/manifest.json). On 2026-10-31 the owner stated that
0/1/2/3.mp3 were recorded from the discrete GPIO output (not a DAC) of the
Schoolbell-2 microcontroller and have not changed since. This is owner testimony;
original firmware, score data and independent comparison were not obtained.
The owner explicitly excluded 4.mp3 and test.mp3 from that provenance.

| Files | Known | Missing |
| --- | --- | --- |
| 0–3.mp3 | Schoolbell-2 output recordings, per owner | Composition/composer, score/firmware origin, arrangement/recording rights and distribution terms |
| 4.mp3 | Historical title «Усатый нянь», unchanged Git bytes | Recording source, authors, rights holders and terms |
| test.mp3 | Historical test file, unchanged Git bytes | Source, content/authorship, rights holder and terms |

melodies.json titles are historical labels, not verified composition identifications.
Do not infer public-domain status from «Бах» or «Князь Игорь». Timbre processing
alone does not resolve composition/recording provenance gaps.

The packaged NOTICE mainly describes test.mp3 and references a repository-only
`assets/melodies/manifest.json`; its installed location is
`/usr/share/modbus-schoolbell/media-manifest.json`. The word original is not proof
of authorship. It does not cover runtime/dependency licensing. The new root
[NOTICE](../NOTICE) records repository evidence and limitations; it is not automatically
shipped in IPK/Pages. The packaged NOTICE stays part of the verified 5.1.28 payload;
correcting it and distributing notices requires a subsequent packaging iteration.

## Open items before distribution

- L1: owner establishes authorship/rights and selects the own-code license and scope,
  separately from third-party components.
- L2: collect exact dependency sources/notices, resolve GPL/LGPL/GCC exception terms,
  and include compliance materials in release artifacts.
- L3: pin the time-zone source revision and review attribution in generated Pages.
- L4: establish rights/provenance for each recording and composition, especially 4/test;
  agree replacement or exclusion where evidence is missing.
- L5: correct packaged NOTICE and notice delivery in IPK/Pages/bundle; inspect actual artifacts.

The audit is complete; these closure items remain open. No new license is assigned.
Local audio trials are documented [separately](AUDIO_EXPERIMENT.en.md), excluded
from stock media, and do not constitute hardware acceptance.

Audit validation: full `make all` — PASS in WSL; `git diff --check` — PASS. Rebuilt IPK metadata, control and payload match the accepted 5.1.28 candidate. All stock MP3 hashes are unchanged. These are host checks, not hardware acceptance.
