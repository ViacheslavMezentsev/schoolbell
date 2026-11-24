import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Rectangle {
 id: pane
 Component.onCompleted:{realBackend.refreshConnections();realBackend.refreshBundles()}
 function run(action) {
  let secret=password.text;
  password.revealed=false;
  realBackend.start(action,selectedSource,selectedIndex,secret);
  secret="";
 }
 property string selectedSource: realBackend.sourceIP
 property int selectedIndex: realBackend.adapterIndex
 property bool connectionSelected: false
 onVisibleChanged: {if(!visible) password.clear(); else {realBackend.refreshConnections();realBackend.refreshBundles();if(["idle","error"].indexOf(realBackend.stage)>=0){connectionSelected=false;connection.currentIndex=-1}}}
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
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;text:"Выберите подключение, введите пароль и проверьте устройство. Подробности — в «Справке»."}
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.warning;text:"MR3020 v3 · OpenWrt 19.07.9 · 192.168.1.1. Автозвонки должны быть выключены. Reset не нужен."}
  RowLayout {
   Layout.fillWidth:true
   Label {text:"Комплект:"}
   StyledComboBox {colors:pane.colors;id:bundlePicker;objectName:"bundle-picker";Layout.fillWidth:true;implicitHeight:48;font.pixelSize:18
    model:realBackend.bundleChoices;textRole:"label"
    displayText:realBackend.zipMode ? realBackend.bundlePath.split(/[\\/]/).pop() : "Выберите ZIP-комплект"
    enabled:!realBackend.busy && !realBackend.bundleLocked
    onActivated:{password.clear();realBackend.selectBundle(realBackend.bundleChoices[currentIndex].path)}
   }
   RealButton {text:"↻";font.pixelSize:28;implicitWidth:48;leftPadding:0;rightPadding:0
    enabled:bundlePicker.enabled;Accessible.name:"Найти ZIP рядом с мастером";ToolTip.visible:hovered;ToolTip.text:Accessible.name
    onClicked:realBackend.refreshBundles()}
  }
  Label {objectName:"bundle-status";Layout.fillWidth:true;wrapMode:Text.WordWrap;color:colors.muted
   text:realBackend.zipMode ? realBackend.bundleLocked ? "ZIP закреплён за сеансом. Для другого комплекта начните новый сеанс." : realBackend.bundleReady ? "ZIP проверен локально · Школьник "+realBackend.bundleVersion+" · только чистая OpenWrt. Кандидат: аппаратная приёмка не выполнена." : "Выберите ZIP для локальной проверки. Установка пока недоступна."
    : "Положите ZIP-комплект рядом с EXE и нажмите ↻. Без проверенного архива установка недоступна."}
  RowLayout {
   Layout.fillWidth:true
   Label {text:"Подключение к роутеру:"}
   StyledComboBox {
    colors:pane.colors
    id:connection;objectName:"connection-picker";Layout.fillWidth:true;implicitHeight:48
    model:realBackend.connections;textRole:"label";currentIndex:-1
    displayText:["ready","uncertain","done","current","backedup"].indexOf(realBackend.stage)>=0 ? realBackend.connectionLabel(pane.selectedSource,pane.selectedIndex) : pane.connectionSelected ? currentText : "Выберите выделенный USB–Ethernet"
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
   RealButton {objectName:"prepare-button";text:"1. Проверить устройство";implicitHeight:48;enabled:!realBackend.busy && realBackend.bundleReady && (!realBackend.zipMode || !realBackend.bundleLocked) && ["idle","error","ready","backedup"].indexOf(realBackend.stage)>=0 && (pane.connectionSelected || realBackend.stage==="ready") && pane.selectedSource.length>0 && password.text.length>0;onClicked:run("prepare")}
   RealButton {objectName:"install-button";text:"2. Установить "+realBackend.bundleVersion;implicitHeight:48;enabled:!realBackend.busy && realBackend.stage==="ready" && password.text.length>0;onClicked:confirm.open()}
   RealButton {text:"Проверить результат";implicitHeight:48;enabled:!realBackend.busy && ["uncertain","done"].indexOf(realBackend.stage)>=0 && password.text.length>0;onClicked:run("verify")}
  }
  Label {Layout.fillWidth:true;wrapMode:Text.WordWrap;font.bold:true;color:["done","current"].indexOf(realBackend.stage)>=0?colors.success:colors.warning;text:realBackend.stage==="not-applied"?"Установка не выполнена. Исходное состояние подтверждено. Начните новый сеанс.":realBackend.busy?realBackend.operationMessage:realBackend.stage==="backedup"?"Копия перед прошивкой проверена и сохранена на ПК.":realBackend.stage==="current"?"Школьник уже установлен. Службы проверены, автозвонки выключены.":realBackend.stage==="done"?(realBackend.fresh?"Новая установка проверена. Автозвонки выключены.":"Установка проверена. Автозвонки выключены, громкость сохранена."):realBackend.stage==="ready"?"Резервная копия проверена. Можно подтвердить установку.":realBackend.stage==="uncertain"?"Исход записи требует проверки. Повторная установка заблокирована.":realBackend.stage==="error"?(realBackend.zipMode && realBackend.bundleLocked?"Подготовка остановлена. Сохраните материалы через «Новый сеанс» перед новой попыткой.":"Операция остановлена. Подробности ниже."):"Начните с проверки устройства и резервной копии."}
  RealButton {objectName:"firmware-backup";text:"Сохранить полную копию";enabled:!realBackend.busy && !realBackend.bundleLocked && ["idle","error","current","backedup"].indexOf(realBackend.stage)>=0 && pane.connectionSelected && password.text.length>0;onClicked:run("backup")}
  RealButton {objectName:"cancel-operation";text:"Отменить операцию";visible:realBackend.busy;enabled:realBackend.canCancel;onClicked:realBackend.requestCancel()}
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
      {title:"ZIP рядом с мастером",body:"Положите schoolbell-v…-openwrt-….zip рядом с EXE, нажмите ↻ у комплекта и выберите файл. Проверка ZIP локальная и не требует пароля. Версия берётся из manifest; несовместимый или повреждённый архив блокирует подготовку. Пока ZIP поддерживает только чистую OpenWrt. После подготовки используется проверенная копия ZIP из сеанса, даже если исходный файл удалён или заменён. Смена комплекта требует нового сеанса. GitHub-загрузка пока не подключена."},
      {title:"1. Подключение и пароль",body:"Выберите имя подключения, описание карты и IP. Если список пуст, проверьте кабель и наличие IPv4 в сети роутера, затем нажмите ↻. Список не доказывает, что выбран нужный роутер: мастер отдельно проверяет прямой маршрут и устройство. Подключение закрепляется после подготовки; сменить его можно через «Новый сеанс». Пароль хранится только в памяти между операциями. «Справка» не очищает его; закрытие окна, смена подключения или новый сеанс очищают пароль. Глазок показывает и скрывает ввод."},
      {title:"2. Проверить устройство",body:"Перед подготовкой выключите автозвонки. Мастер проверит модель, версию OpenWrt, службы и свободное место. Для установки он сохранит и проверит резервную копию. BACKUP VERIFIED означает, что можно перейти к установке. Если Школьник уже установлен, свежая ZIP-установка будет отклонена без записи."},
      {title:"3. Установить и проверить",body:"Внешний ZIP пока поддерживает только чистую OpenWrt. Установка начинается после подтверждения; не отключайте питание и кабель. На чистой системе устанавливаются необходимые зависимости. FRESH VERIFIED означает успешную проверку установки. Мастер не регулирует громкость и не меняет сеть или часы; автозвонки остаются выключенными. При неизвестном исходе записи не повторяйте установку: используйте «Проверить результат». Подробности ошибки находятся в результатах."},
      {title:"Результаты и резервные копии",body:"⧉ копирует весь текст результатов, включая скрытые прокруткой строки. «Открыть резервную копию» открывает каталог на ПК. Отдельная кнопка сохраняет все разделы MTD и overlay, даже без выбранного ZIP. DEVICE BACKUP VERIFIED подтверждает проверку файлов, но не прошивку. Копии содержат частные настройки; не публикуйте их. «Новый сеанс» архивирует предыдущие материалы и очищает пароль. Неизвестный исход записи сначала требует проверки."},
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
 Dialog {id:confirm;anchors.centerIn:parent;width:580;modal:true;title:"Установить Школьник "+realBackend.bundleVersion+"?";standardButtons:Dialog.Ok|Dialog.Cancel
  Label {width:530;wrapMode:Text.WordWrap;text:realBackend.fresh?"Будут установлены Школьник и перечисленные в протоколе зависимости. Копия и образ восстановления сохранены на ПК. Автозвонки останутся выключенными. Во время записи не отключайте питание.":"Будет обновлён пакет на отдельном роутере 192.168.1.1. Копия сохранена на ПК. Автозвонки останутся выключенными; громкость не меняется. Во время записи закрытие мастера заблокировано."}
  onAccepted:run("install")
 }
}
