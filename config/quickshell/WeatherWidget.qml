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

  property string weatherText: "..."

  onWeatherTextChanged: {
    label.text = root.weatherText;
  }

  Process {
    id: weatherProc
    command: ["sh", "-c", "curl -s 'wttr.in?format=%t+%C' | head -c 30 || echo 'N/A'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var result = this.text.trim().replace(/\+/g, " ");
        root.weatherText = result.length > 0 ? result : "N/A";
      }
    }
  }

  Timer {
    interval: 1800000
    running: true
    repeat: true
    onTriggered: weatherProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    onClicked: weatherProc.running = true
  }
}
