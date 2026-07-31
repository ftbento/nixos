import QtQuick
import Quickshell.Services.SystemTray

Row {
  id: root
  spacing: 4

  SystemTray {
    id: systemTray
  }

  Repeater {
    model: systemTray.items

    delegate: Item {
      required property var modelData
      width: 22; height: 22

      IconImage {
        anchors.centerIn: parent
        source: modelData.icon
        width: 18; height: 18
      }

      MouseArea {
        anchors.fill: parent
        onClicked: modelData.activate()
      }
    }
  }
}
