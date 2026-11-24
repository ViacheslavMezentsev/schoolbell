# Комплект выпуска, формат 1 / Release bundle format 1

Дата / Date: 24.11.2026. Статус / Status: согласованный контракт, локальный кандидат;
не готовность к публичному распространению / agreed contract, local candidate only.

## Имена / Names

- `schoolbell-v5.1.127-openwrt-19.07.9-ramips-mt76x8-mipsel_24kc.zip`
- `schoolbell-setup-wizard-v0.1.0-windows-x86_64.zip`
- EXE: `schoolbell-setup-wizard.exe`; продукт / product: Schoolbell Setup Wizard.

Версия комплекта соответствует пакету Школьника; версия мастера независима.
В будущих именах платформ используются `windows`, `linux`, `macos` и `x86_64`, `arm64`;
это не утверждение текущей поддержки платформ. Сейчас мастер проверяется только на Windows 11 x86_64.
Package and wizard versions are independent. Platform naming is not platform acceptance.

## Содержимое ZIP / ZIP layout

Единственный корень `schoolbell-v<version>/` / one archive root:

- `manifest.json`: `kind=schoolbell-package-bundle`, `format=1`, `version`, `tag`,
  `status`, профиль OpenWrt/target/architecture, точный ABI kernel/libc,
  supported_boards, tested_hardware_revisions, packages с относительными путями,
  размерами, SHA256 и зависимостями. Минимальная версия мастера 0.1.0 относится к
  планируемому контракту; `wizard.integration=pending` явно запрещает считать
  интеграцию уже выполненной. Hardware revisions — профиль опытов проекта,
  не приёмка конкретного ZIP; `hardware_validated=false` сохраняется.
- `input-manifest.json`: точные исходные сведения входного комплекта; исходный commit/dirty
  не заменяется коммитом упаковки. `assembly_commit/assembly_dirty` описывают упаковщик отдельно.
- `packages/`: приложение, native clock, 33 закреплённые зависимости, без изменения байтов IPK.
- `dependencies.lock.json`, `packages.tsv`: замкнутый состав; kernel/libc не поставляются для замены.
- `README.md`, `README.en.md`, `RELEASE_NOTES.md`: инструкции RU/EN и заметки версии.
- `scripts/check.sh`, `scripts/verify.sh`: проверки без установки и изменения настроек.
- `scripts/install.py`, `fresh_install.py`, `plan.py`, `schoolbell_ipk.py`, `snapshot.sh` внутри scripts/: host-транзакция и общие проверки.
- `licenses/`: фактические материалы и незакрытые вопросы распространения.
- `SHA256SUMS`: все вложенные файлы, кроме самого списка. Вне ZIP — отдельный SHA256SUMS архива.

Paths are relative and safe; no symlinks, device data, executables, firmware or development
tools enter the package ZIP. The GUI ZIP is separate and will contain its own runtime,
workers, compatibility metadata, documentation and licenses. Its public packager is pending.

## Кандидат и релиз / Candidate versus release

Сборщик принимает проверенный офлайн-каталог и публикует результат только в новый
локальный каталог. ZIP детерминирован для одинаковых входных байтов и сведений о сборке.
Проверяются точный набор зависимостей, ABI, control-метаданные IPK и SHA256.
Кандидат сохраняет `distribution_cleared=false`; нельзя снять его редактированием флага.
Без `--candidate` сборщик отказывает: публичный release gate ещё не реализован.
Ни один шаг упаковки не обращается к роутеру или сети.

For identical input bytes and assembly metadata, ZIP bytes are reproducible. Exact pins,
ABI, package metadata and hashes are checked; destination must not exist. Candidate mode
is explicit, public release is blocked until release gates are implemented. No network/device access.

## Следующие этапы / Next stages

1. Host install.py для свежей установки реализован локально: копия вне устройства,
   подтверждение, защита повторной записи. Аппаратная приёмка и upgrade с откатом остаются открыты.
2. Обнаружение ZIP мастером, ограниченная безопасная распаковка (размер, число файлов,
   дубликаты, traversal, ссылки), проверка manifest и фиксация хеша на сеанс.
3. GitHub Releases: стабильные совместимые assets, скачивание с ограничениями/кэшем;
   подпись manifest/сумм и доверенный открытый ключ. Приватный ключ не входит в репозиторий.
4. Лицензии/соответствующие исходники зависимостей, права аудио, чистый принятый commit,
   аппаратная приёмка точных артефактов, переносимый комплект мастера.

Manual-install hardware acceptance, GUI ZIP discovery, signed release download and distribution clearance are
separate pending stages. Existing GUI package verification does not establish new ZIP acceptance.

## Локальная сборка / Local assembly

```sh
python3 scripts/build-schoolbell-release.py --bundle out/setup-gui-fresh-bundle --out out/release-candidate --candidate
```

Выходной каталог должен быть новым. Старые docs/PACKAGING описывают историческую сборку 5.1.28;
новый процесс ZIP документирован здесь. / Use a new output directory; historical PACKAGING
documents remain the migration record, while this document defines the new ZIP workflow.

## Проверки 24.11.2026 / Checks on 2026-11-24

Полный make all, 15 тестов упаковки, валидатор ТЗ и git diff --check — PASS.
Реальный локальный комплект 35 IPK версии 5.1.127 упакован в ZIP-кандидат;
синтетические тесты проверили повторяемость байтов и отказы без публикации результата.
Мастер 0.1.0 собран статически; версия подтверждена в свойствах EXE и заголовке окна.
7 Qt-проверок прошли. Финальный визуальный осмотр нового длинного названия не завершён
из-за ошибки инструмента просмотра. Стенды не использовались.

Full make all, 15 packaging checks, specification validation and whitespace checks passed.
A real local 35-IPK bundle was packaged as a candidate; synthetic fixtures covered byte
reproducibility and failure atomicity. Static wizard 0.1.0 built; Windows metadata/window
title confirmed the version and 7 Qt checks passed. Final layout inspection of the longer
name remains pending after a viewing-tool failure. No device access occurred.

## Предварительное планирование / Preliminary planning

24.11.2026: добавлен отдельный host-планировщик `scripts/plan.py` и читающий
`scripts/snapshot.sh`; Python не требуется на роутере. В ZIP включён общий
ограниченный читатель IPK `scripts/schoolbell_ipk.py`. Планировщик сверяет все
SHA256, фактические control/payload IPK, lock, ABI, инвентарь, выключенный автомат,
отсутствие pending и остаточных данных перед новой установкой. Размер payload
вычисляется из IPK, а не принимается из manifest. Совместимые штатные зависимости
сохраняются, замыкание проверяется также с их фактическими версиями.

Это только предварительный план по файлу. Нет SSH, записи, копии или утверждения
об исправности служб; текущая версия с отсутствующими зависимостями отклоняется.
Переход со старой версии требует отдельного проверенного IPK отката и пока
не поддерживается этим планировщиком. Установка и аппаратная приёмка остаются открыты.

The ZIP now includes a read-only device snapshot script and an offline Python host
planner with the shared bounded IPK reader. Exact file integrity, real IPK metadata,
pins, ABI, inventory, automation-off/pending/data guards and estimated incremental
space are checked. Retained stock versions participate in dependency validation.
This is a file-based preliminary plan, not SSH, backup, installation or service
verification. Upgrades and repairs are refused; actual manual installation and
hardware acceptance remain pending.

Проверки этого этапа: `make all`, 13 тестов планировщика, 15 тестов упаковки,
валидатор ТЗ без предупреждений и `git diff --check` — PASS. Реальный ZIP из
35 IPK дважды проверен CLI на искусственном снимке; стенды не читались и не менялись.

Stage checks: full `make all`, 13 planner tests, 15 packaging tests, specification
validation without warnings and whitespace checks passed. The actual 35-IPK ZIP
passed two CLI runs with a synthetic snapshot; no device was accessed.

## Транзакция ZIP / ZIP transaction

Host `scripts/install.py`: `prepare`, `install`, `verify`. Общая логика fresh_install.py
используется также GUI. Подготовка принимает ZIP напрямую, ограничивает распаковку
(64 МиБ ZIP, 128 МиБ содержимого, 512 файлов, 16 МиБ файл), запрещает ссылки, повторные
пути без учёта регистра, traversal и специальные Windows-имена. Точный состав и IPK
проверяются до SSH. Комплект фиксируется копией и SHA256 в новом сеансе.

Полный overlay и образ восстановления остаются на ПК. Подготовка не перезаписывается;
повторные команды сверяют хеши всех доказательств. Перед записью живые проверки
устройства/загрузки/инвентаря/настроек/места выполняются в одной SSH-команде с установкой.
До соединения создаётся write-started; неизвестный исход допускает только verify.
Ошибка проверки аннулирует прежний verified. Оригинальный ZIP после подготовки не нужен:
установка использует закреплённую копию, а не меняющийся файл рядом с EXE.

The host CLI accepts a bounded ZIP and pins it in a new private session. It shares the
GUI fresh-install core. Verified overlay/recovery material remains off-device; live
checks precede explicit package installation in the same SSH command. Persistent
write intent blocks retries after uncertain outcomes; verify failures clear old proof.
Only fresh installation is implemented; old-version upgrades, repair, GUI integration
and hardware acceptance remain pending. See the bundled RU/EN READMEs for commands.

Локальный результат 24.11.2026: make all — PASS; 23 теста ZIP-транзакции,
15 тестов fresh-install, 15 упаковки и 13 планировщика — PASS. Часть отрицательных
сценариев исполняет shell в искусственной файловой системе. В Windows проверены
импорт CLI и распаковка настоящих 35 IPK без SSH. ТЗ: 22 требования, 16 TC,
без ошибок и предупреждений. Аппаратные операции не выполнялись.

Local result on 2026-11-24: make all, 23 ZIP-transaction tests, 15 fresh-install tests,
15 packaging tests and 13 planner tests passed. Shell guards run against a synthetic
filesystem in selected tests. Windows CLI import and extraction of the actual 35 IPKs
passed without SSH. Specification validation: 22 requirements, 16 TCs, no errors or
warnings. No hardware operations were performed.
