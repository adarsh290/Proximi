import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Item {
    id: processingRoot
    
    property string phase: "starting"
    property int progressPercent: 0
    
    function isPast(stepPhase) {
        var order = {"starting": 0, "hashing": 1, "comparing": 2, "grouping": 3, "done": 4}
        var currentOrder = order[processingRoot.phase] || 0
        var stepOrder = order[stepPhase] || 0
        return currentOrder > stepOrder
    }
    
    function isCurrent(stepPhase) {
        return processingRoot.phase === stepPhase
    }
    
    // Dim the background behind the card
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.7
        
        // Intercept mouse events
        MouseArea { anchors.fill: parent }
    }
    
    // Soft shadow
    Rectangle {
        x: card.x + 4
        y: card.y + 8
        width: card.width
        height: card.height
        radius: Theme.radiusL
        color: "#000000"
        opacity: 0.4
    }
    
    // Main Card
    Rectangle {
        id: card
        width: 460
        height: 240
        anchors.centerIn: parent
        color: Theme.bgPanel
        radius: Theme.radiusL
        border.color: Theme.border
        border.width: 1
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceL
            spacing: 0
            
            // ── Header ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceM
                
                // Animated icon
                Rectangle {
                    width: 44
                    height: 44
                    radius: 22
                    color: Qt.lighter(Theme.accent, 1.6)
                    
                    Text {
                        anchors.centerIn: parent
                        text: "✨"
                        font.pixelSize: 20
                        
                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 8000
                        }
                    }
                }
                
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Similarity Engine"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                    }
                    Text {
                        text: "Analyzing image relationships and forming clusters"
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }
            
            Item { Layout.fillHeight: true } // Spacer
            
            // ── Stages Indicator ────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceM
                
                // Reusable step component
                Component {
                    id: stepDelegate
                    RowLayout {
                        property string stepPhase: ""
                        property string label: ""
                        spacing: 8
                        
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: processingRoot.isCurrent(stepPhase) ? Theme.accent : (processingRoot.isPast(stepPhase) ? Theme.textSecondary : Theme.bgApp)
                            border.color: processingRoot.isPast(stepPhase) ? "transparent" : Theme.border
                            border.width: 1
                            
                            // Pulse animation if current
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                radius: width / 2
                                color: "transparent"
                                border.color: Theme.accent
                                border.width: 2
                                visible: processingRoot.isCurrent(stepPhase)
                                
                                SequentialAnimation on scale {
                                    loops: Animation.Infinite
                                    running: visible
                                    NumberAnimation { from: 1; to: 1.6; duration: 800; easing.type: Easing.OutQuad }
                                    NumberAnimation { from: 1.6; to: 1; duration: 800; easing.type: Easing.InQuad }
                                }
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: visible
                                    NumberAnimation { from: 0.8; to: 0; duration: 800; easing.type: Easing.OutQuad }
                                    NumberAnimation { from: 0; to: 0.8; duration: 800; easing.type: Easing.InQuad }
                                }
                            }
                        }
                        
                        Text {
                            text: label
                            color: processingRoot.isCurrent(stepPhase) ? Theme.textPrimary : (processingRoot.isPast(stepPhase) ? Theme.textSecondary : Theme.textDisabled)
                            font.pixelSize: Theme.fontSmall
                            font.bold: processingRoot.isCurrent(stepPhase) || processingRoot.isPast(stepPhase)
                        }
                    }
                }
                
                Item { Layout.fillWidth: true } // Left center align
                
                Loader { sourceComponent: stepDelegate; property string stepPhase: "hashing"; property string label: "Hashing" }
                
                Rectangle { Layout.preferredWidth: 30; height: 2; color: processingRoot.isPast("hashing") ? Theme.textSecondary : Theme.border; radius: 1 }
                
                Loader { sourceComponent: stepDelegate; property string stepPhase: "comparing"; property string label: "Comparing" }
                
                Rectangle { Layout.preferredWidth: 30; height: 2; color: processingRoot.isPast("comparing") ? Theme.textSecondary : Theme.border; radius: 1 }
                
                Loader { sourceComponent: stepDelegate; property string stepPhase: "grouping"; property string label: "Grouping" }
                
                Item { Layout.fillWidth: true } // Right center align
            }
            
            Item { Layout.fillHeight: true } // Spacer
            
            // ── Progress Bar & Status ───────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: {
                            if (phase === "hashing") return "Computing perceptual fingerprints..."
                            if (phase === "comparing") return "Filtering & refining similar pairs..."
                            if (phase === "grouping") return "Building connected components..."
                            if (phase === "done") return "Finalizing groups..."
                            return "Preparing engine..."
                        }
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSmall
                        Layout.fillWidth: true
                    }
                    
                    Text {
                        text: progressPercent + "%"
                        color: Theme.accent
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        font.family: "Consolas, monospace"
                    }
                }
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    color: Theme.bgApp
                    radius: 3
                    clip: true
                    
                    Rectangle {
                        width: parent.width * (progressPercent / 100)
                        height: parent.height
                        radius: 3
                        
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.lighter(Theme.accent, 1.4) }
                            GradientStop { position: 1.0; color: Theme.accent }
                        }
                        
                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
}
