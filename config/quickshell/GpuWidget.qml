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

  property string gpuText: "GPU N/A"

  onGpuTextChanged: {
    label.text = root.gpuText;
  }

  Process {
    id: gpuProc
    command: ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo 'N/A,N/A'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = this.text.trim().split(", ");
        if (parts.length >= 2 && parts[0] !== "N/A")
          root.gpuText = "GPU %1% %2°C".arg(parts[0]).arg(parts[1]);
        else
          root.gpuText = "GPU N/A";
      }
    }
  }

  Process {
    id: smiProc
    command: ["kitty", "-e", "nvidia-smi"]
    running: false
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    onTriggered: gpuProc.running = true
  }

  MouseArea {
    anchors.fill: parent
    onClicked: smiProc.running = true
  }
}
