import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
  id: root
  visible: true
  title: "Navuryx Settings"
  width: 980
  height: 680
  minimumWidth: 720
  minimumHeight: 520
  color: "#020208"
  onClosing: Qt.quit()

  property string bin: Quickshell.env("HOME") + "/.config/navuryx/bin/"
  property string appearanceMode: "auto"
  property string waybarPosition: "top"
  property string waybarVisible: "1"
  property string gapsIn: "6"
  property string gapsOut: "14"

  function run(cmd) {
    Quickshell.execDetached(["bash", "-lc", cmd])
  }

  function refresh() {
    appearanceProc.running = false
    appearanceProc.running = true
    positionProc.running = false
    positionProc.running = true
    visibleProc.running = false
    visibleProc.running = true
    gapsInProc.running = false
    gapsInProc.running = true
    gapsOutProc.running = false
    gapsOutProc.running = true
  }

  Component.onCompleted: refresh()

  Process {
    id: appearanceProc
    command: ["bash", "-lc", root.bin + "navuryx-shell-config get appearance_mode auto"]
    stdout: StdioCollector {
      onStreamFinished: root.appearanceMode = this.text.trim() || "auto"
    }
  }
  Process {
    id: positionProc
    command: ["bash", "-lc", root.bin + "navuryx-shell-config get waybar_position top"]
    stdout: StdioCollector {
      onStreamFinished: root.waybarPosition = this.text.trim() || "top"
    }
  }
  Process {
    id: visibleProc
    command: ["bash", "-lc", root.bin + "navuryx-shell-config get waybar_visible 1"]
    stdout: StdioCollector {
      onStreamFinished: root.waybarVisible = this.text.trim() || "1"
    }
  }
  Process {
    id: gapsInProc
    command: ["bash", "-lc", root.bin + "navuryx-shell-config get gaps_in 6"]
    stdout: StdioCollector {
      onStreamFinished: root.gapsIn = this.text.trim() || "6"
    }
  }
  Process {
    id: gapsOutProc
    command: ["bash", "-lc", root.bin + "navuryx-shell-config get gaps_out 14"]
    stdout: StdioCollector {
      onStreamFinished: root.gapsOut = this.text.trim() || "14"
    }
  }

  Rectangle {
    anchors.fill: parent
    color: "#020208"

    RowLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 14

      Rectangle {
        Layout.preferredWidth: 220
        Layout.fillHeight: true
        radius: 16
        color: "#080812"
        border.color: "#3558d4"
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 8

          Text {
            text: "Navuryx"
            color: "#b8c0e8"
            font.pixelSize: 22
            font.bold: true
          }
          Text {
            text: "Settings"
            color: "#5c5c88"
            font.pixelSize: 13
          }

          Repeater {
            model: ["Quick", "Bar", "Appearance", "AI", "System", "About"]
            delegate: Rectangle {
              Layout.fillWidth: true
              height: 38
              radius: 10
              color: pages.currentIndex === index ? "#3558d4" : (navMa.containsMouse ? "#121228" : "#0a0a16")
              Text {
                anchors.centerIn: parent
                text: modelData
                color: "#d0d6f0"
              }
              MouseArea {
                id: navMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: pages.currentIndex = index
              }
            }
          }

          Item { Layout.fillHeight: true }

          Rectangle {
            Layout.fillWidth: true
            height: 38
            radius: 10
            color: closeMa.containsMouse ? "#7a24c9" : "#121228"
            Text {
              anchors.centerIn: parent
              text: "Close"
              color: "#e8ecff"
            }
            MouseArea {
              id: closeMa
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.close()
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 16
        color: "#080812"
        border.color: "#1a1a3a"
        border.width: 1

        StackLayout {
          id: pages
          anchors.fill: parent
          anchors.margins: 18
          currentIndex: 0

          ColumnLayout {
            spacing: 12
            Text { text: "Quick setup"; color: "#b8c0e8"; font.pixelSize: 20; font.bold: true }
            Text { text: "Common shell options without hand-editing configs."; color: "#5c5c88"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Flow {
              Layout.fillWidth: true
              spacing: 10
              Repeater {
                model: [
                  { label: "Wallpaper", cmd: root.bin + "navuryx-wallpaper" },
                  { label: "Spotlight", cmd: root.bin + "navuryx-spotlight" },
                  { label: "AI", cmd: root.bin + "navuryx-ai" },
                  { label: "Overview", cmd: root.bin + "navuryx-overview" },
                  { label: "Control", cmd: root.bin + "navuryx-control" },
                  { label: "Theme packs", cmd: root.bin + "navuryx-theme" },
                  { label: "Welcome", cmd: root.bin + "navuryx-welcome --force" },
                  { label: "VPN", cmd: root.bin + "navuryx-vpn" },
                  { label: "Gaming mode", cmd: root.bin + "navuryx-gaming" },
                  { label: "Apply all", cmd: root.bin + "navuryx-shell-config apply" }
                ]
                delegate: Rectangle {
                  width: 140
                  height: 40
                  radius: 10
                  color: qMa.containsMouse ? "#3558d4" : "#121228"
                  Text { anchors.centerIn: parent; text: modelData.label; color: "#d0d6f0" }
                  MouseArea {
                    id: qMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.run(modelData.cmd)
                  }
                }
              }
            }
            Item { Layout.fillHeight: true }
          }

          ColumnLayout {
            spacing: 12
            Text { text: "Waybar"; color: "#b8c0e8"; font.pixelSize: 20; font.bold: true }
            Text { text: "Position: " + root.waybarPosition; color: "#7f8fd6" }
            Flow {
              Layout.fillWidth: true
              spacing: 8
              Repeater {
                model: ["top", "bottom", "left", "right"]
                delegate: Rectangle {
                  width: 100
                  height: 36
                  radius: 10
                  color: root.waybarPosition === modelData ? "#3558d4" : (pMa.containsMouse ? "#121228" : "#0a0a16")
                  Text { anchors.centerIn: parent; text: modelData; color: "#d0d6f0" }
                  MouseArea {
                    id: pMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                      root.run(root.bin + "navuryx-shell-config set waybar_position " + modelData + "; " + root.bin + "navuryx-shell-config restart-waybar")
                      root.waybarPosition = modelData
                    }
                  }
                }
              }
            }
            Rectangle {
              Layout.preferredWidth: 220
              height: 40
              radius: 10
              color: vMa.containsMouse ? "#7a24c9" : "#121228"
              Text {
                anchors.centerIn: parent
                text: root.waybarVisible === "1" ? "Hide Waybar" : "Show Waybar"
                color: "#e8ecff"
              }
              MouseArea {
                id: vMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                  var next = root.waybarVisible === "1" ? "0" : "1"
                  root.run(root.bin + "navuryx-shell-config set waybar_visible " + next + "; " + root.bin + "navuryx-shell-config restart-waybar")
                  root.waybarVisible = next
                }
              }
            }
            Text { text: "Gaps in/out: " + root.gapsIn + " / " + root.gapsOut; color: "#7f8fd6" }
            Flow {
              Layout.fillWidth: true
              spacing: 8
              Repeater {
                model: [
                  { label: "Compact", gin: "4", gout: "10" },
                  { label: "Default", gin: "6", gout: "14" },
                  { label: "Comfort", gin: "8", gout: "18" },
                  { label: "Wide", gin: "10", gout: "24" }
                ]
                delegate: Rectangle {
                  width: 110
                  height: 36
                  radius: 10
                  color: gMa.containsMouse ? "#3558d4" : "#121228"
                  Text { anchors.centerIn: parent; text: modelData.label; color: "#d0d6f0" }
                  MouseArea {
                    id: gMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                      root.run(root.bin + "navuryx-shell-config set gaps_in " + modelData.gin + "; " + root.bin + "navuryx-shell-config set gaps_out " + modelData.gout + "; " + root.bin + "navuryx-shell-config apply-gaps")
                      root.gapsIn = modelData.gin
                      root.gapsOut = modelData.gout
                    }
                  }
                }
              }
            }
            Item { Layout.fillHeight: true }
          }

          ColumnLayout {
            spacing: 12
            Text { text: "Appearance"; color: "#b8c0e8"; font.pixelSize: 20; font.bold: true }
            Text { text: "Mode: " + root.appearanceMode + "  |  Ctrl+Super+Shift+D toggles dark/light"; color: "#5c5c88"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
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
                  width: 120
                  height: 40
                  radius: 10
                  color: root.appearanceMode === modelData.mode ? "#7a24c9" : (aMa.containsMouse ? "#121228" : "#0a0a16")
                  Text { anchors.centerIn: parent; text: modelData.label; color: "#e8ecff" }
                  MouseArea {
                    id: aMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                      root.run(root.bin + "navuryx-appearance --set " + modelData.mode)
                      root.appearanceMode = modelData.mode
                    }
                  }
                }
              }
            }
            Rectangle {
              Layout.preferredWidth: 200
              height: 40
              radius: 10
              color: tMa.containsMouse ? "#3558d4" : "#121228"
              Text { anchors.centerIn: parent; text: "Toggle now"; color: "#e8ecff" }
              MouseArea {
                id: tMa
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.run(root.bin + "navuryx-appearance --toggle")
              }
            }
            Item { Layout.fillHeight: true }
          }

          ColumnLayout {
            spacing: 12
            Text { text: "Navuryx AI"; color: "#b8c0e8"; font.pixelSize: 20; font.bold: true }
            Text { text: "Local Ollama / OpenAI-compatible assistant. Super+A opens AI."; color: "#5c5c88"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Flow {
              spacing: 10
              Rectangle {
                width: 160
                height: 40
                radius: 10
                color: aiMa.containsMouse ? "#7a24c9" : "#121228"
                Text { anchors.centerIn: parent; text: "Open AI"; color: "#e8ecff" }
                MouseArea { id: aiMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.run(root.bin + "navuryx-ai") }
              }
              Rectangle {
                width: 180
                height: 40
                radius: 10
                color: setupMa.containsMouse ? "#3558d4" : "#121228"
                Text { anchors.centerIn: parent; text: "AI setup"; color: "#e8ecff" }
                MouseArea { id: setupMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.run("kitty --class navuryx-ai -e " + root.bin + "navuryx-ai-setup") }
              }
              Rectangle {
                width: 180
                height: 40
                radius: 10
                color: askMa.containsMouse ? "#3558d4" : "#121228"
                Text { anchors.centerIn: parent; text: "Ask screen"; color: "#e8ecff" }
                MouseArea { id: askMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.run(root.bin + "navuryx-ask-screen") }
              }
            }
            Item { Layout.fillHeight: true }
          }

          ColumnLayout {
            spacing: 12
            Text { text: "System"; color: "#b8c0e8"; font.pixelSize: 20; font.bold: true }
            Text { text: "Network, diagnostics, and maintenance tools."; color: "#5c5c88"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            Flow {
              Layout.fillWidth: true
              spacing: 10
              Repeater {
                model: [
                  { label: "VPN menu", cmd: root.bin + "navuryx-vpn" },
                  { label: "Connect VPN", cmd: root.bin + "navuryx-vpn --connect" },
                  { label: "Disconnect VPN", cmd: root.bin + "navuryx-vpn --disconnect" },
                  { label: "Gaming mode", cmd: root.bin + "navuryx-gaming" },
                  { label: "Keybindings", cmd: root.bin + "navuryx-keybinds" },
                  { label: "Doctor", cmd: root.bin + "navuryx-doctor" },
                  { label: "Features", cmd: root.bin + "navuryx-features" },
                  { label: "Backups", cmd: root.bin + "navuryx-backup" }
                ]
                delegate: Rectangle {
                  width: 150
                  height: 40
                  radius: 10
                  color: sysMa.containsMouse ? "#3558d4" : "#121228"
                  Text { anchors.centerIn: parent; text: modelData.label; color: "#d0d6f0" }
                  MouseArea {
                    id: sysMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.run(modelData.cmd)
                  }
                }
              }
            }
            Item { Layout.fillHeight: true }
          }

          ColumnLayout {
            spacing: 12
            Text { text: "About"; color: "#b8c0e8"; font.pixelSize: 20; font.bold: true }
            Text {
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
              color: "#8f9acc"
              text: "Hybrid Base A+D: Waybar + Spotlight + Navuryx AI, with practical Navuryx / Navuryx / Navuryx patterns.\nSettings: Super+, or Super+I\nWelcome: Super+Shift+Alt+/\nAppearance toggle: Ctrl+Super+Shift+D\nOverview: Super+Tab\nWorkspaces: Super+1–0"
            }
            Item { Layout.fillHeight: true }
          }
        }
      }
    }
  }
}
