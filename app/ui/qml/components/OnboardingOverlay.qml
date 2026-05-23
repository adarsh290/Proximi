import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

// First-launch onboarding carousel — full-screen animated overlay
Item {
    id: onboardingRoot

    signal completed()

    // ── Data Model ─────────────────────────────────────────────────────
    readonly property var slides: [
        {
            emoji:    "✨",
            title:    "Welcome to Proximi",
            subtitle: "Your intelligent photo cleanup companion.\nLet's take a quick tour.",
            accent:   Theme.accent,
        },
        {
            emoji:    "📁",
            title:    "Browse a Folder",
            subtitle: "Click \"Browse\" to open any folder full of photos.\nProximi works locally — nothing leaves your device.",
            accent:   "#7C3AED",
        },
        {
            emoji:    "🔍",
            title:    "Scan & Analyse",
            subtitle: "Proximi scans your photos and builds perceptual fingerprints.\nThis usually takes just a few seconds.",
            accent:   "#2563EB",
        },
        {
            emoji:    "🪄",
            title:    "Find Similar Photos",
            subtitle: "Hit \"Find Similar\" to group near-duplicate photos.\nBurst shots, re-takes, and accidental duplicates — all caught.",
            accent:   "#059669",
        },
        {
            emoji:    "🗑️",
            title:    "Clean Up & Keep the Best",
            subtitle: "Review each group, mark photos to remove, and execute.\nThe originals you keep stay safe — only selected ones are removed.",
            accent:   "#DC2626",
        },
    ]

    property int currentSlide: 0
    readonly property int slideCount: slides.length

    // ── Full-screen backdrop ────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 1.0
    }

    // Blur-like layered gradient
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#10" + Theme.accent.toString().slice(1) }
            GradientStop { position: 1.0; color: "#00000000" }
        }
        opacity: 0.4
    }

    // ── Skip button ────────────────────────────────────────────────────
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spaceL
        width: skipLabel.implicitWidth + 24
        height: 32
        radius: 16
        color: skipArea.containsMouse ? Theme.bgHover : "transparent"
        border.color: Theme.border
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            id: skipLabel
            anchors.centerIn: parent
            text: "Skip"
            color: Theme.textMuted
            font.pixelSize: Theme.fontSmall
        }
        MouseArea {
            id: skipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: onboardingRoot.completed()
        }
    }

    // ── Slide container ────────────────────────────────────────────────
    Item {
        id: slideArea
        anchors.fill: parent
        anchors.bottomMargin: 80  // Reserve space for nav

        // SwipeView-like horizontal pager via x-offset
        Row {
            id: slideRow
            height: parent.height
            x: -currentSlide * slideArea.width
            Behavior on x {
                NumberAnimation { duration: Theme.animPage; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: onboardingRoot.slides
                delegate: Item {
                    width: slideArea.width
                    height: slideArea.height

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width * 0.85, 520)
                        spacing: 0

                        // Emoji icon in a glowing circle
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 120
                            Layout.bottomMargin: Theme.spaceL

                            // Outer glow ring
                            Rectangle {
                                anchors.centerIn: parent
                                width: 120; height: 120; radius: 60
                                color: "transparent"
                                border.width: 2
                                border.color: modelData.accent
                                opacity: 0.3

                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: index === onboardingRoot.currentSlide
                                    NumberAnimation { from: 1.0; to: 1.12; duration: 1800; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.12; to: 1.0; duration: 1800; easing.type: Easing.InOutSine }
                                }
                            }

                            // Icon circle
                            Rectangle {
                                anchors.centerIn: parent
                                width: 96; height: 96; radius: 48
                                color: Qt.rgba(
                                    parseInt(modelData.accent.slice(1,3), 16) / 255,
                                    parseInt(modelData.accent.slice(3,5), 16) / 255,
                                    parseInt(modelData.accent.slice(5,7), 16) / 255,
                                    0.18
                                )
                                border.color: modelData.accent
                                border.width: 1.5

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.emoji
                                    font.pixelSize: 44
                                }
                            }
                        }

                        // Title
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            text: modelData.title
                            color: Theme.textPrimary
                            font.pixelSize: 28
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.preferredHeight: Theme.spaceM }

                        // Subtitle
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.fillWidth: true
                            text: modelData.subtitle
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontMedium
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            lineHeight: 1.5
                        }
                    }
                }
            }
        }
    }

    // ── Navigation bar (dots + buttons) ───────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceXL
            anchors.rightMargin: Theme.spaceXL

            // Back button
            Rectangle {
                width: 80; height: 36; radius: 18
                color: backArea.containsMouse ? Theme.bgHover : "transparent"
                border.color: onboardingRoot.currentSlide > 0 ? Theme.border : "transparent"
                border.width: 1
                opacity: onboardingRoot.currentSlide > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text: "← Back"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSmall
                }
                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (onboardingRoot.currentSlide > 0)
                            onboardingRoot.currentSlide--
                    }
                }
            }

            // Dot indicators
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: onboardingRoot.slideCount
                    delegate: Rectangle {
                        width: index === onboardingRoot.currentSlide ? 24 : 8
                        height: 8
                        radius: 4
                        color: index === onboardingRoot.currentSlide ? Theme.accent : Theme.bgHover
                        Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.animNormal } }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: onboardingRoot.currentSlide = index
                        }
                    }
                }
            }

            // Next / Get Started button
            Rectangle {
                id: nextBtn
                width: onboardingRoot.currentSlide === onboardingRoot.slideCount - 1 ? 140 : 90
                height: 36; radius: 18
                color: nextArea.containsMouse ? Theme.accentHover : Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                // Subtle glow
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: parent.radius + 3
                    color: "transparent"
                    border.color: Theme.glowAccent
                    border.width: 2
                }

                Text {
                    anchors.centerIn: parent
                    text: onboardingRoot.currentSlide === onboardingRoot.slideCount - 1
                          ? "Get Started 🚀" : "Next →"
                    color: "white"
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                }
                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (onboardingRoot.currentSlide < onboardingRoot.slideCount - 1) {
                            onboardingRoot.currentSlide++
                        } else {
                            onboardingRoot.completed()
                        }
                    }
                }
            }
        }
    }

    // ── Entrance animation ─────────────────────────────────────────────
    opacity: 0
    scale: 0.96
    Component.onCompleted: {
        entranceAnim.start()
    }
    ParallelAnimation {
        id: entranceAnim
        NumberAnimation { target: onboardingRoot; property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutCubic }
        NumberAnimation { target: onboardingRoot; property: "scale"; from: 0.96; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
    }
}
