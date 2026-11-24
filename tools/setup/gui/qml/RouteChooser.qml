import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id:pane
 property var colors
 signal selected(string route)
 color:colors.panel;border.color:colors.border;radius:14
 ScrollView {
  anchors.fill:parent;anchors.margins:20;clip:true;contentWidth:availableWidth
  ColumnLayout {
   width:parent.width;spacing:14
   Label {text:"Что вы хотите сделать?";font.pixelSize:25;font.bold:true;color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:"Для всех маршрутов: роутер с питанием, отдельный USB–Ethernet-адаптер и сетевой кабель. Выберите задачу — мастер покажет дальнейшие шаги.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Repeater {
    model:[
     {route:"openwrt",title:"Установить OpenWrt",body:"На новый роутер с заводской прошивкой. Сначала устанавливается OpenWrt, затем можно перейти к комплекту Школьника.",status:"Подготовка и инструкция · запуск прошивки пока через консольный комплект"},
     {route:"packages",title:"Установить Школьник",body:"На роутер, где уже работает OpenWrt. Выберите ZIP-архив комплекта рядом с мастером, сохраните копию и установите пакеты.",status:"Установка из ZIP доступна в мастере"},
     {route:"recovery",title:"Восстановить роутер",body:"Вернуть заводскую прошивку TP-Link через Reset. OpenWrt и Школьник будут удалены; настройки и пароль TP-Link могут сохраниться.",status:"Подготовка и инструкция · запуск восстановления пока через консольный комплект"}
    ]
    delegate:Button {
     id:card;required property var modelData
     objectName:"route-"+modelData.route;Layout.fillWidth:true
     implicitHeight:contentItem.implicitHeight+32;padding:16;hoverEnabled:true
     Accessible.name:modelData.title
     contentItem:ColumnLayout {
      spacing:7
      Label {text:card.modelData.title+"  →";font.pixelSize:21;font.bold:true;color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
      Label {text:card.modelData.body;color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
      Label {text:card.modelData.status;color:card.modelData.route==="packages"?pane.colors.accent:pane.colors.warning;Layout.fillWidth:true;wrapMode:Text.WordWrap;font.pixelSize:13}
     }
     background:Rectangle {radius:10;color:card.hovered||card.down?pane.colors.soft:pane.colors.bg;border.color:card.activeFocus?pane.colors.accent:pane.colors.border;border.width:card.activeFocus?2:1}
     onClicked:pane.selected(modelData.route)
    }
   }
   Label {text:"Подтверждённая ревизия для прошивки: TL-MR3020 EU v3.30. Проверяйте маркировку на корпусе: похожее название модели не гарантирует совместимость.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
  }
 }
}
