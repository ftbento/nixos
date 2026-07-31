import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

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

  property string netText: "⚠"

  onNetTextChanged: {
    label.text = root.netText;
  }

  Network {
    id: network
    onStateChanged: updateNetwork()

    function updateNetwork() {
      var dev = network.primaryDevice;
      if (!dev) { root.netText = "⚠"; return; }
      if (dev.wifiState === WifiDevice.State.Connected) {
        root.netText = " %1%".arg(dev.wifiNetwork?.signalPercent || 0);
      } else if (dev.state === NetworkDevice.State.Connected) {
        root.netText = "󰖟";
      } else {
        root.netText = "⚠";
      }
    }
  }

  Process {
    id: nmtuiProc
    command: ["nmtui"]
    running: false
  }

  MouseArea {
    anchors.fill: parent
    onClicked: nmtuiProc.running = true
  }

  Component.onCompleted: network.updateNetwork()
}
