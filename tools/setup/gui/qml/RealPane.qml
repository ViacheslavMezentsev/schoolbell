import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id: pane
 function run(action) {
  let secret=password.text;
  password.revealed=false;
  realBackend.start(action,selectedSource,selectedIndex,secret);
  secret="";
 }
 property string selectedSource: realBackend.sourceIP
 property int selectedIndex: realBackend.adapterIndex
 property bool connectionSelected: false
 onVisibleChanged: {if(!visible) password.clear(); else {realBackend.refreshConnections();if(["idle","error"].indexOf(realBackend.stage)>=0){connectionSelected=false;connection.currentIndex=-1}}}
 Connections {target:realBackend;function onSessionReset(){password.clear();pane.selectedSource="";pane.selectedIndex=0;pane.connectionSelected=false;realBackend.refreshConnections();connection.currentIndex=-1}}
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
   Layout.fillWidth:true
   Label {text:"Подключение к роутеру:"}
   ComboBox {
    id:connection;objectName:"connection-picker";Layout.fillWidth:true;implicitHeight:48
    model:realBackend.connections;textRole:"label";currentIndex:-1
    displayText:["ready","uncertain","done"].indexOf(realBackend.stage)>=0 ? pane.selectedSource : pane.connectionSelected ? currentText : "Выберите выделенный USB–Ethernet"
    font.pixelSize:18
    leftPadding:16;rightPadding:48
    opacity:enabled?1:0.7
    contentItem:Text {text:connection.displayText;font:connection.font;color:colors.text;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
    background:Rectangle {radius:8;color:colors.bg;border.color:connection.visualFocus?colors.accent:colors.border;border.width:connection.visualFocus?2:1}
    indicator:Canvas {
     id:connectionArrow;width:24;height:24;x:connection.width-36;y:(connection.height-height)/2
     Connections {target:pane.colors;function onTextChanged(){connectionArrow.requestPaint()}}
     onPaint:{let c=getContext("2d");c.clearRect(0,0,width,height);c.strokeStyle=colors.text;c.lineWidth=2.5;c.lineCap="round";c.lineJoin="round";c.beginPath();c.moveTo(5,9);c.lineTo(12,16);c.lineTo(19,9);c.stroke()}
    }
    delegate:ItemDelegate {
     id:option;required property int index;required property var modelData
     width:connection.width-2;implicitHeight:48;leftPadding:16;rightPadding:16
     highlighted:connection.highlightedIndex===index
     contentItem:Text {text:option.modelData.label;font:connection.font;color:option.highlighted?colors.accentText:colors.text;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
     background:Rectangle {color:option.highlighted?colors.accent:colors.panel}
    }
    popup:Popup {
     y:connection.height+6;width:connection.width;padding:1
     implicitHeight:Math.min(contentItem.implicitHeight+2,242)
     contentItem:ListView {clip:true;implicitHeight:contentHeight;model:connection.popup.visible?connection.delegateModel:null;currentIndex:connection.highlightedIndex;ScrollIndicator.vertical:ScrollIndicator {}}
     background:Rectangle {radius:8;color:colors.panel;border.color:colors.border}
    }
    enabled:!realBackend.busy && ["idle","error"].indexOf(realBackend.stage)>=0
    onActivated:{let row=realBackend.connections[currentIndex];password.clear();pane.selectedSource=row.source;pane.selectedIndex=row.index;pane.connectionSelected=true}
   }
   RealButton {text:"Обновить";enabled:connection.enabled;onClicked:{password.clear();pane.connectionSelected=false;realBackend.refreshConnections();connection.currentIndex=-1}}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.muted
   text:["ready","uncertain","done"].indexOf(realBackend.stage)>=0
     ? "Подключение сохранённого сеанса: "+pane.selectedSource+". Для другого подключения начните новый сеанс."
     : realBackend.connections.length ? "Выберите именно отдельный адаптер с кабелем к роутеру. Перед операцией мастер проверит прямой маршрут."
     : "Подходящих Ethernet-подключений нет. Подключите отдельный адаптер к OpenWrt и нажмите «Обновить». Нужен IPv4 в сети роутера; мастер не меняет настройки сети."}
  RowLayout {
   Label {text:"Пароль root:"}
   PasswordField {id:password;objectName:"router-password";colors:pane.colors;Layout.fillWidth:true;enabled:!realBackend.busy;placeholderText:"Пароль администратора OpenWrt (root)"}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Пароль остаётся в этой вкладке между операциями и не записывается на диск. При выходе из вкладки он очищается.";color:colors.muted}
  RowLayout {
   RealButton {text:"1. Проверить и сохранить копию";implicitHeight:48;enabled:!realBackend.busy && ["idle","error","ready"].indexOf(realBackend.stage)>=0 && (pane.connectionSelected || realBackend.stage==="ready") && pane.selectedSource.length>0 && password.text.length>0;onClicked:run("prepare")}
   RealButton {text:"2. Установить 5.1.127";implicitHeight:48;enabled:!realBackend.busy && realBackend.stage==="ready" && password.text.length>0;onClicked:confirm.open()}
   RealButton {text:"Проверить результат";implicitHeight:48;enabled:!realBackend.busy && ["uncertain","done"].indexOf(realBackend.stage)>=0 && password.text.length>0;onClicked:run("verify")}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;font.bold:true;color:realBackend.stage==="done"?colors.success:colors.warning;text:realBackend.busy?"Выполняется операция. Не отключайте питание и кабель.":realBackend.stage==="done"?"Установка проверена. Автозвонки выключены, громкость сохранена.":realBackend.stage==="ready"?"Резервная копия проверена. Можно подтвердить установку.":realBackend.stage==="uncertain"?"Исход записи требует проверки. Повторная установка заблокирована.":realBackend.stage==="error"?"Операция остановлена. Подробности ниже.":"Начните с проверки устройства и резервной копии."}
  ProgressBar {Layout.fillWidth:true;indeterminate:true;visible:realBackend.busy}
  ScrollView {id:outputScroll;Layout.fillWidth:true;Layout.fillHeight:true;contentWidth:availableWidth;TextArea {text:realBackend.report;readOnly:true;wrapMode:TextEdit.Wrap;font.pixelSize:13;onTextChanged:Qt.callLater(function(){outputScroll.ScrollBar.vertical.position=Math.max(0,1-outputScroll.ScrollBar.vertical.size)})}}
  RowLayout {
   RealButton {text:"Новый сеанс";enabled:!realBackend.busy && realBackend.stage!=="uncertain";onClicked:newSessionConfirm.open()}
   RealButton {text:"Открыть резервную копию";implicitHeight:48;onClicked:realBackend.openBackup()}
   RealButton {text:"Архив копий";onClicked:realBackend.openHistory()}
   RealButton {text:"Открыть Школьник";implicitHeight:48;enabled:realBackend.stage==="done";onClicked:realBackend.openDevice()}
  }
 }
 Dialog {id:newSessionConfirm;anchors.centerIn:parent;width:580;modal:true;title:"Начать новый сеанс?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:530;wrapMode:Text.WordWrap;text:"Предыдущие резервные копии и протокол сохранятся в архиве на компьютере. Пароль будет очищен. Для следующего обновления потребуется новая проверка и резервная копия. Роутер не изменяется."}
  onAccepted:realBackend.newSession()
 }
 Dialog {id:confirm;anchors.centerIn:parent;width:580;modal:true;title:"Установить Школьник 5.1.127?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:530;wrapMode:Text.WordWrap;text:"Будет обновлён пакет на отдельном роутере 192.168.1.1. Копия сохранена на ПК. Автозвонки останутся выключенными; громкость не меняется. Во время записи закрытие мастера заблокировано."}
  onAccepted:run("install")
 }
}
