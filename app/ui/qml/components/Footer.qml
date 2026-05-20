import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Rectangle {
    color: Theme.bgGlass

    // Top glow line
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Theme.accentGlow
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceM
        anchors.rightMargin: Theme.spaceM
        spacing: Theme.spaceS

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
            
            // Pulsing dot indicator
            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
                visible: typeof scanController !== "undefined" && scanController.scanState === "scanning"
                
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: visible
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: {
                    if (toastTimer.running) return toastText
                    return typeof scanController !== "undefined" && scanController.scanState === "scanning"
                      ? "Scanning..."
                      : "Ready"
                }
                color: toastTimer.running ? Theme.accent : Theme.textSecondary
                font.pixelSize: Theme.fontCaption
                font.bold: toastTimer.running
                anchors.verticalCenter: parent.verticalCenter
                
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: {
                if (typeof scanController === "undefined") return ""
                var count = scanController.scannedCount
                return count > 0 ? count + " images" : ""
            }
            color: Theme.textMuted
            font.pixelSize: Theme.fontCaption
            Layout.alignment: Qt.AlignVCenter
        }
    }
    
    property string toastText: ""
    
    Timer {
        id: toastTimer
        interval: 2000
        repeat: false
    }
    
    Connections {
        target: typeof cleanupController !== "undefined" ? cleanupController : null
        function onActionCompleted(msg) {
            toastText = msg
            toastTimer.restart()
        }
    }
}
