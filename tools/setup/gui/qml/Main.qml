import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
ApplicationWindow {
 id: app
 visible: true; width: 1060; height: 740; minimumWidth: 900; minimumHeight: 680
 title: "Мастер установки " + Qt.application.version; color: theme.bg
 font.family: "Segoe UI"; font.pixelSize: 15
 Settings { id: preferences; category: "Appearance"; property string themeMode: "system" }
 Theme { id: theme; mode: preferences.themeMode }
 palette.window: theme.bg
 palette.windowText: theme.text
 palette.base: theme.bg
 palette.text: theme.text
 palette.button: theme.panel
 palette.buttonText: theme.text
 palette.highlight: theme.accent
 palette.highlightedText: theme.accentText
 palette.mid: theme.border
 palette.dark: theme.border
 palette.light: theme.panel
 component ActionButton: Button {
  id: control
  implicitHeight: 48; leftPadding: 16; rightPadding: 16
  font.bold: true; hoverEnabled: true
  opacity: enabled ? 1 : 0.6
  contentItem: Text { text: control.text; font: control.font; color: control.highlighted ? theme.accentText : theme.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
  background: Rectangle { radius: 8; color: control.highlighted ? theme.accent : control.down || control.hovered ? theme.soft : theme.panel; border.color: control.visualFocus ? theme.accent : theme.border; border.width: control.visualFocus ? 3 : 1 }
 }

 readonly property bool operationBusy:realBackend.busy || firmwareBackend.busy
 property string route:"home"
 function navigate(next) {
  if(app.operationBusy || ["home","openwrt","packages","recovery"].indexOf(next)<0)return;
  route=next;
 }
 property bool closeConfirmed:false
 readonly property string themeLabel: preferences.themeMode === "system" ? "системная" : preferences.themeMode === "dark" ? "тёмная" : "светлая"
 onClosing:function(event) {
  event.accepted=closeConfirmed && !app.operationBusy;
  if(!event.accepted && !app.operationBusy) interruption.open();
 }
 ColumnLayout {
  anchors.fill:parent;anchors.margins:24;spacing:12
  RowLayout {
   ColumnLayout {
    Layout.fillWidth:true
    Label {text:"Мастер установки";font.pixelSize:28;font.bold:true;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    Label {text:"v"+Qt.application.version+" · OpenWrt · Комплекты · Восстановление";color:theme.muted}
   }
   ActionButton {
    objectName:"route-home";text:"К выбору задачи";visible:app.route!=="home";enabled:!app.operationBusy
    onClicked:app.navigate("home")
   }
   ActionButton {
    text:preferences.themeMode==="system"?"◐":preferences.themeMode==="dark"?"☾":"☀"
    implicitWidth:48;leftPadding:0;rightPadding:0;font.pixelSize:24
    Accessible.name:"Тема: "+app.themeLabel;ToolTip.visible:hovered;ToolTip.text:Accessible.name
    onClicked:preferences.themeMode=preferences.themeMode==="system"?"dark":preferences.themeMode==="dark"?"light":"system"
   }
  }
  RouteChooser {objectName:"route-chooser";visible:app.route==="home";Layout.fillWidth:true;Layout.fillHeight:true;colors:theme;onSelected:function(next){app.navigate(next)}}
  RealPane {objectName:"package-route";visible:app.route==="packages";Layout.fillWidth:true;Layout.fillHeight:true;colors:theme}
  FirmwareRoute {objectName:"firmware-route";visible:app.route==="openwrt" || app.route==="recovery";recovery:app.route==="recovery";Layout.fillWidth:true;Layout.fillHeight:true;colors:theme;onPackagesRequested:app.navigate("packages")}
 }
 Dialog {
  id:interruption;objectName:"close-confirmation";anchors.centerIn:parent;width:620;modal:true;title:"Закрытие мастера"
  closePolicy:Popup.NoAutoClose
  contentItem:Label {text:"Закрыть мастер? Резервные копии и журнал останутся на ПК. Если результат установки не подтверждён, при следующем запуске сначала выполните проверку. Если вы подготавливали сеть, сначала вернитесь и нажмите «Восстановить сеть».";wrapMode:Text.WordWrap;color:theme.text}
  background:Rectangle {color:theme.panel;border.color:theme.border;radius:10}
  footer:Item {
   implicitHeight:76
   RowLayout {
    anchors.fill:parent;anchors.leftMargin:20;anchors.rightMargin:20;anchors.topMargin:8;anchors.bottomMargin:20;spacing:12
    Item {Layout.fillWidth:true}
    ActionButton {text:"Продолжить работу";onClicked:interruption.close()}
    ActionButton {text:"Закрыть мастер";enabled:!app.operationBusy;onClicked:{app.closeConfirmed=true;app.close()}}
   }
  }
 }
}
