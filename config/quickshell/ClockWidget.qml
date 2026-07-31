import QtQuick
import Quickshell

Text {
  id: root
  color: "#ffffff"
  font.pixelSize: 14
  verticalAlignment: Text.AlignVCenter

  SystemClock {
    id: clockSource
    precision: SystemClock.Minutes
  }

  property string displayText: Qt.formatDateTime(clockSource.date, "ddd HH:mm")
  text: displayText
}
