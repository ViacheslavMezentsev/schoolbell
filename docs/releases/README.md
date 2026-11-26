# Описания релизов / Release notes

[Порядок подготовки выпуска](../RELEASING.md) · [Release workflow](../RELEASING.en.md)

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

Решение владельца 25.11.2026: публикация разрешена как есть. Незавершённые материалы распространения не блокируют выпуск; прежние формулировки о блокировке заменены этим решением. Открытые вопросы остаются сведениями, не утверждением завершённого аудита. / Owner decision 2026-11-25: as-is publication authorized; incomplete distribution materials do not block releases. Prior blocking statements are superseded; open review items remain informational.

## Оформление / Formatting

Русская часть открыта; английская целиком в `<details><summary>English release notes</summary>` с пустыми строками вокруг Markdown. Сообщение Git-тега остаётся коротким. Перед копированием в GitHub Release замените относительные ссылки на полные ссылки документов именно тега выпуска; проверьте их после создания тега. Не публикуйте шаблонные имена файлов и незаполненные суммы. / Keep Russian visible and English collapsed. Use tag-pinned absolute document links in the actual GitHub Release, and replace all filename placeholders before publication.
