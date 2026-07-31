import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  width: label.implicitWidth + 8
  height: 24

  Text {
    id: label
    anchors.centerIn: parent
    color: "#ffffff"
    font.pixelSize: 14
  }

  property int notifCount: 0

  onNotifCountChanged: {
    label.text = root.notifCount > 0 ? " %1".arg(root.notifCount) : "";
  }

  Process {
    id: notifProc
    command: ["sh", "-c", "swaync-client -c 2>/dev/null || echo 0"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var count = parseInt(this.text.trim()) || 0;
        root.notifCount = count;
      }
    }
  }

  Process {
    id: toggleNotifProc
    command: ["swaync-client", "-t", "-sw"]
    running: false
  }

  Process {
    id: dismissNotifProc
    command: ["swaync-client", "-d", "-sw"]
    running: false
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: notifProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    onClicked: toggleNotifProc.running = true
    onPressAndHold: dismissNotifProc.running = true
  }
}
