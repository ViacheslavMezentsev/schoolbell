# Сохранённые материалы / Preserved upstream materials

Поддерживаемый профиль восстановления: **TP-Link TL-MR3020 (EU) Ver. 3.30**, оригинальный загрузчик, возврат Build250625. Другие модели, регионы и ревизии (включая V1, V2, V3.0, V3.20) не заявлены поддерживаемыми этим мастером.

Supported recovery profile: **TP-Link TL-MR3020 (EU) Ver. 3.30**, original bootloader, stock Build250625. Other models, regions and revisions (including V1, V2, V3.0 and V3.20) are not supported by this wizard.

- [Страница поддержки — RU, перевод EN](support.md) / [Support summary — EN](support.en.md).
- [manifest.json](manifest.json): original/resolved URLs, retrieval UTC, sizes and SHA256; also unavailable Russian URL. / URL, дата получения, размер, SHA256 и недоступный российский адрес.
- Original OEM ZIP is preserved byte-for-byte, including its GPL terms and upgrade instructions. / OEM ZIP сохранён без изменений с условиями GPL и инструкцией производителя.
- Python 3.11.9 embedded x64 ZIP is from [python.org](https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip); its LICENSE.txt remains inside and is included in the prepared kit. / Лицензия Python сохраняется в архиве и комплекте.

These vendor materials retain their upstream rights and are **not relicensed under this project's MIT license**. Their presence does not establish TP-Link support for third-party firmware or for this recovery method. No private device backup or credentials are included.

Материалы сохраняют права и лицензии производителей и **не переводятся под MIT проекта**. Их наличие не означает поддержку TP-Link сторонней прошивки или нашего метода восстановления. Дампов конкретного устройства и паролей здесь нет.

Use Prepare-Recovery.ps1 one directory above to build the stock-recovery ZIP offline. Generated payloads and kits stay in ignored dist; the pinned original archives and snapshots are versioned. / Prepare-Recovery.ps1 уровнем выше собирает комплект без сети; результаты находятся в исключённом из Git dist.

[Фотографии / Photographs](photos.md): Ver. 3.30 — 4, включая упаковку / including packaging; Ver. 3.20 — 3. Ver. 3.30: USB Type-C для питания / power.
