# Общие зависимости / Shared dependencies

`modbus/json_strict.lua` перенесён из openwrt-modbus-core, commit
243a7ccad6aeb2499d3efd5d0c4cef9e822d393e, путь pkg/usr/lib/modbus/json_strict.lua.
Хеш и исходный путь — в docs/source-map.json. Installed module name сохранён.
Нет зависимости от соседней рабочей копии. Исходный коммит добавления декодера
в core — e2c5258 (автор ViacheslavMezentsev). По решению владельца текущая копия
собственного декодера в schoolbell включена в [MIT](../LICENSE);
[область действия](../docs/LICENSING.md). Исторический снимок core не изменён.

The strict JSON decoder comes from the pinned core commit and path above;
docs/source-map.json records provenance. No sibling checkout is required.
The decoder was introduced in core by ViacheslavMezentsev in e2c5258. The owner
licenses this own-code copy in schoolbell under [MIT](../LICENSE);
see [scope](../docs/LICENSING.en.md). The historical core snapshot is unchanged.
