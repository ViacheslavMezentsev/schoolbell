import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
Rectangle {
 id: pane
 Component.onCompleted:{realBackend.refreshConnections();realBackend.refreshBundles()}
 FileDialog {
  id:bundleDialog;objectName:"bundle-file-dialog"
  title:"Выберите ZIP-комплект Школьника"
  fileMode:FileDialog.OpenFile
  nameFilters:["ZIP-комплекты (*.zip)"]
  onAccepted:realBackend.selectBundleUrl(selectedFile)
 }
 property string pendingAction:"install"
 function run(action,trustHost=false) {
  pendingAction=action;
  let secret=password.text;
  password.revealed=false;
  realBackend.start(action,selectedSource,selectedIndex,secret,trustHost);
  secret="";
 }
 property string selectedSource: realBackend.sourceIP
 property int selectedIndex: realBackend.adapterIndex
 property bool connectionSelected: false
 onVisibleChanged: {if(!visible) password.clear(); else {realBackend.refreshConnections();realBackend.refreshBundles();}}
 Connections {target:realBackend;function onSessionReset(){password.clear();pane.selectedSource="";pane.selectedIndex=0;pane.connectionSelected=false;realBackend.refreshConnections();connection.currentIndex=-1}}
 property bool helpVisible:false
 property var colors
 component RealButton: Button {
  id:control;implicitHeight:48;leftPadding:16;rightPadding:16;font.bold:true;opacity:enabled?1:0.45
  contentItem:Text {text:control.text;font:control.font;color:colors.text;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
  hoverEnabled:true
  background:Rectangle {radius:8;color:control.down||control.checked?colors.soft:colors.panel;border.color:control.visualFocus?colors.accent:colors.border}
 }
 color:colors.panel; border.color:colors.border; radius:14
 ColumnLayout {anchors.fill:parent; anchors.margins:20; spacing:12
  RowLayout {
   Layout.fillWidth:true
   Label {objectName:"section-title";text:"OpenWrt · Комплект";font.pixelSize:25;font.bold:true;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   RealButton {objectName:"work-tab";text:"Установка";checkable:true;checked:!pane.helpVisible;onClicked:pane.helpVisible=false}
   RealButton {objectName:"help-tab";text:"Справка";checkable:true;checked:pane.helpVisible;onClicked:pane.helpVisible=true}
  }
  ScrollView {
   id:formScroll;objectName:"work-scroll";Layout.fillWidth:true;Layout.fillHeight:true
   visible:!pane.helpVisible;clip:true;contentWidth:availableWidth
   ColumnLayout {width:formScroll.availableWidth;spacing:12
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Выберите ZIP и подключение, введите пароль и нажмите «Установить Школьник». Можно установить поверх или повторить после ошибки."}
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.warning;text:"MR3020 v3 · OpenWrt 19.07.9 · 192.168.1.1. Автозвонки должны быть выключены. Reset не нужен."}
  RowLayout {
   Layout.fillWidth:true
   Label {text:"Комплект:"}
   StyledComboBox {colors:pane.colors;id:bundlePicker;objectName:"bundle-picker";Layout.fillWidth:true;implicitHeight:48;font.pixelSize:18
    model:realBackend.bundleChoices;textRole:"label";wrapOptions:true
    property string selectedPath:realBackend.bundlePath
    function syncSelection(){let rows=realBackend.bundleChoices;currentIndex=-1;for(let i=0;i<rows.length;i++)if(rows[i].path===selectedPath){currentIndex=i;break}}
    onSelectedPathChanged:Qt.callLater(syncSelection)
    onModelChanged:Qt.callLater(syncSelection)
    Component.onCompleted:syncSelection()
    displayText:realBackend.zipMode ? realBackend.bundlePath.split(/[\\/]/).pop() : "Выберите ZIP-комплект"
    enabled:!realBackend.busy
    onActivated:function(index){realBackend.selectBundle(realBackend.bundleChoices[index].path)}
   }
   IconButton {objectName:"choose-bundle-file";colors:pane.colors;symbol:"folder";label:"Выбрать файл…";enabled:!realBackend.busy;onClicked:bundleDialog.open()}
   RealButton {text:"↻";font.pixelSize:28;implicitWidth:48;leftPadding:0;rightPadding:0
    enabled:bundlePicker.enabled;Accessible.name:"Найти ZIP рядом с мастером";ToolTip.visible:hovered;ToolTip.text:Accessible.name
    onClicked:realBackend.refreshBundles()}
  }
  Label {objectName:"bundle-source";Layout.fillWidth:true;wrapMode:Text.WrapAnywhere;color:colors.muted
   text:realBackend.bundlePath.length ? "Выбранный архив: "+realBackend.bundlePath : "Архив не выбран"
   textFormat:Text.PlainText
  }
  Label {objectName:"bundle-status";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.muted
   text:realBackend.zipMode ? "Комплект: Школьник "+realBackend.bundleVersion+". Первая установка, обновление и повторная установка." : "Выберите ZIP рядом с мастером из списка или нажмите «Выбрать файл…»."}

  RowLayout {
   Layout.fillWidth:true
   Label {text:"Подключение к роутеру:"}
   StyledComboBox {
    colors:pane.colors
    id:connection;objectName:"connection-picker";Layout.fillWidth:true;implicitHeight:48
    model:realBackend.connections;textRole:"label";currentIndex:-1
    displayText:["ready","uncertain","done","current","backedup"].indexOf(realBackend.stage)>=0 ? realBackend.connectionLabel(pane.selectedSource,pane.selectedIndex) : pane.connectionSelected ? currentText : "Выберите выделенный USB–Ethernet"
    enabled:!realBackend.busy
    onActivated:{let row=realBackend.connections[currentIndex];password.clear();pane.selectedSource=row.source;pane.selectedIndex=row.index;pane.connectionSelected=true}
   }
   RealButton {text:"↻";font.pixelSize:28;implicitWidth:48;leftPadding:0;rightPadding:0;Accessible.name:"Обновить список подключений";ToolTip.visible:hovered;ToolTip.text:Accessible.name;enabled:connection.enabled;onClicked:{password.clear();pane.connectionSelected=false;realBackend.refreshConnections();connection.currentIndex=-1}}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.muted
   text:realBackend.connections.length ? "Выберите USB–Ethernet, подключённый к нужному роутеру." : "Подключите USB–Ethernet к роутеру и нажмите ↻."}

  RowLayout {
   Label {text:"Пароль root:"}
   PasswordField {id:password;clearOnHide:false;objectName:"router-password";colors:pane.colors;Layout.fillWidth:true;enabled:!realBackend.busy;placeholderText:"Пароль администратора OpenWrt (root)"}
  }
  Label {objectName:"root-password-hint";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:pane.colors.muted
   text:"На новой OpenWrt сначала задайте пароль root через LuCI (Система → Администрирование). Здесь введите тот же пароль, что используете для входа в LuCI."}
  Flow {Layout.fillWidth:true;spacing:6
   RealButton {objectName:"install-button";text:"Установить Школьник "+realBackend.bundleVersion;enabled:!realBackend.busy && realBackend.bundlePath.length>0 && pane.selectedSource.length>0 && password.text.length>0;onClicked:confirm.open()}
   RealButton {objectName:"prepare-button";text:"Проверить устройство";enabled:!realBackend.busy && realBackend.bundlePath.length>0 && pane.selectedSource.length>0 && password.text.length>0;onClicked:run("prepare")}
   RealButton {text:"Проверить результат";enabled:!realBackend.busy && realBackend.bundlePath.length>0 && pane.selectedSource.length>0 && password.text.length>0;onClicked:run("verify")}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;font.bold:true;color:realBackend.stage==="done"?colors.success:colors.warning
   text:realBackend.busy?realBackend.operationMessage:realBackend.stage==="authentication-error"?"Не удалось войти как root. Проверьте пароль OpenWrt, исправьте его в поле и повторите действие. Новый сеанс не нужен.":realBackend.stage==="done"?"Установка проверена. При необходимости можно установить повторно.":realBackend.stage==="uncertain"||realBackend.stage==="error"?"Последний результат не подтверждён. Можно проверить результат или повторить установку.":"Проверка и резервная копия необязательны. Настройки сохраняются при установке поверх."}
  Label {id:schoolbellLink;objectName:"schoolbell-link";visible:!realBackend.busy && realBackend.installationAttempted;Layout.fillWidth:true;wrapMode:Text.WrapAnywhere;textFormat:Text.RichText
   text:'Интерфейс Школьника: <a href="http://192.168.1.1/cgi-bin/luci/admin/schoolbell">http://192.168.1.1/cgi-bin/luci/admin/schoolbell</a>'
   color:pane.colors.text;linkColor:pane.colors.accent;onLinkActivated:Qt.openUrlExternally(link)
   HoverHandler {cursorShape:schoolbellLink.hoveredLink.length>0?Qt.PointingHandCursor:Qt.ArrowCursor}
   ToolTip.visible:hoveredLink.length>0
   ToolTip.delay:400
   ToolTip.text:"Открыть интерфейс Школьника"
  }
  Label {visible:!realBackend.busy && realBackend.installationAttempted && realBackend.stage!=="done";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:pane.colors.muted;text:"После ошибки установки доступность интерфейса не подтверждена."}
  RealButton {text:"Подтвердить новый SSH-ключ…";visible:!realBackend.busy && realBackend.hostKeyWarning.length>0;onClicked:hostConfirm.open()}
  RealButton {objectName:"firmware-backup";text:"Сохранить полную копию (необязательно)";enabled:!realBackend.busy && pane.selectedSource.length>0 && password.text.length>0;onClicked:run("backup")}
  RealButton {objectName:"cancel-operation";text:"Отменить операцию";visible:realBackend.busy;enabled:realBackend.canCancel;onClicked:realBackend.requestCancel()}
  ProgressBar {
   id:operationProgress;objectName:"package-progress";Layout.fillWidth:true;indeterminate:true;visible:realBackend.busy
   Accessible.name:"Выполняется операция; время завершения неизвестно"
   background:Rectangle {implicitHeight:8;radius:4;color:pane.colors.border}
   contentItem:Item {
    implicitHeight:8;clip:true
    Rectangle {id:movingSegment;objectName:"package-progress-segment";width:parent.width*0.28;height:parent.height;radius:4;color:pane.colors.accent
     NumberAnimation on x {from:-movingSegment.width;to:operationProgress.availableWidth;duration:1400;loops:Animation.Infinite;running:operationProgress.visible && realBackend.busy}
    }
   }
  }
  Rectangle {
   Layout.fillWidth:true;Layout.preferredHeight:140;Layout.minimumHeight:140
   color:colors.bg;border.color:colors.border;radius:8
   ScrollView {id:outputScroll;anchors.fill:parent;anchors.margins:10;anchors.rightMargin:62;contentWidth:availableWidth;clip:true
    TextArea {text:realBackend.report;readOnly:true;selectByMouse:true;wrapMode:TextEdit.Wrap;font.pixelSize:13;padding:0;background:null
     onTextChanged:Qt.callLater(function(){outputScroll.ScrollBar.vertical.position=Math.max(0,1-outputScroll.ScrollBar.vertical.size)})}
   }
   RealButton {id:copyReport;objectName:"copy-report";anchors.right:parent.right;anchors.top:parent.top;anchors.margins:6
    text:copied?"✓":"⧉";font.pixelSize:24;implicitWidth:48;leftPadding:0;rightPadding:0
    property bool copied:false
    enabled:realBackend.report.length>0;Accessible.name:"Копировать результаты";ToolTip.visible:hovered;ToolTip.text:copied?"Скопировано":"Копировать все результаты"
    onClicked:{realBackend.copyReport();copied=true;copiedTimer.restart()}
    Timer {id:copiedTimer;interval:2000;onTriggered:copyReport.copied=false}
   }
  }
  Flow {Layout.fillWidth:true;spacing:6
   RealButton {objectName:"new-session";text:"Новый сеанс";enabled:!realBackend.busy;onClicked:newSessionConfirm.open()}
   RealButton {text:"Открыть резервную копию";implicitHeight:48;onClicked:realBackend.openBackup()}
   RealButton {text:"Архив копий";onClicked:realBackend.openHistory()}
   RealButton {text:"Открыть Школьник";implicitHeight:48;enabled:!realBackend.busy && realBackend.installationAttempted;onClicked:realBackend.openDevice()}
  }
   }
  }
  ScrollView {
   id:helpScroll;objectName:"help-scroll";Layout.fillWidth:true;Layout.fillHeight:true
   visible:pane.helpVisible;clip:true;contentWidth:availableWidth
   ColumnLayout {width:helpScroll.availableWidth;spacing:16
    Repeater {
     model:[
      {title:"Что понадобится",body:"Роутер с OpenWrt, питание, USB–Ethernet и кабель RJ45, ZIP-комплект и пароль root. На новой OpenWrt задайте пароль через LuCI. Reset для пакетов не нужен."},
      {title:"Установка",body:"Выберите ZIP рядом с EXE, подключение и введите пароль. «Установить Школьник» работает для новой установки, обновления, той же версии и повтора после ошибки. Предварительная проверка и полная копия необязательны. Зависимости, уже имеющиеся в OpenWrt, сохраняются; отсутствующие добавляются. Настройки не удаляются. Сеть, часы и громкость мастер не меняет."},
      {title:"Ошибки и повтор",body:"Каждое нажатие установки создаёт отдельную попытку, сохраняя предыдущие материалы. Ручной новый сеанс не требуется. Ошибка связи, пароля или opkg показывается в протоколе; исправьте причину и повторите. Успех показывается только после проверки версии, служб и выключенных автозвонков. Проверка не обещает совместимость любого комплекта с любой OpenWrt."},
      {title:"Ключ SSH",body:"После перепрошивки ключ роутера меняется. Мастер показывает отпечаток и предлагает подтвердить новый ключ. Подтверждение относится только к показанному ключу; затем повторяется выбранное действие. Пароль остаётся в текущей вкладке, глазок позволяет проверить ввод."},
      {title:"Копии и результаты",body:"Полная копия сохраняется отдельной кнопкой и не обязательна для установки. ⧉ копирует протокол. Старые сеансы и копии сохраняются на ПК. Не публикуйте их: они могут содержать частные настройки. Во время установки не отключайте питание и кабель."}
     ]

     delegate:ColumnLayout {required property var modelData;Layout.fillWidth:true;spacing:6
      Label {text:modelData.title;font.bold:true;font.pixelSize:20;Layout.fillWidth:true;wrapMode:Text.WordWrap}
      Label {text:modelData.body;Layout.fillWidth:true;wrapMode:Text.WordWrap}
     }
    }
   }
  }
 }
 Dialog {id:recoveryConfirm;anchors.centerIn:parent;width:580;modal:true;title:"Восстановить локальный сеанс?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:530;wrapMode:Text.WordWrap;text:"Мастер проверит, завершился ли прежний процесс, и сохранит оставшиеся блокировки в архиве. Копии сохранятся. Установка не повторяется. После начавшейся записи потребуется проверка результата на роутере."}
  onAccepted:realBackend.recoverSession()
 }
 Dialog {id:newSessionConfirm;anchors.centerIn:parent;width:580;modal:true;title:"Начать новый сеанс?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:530;wrapMode:Text.WordWrap;text:"Предыдущие резервные копии и протокол сохранятся в архиве на компьютере. Пароль будет очищен. Для следующего обновления потребуется новая проверка и резервная копия. Роутер не изменяется."}
  onAccepted:realBackend.newSession()
 }
 Dialog {id:hostConfirm;anchors.centerIn:parent;width:Math.min(580,pane.width-30);modal:true;title:"Принять SSH-ключ роутера?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:hostConfirm.availableWidth;wrapMode:Text.WrapAnywhere;text:"После перепрошивки ключ меняется. Убедитесь, что выбран ваш роутер. Новый отпечаток:\n"+realBackend.hostKeyWarning}
  onAccepted:run(pendingAction,true)
 }
 Dialog {id:confirm;anchors.centerIn:parent;width:Math.min(580,pane.width-30);modal:true;title:"Установить Школьник "+realBackend.bundleVersion+"?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:confirm.availableWidth;wrapMode:Text.WordWrap;text:"Комплект будет установлен, в том числе поверх имеющейся версии. Настройки сохраняются. Резервная копия необязательна. Громкость, сеть и часы не меняются. Не отключайте питание и кабель."}
  onAccepted:run("install")
 }
}
