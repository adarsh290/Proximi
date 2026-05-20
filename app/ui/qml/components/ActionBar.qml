import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Rectangle {
    id: root
    height: 64
    color: Theme.bgPanel
    border.color: Theme.borderLight
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceL
        anchors.rightMargin: Theme.spaceL
        spacing: Theme.spaceM


        Button {
            text: "Reject Others"
            onClicked: {
                if (typeof cleanupController !== "undefined") {
                    cleanupController.selectAllExceptKeeper()
                }
            }
            
            contentItem: Text {
                text: parent.text
                color: Theme.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Theme.radiusS
                color: parent.hovered ? Theme.bgHover : Theme.bgElevated
                border.color: Theme.borderLight
            }
        }

        Item { Layout.fillWidth: true } // Spacer
        
        // Progress / Stats 
        Text {
            text: {
                if (typeof cleanupController === "undefined") return ""
                return cleanupController.keeperCount + " Keepers • " + cleanupController.rejectedCount + " Rejected"
            }
            color: Theme.textSecondary
            font.pixelSize: Theme.fontBody
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Theme.spaceL
        }

        // Navigation and Execution
        Button {
            text: "Skip"
            onClicked: {
                if (typeof similarityController !== "undefined") {
                    similarityController.skipGroup()
                }
            }
            
            contentItem: Text {
                text: parent.text
                color: Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Theme.radiusS
                color: "transparent"
                border.color: "transparent"
            }
        }

        Button {
            text: "Execute Cleanup"
            onClicked: cleanupController.executeCleanup()
            enabled: typeof cleanupController !== "undefined" && cleanupController.rejectedCount > 0
            
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Theme.radiusS
                color: parent.enabled ? Theme.accent : Theme.borderLight
                opacity: parent.hovered ? 0.9 : 1.0
            }
        }
    }
}
