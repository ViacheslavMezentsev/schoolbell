import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id:pane
 property var colors
 property bool recovery:false
 signal packagesRequested()
 color:colors.panel;border.color:colors.border;radius:14
 ScrollView {
  id:scroll;anchors.fill:parent;anchors.margins:20;clip:true;contentWidth:availableWidth
  ColumnLayout {
   width:scroll.availableWidth;spacing:16
   Label {objectName:"firmware-title";text:pane.recovery?"Восстановление · Заводская прошивка":"Новый роутер · OpenWrt";font.pixelSize:25;font.bold:true;color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:pane.recovery?"Возврат TP-Link TL-MR3020 EU v3.30 к заводской системе. Это не восстановление настроек из резервной копии.":"Замена заводской системы на OpenWrt. Установка Школьника — следующий отдельный маршрут.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:"Что понадобится";font.pixelSize:21;font.bold:true;color:pane.colors.text}
   Label {text:"• TL-MR3020 EU v3.30 и его блок питания.\n• Отдельный USB–Ethernet-адаптер и сетевой кабель.\n• Windows 11, PowerShell 7 и права администратора.\n• Полный распакованный консольный комплект установки с проверенными образами.\n• Резервная копия важных настроек до прошивки.";color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:pane.recovery?"Для передачи через Reset пароль не нужен. После восстановления может понадобиться прежний пароль TP-Link. Если он забыт, потребуется отдельный сброс настроек; ключ Wi-Fi на наклейке не заменяет пароль администратора.":"Для передачи через Reset пароль не нужен. Для сохранения настроек через заводской интерфейс нужен пароль TP-Link. После установки OpenWrt задайте пароль root в LuCI — он понадобится при установке Школьника.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:"Порядок действий";font.pixelSize:21;font.bold:true;color:pane.colors.text}
   Label {text:pane.recovery?"1. Сохраните резервную копию. Возврат заводской системы удалит OpenWrt и Школьник.\n2. В консольном комплекте запустите Setup.cmd -RestoreFactory от имени администратора и выберите выделенный адаптер.\n3. Только после READY зажмите Reset и подайте питание. Отпустите кнопку после начала передачи.\n4. Не отключайте питание. Дождитесь записи, загрузки и восстановления DHCP.\n5. Откройте заводской интерфейс, проверьте версию и вход с прежним паролем.":"1. Проверьте ревизию и регион на корпусе, сохраните нужные настройки.\n2. Подключите роутер к отдельному USB–Ethernet-адаптеру.\n3. Запустите полный консольный комплект по его руководству. Только после READY зажмите Reset и подайте питание.\n4. Отпустите Reset после начала передачи; питание больше не отключайте до загрузки.\n5. Проверьте доступ к OpenWrt. Текущий консольный комплект также предлагает установку пакетов: отдельный маршрут только прошивки ещё предстоит подключить к GUI.";color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {objectName:"firmware-availability";text:"Прошивка из этого окна ещё не подключена. Здесь нет имитации передачи или сообщения об успешном восстановлении. Сейчас Reset не нажимайте: сервер не запущен.";color:pane.colors.warning;font.bold:true;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:"Передача файла не доказывает успешную загрузку — результат проверяется после перезапуска устройства. Восстановление резервной копии настроек выполняется отдельно.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Button {
    objectName:"go-packages";visible:!pane.recovery;Layout.fillWidth:true;padding:14
    text:"OpenWrt уже работает — перейти к установке Школьника"
    contentItem:Label {text:parent.text;color:pane.colors.text;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;font.bold:true}
    background:Rectangle {color:pane.colors.soft;border.color:pane.colors.border;radius:8}
    onClicked:pane.packagesRequested()
   }
  }
 }
}
