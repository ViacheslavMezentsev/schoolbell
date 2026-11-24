import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
 id: root
 property alias text: input.text
 property alias placeholderText: input.placeholderText
 property var colors
 property bool revealed: false
 property bool clearOnHide: true
 function clear() { input.clear(); revealed = false }
 onVisibleChanged: if (!visible) { if (clearOnHide) clear(); else revealed=false }
 TextField {
  id: input
  Layout.fillWidth: true
  echoMode: root.revealed ? TextInput.Normal : TextInput.Password
  selectByMouse: true
  Accessible.name: "Пароль администратора роутера"
 }
 Button {
  id: toggle; objectName: "password-visibility"
  implicitWidth: 48; implicitHeight: 48
  checkable: true; checked: root.revealed
  onClicked: root.revealed = !root.revealed
  Accessible.name: root.revealed ? "Скрыть пароль" : "Показать пароль"
  ToolTip.visible: hovered
  ToolTip.text: Accessible.name
  background: Rectangle {radius:8;color:toggle.down?root.colors.soft:root.colors.panel;border.color:toggle.visualFocus?root.colors.accent:root.colors.border}
  contentItem: Canvas {
   id: eye
   onWidthChanged: requestPaint()
   onHeightChanged: requestPaint()
   Connections {target:root.colors;function onTextChanged(){eye.requestPaint()}}
   Connections {target:root;function onRevealedChanged(){eye.requestPaint()} function onColorsChanged(){eye.requestPaint()}}
   onPaint: {
    let c=getContext("2d");c.clearRect(0,0,width,height);c.strokeStyle=root.colors.text;c.lineWidth=2;
    let x=width/2,y=height/2;
    c.beginPath();c.moveTo(x-12,y);c.quadraticCurveTo(x,y-14,x+12,y);c.quadraticCurveTo(x,y+14,x-12,y);c.stroke();
    c.beginPath();c.arc(x,y,4,0,2*Math.PI);c.stroke();
    if(root.revealed){c.beginPath();c.moveTo(x-12,y+11);c.lineTo(x+12,y-11);c.stroke()}
   }
  }
 }
}
