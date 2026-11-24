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
   Label {objectName:"section-title";text:"Школьник поверх OpenWrt";font.pixelSize:25;font.bold:true;Layout.fillWidth:true;wrapMode:Text.WordWrap}
   RealButton {objectName:"work-tab";text:"Установка";checkable:true;checked:!pane.helpVisible;onClicked:pane.helpVisible=false}
   RealButton {objectName:"help-tab";text:"Справка";checkable:true;checked:pane.helpVisible;onClicked:pane.helpVisible=true}
  }
  ScrollView {
   id:formScroll;objectName:"work-scroll";Layout.fillWidth:true;Layout.fillHeight:true
   visible:!pane.helpVisible;clip:true;contentWidth:availableWidth
   ColumnLayout {width:formScroll.availableWidth;spacing:12
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Выберите подключение, введите пароль и проверьте устройство. Подробности — в «Справке»."}
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.warning;text:"MR3020 v3 · OpenWrt 19.07.9 · 192.168.1.1. Автозвонки должны быть выключены. Reset не нужен."}
  RowLayout {
   Layout.fillWidth:true
   Label {text:"Подключение к роутеру:"}
   ComboBox {
    id:connection;objectName:"connection-picker";Layout.fillWidth:true;implicitHeight:48
    model:realBackend.connections;textRole:"label";currentIndex:-1
    displayText:["ready","uncertain","done","current","backedup"].indexOf(realBackend.stage)>=0 ? realBackend.connectionLabel(pane.selectedSource,pane.selectedIndex) : pane.connectionSelected ? currentText : "Выберите выделенный USB–Ethernet"
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
   RealButton {text:"↻";font.pixelSize:28;implicitWidth:48;leftPadding:0;rightPadding:0;Accessible.name:"Обновить список подключений";ToolTip.visible:hovered;ToolTip.text:Accessible.name;enabled:connection.enabled;onClicked:{password.clear();pane.connectionSelected=false;realBackend.refreshConnections();connection.currentIndex=-1}}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.muted
   text:["ready","uncertain","done","current","backedup"].indexOf(realBackend.stage)>=0
     ? "Подключение закреплено за сеансом."
     : realBackend.connections.length ? "Выберите отдельный USB–Ethernet, подключённый к роутеру."
     : "Подключений нет. Подключите USB–Ethernet к роутеру и нажмите ↻. Подробнее — в «Справке»."}
  RowLayout {
   Label {text:"Пароль root:"}
   PasswordField {id:password;clearOnHide:false;objectName:"router-password";colors:pane.colors;Layout.fillWidth:true;enabled:!realBackend.busy;placeholderText:"Пароль администратора OpenWrt (root)"}
  }
  Flow {Layout.fillWidth:true;spacing:6
   RealButton {text:"1. Проверить устройство";implicitHeight:48;enabled:!realBackend.busy && ["idle","error","ready"].indexOf(realBackend.stage)>=0 && (pane.connectionSelected || realBackend.stage==="ready") && pane.selectedSource.length>0 && password.text.length>0;onClicked:run("prepare")}
   RealButton {text:"2. Установить 5.1.127";implicitHeight:48;enabled:!realBackend.busy && realBackend.stage==="ready" && password.text.length>0;onClicked:confirm.open()}
   RealButton {text:"Проверить результат";implicitHeight:48;enabled:!realBackend.busy && ["uncertain","done"].indexOf(realBackend.stage)>=0 && password.text.length>0;onClicked:run("verify")}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;font.bold:true;color:["done","current"].indexOf(realBackend.stage)>=0?colors.success:colors.warning;text:realBackend.busy?"Выполняется операция. Не отключайте питание и кабель.":realBackend.stage==="backedup"?"Копия перед прошивкой проверена и сохранена на ПК.":realBackend.stage==="current"?"Школьник уже установлен. Службы проверены, автозвонки выключены.":realBackend.stage==="done"?(realBackend.fresh?"Новая установка проверена. Автозвонки выключены.":"Установка проверена. Автозвонки выключены, громкость сохранена."):realBackend.stage==="ready"?"Резервная копия проверена. Можно подтвердить установку.":realBackend.stage==="uncertain"?"Исход записи требует проверки. Повторная установка заблокирована.":realBackend.stage==="error"?"Операция остановлена. Подробности ниже.":"Начните с проверки устройства и резервной копии."}
  RealButton {objectName:"firmware-backup";text:"Сохранить копию перед прошивкой";visible:realBackend.stage==="current";enabled:!realBackend.busy && password.text.length>0;onClicked:run("backup")}
  ProgressBar {Layout.fillWidth:true;indeterminate:true;visible:realBackend.busy}
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
   RealButton {objectName:"new-session";text:"Новый сеанс";enabled:!realBackend.busy && realBackend.stage!=="uncertain";onClicked:newSessionConfirm.open()}
   RealButton {text:"Открыть резервную копию";implicitHeight:48;onClicked:realBackend.openBackup()}
   RealButton {text:"Архив копий";onClicked:realBackend.openHistory()}
   RealButton {text:"Открыть Школьник";implicitHeight:48;enabled:["done","current"].indexOf(realBackend.stage)>=0;onClicked:realBackend.openDevice()}
  }
   }
  }
  ScrollView {
   id:helpScroll;objectName:"help-scroll";Layout.fillWidth:true;Layout.fillHeight:true
   visible:pane.helpVisible;clip:true;contentWidth:availableWidth
   ColumnLayout {width:helpScroll.availableWidth;spacing:16
    Repeater {
     model:[
      {title:"Что понадобится",body:"Отдельный MR3020 v3 с OpenWrt 19.07.9, его блок питания, USB–Ethernet-адаптер и кабель RJ45. Подключите роутер к отдельному адаптеру. Нужно знать пароль администратора OpenWrt (root); на чистой OpenWrt сначала задайте его через LuCI. Этот режим устанавливает пакеты, а не прошивает OpenWrt или заводскую ОС."},
      {title:"1. Подключение и пароль",body:"Выберите имя подключения, описание карты и IP. Если список пуст, проверьте кабель и наличие IPv4 в сети роутера, затем нажмите ↻. Список не доказывает, что выбран нужный роутер: мастер отдельно проверяет прямой маршрут и устройство. Подключение закрепляется после подготовки; сменить его можно через «Новый сеанс». Пароль хранится только в памяти между операциями. «Справка» не очищает его; выход к макету, закрытие окна, смена подключения или новый сеанс очищают пароль. Глазок показывает и скрывает ввод."},
      {title:"2. Проверить устройство",body:"Перед подготовкой выключите автозвонки. Мастер проверит модель, версию OpenWrt, службы и свободное место. Для установки или обновления он сохранит и проверит резервную копию. BACKUP VERIFIED означает, что можно перейти к установке. ALREADY CURRENT означает, что Школьник 5.1.127 уже установлен и службы проверены: повторная установка не нужна."},
      {title:"3. Установить и проверить",body:"Поддержаны чистая OpenWrt и обновление Школьника с 5.1.124 до 5.1.127. Установка начинается после подтверждения; не отключайте питание и кабель. На чистой системе устанавливаются необходимые зависимости. UPGRADE VERIFIED означает успешную проверку обновления. Мастер не регулирует громкость и не меняет сеть или часы; автозвонки остаются выключенными. При неизвестном исходе записи не повторяйте установку: используйте «Проверить результат». Подробности ошибки находятся в результатах."},
      {title:"Результаты и резервные копии",body:"⧉ копирует весь текст результатов, включая скрытые прокруткой строки. «Открыть резервную копию» открывает каталог на ПК. После проверки актуальной версии доступна отдельная копия всех разделов MTD и overlay перед прошивкой. DEVICE BACKUP VERIFIED подтверждает проверку файлов, но не прошивку. Копии содержат частные настройки; не публикуйте их. «Новый сеанс» архивирует предыдущие материалы и очищает пароль. Неизвестный исход записи сначала требует проверки."},
      {title:"Если окно небольшое",body:"Рабочая форма и справка прокручиваются независимо. Если нижние действия не видны, прокрутите форму вниз. Во время операции можно читать справку: операция продолжится. Для свежей установки восстановление выполняется отдельно: та же OpenWrt через Reset и сохранённый overlay; автоматического отката нет."}
     ]
     delegate:ColumnLayout {required property var modelData;Layout.fillWidth:true;spacing:6
      Label {text:modelData.title;font.bold:true;font.pixelSize:20;Layout.fillWidth:true;wrapMode:Text.WordWrap}
      Label {text:modelData.body;Layout.fillWidth:true;wrapMode:Text.WordWrap}
     }
    }
   }
  }
 }
 Dialog {id:newSessionConfirm;anchors.centerIn:parent;width:580;modal:true;title:"Начать новый сеанс?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:530;wrapMode:Text.WordWrap;text:"Предыдущие резервные копии и протокол сохранятся в архиве на компьютере. Пароль будет очищен. Для следующего обновления потребуется новая проверка и резервная копия. Роутер не изменяется."}
  onAccepted:realBackend.newSession()
 }
 Dialog {id:confirm;anchors.centerIn:parent;width:580;modal:true;title:"Установить Школьник 5.1.127?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:530;wrapMode:Text.WordWrap;text:realBackend.fresh?"Будут установлены Школьник и перечисленные в протоколе зависимости. Копия и образ восстановления сохранены на ПК. Автозвонки останутся выключенными. Во время записи не отключайте питание.":"Будет обновлён пакет на отдельном роутере 192.168.1.1. Копия сохранена на ПК. Автозвонки останутся выключенными; громкость не меняется. Во время записи закрытие мастера заблокировано."}
  onAccepted:run("install")
 }
}
