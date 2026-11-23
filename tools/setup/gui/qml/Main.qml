import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "Flow.js" as Flow
ApplicationWindow {
 id: app
 visible: true; width: 1060; height: 740; minimumWidth: 900; minimumHeight: 680
 title: realMode ? "Мастер установки — реальные пакеты" : "Мастер установки — макет"; color: theme.bg
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

 component ChoiceBox: ComboBox {
  id: choice; implicitHeight: 44; leftPadding: 12; rightPadding: 32
  opacity: enabled ? 1 : 0.6
  contentItem: Text { text: choice.displayText; color: theme.text; font: choice.font; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
  background: Rectangle { color: theme.bg; radius: 7; border.color: choice.visualFocus ? theme.accent : theme.border; border.width: choice.visualFocus ? 3 : 1 }
  indicator: Text { x: choice.width-25; y: (choice.height-height)/2; text: "⌄"; color: theme.text }
  delegate: ItemDelegate { required property int index; required property var modelData; width: choice.width; text: modelData; highlighted: choice.highlightedIndex === index
   contentItem: Text { text: modelData; color: parent.highlighted ? theme.accentText : theme.text; font: choice.font }
   background: Rectangle { color: parent.highlighted ? theme.accent : theme.panel }
  }
  popup: Popup { y: choice.height+4; width: choice.width; padding: 1; implicitHeight: contentItem.implicitHeight+2
   contentItem: ListView { implicitHeight: contentHeight; model: choice.popup.visible ? choice.delegateModel : null; currentIndex: choice.highlightedIndex; clip: true }
   background: Rectangle { color: theme.panel; border.color: theme.border; radius: 7 }
  }
 }
 property bool realMode: false
 property var state: Flow.initial(false, 0)
 readonly property bool expert: state.expert
 readonly property int task: state.task
 readonly property int step: state.step
 readonly property int progress: state.progress
 readonly property bool running: state.running
 readonly property bool failed: state.failed
 readonly property bool confirmed: state.confirmed
 readonly property string selectedBundle: state.selectedBundle
 readonly property string report: state.report
 readonly property string themeLabel: preferences.themeMode === "system" ? "системная" : preferences.themeMode === "dark" ? "тёмная" : "светлая"
 readonly property var route: Flow.routeFor(task,expert)
 readonly property var page: Flow.pageOf(state)
 readonly property bool executing: page.id === "execute"
 function dispatch(event) {
  event.revision=state.revision;
  state=Flow.transition(state,event);
  if(state.pending && !interruption.visible) interruption.open();
  if(state.closed) Qt.quit();
 }
 onClosing: function(close) {
  if(realBackend.busy) {close.accepted=false;return;}
  close.accepted=state.closed;
  if(!state.closed) dispatch({type:"request",action:"close"});
 }
 Timer { interval:120; repeat:true; running:app.state.running && !app.state.pending
  onTriggered:app.dispatch({type:"tick",generation:app.state.generation})
 }
 ColumnLayout {
  anchors.fill: parent; anchors.margins: 24; spacing: 12
  RowLayout {
   ColumnLayout {
    Label { text: "Мастер установки"; font.pixelSize: 30; font.bold: true }
    Label { text: "OpenWrt · пакеты · заводская прошивка"; color: theme.muted }
   }
   Item {Layout.fillWidth:true}
   ActionButton {text:app.realMode ? "К макету" : "Реальная установка";enabled:!realBackend.busy;onClicked:app.realMode=!app.realMode}
   ChoiceBox {visible:!app.realMode;implicitWidth:180; model:["Простой режим","Режим эксперта"]; currentIndex:app.expert?1:0; enabled:app.step===-2
    onActivated:app.dispatch({type:"mode",value:currentIndex===1})
   }
   ActionButton {
    text: preferences.themeMode === "system" ? "◐" : preferences.themeMode === "dark" ? "☾" : "☀"
    implicitWidth:48; leftPadding:0; rightPadding:0; font.pixelSize:24
    Accessible.name: "Тема: " + app.themeLabel
    ToolTip.visible:hovered; ToolTip.text:"Тема: " + app.themeLabel
    onClicked: preferences.themeMode=preferences.themeMode==="system"?"dark":preferences.themeMode==="dark"?"light":"system"
   }
   Label {text:app.realMode?"УСТРОЙСТВО":"МАКЕТ"; color:theme.warning; font.bold:true; padding:12; background:Rectangle{color:theme.soft;radius:8}}
  }
  Label {visible:!app.realMode;text:"Все действия ниже — имитация. Роутер подключать и нажимать его кнопки не нужно."; color:theme.muted}
  RowLayout {visible:!app.realMode
   Label {text:app.step===-2 ? "Начните с подготовки" : app.step<0 ? "Что вы хотите сделать?" : app.route.name; color:theme.accent; font.bold:true}
   Item {Layout.fillWidth:true}
   Label {text:app.step===-2 ? "Оборудование · первый шаг" : app.step<0 ? "" : "Шаг "+(app.step+1)+" из "+app.route.steps.length; color:theme.muted}
  }
  RealPane {visible:app.realMode;Layout.fillWidth:true;Layout.fillHeight:true;colors:theme}
  Rectangle {visible:!app.realMode
   Layout.fillWidth:true; Layout.fillHeight:true; color:theme.panel; border.color:theme.border; radius:14
   ColumnLayout {anchors.fill:parent; anchors.margins:20; spacing:12
    Label {text:app.page.title; font.pixelSize:25; font.bold:true}
    RowLayout {Layout.fillWidth:true; Layout.fillHeight:true; spacing:24
     ScrollView {Layout.fillWidth:true; Layout.fillHeight:true; clip:true; contentWidth:availableWidth
      ColumnLayout {width:parent.width; spacing:16
       Repeater {model:app.step===-1 ? Flow.choices(app.expert) : []
        RadioButton {required property int index; required property var modelData; text:Flow.routeFor(modelData,app.expert).name; checked:app.task===modelData; onClicked:app.dispatch({type:"task",value:modelData}); font.pixelSize:18}
       }
       Label {visible:app.step!==-1; Layout.fillWidth:true; text:app.page.text; wrapMode:Text.WordWrap; lineHeight:1.35}
       ChoiceBox {id:bundle; visible:app.page.id==="bundle"; Layout.fillWidth:true; model:app.route.bundles; currentIndex:Math.max(0,app.route.bundles.indexOf(app.selectedBundle)); onActivated:app.dispatch({type:"bundle",value:currentText})}
       CheckBox {visible:!!app.page.confirm; text:app.page.confirm || ""; checked:app.confirmed; onToggled:app.dispatch({type:"confirm",value:checked})}
       Label {visible:app.page.id==="check"; Layout.fillWidth:true; wrapMode:Text.WordWrap; text:scenario.currentIndex===1 ? Flow.errorText(app.task,1,app.expert) : app.expert ? "✓ Комплект и контрольные суммы\n✓ Совместимость устройства\n✓ Выделенный адаптер и маршрут" : "✓ Роутер подходит\n✓ Подключение готово\n✓ Комплект проверен (имитация)"; color:scenario.currentIndex===1?theme.danger:theme.success; lineHeight:1.5}
       ActionButton {visible:app.page.id==="check" && scenario.currentIndex===1; text:"Повторить проверку — имитация"; onClicked:app.dispatch({type:"recheck"})}
       Label {visible:app.executing; Layout.fillWidth:true; wrapMode:Text.WordWrap; text:app.failed ? (app.state.scenario===4 ? "Результат не подтверждён. Повторите проверку; прошивка заново не записывается." : Flow.errorText(app.task,app.state.scenario,app.expert)) : app.state.verifying ? "Проверяем результат — успех ещё не подтверждён" : Flow.phase(app.task, app.progress); font.bold:true; color:app.failed?theme.danger:theme.text}
       ProgressBar {visible:app.executing; Layout.fillWidth:true; from:0; to:100; value:app.progress}
       Label {visible:app.executing; text:"Ход имитации: "+app.progress+" %"; color:theme.muted}
       ActionButton {visible:app.failed; text:app.expert ? "Повторить этап" : "Повторить проверку"; onClicked:app.dispatch({type:"retry"})}
       Label {visible:app.page.id==="result" && app.state.verified; text:"✓ Имитация завершена. Устройство не изменялось.\nВыбранный комплект: "+app.selectedBundle; color:theme.success; Layout.fillWidth:true; wrapMode:Text.WordWrap}
      }
     }
     ColumnLayout {visible:!!app.page.resetPhoto; Layout.preferredWidth:300; Layout.alignment:Qt.AlignTop; spacing:8
      Item {Layout.preferredWidth:300; Layout.preferredHeight:300
       Image {anchors.fill:parent; source:"qrc:/images/tl-mr3020-3.jpg"; fillMode:Image.PreserveAspectFit}
       // Original square photo: WPS/RESET centre is at (27%, 65%).
       Rectangle {x:72; y:176; width:18; height:42; radius:9; color:"transparent"; border.color:"#d97706"; border.width:3}
       Rectangle {x:91; y:195; width:80; height:3; color:"#d97706"}
       Label {x:172; y:182; text:"WPS/RESET"; color:"#111111"; font.bold:true; padding:5; background:Rectangle{color:"#ffd166";radius:4}}
      }
      Label {text:"TP-Link TL-MR3020 · EU v3.30\nКнопка WPS/RESET сверху корпуса"; color:theme.muted; Layout.fillWidth:true; wrapMode:Text.WordWrap}
     }
    }
    RowLayout {Layout.fillWidth:true
     ActionButton {text:"Назад"; visible:app.step>=-1 && !app.executing && app.page.id!=="result"; onClicked:app.dispatch({type:"back"})}
     Item {Layout.fillWidth:true}
     ActionButton {visible:!app.executing; highlighted:true; text:app.page.next ? app.page.next : app.page.id==="result" ? "Начать заново" : app.page.id==="reset" ? "Имитировать подачу питания" : app.page.id==="check" && app.task===1 ? "Имитировать установку" : "Далее"
      enabled:app.page.id==="result" || Flow.canNext(app.state)
      onClicked:app.dispatch(app.page.id==="result" ? {type:"request",action:"reset"} : {type:"next"})
     }
    }
   }
  }
  RowLayout {visible:!app.realMode
   Label {text:"Проверка макета";color:theme.muted}
   ChoiceBox {id:scenario; Layout.fillWidth:true; currentIndex:app.state.scenario; onActivated:app.dispatch({type:"scenario",value:currentIndex}); enabled:!app.executing && app.page.id!=="result"; model:app.task===1 ? ["Успешная установка","Нет кабеля","Ошибка SSH","Ошибка установки пакетов","Не пройдена итоговая проверка"] : app.task===2 ? ["Успешный возврат","Нет кабеля","Тайм-аут загрузки","Не восстановлен DHCP","Не пройдена итоговая проверка"] : ["Успешная установка","Кабель не подключён","Роутер долго включается","Нет адреса компьютера","Не пройдена итоговая проверка"]}
   ActionButton {text:"Подробности";onClicked:log.open()}
   ActionButton {text:"Отменить сценарий";onClicked:app.dispatch({type:"request",action:"reset"})}
  }
 }
 Dialog {
  id:interruption; anchors.centerIn:parent; width:620; modal:true; title:app.state.pending==="close" ? (app.realMode ? "Закрытие мастера" : "Закрытие макета") : "Отмена сценария"
  closePolicy:Popup.NoAutoClose
  onRejected:app.dispatch({type:"dismiss"})
  contentItem:Label {text:app.realMode ? "Закрыть мастер? Резервная копия и журнал этапа останутся на ПК. Если результат установки не подтверждён, при следующем запуске сначала выполните проверку." : Flow.interruptionText(app.state); wrapMode:Text.WordWrap; color:theme.text}
  background:Rectangle {color:theme.panel; border.color:theme.border; radius:10}
  footer:RowLayout {
   ActionButton {text:"Продолжить сценарий"; onClicked:{app.dispatch({type:"dismiss"});interruption.close()}}
   Item {Layout.fillWidth:true}
   ActionButton {text:app.state.pending==="close" ? (app.realMode ? "Закрыть мастер" : "Закрыть макет") : "Начать заново"; onClicked:{app.dispatch({type:"accept"});interruption.close()}}
  }
 }
 Dialog {id:log; anchors.centerIn:parent; width:650; title:"Журнал имитации"; standardButtons:Dialog.Close; TextArea{width:600;text:app.report;readOnly:true;wrapMode:Text.Wrap}}
}
