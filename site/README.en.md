# Shkolnik Pages

[Русский](README.md) · [Document map](../docs/README.en.md)

`make check-site` builds `out/site` and checks routes, shared assets, provenance,
localStorage migration and `.sbp` export/import preview. `/schoolbell/` opens the
bell UI directly. Guides, training (RU/EN) and `devices/` are separate pages;
`ranges.html` returns to the calendar editor. UI comes from `ui/root`; the demo
API never contacts hardware. Six built-in MP3s play in the browser. User media
and real device commands are unavailable. Issue forms target schoolbell.

## Drafts

The new key is `schoolbell-public-demo-v1`. The old key
`openwrt-schoolbell-public-demo-v1` is never changed or deleted. If no new key
exists and the old draft validates, demo details offer an explicit copy button.
Confirmation is required; data is retained and simulated automatic bells are
disabled. Existing new data and unsaved edits prevent overwriting. Reset affects
only the new key. Storage failures preserve the old copy; use `.sbp` export from
the previous page instead. Cross-path transfer requires the same origin;
different domains require manual `.sbp` transfer.

## Owner publication

After merge and successful CI, select GitHub Actions in Settings → Pages and
manually run **GitHub Pages** from `main`. Push does not deploy. Build SHA/date
appear in Feedback and `build-info.json`; dirty local builds are labelled.

Guide/device pages retain historical source-bench information and carry a
migration-draft notice. They are not new hardware acceptance. Firmware, backups
and private data are excluded. No publication, old-site redirects or device
changes were performed in this iteration.
