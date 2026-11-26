import QtQuick
import QtQuick.Controls
Button {
 id:control
 property var colors
 property string symbol
 property string label
 implicitWidth:48;implicitHeight:48;padding:0;hoverEnabled:true
 opacity:enabled?1:0.45
 Accessible.name:label
 ToolTip.visible:hovered;ToolTip.text:label
 background:Rectangle {radius:8;color:control.down||control.hovered?colors.soft:colors.panel;border.color:control.visualFocus?colors.accent:colors.border;border.width:control.visualFocus?2:1}
 contentItem:Canvas {
  id:icon
  onWidthChanged:requestPaint()
  onHeightChanged:requestPaint()
  Connections {target:control.colors;function onTextChanged(){icon.requestPaint()}}
  Connections {target:control;function onSymbolChanged(){icon.requestPaint()} function onColorsChanged(){icon.requestPaint()}}
  onPaint:{
   let c=getContext("2d");c.clearRect(0,0,width,height);c.save();c.translate(width/2-12,height/2-12);
   c.strokeStyle=control.colors.text;c.fillStyle=control.colors.text;c.lineWidth=2;c.lineCap="round";c.lineJoin="round";
   if(control.symbol==="list"){
    for(let y of [5,12,19]){c.fillRect(1,y-1,3,3);c.beginPath();c.moveTo(8,y);c.lineTo(23,y);c.stroke()}
   }else if(control.symbol==="folder"){
    c.beginPath();c.moveTo(2,20);c.lineTo(2,5);c.lineTo(9,5);c.lineTo(12,8);c.lineTo(21,8);c.lineTo(21,11);c.stroke();
    c.beginPath();c.moveTo(2,20);c.lineTo(6,11);c.lineTo(24,11);c.lineTo(20,20);c.closePath();c.stroke();
   }else if(control.symbol==="exit"){
    c.beginPath();c.moveTo(9,3);c.lineTo(2,3);c.lineTo(2,21);c.lineTo(9,21);c.stroke();
    c.beginPath();c.moveTo(9,12);c.lineTo(23,12);c.moveTo(17,6);c.lineTo(23,12);c.lineTo(17,18);c.stroke();
   }
   c.restore();
  }
 }
}
