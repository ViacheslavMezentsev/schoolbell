# «Школьник» с заводской прошивки — Windows 11 x64

Автономный мастер для **TP-Link TL-MR3020 (EU) Ver. 3.30**. Первичный переход на OpenWrt 19.07.9 заменяет заводскую ОС и настройки. Для обновления работающего «Школьника» используйте отдельную процедуру обновления IPK. Ветка OpenWrt 19.07 завершила поддержку безопасности.

## Запуск

1. Полностью распакуйте ZIP на локальный диск. В терминале из папки комплекта выполните `Setup.cmd -CheckOnly`. Для установки нужен стандартный компонент Windows «Клиент OpenSSH». Подготовьте его заранее. Образ OpenWrt, 35 IPK и Python входят в ZIP.
2. Отключите роутер от питания и от обычной сети. Соедините его кабелем с выделенным физическим Ethernet-адаптером ПК. Требуется автоматическая настройка IPv4 (DHCP) без ручных адресов. Отключите пересекающиеся сети и VPN.
3. Запустите **Setup.cmd от имени администратора**, выберите номер Ethernet-адаптера и сверьте регион и ревизию с наклейкой. После **READY** зажмите Reset и подайте питание. После начала передачи отпустите кнопку. Не прерывайте питание при записи и перезагрузке.
4. После последнего ACK мастер ждёт SSH на 192.168.1.1, отдельно проверяет модель, релиз, архитектуру, ABI ядра и libc. Подтверждайте первый ключ SSH только при прямом кабельном соединении с нужным устройством. Проверьте список недостающих пакетов и подтвердите установку. В конце задайте пароль root через SSH.
5. После возврата адаптера на DHCP откройте [Школьник](http://192.168.1.1/cgi-bin/luci/admin/schoolbell) и войдите как root. Автомат выключен. Сверьте часы, проверьте звук и затем выберите план.

## Если установка прервалась

- ACK означает получение файла загрузчиком. Загрузку ОС подтверждает последующая проверка по SSH. Если OpenWrt уже загрузилась, используйте **Setup.cmd -InstallOnly** без повторной прошивки.
- После аварийного закрытия окна используйте **Setup.cmd -RestoreNetwork** от имени того же администратора и с тем же Ethernet-адаптером. Мастер использует временные адреса 192.168.0.225 и 192.168.1.2 и ограниченное правило входящего UDP. При штатном завершении или ошибке удаляет своё правило и возвращает DHCP.
- Установка IPK не атомарна. При ошибке изучите вывод opkg. Повтор учитывает установленные версии, а маркер сеанса в /tmp сохраняется до перезагрузки. При неподходящих версиях или наличии чужой конфигурации мастер останавливается.
- Ключ роутера хранится в отдельном файле known_hosts в каталоге SchoolbellSetup профиля Windows. Если после новой прошивки ключ изменился, проверьте физическое подключение, затем удалите только устаревшую запись для 192.168.1.1 с помощью ssh-keygen -R и параметра -f для этого файла.

## Происхождение и сборка ZIP

Основа сервера — tftp-readonly.py от 31.10.2026, SHA-256 исходника `feca2cb4d6baf91c6462473f53f77dbb9ea58cd24301671e5baca01a10e45675`. В опыте зафиксированы последний ACK 15873, 8 126 464 полученных байта и последующее чтение OpenWrt 19.07.9 на MR3020. Сохранены RRQ только для tp_recovery.bin/octet от 192.168.0.2, порт 69, отдельный порт 1069 для DATA, блок 512, отсутствие OACK и повторы при потере ACK. Полный новый мастер требует аппаратной приёмки.

Сборщик принимает готовую папку bundle из scripts/build-schoolbell-bundle.py (пакет 5.1.100, native 1.0.0), [официальный recovery-образ](https://downloads.openwrt.org/releases/19.07.9/targets/ramips/mt76x8/openwrt-19.07.9-ramips-mt76x8-tplink_tl-mr3020-v3-squashfs-tftp-recovery.bin) и [Windows embedded Python x64](https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip).

```sh
python3 tools/setup/build.py --bundle /path/to/bundle --image /path/to/recovery.bin --runtime /path/to/python-3.11.9-embed-amd64.zip
```

ZIP и SHA-256 создаются в dist/. Для локальной приёмки; публичное распространение комплекта зависит от открытых пунктов аудита зависимостей и аудио.

## English

Offline setup candidate for a factory TL-MR3020 EU v3.30 on Windows 11 x64. Extract the ZIP to a local drive. Use Setup.cmd -CheckOnly for a local check, then run Setup.cmd as Administrator with the router directly attached to a dedicated DHCP Ethernet adapter. Hold Reset at power-on after READY. Leave power connected until OpenWrt boots. Use -InstallOnly to resume package installation or -RestoreNetwork after interruption. The operator sets a root password and automatic bells remain off. End-to-end acceptance on a spare factory router is pending.
