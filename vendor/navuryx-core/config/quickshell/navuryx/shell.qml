import Quickshell
import Quickshell.Hyprland
import QtQuick

ShellRoot {
  FloatingWindow {
    id: panel
    visible: false
    width: 360
    height: 460
    title: "Navuryx"
    color: "#020208"

    Rectangle {
      anchors.fill: parent
      color: "#080812"
      border.color: "#3558d4"
      border.width: 2
      radius: 16

      Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        Text {
          text: "Navuryx Control"
          color: "#b8c0e8"
          font.pixelSize: 20
          font.bold: true
        }
        Text {
          text: "Hybrid panel. Waybar stays primary."
          color: "#5c5c88"
          font.pixelSize: 12
          wrapMode: Text.WordWrap
          width: parent.width
        }

        Repeater {
          model: [
            "Spotlight",
            "AI",
            "Overview",
            "Notifications",
            "Wallpaper",
            "Appearance",
            "Theme packs",
            "Settings",
            "Welcome",
            "Power"
          ]
          delegate: Rectangle {
            width: parent.width
            height: 34
            radius: 10
            color: ma.containsMouse ? "#3558d4" : "#10101c"
            Text {
              text: modelData
              anchors.centerIn: parent
              color: "#d0d6f0"
            }
            MouseArea {
              id: ma
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                const bin = Quickshell.env("HOME") + "/.config/navuryx/bin/"
                const map = {
                  "Spotlight": bin + "navuryx-spotlight",
                  "AI": bin + "navuryx-ai",
                  "Overview": bin + "navuryx-overview",
                  "Notifications": bin + "navuryx-notifications",
                  "Wallpaper": bin + "navuryx-wallpaper",
                  "Appearance": bin + "navuryx-appearance --menu",
                  "Theme packs": bin + "navuryx-theme",
                  "Settings": bin + "navuryx-settings",
                  "Welcome": bin + "navuryx-welcome --force",
                  "Power": bin + "navuryx-power"
                }
                Quickshell.execDetached(["bash", "-lc", map[modelData]])
                panel.visible = false
              }
            }
          }
        }
      }
    }
  }

  GlobalShortcut {
    name: "navuryxControl"
    description: "Toggle Navuryx Quickshell control"
    onPressed: panel.visible = !panel.visible
  }
}
