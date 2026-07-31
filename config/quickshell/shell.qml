import QtQuick
import Quickshell

ShellRoot {
  id: root

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: barWindow
      required property var modelData
      screen: modelData
      anchors { top: true; left: true; right: true }
      height: 40
      exclusionMode: ExclusionMode.Normal
      layer: WlrLayer.Top

      Bar {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
      }
    }
  }
}
