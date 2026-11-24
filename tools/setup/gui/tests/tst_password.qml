import QtQuick
import QtTest
import "../qml"
Item {
 width: 1100; height: 750
 QtObject {
  id: realBackend
  property string sourceIP: "192.0.2.2"
  property int adapterIndex: 1
  property bool busy: false
  property string stage: "idle"
  property string report: ""
  property string received: ""
  function start(action, source, adapter, secret) { received=secret; stage=action==="prepare"?"ready":"done" }
 }
 Theme {id: theme}
 RealPane {id:pane;anchors.fill:parent;colors:theme}
 TestCase {
  name: "PasswordLifecycle"; when: windowShown
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
