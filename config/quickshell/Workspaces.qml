import QtQuick
import Quickshell
import Quickshell.Hyprland

Row {
  id: root
  spacing: 4

  Repeater {
    model: Hyprland.workspaces

    delegate: Rectangle {
      required property var modelData
      width: 8; height: 8; radius: 4
      color: modelData === Hyprland.focusedWorkspace ? "#96d8ff" : modelData.windows > 0 ? "#ffffff" : "#444444"

      MouseArea {
        anchors.fill: parent
        onClicked: {
          Hyprland.focusedWorkspace = modelData;
        }
      }
    }
  }
}
