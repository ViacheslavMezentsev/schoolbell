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

## Проверка вложений черновика и сокращение набора

26.11.2026: GitHub Release ID 459320346 содержит тег v5.1.127, но остаётся draft=true; публичной публикации не было. Аннотированный тег указывает на коммит сборки 9aa047b. Все десять исходных вложений скачаны через авторизованный API, их digest и подпись совпали.

По запросу владельца описание сокращено, состав уменьшен до двух исходных ZIP и нового SHA256SUMS с подписью. IPK и JSON не удалялись из самих архивов; ключ и инструкции доступны по ссылкам на коммит. После изменения все четыре файла повторно скачаны из Release, подпись и суммы — PASS. SHA256SUMS публичного набора: `fc7ccf8cd46a5b1ae51bb60706194c4cb265a9e267e49813b5bb28cc2497b1a6`; подпись: `9ade499929afa4a1adca5170526b7c72053ce90367f389bdd70f5564860c355d`. Хеши ZIP выше не изменились. Это проверка доступных владельцу вложений черновика, не публичного скачивания. Стенды не затрагивались.

Release ID 459320346 remains a draft for tag v5.1.127. The ten original assets were downloaded and verified. At the owner's request the draft was simplified to two unchanged ZIPs and a newly signed checksum list; all four assets were downloaded again and verified. Public-key/instruction links point to the build revision. No public-download or new hardware acceptance is claimed.

## Публичное скачивание после публикации — 26.11.2026

[Release v5.1.127](https://github.com/ViacheslavMezentsev/schoolbell/releases/tag/v5.1.127) проверен отдельными HTTP-запросами без токена и без авторизации GitHub CLI. API: draft=false, prerelease=true, tag_name=v5.1.127; публичная страница — HTTP 200. Четыре вложения заново скачаны по публичным browser_download_url в новый локальный каталог.

| Файл | SHA-256 публичного скачивания |
| --- | --- |
| schoolbell-setup-wizard-v0.3.2-windows-x86_64.zip | `73126e4d977f3bee371ba5f2f3b27676f80b7f94c24f1d7a1283f6b5256409fd` |
| schoolbell-v5.1.127-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip | `8b0805b0da2af7f6a8df579a055eaa61a9bf87761358f4afd4dea3574a85d05d` |
| SHA256SUMS | `fc7ccf8cd46a5b1ae51bb60706194c4cb265a9e267e49813b5bb28cc2497b1a6` |
| SHA256SUMS.sig | `9ade499929afa4a1adca5170526b7c72053ce90367f389bdd70f5564860c355d` |

Все четыре хеша совпали с digest GitHub. SSH-подпись скачанного списка проверена по доверенному ключу репозитория, namespace schoolbell-release; обе суммы ZIP совпали. Итог — **PASS публичной доставки**. Байты ZIP совпадают с ранее проверенной парой. Это не новый запуск сценариев на роутере; стенды не затрагивались. Исторические результаты черновика выше сохранены как этап до публикации.

Public verification used unauthenticated HTTP requests, without a token or authenticated CLI. The release returned draft=false/prerelease=true, its page returned HTTP 200, and all four assets were downloaded afresh. Their SHA-256 digests matched GitHub; the checksum signature matched the trusted project key and both ZIP checksums passed. The bytes match the previously checked pair. **Public delivery PASS**, not new hardware acceptance; no router access.
