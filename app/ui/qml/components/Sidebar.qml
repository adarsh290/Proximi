import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Rectangle {
    color: Theme.bgSidebar

    // Derived state
    property bool inGroupReview: typeof similarityController !== "undefined"
                                 && similarityController.similarityState === "ready"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceM
        spacing: Theme.spaceS

        // ── Library section (hidden during group review) ─────────────
        Text {
            visible: !inGroupReview
            text: "Library"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
            font.bold: true
            font.letterSpacing: 1.2
            Layout.bottomMargin: Theme.spaceXS
        }

        Rectangle {
            visible: !inGroupReview
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Theme.radiusS
            color: Theme.accent

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceS
                anchors.rightMargin: Theme.spaceS
                spacing: Theme.spaceS

                Text {
                    text: "🖼"
                    font.pixelSize: Theme.fontBody
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "All Photos"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontBody
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    visible: typeof scanController !== "undefined" && scanController.scannedCount > 0
                    Layout.preferredWidth: countLabel.implicitWidth + Theme.spaceS * 2
                    Layout.preferredHeight: 20
                    radius: 10
                    color: Theme.accentHover

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: typeof scanController !== "undefined" ? scanController.scannedCount : "0"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontCaption
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // ── Group Review Panel (replaces Library when reviewing) ─────
        // ══════════════════════════════════════════════════════════════

        // Section header
        Text {
            visible: inGroupReview
            text: "GROUP REVIEW"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
            font.bold: true
            font.letterSpacing: 1.2
            Layout.bottomMargin: Theme.spaceXS
        }

        // Group info card
        Rectangle {
            visible: inGroupReview
            Layout.fillWidth: true
            color: Theme.bgPanel
            radius: Theme.radiusM
            border.color: Theme.border
            border.width: 1
            Layout.preferredHeight: groupInfoColumn.implicitHeight + Theme.spaceM * 2

            ColumnLayout {
                id: groupInfoColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceM
                spacing: Theme.spaceS

                // Row 1: Group number (large)
                Text {
                    text: {
                        if (typeof similarityController === "undefined") return "—"
                        return "Group " + (similarityController.currentGroupIndex + 1)
                    }
                    color: Theme.textPrimary
                    font.pixelSize: 24
                    font.bold: true
                    Layout.fillWidth: true
                }

                // "of N" subtitle
                Text {
                    text: {
                        if (typeof similarityController === "undefined") return ""
                        return "of " + similarityController.groupCount
                    }
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    Layout.fillWidth: true
                    Layout.topMargin: -Theme.spaceXS
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                    Layout.topMargin: Theme.spaceXS
                    Layout.bottomMargin: Theme.spaceXS
                }

                // Row 2: Image count
                RowLayout {
                    spacing: Theme.spaceS
                    Text {
                        text: "🖼"
                        font.pixelSize: Theme.fontBody
                    }
                    Text {
                        property var grp: typeof similarityController !== "undefined" ? similarityController.currentGroupData : ({})
                        text: {
                            if (grp && grp.count) return grp.count + " images"
                            return "..."
                        }
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontBody
                    }
                }

                // Row 3: Type badge + Score
                RowLayout {
                    spacing: Theme.spaceS

                    Rectangle {
                        property var grp: typeof similarityController !== "undefined" ? similarityController.currentGroupData : ({})
                        property bool isBurst: grp && grp.type === "burst"
                        color: isBurst ? "#4A3300" : "#1A2E35"
                        radius: 4
                        Layout.preferredWidth: badgeText.implicitWidth + 16
                        Layout.preferredHeight: badgeText.implicitHeight + 8

                        Text {
                            id: badgeText
                            anchors.centerIn: parent
                            text: {
                                var g = typeof similarityController !== "undefined" ? similarityController.currentGroupData : null
                                if (g && g.type) return g.type.toUpperCase()
                                return "..."
                            }
                            color: parent.isBurst ? "#FFB000" : "#00C3FF"
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    Text {
                        property var grp: typeof similarityController !== "undefined" ? similarityController.currentGroupData : ({})
                        text: {
                            if (grp && grp.score !== undefined) return Math.round(grp.score * 100) + "%"
                            return ""
                        }
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSmall
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        // ── Navigation Buttons (stacked vertically) ──────────────────
        Button {
            id: prevBtn
            visible: inGroupReview
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            text: "◀  Previous"
            enabled: typeof similarityController !== "undefined" && similarityController.currentGroupIndex > 0

            onClicked: {
                if (typeof similarityController !== "undefined")
                    similarityController.previousGroup()
            }

            background: Rectangle {
                color: prevBtn.enabled ? (prevBtn.hovered ? Theme.bgHover : Theme.bgPanel) : Theme.bgPanel
                radius: Theme.radiusS
                border.color: prevBtn.enabled ? Theme.border : "transparent"
                border.width: 1
                opacity: prevBtn.enabled ? 1.0 : 0.4
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            contentItem: Text {
                text: prevBtn.text
                color: prevBtn.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSmall
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Button {
            id: nextBtn
            visible: inGroupReview
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            text: "Next  ▶"
            enabled: typeof similarityController !== "undefined"
                     && similarityController.currentGroupIndex < similarityController.groupCount - 1

            onClicked: {
                if (typeof similarityController !== "undefined")
                    similarityController.nextGroup()
            }

            background: Rectangle {
                color: nextBtn.enabled ? (nextBtn.hovered ? Theme.accentHover : Theme.accent) : Theme.accentDisabled
                radius: Theme.radiusS
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            contentItem: Text {
                text: nextBtn.text
                color: nextBtn.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSmall
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Spacer
        Item {
            Layout.fillHeight: true
        }
    }
}
