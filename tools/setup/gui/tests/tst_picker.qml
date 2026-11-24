import QtQuick
import QtTest
import "../qml"
Item {
 width:600;height:400
 Theme {id:theme}
 StyledComboBox {id:strings;width:400;colors:theme;model:["Первый","Второй"]}
 StyledComboBox {id:objects;y:60;width:400;colors:theme;textRole:"label";model:[{label:"ZIP A"},{label:"ZIP B"}]}
 TestCase {
  name:"SharedPickers";when:windowShown
  function test_models_and_themes() {
   for(let mode of ["light","dark"]) {
    theme.mode=mode
    for(let picker of [strings,objects]) {
     compare(picker.indicator.width,24);compare(picker.indicator.height,24)
     compare(picker.font.pixelSize,18);compare(picker.implicitHeight,48)
     picker.popup.open();tryCompare(picker.popup,"visible",true)
     let list=picker.popup.contentItem;tryCompare(list,"count",2);waitForRendering(list)
     let row=list.itemAtIndex(1);verify(row!==null)
     compare(row.contentItem.text,picker===strings?"Второй":"ZIP B")
     mouseClick(row);tryCompare(picker.popup,"visible",false)
     compare(picker.currentIndex,1)
    }
   }
  }
 }
}
