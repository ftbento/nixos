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

  property int usage: 0

  onUsageChanged: {
    label.text = "CPU %1%".arg(root.usage);
  }

  Process {
    id: cpuProc
    command: ["sh", "-c", "ps -eo pcpu | awk '{s+=$1} END {printf \"%.0f\\n\", s/$(nproc)}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var val = parseInt(this.text.trim());
        if (!isNaN(val)) root.usage = val;
      }
    }
  }

  Process {
    id: btopProc
    command: ["kitty", "-e", "btop"]
    running: false
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: cpuProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    onClicked: btopProc.running = true
  }
}
