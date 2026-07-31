import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
  id: root
  height: 24
  width: label.implicitWidth

  Text {
    id: label
    anchors.verticalCenter: parent.verticalCenter
    color: "#ffffff"
    font.pixelSize: 14
    clip: true
    elide: Text.ElideRight
    width: Math.min(implicitWidth, 300)

    property string displayText: "♪ none"
    text: displayText
  }

  Mpris {
    id: mpris
    onPlayerAdded: updateDisplay()
    onPlayerRemoved: updateDisplay()
  }

  Process {
    id: playPauseProc
    command: ["playerctl", "play-pause"]
    running: false
  }

  Process {
    id: nextProc
    command: ["playerctl", "next"]
    running: false
  }

  function updateDisplay() {
    var players = mpris.players;
    if (players.length === 0) {
      label.displayText = "♪ none";
      return;
    }
    var player = players[0];
    if (player.playbackState !== MprisPlaybackState.Playing) {
      label.displayText = "⏸ %1".arg(player.trackTitle || "paused");
      return;
    }
    label.displayText = "▶ %1 - %2".arg(player.trackTitle || "").arg(player.artist || "");
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      var players = mpris.players;
      if (players.length > 0 && players[0].canPlay)
        playPauseProc.running = true;
    }
    onDoubleClicked: nextProc.running = true
  }
}
