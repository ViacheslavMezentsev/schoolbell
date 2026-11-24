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
  property bool fresh: false
  property string stage: "idle"
  property string report: ""
  property var connections: []
  signal sessionReset()
  function refreshConnections() {}
  function connectionLabel(ip,index) {return ip}
  property string copiedReport:""
  function copyReport(){copiedReport=report}
  property string received: ""
  function start(action, source, adapter, secret) { received=secret; stage=action==="prepare"?"ready":"done" }
 }
 Theme {id: theme}
 RealPane {id:pane;anchors.fill:parent;colors:theme}
 TestCase {
  name: "PasswordLifecycle"; when: windowShown
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
