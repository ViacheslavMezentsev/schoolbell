import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id:pane
 property var colors
 property bool recovery:false
 property string selectedGuid:""
 readonly property string phase:firmwareBackend.stage
 readonly property bool selecting:phase==="connection" || phase==="checked" || phase==="checking"
 readonly property string startText:recovery?"Начать восстановление":"Установить OpenWrt"
 signal packagesRequested()
 color:colors.panel;border.color:colors.border;radius:14
 onRecoveryChanged:{selectedGuid="";modelConfirmed.checked=false;firmwareBackend.newSession()}
 onVisibleChanged:if(!visible){selectedGuid="";modelConfirmed.checked=false;firmwareBackend.newSession()}
 component Action: Button {
  id:control;implicitHeight:46;leftPadding:16;rightPadding:16;font.bold:true;hoverEnabled:true
  opacity:enabled?1:0.55
  contentItem:Text {text:control.text;font:control.font;color:pane.colors.text;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
  background:Rectangle {radius:8;color:control.down||control.hovered?pane.colors.soft:pane.colors.panel;border.color:control.visualFocus?pane.colors.accent:pane.colors.border;border.width:control.visualFocus?2:1}
 }
 Connections {target:firmwareBackend
  function onChoicesChanged(){let found=-1;for(let i=0;i<firmwareBackend.choices.length;i++)if(firmwareBackend.choices[i].guid===pane.selectedGuid)found=i;adapter.currentIndex=found;if(found<0)pane.selectedGuid=""}
 }
 function heading(){
  switch(phase){
   case "checking":return "Проверяем подключение";
   case "checked":return "Подключение проверено";
   case "preparing":return "Подготавливаем сеть и сервер";
   case "ready":return "Сервер готов — подключите питание с Reset";
   case "transferring":return "Передаём прошивку · "+Math.round(firmwareBackend.progress*100)+" %";
   case "transferred":case "boot-wait":return "Ждём записи и загрузки роутера";
   case "restoring":return "Восстанавливаем сеть компьютера";
   case "recovery":return "Нужно восстановить сеть компьютера";
   case "verify":return "Передача завершена — проверьте роутер";
   case "complete":return "Роутер работает — проверено вами";
   case "interrupted":return "Предыдущая операция прервана";
   default:return "Подключите роутер и выберите адаптер";
  }
 }
 ColumnLayout {
  anchors.fill:parent;anchors.margins:20;spacing:12
  Label {text:pane.recovery?"Восстановление заводской прошивки":"Установка OpenWrt";font.pixelSize:24;font.bold:true;color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
  Label {text:"Подключение → Подготовка → Reset → Передача → Проверка результата";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
  ScrollView {
   id:scroll;Layout.fillWidth:true;Layout.fillHeight:true;clip:true;contentWidth:availableWidth
   ColumnLayout {
    width:scroll.availableWidth;spacing:12
    ColumnLayout {visible:pane.selecting;Layout.fillWidth:true
     Label {text:"Нужны TL-MR3020 EU v3.30, его питание, отдельный USB–Ethernet и кабель. Подключите роутер к этому адаптеру. Пока не нажимайте Reset.";color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
     RowLayout {Layout.fillWidth:true
      StyledComboBox {id:adapter;objectName:"firmware-adapter";Layout.fillWidth:true;colors:pane.colors;textRole:"label";model:firmwareBackend.choices;currentIndex:-1;enabled:!firmwareBackend.busy
       displayText:pane.selectedGuid.length?currentText:"Выберите USB–Ethernet"
       onActivated:function(index){pane.selectedGuid=firmwareBackend.choices[index].guid;firmwareBackend.selectAdapter(pane.selectedGuid,firmwareBackend.choices[index].label)}
      }
      Action {text:"↻";implicitWidth:48;font.pixelSize:28;enabled:!firmwareBackend.busy;Accessible.name:"Обновить список адаптеров";onClicked:{pane.selectedGuid="";firmwareBackend.inspect()}}
     }
     CheckBox {id:modelConfirmed;objectName:"firmware-model-confirmed";text:"На корпусе указано TL-MR3020 EU v3.30";enabled:!firmwareBackend.busy;onCheckedChanged:firmwareBackend.modelChoice(checked)}
     Label {text:pane.recovery?"Будет записана заводская TP-Link Build250625. OpenWrt и Школьник будут удалены. Старый пароль TP-Link может сохраниться.":"Будет записана OpenWrt 19.07.9. Текущая система будет заменена. Комплект Школьника устанавливается следующим этапом.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    }
    RowLayout {visible:pane.phase==="ready";Layout.fillWidth:true
     Label {text:"1. Отключите питание только выбранного роутера.\n2. Зажмите WPS/RESET и подайте питание.\n3. Когда начнётся передача, отпустите кнопку.\n\nДалее питание не отключайте. Сервер ждёт до 3 минут.";font.pixelSize:18;color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
     ColumnLayout {Layout.preferredWidth:170
      Image {id:photo;source:"qrc:/firmware/reset.jpg";Layout.preferredWidth:170;Layout.preferredHeight:170;fillMode:Image.PreserveAspectFit
       Rectangle {x:photo.width*0.25;y:photo.height*0.58;width:photo.width*0.04;height:photo.height*0.15;radius:5;color:"transparent";border.width:2;border.color:pane.colors.warning}
      }
      Label {text:"WPS/RESET — кнопка слева";color:pane.colors.muted;Layout.preferredWidth:170;wrapMode:Text.WordWrap}
     }
    }
    Label {visible:pane.phase==="verify" || pane.phase==="complete";text:"Передача файла: завершена.\nСеть компьютера: восстановлена.\nЗагрузка роутера: "+(pane.phase==="complete"?"подтверждена вами.":"нужно проверить вход и версию.")+"\n\nОжидается: "+firmwareBackend.receiptLabel;color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    Action {id:help;checkable:true;text:(checked?"▾ ":"▸ ")+"Справка"}
    Label {visible:help.checked;text:"Проверка подключения читает параметры адаптера и ищет конфликты без изменения сети. Основная кнопка сама подготовит сеть и запустит сервер; подтвердите запрос Windows UAC. Нужны Windows 11 и PowerShell 7.\n\nСохранение важных настроек необязательно для запуска, но их лучше скопировать заранее. Для передачи пароль не нужен. После восстановления используйте прежний пароль TP-Link; если он забыт, сбросьте настройки отдельно на загруженном роутере. Ключ Wi-Fi не заменяет пароль администратора.\n\nПосле установки OpenWrt задайте пароль root через LuCI и переходите к комплекту. Передача файла сама по себе не подтверждает загрузку системы.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    Action {id:diagnostics;checkable:true;text:(checked?"▾ ":"▸ ")+"Диагностика сети (необязательно)"}
    ColumnLayout {visible:diagnostics.checked;Layout.fillWidth:true
     Label {text:"Проверка изменения адреса без передачи прошивки. После неё восстановите сеть. Для обычной установки этот шаг не нужен.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
     Action {objectName:"network-prepare";text:"Проверить подготовку сети…";enabled:firmwareBackend.canPrepare && !firmwareBackend.needsNetworkRestore && !firmwareBackend.busy;onClicked:networkConfirm.open()}
    }
   }
  }
  Rectangle {
   objectName:"firmware-operation-panel";Layout.fillWidth:true;implicitHeight:statusColumn.implicitHeight+24
   radius:10;color:pane.colors.soft;border.color:pane.colors.border
   ColumnLayout {id:statusColumn;anchors.fill:parent;anchors.margins:12;spacing:8
    Label {text:pane.heading();font.bold:true;font.pixelSize:19;color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    Label {visible:firmwareBackend.networkRestored;text:"✓ Восстановление сети завершено";font.bold:true;color:pane.colors.success;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    Label {text:firmwareBackend.busy?firmwareBackend.message:(pane.phase==="checked"?"Нажмите «"+pane.startText+"». Мастер подготовит сеть автоматически.":pane.phase==="verify"?"Нажмите «Открыть интерфейс роутера», войдите и сверьте указанную версию. Отмечать результат в мастере не требуется.":pane.phase==="complete"?"Проверка завершена. Можно выбрать следующую задачу.":(pane.phase==="connection" && firmwareBackend.message.length>0?firmwareBackend.message:firmwareBackend.flashBlockReason));color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    Label {objectName:"firmware-countdown";visible:firmwareBackend.countdown.length>0;text:(pane.phase==="ready"?"Ожидание запроса роутера · осталось ":"Ожидание записи и загрузки · осталось ")+firmwareBackend.countdown;font.bold:true;font.pixelSize:21;color:pane.colors.accent;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    Label {visible:pane.phase==="restoring";text:"Ожидаем адрес от роутера. Точный срок зависит от DHCP; результат появится здесь.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    ProgressBar {id:progress;visible:firmwareBackend.busy;Layout.fillWidth:true;from:0;to:1;value:firmwareBackend.progress
     background:Rectangle {implicitHeight:8;radius:4;color:pane.colors.border}
     contentItem:Item {implicitHeight:8;Rectangle {width:progress.visualPosition*parent.width;height:parent.height;radius:4;color:pane.colors.accent}}
    }
    Label {text:firmwareBackend.logSaved;visible:text.length>0;color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WrapAnywhere}
    Flow {Layout.fillWidth:true;spacing:8
     Action {objectName:"firmware-check";text:"Проверить подключение";visible:pane.phase==="connection" || pane.phase==="checking";enabled:!firmwareBackend.busy && pane.selectedGuid.length>0 && modelConfirmed.checked;onClicked:firmwareBackend.inspect(pane.selectedGuid,pane.recovery?"factory":"openwrt",true)}
     Action {objectName:"firmware-start";text:pane.startText;visible:pane.phase==="checked";enabled:firmwareBackend.canFlash;onClicked:flashConfirm.open()}
     Action {objectName:"network-restore";text:"Восстановить сеть…";visible:pane.phase==="recovery";enabled:!firmwareBackend.busy;onClicked:restoreConfirm.open()}
     Action {objectName:"firmware-open";text:"Открыть интерфейс роутера";visible:pane.phase==="verify" || pane.phase==="interrupted";enabled:!firmwareBackend.busy;onClicked:Qt.openUrlExternally("http://192.168.1.1")}
     Action {objectName:"firmware-open-log";text:"Открыть лог действий";visible:firmwareBackend.canOpenLog;onClicked:firmwareBackend.openLog()}
     Action {text:"Новая операция";visible:pane.phase==="complete" || pane.phase==="verify";onClicked:{firmwareBackend.newSession();pane.selectedGuid="";modelConfirmed.checked=false}}
     Action {text:"Установить комплект Школьника";visible:(pane.phase==="complete" || pane.phase==="verify") && !pane.recovery;onClicked:pane.packagesRequested()}
    }
   }
  }
 }
 Dialog {id:flashConfirm;objectName:"firmware-confirm";anchors.centerIn:parent;width:Math.min(580,pane.width-32);modal:true;title:pane.startText+"?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:parent.width;wrapMode:Text.WordWrap;text:"Текущая система роутера будет заменена. Используется выбранный USB–Ethernet. Подтвердите запрос Windows, затем дождитесь сообщения «Сервер готов» перед действиями с Reset и питанием."}
  onAccepted:firmwareBackend.flash()
 }
 Dialog {id:restoreConfirm;anchors.centerIn:parent;width:Math.min(560,pane.width-32);modal:true;title:"Восстановить сеть?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:parent.width;wrapMode:Text.WordWrap;text:"Мастер вернёт настройки адаптера из сохранённого журнала. Подключите тот же USB–Ethernet и подтвердите запрос Windows."}
  onAccepted:firmwareBackend.changeNetwork(true)
 }
 Dialog {id:networkConfirm;objectName:"network-confirm";anchors.centerIn:parent;width:Math.min(560,pane.width-32);modal:true;title:"Проверить подготовку сети?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:parent.width;wrapMode:Text.WordWrap;text:"Адрес выбранного адаптера временно изменится. Сервер не запускается. После проверки нажмите «Восстановить сеть»."}
  onAccepted:firmwareBackend.changeNetwork(false)
 }
}
