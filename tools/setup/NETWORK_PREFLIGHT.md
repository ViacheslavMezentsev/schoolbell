# Предварительный план сети / Network preflight

`network_plan.py` — локальная основа будущего GUI-помощника. Он читает JSON-снимок,
не собирает его сам и не меняет сеть. Администратор, Интернет и роутер не нужны.
Это не замена `Setup.cmd -DryRun` и не готовый маршрут прошивки GUI.
В маршрутах GUI кнопка ↻ читает список адаптеров Windows. После выбора и
подтверждения модели кнопка «Проверить без изменения сети» собирает новый снимок
и показывает результат. Профиль или адаптер изменились — прежний итог скрывается.

```sh
python3 tools/setup/network_plan.py --snapshot snapshot.json --adapter-guid 11111111-1111-4111-8111-111111111111 --profile openwrt --model "MR3020 EU V3.30"
```

Для OEM используйте `--profile factory`. Профили и хеши взяты из существующего
`firmware.py`; образ здесь не читается и не считается проверенным.
Код выхода 0 означает только отсутствие препятствий в переданном снимке;
2 — обнаружены препятствия. Поля `ready` и `image.verified` всегда false.

Минимальный искусственный снимок (не данные реального адаптера):

```json
{
  "schema": 1,
  "pending_restore": false,
  "adapters": [{
    "guid": "11111111-1111-4111-8111-111111111111",
    "index": 7,
    "name": "USB Ethernet",
    "physical": true,
    "usb": true,
    "dhcp": true,
    "link_up": true,
    "media": "ethernet",
    "addresses": []
  }],
  "routes": [],
  "udp_ports": []
}
```

Адреса: `{"ip":"192.0.2.7","origin":"dhcp"}`; origin допускает dhcp/manual/well-known.
Маршруты: `{"prefix":"192.168.1.0/24","next_hop":"192.0.2.1","index":9}`.
Снимок должен включать все интерфейсы, IPv4-маршруты и занятые UDP-порты.
Отсутствующий линк, ручные адреса, не USB/не физический Ethernet, незавершённое
восстановление, занятые адреса профиля и UDP 69/1069 блокируют допуск.
Широкие маршруты через шлюз требуют повторной проверки, а не отключения VPN.

План содержит GUID адаптера, SHA256 снимка, образ, последовательность этапов и
границы очистки: только собственные временные адреса и правило firewall.
Он не является разрешением выполнить эти изменения. Будущий привилегированный
helper обязан заново собрать состояние, проверить образ, адаптер и прямой маршрут,
сохранить конфигурацию до изменений и обеспечить восстановление после сбоя.
Сборщик Windows-снимка и GUI-проверка подключены. Используются только локальные
Get-Net*/Get-CimInstance и чтение признака SchoolbellSetup/network.json. Снимок
не сохраняется мастером на диск. UAC/helper, встроенный OEM и аппаратная приёмка впереди.

## English

The pure planner consumes a JSON snapshot and never collects host data, changes
network settings or contacts a device. The command above supports `openwrt` and
`factory`; profile hashes come from the existing firmware module. Exit 0 means
only that the supplied snapshot has no blockers, not READY or permission to flash.
Image bytes are not verified here. `ready` and `image.verified` stay false.

Provide all adapters, IPv4 routes and occupied UDP ports using the schema above.
The selected GUID must identify one physical USB Ethernet adapter with DHCP.
A valid adapter may have no IP address. Link loss, manual/reserved addresses,
conflicting routes, occupied TFTP ports and pending restoration block the plan.
Gateway fallback routes require a later direct-route check; VPN is not rejected
as a category. The input is not mutated. Snapshot hashes detect changes, not
malicious input or authenticity.

The plan records the selected adapter, pinned image metadata, steps and cleanup
scope. A future privileged helper must collect and revalidate live state, verify
image bytes and direct routing, save the original configuration and restore only
its own changes. Windows collection and GUI preflight are connected: refresh adapters, select one,
confirm the exact label, then check a fresh snapshot. Local Get-Net*/CIM queries
and the existing restoration-state file are read without network probes or writes.
The wizard does not persist the inventory. UAC, embedded OEM and hardware
acceptance remain pending.
