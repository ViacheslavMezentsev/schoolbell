import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id: pane
 function run(action) {
  let secret=password.text;
  password.revealed=false;
  realBackend.start(action,source.text,adapter.value,secret);
  secret="";
 }
 onVisibleChanged: if(!visible) password.clear()
 property var colors
 component RealButton: Button {
  id:control;implicitHeight:48;leftPadding:16;rightPadding:16;font.bold:true;opacity:enabled?1:0.45
  contentItem:Text {text:control.text;font:control.font;color:colors.text;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
  background:Rectangle {radius:8;color:control.down?colors.soft:colors.panel;border.color:control.visualFocus?colors.accent:colors.border}
 }
 color:colors.panel; border.color:colors.border; radius:14
 ColumnLayout {anchors.fill:parent; anchors.margins:24; spacing:14
  Label {text:"Школьник поверх OpenWrt";font.pixelSize:25;font.bold:true}
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Первый реальный режим: обновление существующего Школьника 5.1.124 → 5.1.127. Нужны питание роутера, отдельный USB–Ethernet и кабель RJ45. Также нужно знать пароль администратора OpenWrt (root). Reset не нужен. Сеть, часы и громкость не изменяются."}
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.warning;text:"Только отдельный MR3020 v3 с OpenWrt 19.07.9 по адресу 192.168.1.1. Автозвонки должны быть выключены до подготовки. Прошивка OpenWrt и возврат OEM здесь не выполняются."}
  RowLayout {
   Label {text:"IP компьютера на выделенном кабеле:"}
   TextField {id:source;text:realBackend.sourceIP;placeholderText:"Например, 192.168.1.165";onTextEdited:password.clear();enabled:!realBackend.busy && realBackend.stage!=="ready";implicitWidth:215}
   Label {text:"Индекс адаптера:"}
   SpinBox {id:adapter;value:realBackend.adapterIndex;from:1;to:999;editable:true;onValueModified:password.clear();enabled:!realBackend.busy && realBackend.stage!=="ready"}
  }
  RowLayout {
   Label {text:"Пароль root:"}
   PasswordField {id:password;objectName:"router-password";colors:pane.colors;Layout.fillWidth:true;enabled:!realBackend.busy;placeholderText:"Пароль администратора OpenWrt (root)"}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Пароль остаётся в этой вкладке между операциями и не записывается на диск. При выходе из вкладки он очищается.";color:colors.muted}
  RowLayout {
   RealButton {text:"1. Проверить и сохранить копию";implicitHeight:48;enabled:!realBackend.busy && ["idle","error","ready"].indexOf(realBackend.stage)>=0 && source.text.length>0 && password.text.length>0;onClicked:run("prepare")}
   RealButton {text:"2. Установить 5.1.127";implicitHeight:48;enabled:!realBackend.busy && realBackend.stage==="ready" && password.text.length>0;onClicked:confirm.open()}
   RealButton {text:"Проверить результат";implicitHeight:48;enabled:!realBackend.busy && ["uncertain","done"].indexOf(realBackend.stage)>=0 && password.text.length>0;onClicked:run("verify")}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;font.bold:true;color:realBackend.stage==="done"?colors.success:colors.warning;text:realBackend.busy?"Выполняется операция. Не отключайте питание и кабель.":realBackend.stage==="done"?"Установка проверена. Автозвонки выключены, громкость сохранена.":realBackend.stage==="ready"?"Резервная копия проверена. Можно подтвердить установку.":realBackend.stage==="uncertain"?"Исход записи требует проверки. Повторная установка заблокирована.":realBackend.stage==="error"?"Операция остановлена. Подробности ниже.":"Начните с проверки устройства и резервной копии."}
  ProgressBar {Layout.fillWidth:true;indeterminate:true;visible:realBackend.busy}
  ScrollView {id:outputScroll;Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth;TextArea {text:realBackend.report;readOnly:true;wrapMode:TextEdit.Wrap;font.pixelSize:13;onTextChanged:Qt.callLater(function(){outputScroll.ScrollBar.vertical.position=Math.max(0,1-outputScroll.ScrollBar.vertical.size)})}}
  RowLayout {
   RealButton {text:"Открыть резервную копию";implicitHeight:48;onClicked:realBackend.openBackup()}
   RealButton {text:"Открыть Школьник";implicitHeight:48;enabled:realBackend.stage==="done";onClicked:realBackend.openDevice()}
  }
 }
 Dialog {id:confirm;anchors.centerIn:parent;width:580;modal:true;title:"Установить Школьник 5.1.127?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:530;wrapMode:Text.WordWrap;text:"Будет обновлён пакет на отдельном роутере 192.168.1.1. Копия сохранена на ПК. Автозвонки останутся выключенными; громкость не меняется. Во время записи закрытие мастера заблокировано."}
  onAccepted:run("install")
 }
}
