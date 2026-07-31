import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  spacing: 8

  Item { Layout.fillWidth: true }

  RowLayout {
    spacing: 4
    CpuWidget {}
    GpuWidget {}
    MusicWidget {}
  }

  Item { Layout.fillWidth: true }

  RowLayout {
    spacing: 4
    WeatherWidget {}
    Workspaces {}
    NotificationWidget {}
  }

  Item { Layout.fillWidth: true }

  RowLayout {
    spacing: 4
    TrayWidget {}
    NetworkWidget {}
    ClockWidget {}
    PowerWidget {}
  }

  Item { Layout.fillWidth: true }
}
