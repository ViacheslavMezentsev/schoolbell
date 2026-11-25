import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id:pane
 component RouteButton: Button {
  id:control;implicitHeight:48;leftPadding:16;rightPadding:16;font.bold:true;hoverEnabled:true
  opacity:enabled?1:0.55
  contentItem:Text {text:control.text;font:control.font;color:pane.colors.text;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
  background:Rectangle {radius:8;color:control.down||control.hovered?pane.colors.soft:pane.colors.panel;border.color:control.visualFocus?pane.colors.accent:pane.colors.border;border.width:control.visualFocus?2:1}
 }

 property var colors
 property bool recovery:false
 property string selectedGuid:""
 onRecoveryChanged:{selectedGuid="";modelConfirmed.checked=false;firmwareBackend.clearResult()}
 onVisibleChanged:if(!visible){selectedGuid="";modelConfirmed.checked=false;firmwareBackend.clearResult()}
 Connections {target:firmwareBackend
  function onChoicesChanged(){
   let found=-1
   for(let i=0;i<firmwareBackend.choices.length;i++)if(firmwareBackend.choices[i].guid===pane.selectedGuid)found=i
   adapter.currentIndex=found
   if(found<0)pane.selectedGuid=""
  }
 }
 signal packagesRequested()
 color:colors.panel;border.color:colors.border;radius:14
 ScrollView {
  id:scroll;anchors.fill:parent;anchors.margins:20;clip:true;contentWidth:availableWidth
  ColumnLayout {
   width:scroll.availableWidth;spacing:16
   Label {objectName:"firmware-title";text:pane.recovery?"Восстановление · Заводская прошивка":"Новый роутер · OpenWrt";font.pixelSize:25;font.bold:true;color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:pane.recovery?"Возврат TP-Link TL-MR3020 EU v3.30 к заводской системе. Это не восстановление настроек из резервной копии.":"Замена заводской системы на OpenWrt. Установка Школьника — следующая отдельная операция.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:"Что понадобится";font.pixelSize:21;font.bold:true;color:pane.colors.text}
   Label {text:"• TL-MR3020 EU v3.30 и его блок питания.\n• Отдельный USB–Ethernet-адаптер и сетевой кабель.\n• Windows 11, PowerShell 7 и права администратора.\n• Полностью распакованный архив мастера; оба образа встроены в EXE.\n• При необходимости — резервная копия важных настроек.";color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:pane.recovery?"Для передачи через Reset пароль не нужен. После восстановления может понадобиться прежний пароль TP-Link. Если он забыт, потребуется отдельный сброс настроек; ключ Wi-Fi на наклейке не заменяет пароль администратора.":"Для передачи через Reset пароль не нужен. Для сохранения настроек через заводской интерфейс нужен пароль TP-Link. После установки OpenWrt задайте пароль root в LuCI — он понадобится при установке Школьника.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:"Проверка подключения на компьютере";font.pixelSize:21;font.bold:true;color:pane.colors.text}
   RowLayout {
    Layout.fillWidth:true
    StyledComboBox {id:adapter;objectName:"firmware-adapter";Layout.fillWidth:true;colors:pane.colors;textRole:"label";model:firmwareBackend.choices;currentIndex:-1;enabled:!firmwareBackend.busy
     displayText:pane.selectedGuid.length>0?currentText:"Выберите USB–Ethernet-адаптер"
     onActivated:function(index){pane.selectedGuid=firmwareBackend.choices[index].guid;firmwareBackend.clearResult()}
    }
    RouteButton {objectName:"firmware-refresh";text:"↻";font.pixelSize:28;implicitHeight:48;implicitWidth:48;enabled:!firmwareBackend.busy;Accessible.name:"Прочитать список адаптеров";ToolTip.visible:hovered;ToolTip.text:Accessible.name
     onClicked:{pane.selectedGuid="";adapter.currentIndex=-1;firmwareBackend.inspect()}
    }
   }
   CheckBox {id:modelConfirmed;objectName:"firmware-model-confirmed";text:"На корпусе указано TL-MR3020 EU v3.30";enabled:!firmwareBackend.busy;onCheckedChanged:firmwareBackend.clearResult()}
   RouteButton {objectName:"firmware-check";text:"Проверить без изменения сети";padding:14;enabled:!firmwareBackend.busy && pane.selectedGuid.length>0 && modelConfirmed.checked
    onClicked:firmwareBackend.inspect(pane.selectedGuid,pane.recovery?"factory":"openwrt",modelConfirmed.checked)
   }
   Label {text:"Прошивка заменяет текущую систему. При необходимости заранее сохраните настройки.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   Label {text:firmwareBackend.imagesAvailable?(pane.recovery?"Встроенный образ: TP-Link EU v3.30 · Build250625":"Встроенный образ: OpenWrt 19.07.9"):"Встроенные образы повреждены или отсутствуют. Запуск запрещён.";color:firmwareBackend.imagesAvailable?pane.colors.muted:pane.colors.warning;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   RowLayout {
    Layout.fillWidth:true
    ColumnLayout {
     Layout.fillWidth:true
     Label {text:"Порядок действий";font.pixelSize:21;font.bold:true;color:pane.colors.text}
     Label {text:"1. Выберите USB–Ethernet и подтвердите модель.\n2. Нажмите «Проверить без изменения сети», затем кнопку прошивки. Подтвердите запрос Windows.\n3. Только после READY отключите питание нужного роутера, зажмите WPS/RESET и подайте питание. После начала передачи отпустите кнопку.\n4. Не отключайте питание. Мастер дождётся записи и восстановит сеть компьютера.\n5. Откройте интерфейс роутера, сверьте версию и отметьте результат ниже.";color:pane.colors.text;Layout.fillWidth:true;wrapMode:Text.WordWrap}
     Label {objectName:"firmware-availability";text:"Это реальная перепрошивка. Не нажимайте Reset до READY. До запроса роутера сервер ждёт не более 10 минут; остановка не отменяет запись, уже начатую роутером.";color:pane.colors.warning;Layout.fillWidth:true;wrapMode:Text.WordWrap}
    }
    ColumnLayout {
     Layout.preferredWidth:210
     Image {id:routerPhoto;source:"qrc:/firmware/reset.jpg";Layout.preferredWidth:210;Layout.preferredHeight:210;fillMode:Image.PreserveAspectFit
      Rectangle {x:routerPhoto.width*0.25;y:routerPhoto.height*0.58;width:routerPhoto.width*0.04;height:routerPhoto.height*0.15;radius:6;color:"transparent";border.width:2;border.color:pane.colors.warning}
     }
     Label {text:"WPS/RESET — длинная кнопка слева";color:pane.colors.muted;Layout.preferredWidth:210;wrapMode:Text.WordWrap}
    }
   }
   Rectangle {
    objectName:"firmware-operation-panel";Layout.fillWidth:true;implicitHeight:operationContent.implicitHeight+32
    color:"transparent";radius:10;border.width:2;border.color:pane.colors.muted
    ColumnLayout {id:operationContent;anchors.fill:parent;anchors.margins:16;spacing:12
     Label {text:"Прошивка и состояние операции";font.bold:true;font.pixelSize:20;color:pane.colors.text}
   RouteButton {objectName:"firmware-start";text:pane.recovery?"Восстановить заводскую прошивку…":"Установить OpenWrt…";enabled:firmwareBackend.canFlash && !firmwareBackend.busy;onClicked:flashConfirm.open()}
   ProgressBar {
    id:transferProgress;Layout.fillWidth:true;from:0;to:1;value:firmwareBackend.progress;visible:firmwareBackend.busy
    background:Rectangle {implicitHeight:8;radius:4;color:pane.colors.border}
    contentItem:Item {implicitHeight:8
     Rectangle {width:transferProgress.visualPosition*parent.width;height:parent.height;radius:4;color:pane.colors.accent}
    }
   }
   RowLayout {
    RouteButton {objectName:"network-prepare";text:"Подготовить сеть…";padding:14;enabled:firmwareBackend.canPrepare && !firmwareBackend.busy;onClicked:networkConfirm.open()}
    RouteButton {objectName:"network-restore";text:"Восстановить сеть…";padding:14;enabled:!firmwareBackend.busy;onClicked:restoreConfirm.open()}
   }
   Label {objectName:"firmware-result";text:firmwareBackend.message;visible:text.length>0;Layout.fillWidth:true;wrapMode:Text.WordWrap;color:pane.colors.muted}
    }
   }
   Label {text:pane.recovery?"Проверьте TP-Link: 1.8.0 0.9.1 v0001.0 Build250625 Rel.56805n. Прежний пароль может сохраниться. Сброс забытого пароля выполняется отдельно на загруженном роутере.":"Проверьте OpenWrt 19.07.9 и модель TP-Link TL-MR3020 v3 в LuCI. Задайте пароль root, затем переходите к установке комплекта. Пакеты на этом этапе не устанавливаются.";color:pane.colors.muted;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   RowLayout {
    RouteButton {objectName:"firmware-open";text:"Открыть 192.168.1.1";enabled:!firmwareBackend.busy;onClicked:Qt.openUrlExternally("http://192.168.1.1")}
    RouteButton {objectName:"firmware-confirm-result";text:"Отметить проверку загрузки…";enabled:firmwareBackend.canConfirm;onClicked:{resultChecked.checked=false;resultConfirm.open()}}
   }
   RouteButton {
    objectName:"go-packages";visible:!pane.recovery;enabled:!firmwareBackend.busy;Layout.fillWidth:true;padding:14
    text:"OpenWrt уже работает — перейти к установке Школьника"
    contentItem:Label {text:parent.text;color:pane.colors.text;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;font.bold:true}
    background:Rectangle {color:pane.colors.soft;border.color:pane.colors.border;radius:8}
    onClicked:pane.packagesRequested()
   }
  }
 }
 Dialog {id:networkConfirm;objectName:"network-confirm";anchors.centerIn:parent;width:560;modal:true;title:"Подготовить выделенный адаптер?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:510;wrapMode:Text.WordWrap;text:"После подтверждения Windows мастер временно добавит адрес 192.168.0.225 к выбранному USB–Ethernet и проверит прямое подключение к роутеру. Подключение этого адаптера изменится. Сервер не запускается; Reset не нажимайте. После проверки нажмите «Восстановить сеть»."}
  onAccepted:firmwareBackend.changeNetwork(false)
 }
 Dialog {id:restoreConfirm;anchors.centerIn:parent;width:560;modal:true;title:"Восстановить сеть?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:510;wrapMode:Text.WordWrap;text:"После подтверждения Windows мастер удалит собственный временный адрес и вернёт DHCP на адаптере из сохранённого состояния. Подключите тот же USB–Ethernet. Получение нового адреса зависит от DHCP-сервера."}
  onAccepted:firmwareBackend.changeNetwork(true)
 }

 Dialog {id:flashConfirm;objectName:"firmware-confirm";anchors.centerIn:parent;width:600;modal:true;title:pane.recovery?"Вернуть заводскую систему?":"Установить OpenWrt?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:550;wrapMode:Text.WordWrap;text:(pane.recovery?"OpenWrt и Школьник будут удалены. Будет записана заводская Build250625. Старый пароль TP-Link может сохраниться.":"Текущая система и настройки будут заменены OpenWrt 19.07.9. Пакеты Школьника устанавливаются отдельно.")+"\n\nИспользуется выбранный выделенный USB–Ethernet. После UAC дождитесь READY, прежде чем нажимать Reset. Передача не доказывает загрузку; в конце проверьте интерфейс и версию."}
  onAccepted:firmwareBackend.flash()
 }
 Dialog {id:resultConfirm;objectName:"firmware-result-confirm";anchors.centerIn:parent;width:600;modal:true;title:"Проверка пользователем";standardButtons:Dialog.Ok|Dialog.Cancel
  ColumnLayout {
   width:550
   Label {text:"Отмечайте результат только после входа в интерфейс нужного роутера и сверки: "+firmwareBackend.receiptLabel+". Это позволит начать новый опыт; повторная передача сейчас не запускается.";Layout.fillWidth:true;wrapMode:Text.WordWrap}
   CheckBox {id:resultChecked;text:"Вход и указанная версия проверены"}
  }
  onAccepted:if(resultChecked.checked)firmwareBackend.confirmResult()
 }

}
