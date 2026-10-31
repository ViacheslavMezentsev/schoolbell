# Schoolbell licensing

[Русский](LICENSING.md)

By the owner's decision on 2026-10-31, schoolbell's own code and associated
documentation are licensed under [MIT](../LICENSE).
Copyright (c) 2026 Viacheslav Mezentsev. The standard
[MIT text](https://opensource.org/license/mit) is used without changing its terms.
This document identifies the covered materials; it does not add MIT restrictions.
[NOTICE](../NOTICE) records provenance and exclusions.

## Scope

MIT covers the project's own materials in the current schoolbell tree:

- `src/`, `ui/`, and own code/design in `site/`.
- Scripts, tests and own build/packaging, CI and project configuration.
- Own documentation and metadata, including materials migrated from core.
- `vendor/modbus/json_strict.lua`: the project author's own strict JSON decoder,
  migrated from core. See [vendor](../vendor/README.md) and the
  [source map](source-map.json).

The exclusions below and explicit third-party notices apply. This decision concerns
copies of own code in schoolbell; it does not modify the sibling core repository,
pinned historical snapshots or third-party terms. Provenance hashes are retained.
The license does not attribute third-party materials to the project author.

## Exclusions

| Materials | Status |
| --- | --- |
| All audio files and underlying compositions, including `assets/melodies/*.mp3` and packaging/Pages copies | Outside this MIT grant; making a recording of an existing tune does not establish composition rights |
| All of `docs/archive/` | Historical archive excluded; files and manifest unchanged |
| `site/portable-zones.json`, LuCI source data and associated notices | Separate Apache-2.0 terms; see `site/portable-zones.NOTICE` and `site/LUCI-LICENSE` |
| Third-party libraries, OpenWrt packages, toolchain/SDK, firmware and other external materials | Their own licenses; see [dependency table](LICENSE_DEPENDENCIES.md) |
| Other materials bearing explicit third-party notices | Retain their stated terms |

Metadata (such as a manifest) does not grant rights to the audio file or composition.
Per owner testimony, 0–3.mp3 are his recordings of known melodies from Schoolbell-2's
output; 4.mp3 is an excerpt from the film «Усатый нянь». This clarification identifies
the reported source of 4.mp3, not rights to the film, composition or recording.
test.mp3 provenance remains unknown. See the [audit](LICENSE_AUDIT.en.md).

## Distribution

When conveying own code or substantial portions, retain the copyright notice and
full MIT text. Excluded materials follow their separate terms. NOTICE helps identify
components, but does not replace LICENSE.

This iteration licenses the source repository. The verified 5.1.28 payload, IPK
version and archive are unchanged; new LICENSE/NOTICE files are not automatically
included in the old IPK. Delivery of current licenses/notices in IPK, native package,
Pages and offline bundle remains L5 before distributing new artifacts. Audit L2–L4
also remain open. Runtime requirements are unchanged.
