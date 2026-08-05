import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
  id: root
  visible: true
  title: "Navuryx Welcome"
  width: 900
  height: 620
  minimumWidth: 680
  minimumHeight: 480
  color: "#020208"
  property string bin: Quickshell.env("HOME") + "/.config/navuryx/bin/"
  property bool showNextTime: false

  onClosing: {
    if (!root.showNextTime) {
      Quickshell.execDetached(["bash", "-lc", root.bin + "navuryx-shell-config set welcome_shown 1"])
    } else {
      Quickshell.execDetached(["bash", "-lc", root.bin + "navuryx-shell-config set welcome_shown 0"])
    }
    Quickshell.execDetached(["notify-send", "-a", "Navuryx", "Welcome", "Reopen with Super+Shift+Alt+/. Settings: Super+I"])
    Qt.quit()
  }

  function run(cmd) {
    Quickshell.execDetached(["bash", "-lc", cmd])
  }

  Rectangle {
    anchors.fill: parent
    color: "#020208"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 22
      spacing: 14

      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "Welcome to Navuryx"
          color: "#b8c0e8"
          font.pixelSize: 28
          font.bold: true
          Layout.fillWidth: true
        }
        Text {
          text: "Show next time"
          color: "#5c5c88"
          font.pixelSize: 12
        }
        Switch {
          checked: root.showNextTime
          onCheckedChanged: root.showNextTime = checked
        }
        Rectangle {
          width: 36
          height: 36
          radius: 18
          color: closeMa.containsMouse ? "#7a24c9" : "#121228"
          Text { anchors.centerIn: parent; text: "x"; color: "#e8ecff" }
          MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.close() }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 16
        color: "#080812"
        border.color: "#1a1a3a"
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 20
          spacing: 16

          Text {
            text: "Near-black royal desktop with Waybar, Spotlight, and Navuryx AI."
            color: "#8f9acc"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          Text { text: "Appearance"; color: "#b8c0e8"; font.pixelSize: 16; font.bold: true }
          Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
              model: [
                { label: "Auto", mode: "auto" },
                { label: "Dark", mode: "dark" },
                { label: "Light", mode: "light" }
              ]
              delegate: Rectangle {
                width: 110
                height: 38
                radius: 10
                color: mMa.containsMouse ? "#7a24c9" : "#121228"
                Text { anchors.centerIn: parent; text: modelData.label; color: "#e8ecff" }
                MouseArea {
                  id: mMa
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: root.run(root.bin + "navuryx-appearance --set " + modelData.mode)
                }
              }
            }
          }

          Text { text: "Waybar position"; color: "#b8c0e8"; font.pixelSize: 16; font.bold: true }
          Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
              model: ["top", "bottom", "left", "right"]
              delegate: Rectangle {
                width: 100
                height: 36
                radius: 10
                color: bMa.containsMouse ? "#3558d4" : "#121228"
                Text { anchors.centerIn: parent; text: modelData; color: "#d0d6f0" }
                MouseArea {
                  id: bMa
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: root.run(root.bin + "navuryx-shell-config set waybar_position " + modelData + "; " + root.bin + "navuryx-shell-config restart-waybar")
                }
              }
            }
          }

          Text { text: "Get started"; color: "#b8c0e8"; font.pixelSize: 16; font.bold: true }
          Flow {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
              model: [
                { label: "Open settings", cmd: root.bin + "navuryx-settings --ui || " + root.bin + "navuryx-settings" },
                { label: "Set up AI", cmd: "kitty --class navuryx-ai -e " + root.bin + "navuryx-ai-setup" },
                { label: "Open AI", cmd: root.bin + "navuryx-ai" },
                { label: "Spotlight", cmd: root.bin + "navuryx-spotlight" },
                { label: "Wallpaper", cmd: root.bin + "navuryx-wallpaper" },
                { label: "Overview", cmd: root.bin + "navuryx-overview" }
              ]
              delegate: Rectangle {
                width: 140
                height: 40
                radius: 10
                color: sMa.containsMouse ? "#3558d4" : "#121228"
                Text { anchors.centerIn: parent; text: modelData.label; color: "#d0d6f0" }
                MouseArea {
                  id: sMa
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: root.run(modelData.cmd)
                }
              }
            }
          }

          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: "#5c5c88"
            text: "Shortcuts: Super+Space Spotlight · Super+A AI · Super+Tab overview · Super+1–0 workspaces · Super+I settings"
          }

          Item { Layout.fillHeight: true }
        }
      }
    }
  }
}
