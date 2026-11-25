import QtQuick
import QtTest
import "../qml"
Item {
 id:root
 width: 1100; height: 750
 QtObject {
  id: realBackend
  property string sourceIP: "192.0.2.2"
  property int adapterIndex: 1
  property bool busy: false
  property bool installationAttempted:false
  property string hostKeyWarning:""
  property bool interrupted:false
  function recoverSession() {}
  property bool canCancel:false
  property string operationMessage:"Выполняется проверка"
  function requestCancel(){canCancel=false}
  function requestStop(){canCancel=false;report="stop-requested"}
  property bool fresh: false
  property string stage: "idle"
  property string report: ""
  property var connections: []
  property var bundleChoices: [{label:"Local ZIP",path:"fixture.zip"}]
  property string bundlePath:""
  property string bundleVersion:"5.1.127"
  property bool zipMode:false
  property bool bundleReady:false
  property bool bundleLocked:false
  function refreshBundles() {}
  function selectBundle(path){bundlePath=path;zipMode=path.length>0;bundleReady=false}

  signal sessionReset()
  function refreshConnections() {}
  function connectionLabel(ip,index) {return ip}
  property string copiedReport:""
  function copyReport(){copiedReport=report}
  property string received: ""
  function start(action, source, adapter, secret) { received=secret; stage=action==="prepare"?"ready":"done" }
 }
 QtObject {
  id:firmwareBackend
  property string stage:"connection"
  property string countdown:""
  property string logSaved:""
  property string flashBlockReason:""
  property bool canOpenLog:false
  property bool networkRestored:false
  property bool needsNetworkRestore:false
  function newSession(){message="";stage="connection"}
  function selectAdapter(guid,label){clearResult()}
  function modelChoice(checked){clearResult()}
  property bool canPrepare:false
  property bool canFlash:false
  property bool canConfirm:false
  property bool imagesAvailable:true
  property real progress:0
  property string receiptLabel:"OpenWrt 19.07.9"
  function flash(){helperAction="flash"}
  function requestStop(){helperAction="stop"}
  function confirmResult(){helperAction="confirm"}
  property string helperAction:""
  function changeNetwork(restore) {helperAction=restore?"restore":"prepare"}
  property bool busy:false
  property var choices:[]
  property string message:""
  property string selectedProfile:""
  function clearResult(){message="";canPrepare=false}
  function inspect(guid,profile,confirmed){selectedProfile=profile||"openwrt";message="Сеть не изменена"}
 }
 Component {id:windowFactory; Main {}}
 Theme {id: theme}
 RealPane {id:pane;anchors.fill:parent;colors:theme}
 TestCase {
  name: "PasswordLifecycle"; when: windowShown
  function test_header_stop_requires_confirmation() {
   let window=windowFactory.createObject(root);window.navigate("openwrt")
   let stop=findChild(window,"stop-route"),dialog=findChild(window,"stop-route-confirm")
   firmwareBackend.helperAction="";firmwareBackend.busy=true;stop.clicked();verify(dialog.visible);compare(firmwareBackend.helperAction,"")
   dialog.close();compare(firmwareBackend.helperAction,"")
   stop.clicked();findChild(window,"stop-route-accept").clicked();compare(firmwareBackend.helperAction,"stop")
   firmwareBackend.busy=false;stop.clicked();findChild(window,"stop-route-accept").clicked();compare(window.route,"home");window.destroy()
  }
  function test_flash_requires_confirmation_without_backup_gate() {
   let window=windowFactory.createObject(root);window.navigate("openwrt")
   let route=findChild(window,"firmware-route"),button=findChild(route,"firmware-start")
   firmwareBackend.canFlash=false;verify(!button.enabled)
   firmwareBackend.canFlash=true;firmwareBackend.helperAction="";verify(button.enabled)
   button.clicked();compare(firmwareBackend.helperAction,"")
   let dialog=findChild(route,"firmware-confirm");verify(dialog.visible)
   dialog.rejected();dialog.close();compare(firmwareBackend.helperAction,"")
   button.clicked();dialog.accepted();dialog.close();compare(firmwareBackend.helperAction,"flash")
   firmwareBackend.busy=true;firmwareBackend.canFlash=false;verify(!button.enabled);window.navigate("home");compare(window.route,"openwrt")
   firmwareBackend.busy=false;firmwareBackend.canFlash=false;window.destroy()
  }
  function test_old_state_never_blocks_install() {
   pane.visible=true;pane.helpVisible=false;realBackend.busy=false
   pane.selectedSource="192.0.2.2";pane.selectedIndex=1
   realBackend.bundlePath="fixture.zip"
   let field=findChild(pane,"router-password");field.text="test-only"
   for(let state of ["idle","error","authentication-error","uncertain","done","current","not-applied"]){
    realBackend.stage=state;realBackend.interrupted=true;realBackend.bundleLocked=true
    verify(findChild(pane,"install-button").enabled)
    verify(findChild(pane,"bundle-picker").enabled)
    verify(findChild(pane,"new-session").enabled)
   }
   realBackend.busy=true;verify(!findChild(pane,"install-button").enabled)
   realBackend.busy=false;realBackend.interrupted=false;realBackend.bundleLocked=false;field.clear()
  }
  function test_blue_indeterminate_progress() {
   pane.visible=true;pane.helpVisible=false
   let bar=findChild(pane,"package-progress"),segment=findChild(pane,"package-progress-segment")
   realBackend.busy=false;verify(!bar.visible)
   realBackend.busy=true;verify(bar.visible)
   let scroll=findChild(pane,"work-scroll")
   waitForRendering(scroll)
   scroll.contentItem.contentY=Math.max(0,bar.mapToItem(scroll.contentItem,0,0).y-100)
   waitForRendering(bar)
   for(let mode of ["light","dark"]){
    theme.mode=mode;compare(segment.color,theme.accent)
    let before=segment.x;tryVerify(function(){return segment.x!==before},2000)
    verify(segment.width>0);verify(segment.width<bar.width)
   }
   realBackend.busy=false;verify(!bar.visible)
  }
  function test_cancel_button_tracks_operation() {
   pane.visible=true;pane.helpVisible=false
   let button=findChild(pane,"cancel-operation")
   verify(button!==null)
   realBackend.busy=false;verify(!button.visible)
   realBackend.busy=true;realBackend.canCancel=true
   verify(button.visible);verify(button.enabled)
   button.clicked();compare(realBackend.canCancel,false);verify(!button.enabled)
   realBackend.busy=false;verify(!button.visible)
  }
  function test_firmware_preflight_requires_selection_and_model() {
   let window=windowFactory.createObject(null);window.navigate("openwrt")
   let route=findChild(window,"firmware-route"),picker=findChild(route,"firmware-adapter"),check=findChild(route,"firmware-check"),confirm=findChild(route,"firmware-model-confirmed")
   verify(!check.enabled)
   firmwareBackend.choices=[{guid:"fixture",label:"USB Ethernet"}]
   picker.currentIndex=0;picker.activated(0);verify(!check.enabled)
   confirm.checked=true;verify(check.enabled);check.clicked();compare(firmwareBackend.selectedProfile,"openwrt")
   firmwareBackend.choices=[{guid:"other",label:"Other Ethernet"},{guid:"fixture",label:"USB Ethernet"}]
   compare(picker.currentIndex,1);compare(route.selectedGuid,"fixture")
   firmwareBackend.busy=true;window.navigate("home");compare(window.route,"openwrt");verify(!check.enabled)
   firmwareBackend.busy=false;window.navigate("recovery");verify(!check.enabled);compare(firmwareBackend.message,"")
   picker.currentIndex=0;picker.activated(0);confirm.checked=true;check.clicked();compare(firmwareBackend.selectedProfile,"factory")
   window.destroy();firmwareBackend.choices=[];firmwareBackend.message=""
  }
  function test_network_helper_requires_confirmation() {
   let window=windowFactory.createObject(null);window.navigate("openwrt")
   let route=findChild(window,"firmware-route"),button=findChild(route,"network-prepare")
   firmwareBackend.helperAction="";firmwareBackend.canPrepare=false;verify(!button.enabled)
   firmwareBackend.canPrepare=true;button.clicked();compare(firmwareBackend.helperAction,"")
   let dialog=findChild(route,"network-confirm");verify(dialog.visible);dialog.accepted();dialog.close()
   compare(firmwareBackend.helperAction,"prepare")
   firmwareBackend.busy=true;verify(!button.enabled);verify(!findChild(route,"network-restore").enabled)
   firmwareBackend.busy=false;firmwareBackend.canPrepare=false;window.destroy()
  }
  function test_main_routes_and_close_is_guarded() {
   let window=windowFactory.createObject(null)
   verify(window!==null);verify(window.title.indexOf("макет")<0)
   compare(window.route,"home")
   window.navigate("openwrt");compare(window.route,"openwrt")
   compare(findChild(window,"firmware-route").recovery,false)
   window.navigate("recovery");compare(findChild(window,"firmware-route").recovery,true)
   window.navigate("packages");verify(findChild(window,"package-route").visible)
   let routePassword=findChild(findChild(window,"package-route"),"router-password")
   routePassword.text="local-test-only"
   window.navigate("home");compare(routePassword.text,"")
   window.navigate("packages")
   realBackend.busy=true;window.navigate("home");compare(window.route,"packages")
   realBackend.busy=false;window.navigate("home");compare(window.route,"home")
   window.navigate("invalid");compare(window.route,"home")
   realBackend.busy=true;window.close();verify(window.visible)
   realBackend.busy=false;window.close()
   let dialog=findChild(window,"close-confirmation");verify(dialog.visible)
   dialog.close();window.destroy()
  }
  function test_without_bundle_backup_remains_available() {
   realBackend.stage="idle";realBackend.bundleLocked=false;realBackend.bundleReady=false
   realBackend.bundlePath="";realBackend.zipMode=false;pane.connectionSelected=true
   let field=findChild(pane,"router-password");field.text="test-only"
   verify(!findChild(pane,"prepare-button").enabled)
   verify(findChild(pane,"firmware-backup").enabled)
   field.clear();pane.connectionSelected=false
  }
  function test_zip_selection_and_locking() {
   realBackend.stage="idle";realBackend.busy=false
   pane.visible=true;pane.helpVisible=false;pane.selectedSource="192.0.2.2"
   let field=findChild(pane,"router-password"),picker=findChild(pane,"bundle-picker")
   field.text="retained";picker.currentIndex=0;picker.activated(0)
   compare(field.text,"retained");compare(realBackend.bundlePath,"fixture.zip")
   realBackend.bundleVersion="5.2.3"
   compare(findChild(pane,"install-button").text,"Установить Школьник 5.2.3")
   realBackend.stage="uncertain";verify(findChild(pane,"install-button").enabled)
   verify(findChild(pane,"new-session").enabled)
   realBackend.busy=true;verify(!picker.enabled)
   realBackend.busy=false;realBackend.stage="idle";realBackend.bundleVersion="5.1.127";field.clear()
  }
  function test_help_and_small_window() {
   pane.visible=true;pane.helpVisible=false;realBackend.stage="current"
   let field=findChild(pane,"router-password"), scroll=findChild(pane,"work-scroll")
   field.text="local-test-only"
   root.width=800;root.height=450
   for(let mode of ["light","dark"]) {
    theme.mode=mode
    mouseClick(findChild(pane,"help-tab"));compare(pane.helpVisible,true)
    compare(field.text,"local-test-only")
    mouseClick(findChild(pane,"work-tab"));compare(pane.helpVisible,false)
    compare(field.text,"local-test-only")
    waitForRendering(scroll)
    let flick=scroll.contentItem
    verify(flick.contentHeight>flick.height)
    flick.contentY=flick.contentHeight-flick.height
    waitForRendering(scroll)
    let button=findChild(pane,"new-session"), point=button.mapToItem(scroll,0,0)
    verify(point.y>=0);verify(point.y+button.height<=scroll.height+1)
   }
   root.width=1100;root.height=750;realBackend.stage="idle";field.clear()
   scroll.contentItem.contentY=0
  }
  function test_connection_selection_and_session_reset() {
   realBackend.stage="idle"
   realBackend.connections=[{label:"Test Ethernet · 192.0.2.3",source:"192.0.2.3",index:7}]
   let field=findChild(pane,"router-password"), picker=findChild(pane,"connection-picker")
   field.text="test-only";picker.currentIndex=0;picker.activated(0)
   compare(pane.selectedSource,"192.0.2.3");compare(pane.selectedIndex,7);compare(field.text,"");compare(pane.connectionSelected,true)
   field.text="test-only";realBackend.sessionReset()
   compare(field.text,"");compare(pane.connectionSelected,false);compare(picker.currentIndex,-1)
  }
  function test_picker_popup_both_themes() {
   pane.visible=true;realBackend.stage="idle"
   realBackend.connections=[{label:"USB Ethernet A · 192.0.2.3",source:"192.0.2.3",index:7},{label:"USB Ethernet B · 192.0.2.4",source:"192.0.2.4",index:8}]
   let picker=findChild(pane,"connection-picker")
   for(let mode of ["light","dark"]) {
    theme.mode=mode;picker.popup.open();tryCompare(picker.popup,"visible",true)
    let list=picker.popup.contentItem;tryCompare(list,"count",2)
    waitForRendering(list)
    let option=list.itemAtIndex(1);verify(option!==null)
    compare(option.contentItem.text,"USB Ethernet B · 192.0.2.4")
    mouseClick(option);tryCompare(picker.popup,"visible",false)
    compare(pane.selectedSource,"192.0.2.4");compare(pane.selectedIndex,8)
   }
  }
  function test_copy_complete_report() {
   realBackend.report="";let button=findChild(pane,"copy-report");verify(!button.enabled)
   realBackend.report="first line\nsecond line";tryCompare(button,"enabled",true);mouseClick(button)
   compare(realBackend.copiedReport,realBackend.report);compare(button.copied,true)
  }
  function test_operations_and_visibility() {
   let field=findChild(pane,"router-password");verify(field!==null)
   field.text="test-only-password";compare(field.revealed,false)
   let button=findChild(field,"password-visibility");mouseClick(button);compare(field.revealed,true)
   pane.run("prepare");compare(realBackend.received,"test-only-password");compare(field.text,"test-only-password");compare(field.revealed,false)
   pane.run("install");compare(field.text,"test-only-password")
   realBackend.stage="error";compare(field.text,"test-only-password")
   pane.run("verify");compare(realBackend.received,"test-only-password")
   pane.visible=false;compare(field.text,"");compare(field.revealed,false)
   pane.visible=true;field.text="other-test";field.clear();compare(field.text,"")
  }
 }
}
