# Описания релизов / Release notes

Один файл `v<версия>.md` на тег Школьника, например [v5.1.127](v5.1.127.md).
Заметки RU/EN готовятся до создания тега и копируются владельцем в GitHub Release.
Наличие файла не означает, что тег создан или выпуск опубликован. После публикации
файл должен соответствовать описанию выпуска; исправления явно отмечаются.

Структура: изменения; совместимость; артефакты; установка/обновление; ограничения;
проверенные сценарии. Не включать пароли, адреса стендов, локальные пути и логи.
В окончательном описании указывать совместимую проверенную версию мастера.
Версия мастера независима от версии Школьника. Формат артефактов описан в
[контракте](../formats/release-bundle-v1.md).

One bilingual `v<version>.md` file per Schoolbell tag. Prepare before tagging; the owner
copies it to GitHub Release. Files do not imply published tags/releases. Include changes,
compatibility, assets, installation/upgrade, limits and tested scenarios; omit private
paths, device identifiers, secrets and logs. State the tested wizard version separately.
