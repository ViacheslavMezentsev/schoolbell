import QtQuick
import QtQuick.Controls
ComboBox {
 id:control
 property var colors
 implicitHeight:48
    font.pixelSize:18
    leftPadding:16;rightPadding:48
    opacity:enabled?1:0.7
    contentItem:Text {text:control.displayText;font:control.font;color:colors.text;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
    background:Rectangle {radius:8;color:colors.bg;border.color:control.visualFocus?colors.accent:colors.border;border.width:control.visualFocus?2:1}
    indicator:Canvas {
     id:pickerArrow;objectName:"picker-arrow";width:24;height:24;x:control.width-36;y:(control.height-height)/2
     Connections {target:control.colors;function onTextChanged(){pickerArrow.requestPaint()}}
     onPaint:{let c=getContext("2d");c.clearRect(0,0,width,height);c.strokeStyle=colors.text;c.lineWidth=2.5;c.lineCap="round";c.lineJoin="round";c.beginPath();c.moveTo(5,9);c.lineTo(12,16);c.lineTo(19,9);c.stroke()}
    }
    delegate:ItemDelegate {
     id:option;required property int index;required property var modelData
     width:control.width-2;implicitHeight:48;leftPadding:16;rightPadding:16
     highlighted:control.highlightedIndex===index
     contentItem:Text {text:typeof option.modelData === "string" ? option.modelData : option.modelData[control.textRole];font:control.font;color:option.highlighted?colors.accentText:colors.text;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
     background:Rectangle {color:option.highlighted?colors.accent:colors.panel}
    }
    popup:Popup {
     y:control.height+6;width:control.width;padding:1
     implicitHeight:Math.min(contentItem.implicitHeight+2,242)
     contentItem:ListView {clip:true;implicitHeight:contentHeight;model:control.popup.visible?control.delegateModel:null;currentIndex:control.highlightedIndex;ScrollIndicator.vertical:ScrollIndicator {}}
     background:Rectangle {radius:8;color:colors.panel;border.color:colors.border}
    }
}
