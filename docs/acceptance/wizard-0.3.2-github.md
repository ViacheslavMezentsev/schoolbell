# Скачанный комплект 0.3.2 / 5.1.127 — проверка перед выпуском

Дата: 26.11.2026. Только локальные проверки, без операций на роутерах.

## Происхождение

- Коммит сборки: `9aa047b5003e67445c242821b2d3d76fa91dcd9f`.
- [Actions 45802082597](https://github.com/ViacheslavMezentsev/schoolbell/actions/runs/45802082597): success; CI того же HEAD — success.
- Артефакт: `schoolbell-v5.1.127-wizard-v0.3.2-windows-x86_64`, ID 15107533055.
- Digest внешнего архива: `13077f33ed5728bfa01d02d59dc9747e81944538eef33bf8d05f07f7a74722ac` — совпал с GitHub API.

## Результаты

| Проверка | Результат |
| --- | --- |
| SHA256SUMS и все перечисленные файлы | PASS, исходные скачанные байты сохранены |
| Внутренние суммы обоих ZIP, версия и коммит manifest | PASS, 0.3.2 / 5.1.127, чистая сборка |
| Отдельный IPK против пакета внутри ZIP | PASS |
| Квитанция EXE, UCRT64, системные DLL, встроенные образы | PASS; распакованный EXE выполнил `--check-firmware` |
| Локальная проверка ZIP самим скачанным zip_worker | PASS, версия 5.1.127 и совместимость с мастером 0.3.2 |
| Python и worker-импорты из распакованной поставки | PASS без MSYS2 в PATH |
| Начальный запуск GUI | Процесс достиг input-idle; это не визуальная проверка всех вкладок |
| Подпись скачанного SHA256SUMS существующим ключом | PASS, SSHSIG namespace schoolbell-release; повторная проверка подписи и всех файлов PASS, включая команды Windows из VERIFY.md |

Окончания строк материалов Windows — CRLF; их текст совпадает с репозиторием. Файлы не нормализовались и не перепаковывались. Подпись добавлена отдельно; внешняя ZIP-обёртка Actions не публикуется вместо вложенных assets.

## Контрольные суммы

| Файл | SHA-256 |
| --- | --- |
| schoolbell-setup-wizard-v0.3.2-windows-x86_64.zip | `73126e4d977f3bee371ba5f2f3b27676f80b7f94c24f1d7a1283f6b5256409fd` |
| schoolbell-v5.1.127-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip | `8b0805b0da2af7f6a8df579a055eaa61a9bf87761358f4afd4dea3574a85d05d` |
| modbus-schoolbell_5.1.127_all.ipk | `6b46f1824c4cfad0163a8f22436bf9ff007cd02943e7aaa3f6aafd6b1c38a658` |
| SHA256SUMS | `024a3e4b87b4643629fc3e1e7c1d62c7717ea7a1328fad90df771b9e9ccbb213` |

Отпечаток ключа: `SHA256:ekq3AjehBO2o+e63uOrpGLLKjmHc7kjnPZhIkgzLT88`. [Проверка пользователем](../../packaging/release/VERIFY.md).

## Границы

Это не аппаратная приёмка 0.3.2 и не проверка полностью чистой Windows. Работоспособность трёх маршрутов на устройстве относится к [скачанной паре 0.3.1](wizard-0.3.1-github.md). Authenticode отсутствует. Публикация и тег выполняются отдельно владельцем; подписанные файлы сами по себе не означают опубликованный выпуск.

<details>
<summary>English</summary>

The downloaded pair from successful run 45802082597, commit 9aa047b5003e67445c242821b2d3d76fa91dcd9f, passed the GitHub artifact digest, outer/inner checksum checks, clean manifest provenance and standalone-IPK comparison. The extracted UCRT64 executable passed embedded firmware checks and reached GUI input-idle; bundled Python imported its workers without MSYS2 on PATH. No full visual review was performed.

The original downloaded SHA256SUMS was signed using the existing project Ed25519 key; signature and every listed file were verified. Windows CRLF bytes were preserved. Hashes are listed above. This is not hardware or clean-Windows acceptance of 0.3.2; prior three-route hardware evidence remains scoped to 0.3.1. No router operations, tag or publication took place.

</details>
