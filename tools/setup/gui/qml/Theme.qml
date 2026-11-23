import QtQuick
QtObject {
 property string mode: "system"
 readonly property bool dark: mode === "dark" || (mode !== "light" && Qt.styleHints.colorScheme === Qt.Dark)
 // Tokens mirror ui/root/www/schoolbell-test/style.css.
 readonly property color bg: dark ? "#0d1117" : "#f6f8fa"
 readonly property color panel: dark ? "#161b22" : "#ffffff"
 readonly property color text: dark ? "#e6edf3" : "#1f2328"
 readonly property color muted: dark ? "#919ba7" : "#59636e"
 readonly property color border: dark ? "#30363d" : "#d1d9e0"
 readonly property color soft: dark ? "#15263c" : "#eaf2ff"
 readonly property color accent: dark ? "#58a6ff" : "#0969da"
 readonly property color accentText: dark ? "#0d1117" : "#ffffff"
 readonly property color danger: dark ? "#ff7b72" : "#cf222e"
 readonly property color warning: dark ? "#e3b341" : "#9a6700"
 readonly property color success: dark ? "#3fb950" : "#1a7f37"
}
