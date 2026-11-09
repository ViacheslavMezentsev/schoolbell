# Возврат TP-Link / TP-Link stock recovery

## Поддерживаемые устройства / Supported devices

| Тип / Model | Регион / Region | Ревизия / Revision | Результат / Target | Проверка / Evidence |
| --- | --- | --- | --- | --- |
| TP-Link TL-MR3020 | EU | Ver. 3.30 | Build250625, UI 1.8.0 0.9.1 v0001.0 Rel.56805n | Образ принят на устройстве; полный новый мастер ещё не принят / Image hardware-tested; complete new wizard pending |

Особенность Ver. 3.30: питание через **USB Type-C**. [Фотографии обеих ревизий](vendor/photos.md) помогают опознать корпус; ревизию для прошивки сверяйте по наклейке.

Ver. 3.30 uses **USB Type-C for power**. [Photographs of both revisions](vendor/photos.md) help identify the housing; confirm the firmware revision from the device label.

Другие модели, регионы, V1/V2/V3.0/V3.20 не поддерживаются этим комплектом. Нужен исправный оригинальный загрузчик. Полный новый мастер проверен локально; аппаратно проверен его образ через Python TFTP. OEM → OEM отдельно не проверялся.

Other models, regions and V1/V2/V3.0/V3.20 are not supported by this kit. A working original bootloader is required. The new wizard is locally tested; its image was hardware-tested via Python TFTP. OEM → OEM has not been separately tested.

## Подготовка из репозитория / Preparation from the repository

Windows 11 x64, PowerShell 5.1. Интернет, WSL, установленный Python и права администратора для подготовки не требуются:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\setup\Prepare-Recovery.ps1
```

Получится tools/setup/dist/mr3020-eu-v3.30-stock-recovery.zip. Распакуйте на локальный диск. Подготовка ничего не делает с сетью или устройством. / This builds the ZIP entirely offline without device/network changes; extract it to a local drive.

## Проверка и запуск / Check and run

Из распакованной папки / From the extracted folder:

```powershell
.\Recovery.cmd -CheckOnly
.\Recovery.cmd -DryRun
# Реальное восстановление, только после проверки, от администратора:
# Real recovery, only after checking, as Administrator:
.\Recovery.cmd
```

DryRun проверяет файлы и локальные условия, без доступа к роутеру и изменений сети. Не нажимайте Reset при DryRun. При реальном запуске сначала сохраните необходимые данные OpenWrt/Школьника отдельно. Используйте выделенный Ethernet с DHCP. Подтвердите модель и RESTORE FACTORY. Только после READY зажмите Reset и подайте питание. После начала передачи отпустите Reset. Оставьте питание включённым до окончания записи и загрузки. Комплект восстанавливает DHCP на ПК; пакеты Школьника не устанавливает. Финальный ACK подтверждает передачу, не загрузку ОС. Откройте заводской интерфейс и проверьте модель/версию; адрес может отличаться из-за сохранённых настроек.

DryRun checks files and local prerequisites without router access or network changes; do not press Reset. Before real recovery, back up necessary OpenWrt/Schoolbell data separately. Use dedicated Ethernet with DHCP, confirm model and RESTORE FACTORY. Hold Reset at power-on only after READY, release when transfer begins, and keep power connected through writing/boot. The kit restores PC DHCP and does not install Schoolbell. The final ACK proves transfer, not OS boot. Check the model/version in the stock interface; retained settings can change its address.

## Пароль и отдельный сброс / Password and separate reset

Прежний пароль TP-Link и конфигурация могут сохраниться. Ключ Wi-Fi на корпусе не является паролем администратора, если вы сами не задали его таким. Если пароль забыт, отдельно удерживайте WPS/Reset около 10 секунд на уже включённом и загруженном роутере до реакции индикаторов; отпустите, дождитесь загрузки и задайте новый пароль. Сброс удаляет настройки. Мастер сам его не выполняет. Не путайте этот сброс с удержанием Reset при подаче питания для recovery.

The previous TP-Link password/configuration may remain. The label's Wi-Fi key is not the administrator password unless you chose it yourself. If forgotten, separately hold WPS/Reset for about 10 seconds on the powered-on, booted router until LEDs react; release, wait and create a new password. Reset erases settings; the wizard never performs it. This differs from holding Reset during power-on for recovery.

## Оригиналы / Original sources

[RU: перевод английской выжимки](vendor/support.md) · [English summary](vendor/support.en.md) · [Original archives and rights](vendor/README.md) · [URLs / SHA256](vendor/manifest.json).

Все необходимые для возврата исходники и архивы находятся в репозитории. Этот комплект только возвращает OEM: для OpenWrt со Школьником нужен отдельный полный установочный ZIP. / All stock-recovery sources and archives are in the repository. This kit restores OEM only; OpenWrt/Schoolbell installation needs the separate full installation ZIP.
