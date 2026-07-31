import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  width: 24; height: 24

  property bool menuOpen: false
  property var menuItems: [
    { label: "  Lock",     cmd: ["hyprlock"] },
    { label: "  Logout",   cmd: ["hyprctl", "dispatch", "exit"] },
    { label: "  Suspend",  cmd: ["systemctl", "suspend"] },
    { label: "  Reboot",   cmd: ["systemctl", "reboot"] },
    { label: "  Shutdown", cmd: ["systemctl", "poweroff"] }
  ]

  Process {
    id: cmdProc
    command: []
    running: false
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: "⏻"
    color: "#ffffff"
    font.pixelSize: 16
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      root.menuOpen = !root.menuOpen;
      menuLoader.active = root.menuOpen;
    }
  }

  Loader {
    id: menuLoader
    active: false
    sourceComponent: MenuComponent {}
  }

  Component {
    id: MenuComponent
    Item {
      id: menuRoot
      x: -80
      y: parent.height + 4
      width: 120
      height: menuItems.length * 30 + 8
      z: 999

      Rectangle {
        anchors.fill: parent
        color: "#15121b"
        border.color: "#96d8ff"
        border.width: 1
        radius: 8

        Column {
          anchors.fill: parent
          anchors.margins: 4
          spacing: 2

          Repeater {
            model: root.menuItems

            delegate: Rectangle {
              required property var modelData
              required property int index
              width: parent.width
              height: 28
              radius: 4
              color: mouseArea.containsMouse ? "#1e1e2e" : "transparent"

              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: "#ffffff"
                font.pixelSize: 13
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  cmdProc.command = modelData.cmd;
                  cmdProc.running = true;
                  root.menuOpen = false;
                  menuLoader.active = false;
                }
              }
            }
          }
        }
      }
    }
  }
}
