import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

// Settings overlay panel — floating dialog
Item {
    id: overlayRoot
    property bool panelVisible: typeof settingsController !== "undefined" ? settingsController.settingsPanelVisible : false

    visible: panelVisible
    anchors.fill: parent
    z: 200

    // Click-away backdrop
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (typeof settingsController !== "undefined")
                settingsController.closeSettingsPanel()
        }
    }

    Rectangle {
        id: settingsPanel
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Theme.spaceM
        anchors.topMargin: 56 // Positioned appropriately below the top bar
        width: 360
        height: Math.min(settingsColumn.implicitHeight + Theme.spaceM * 2, parent.height - 80)
        color: Theme.bgPanel
        border.color: Theme.borderLight
        border.width: 1
        radius: Theme.radiusM

        Flickable {
            id: settingsFlickable
            anchors.fill: parent
            anchors.margins: Theme.spaceM
            contentHeight: settingsColumn.implicitHeight
            clip: true
            // FIX 5: Disable interactive flickable so sliders can receive mouse events
            interactive: !sliderInteracting

            // Track if any slider is being interacted with
            property bool sliderInteracting: phashSlider.pressed || ssimSlider.pressed || dhashSlider.pressed || histSlider.pressed

            ColumnLayout {
                id: settingsColumn
                width: parent.width
                spacing: Theme.spaceL

                // ── Header ───────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "⚙  Settings"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    // Close button
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: closeMouse.containsMouse ? Theme.bgHover : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Theme.textSecondary
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsController.closeSettingsPanel()
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                // ── Section: Similarity Thresholds ───────────────────────
                Text {
                    text: "SIMILARITY THRESHOLDS"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSmall
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                Text {
                    text: "Adjust how aggressively photos are grouped.\nLower strictness = more groups, fewer false matches.\nHigher strictness = fewer groups, catches more similar shots."
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontCaption
                    wrapMode: Text.WordWrap
                    lineHeight: 1.4
                    Layout.fillWidth: true
                }

                // ── pHash Threshold ──────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "pHash Distance"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontBody
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                        TextField {
                            id: phashInput
                            text: typeof settingsController !== "undefined" ? settingsController.phashThreshold.toString() : "12"
                            color: Theme.accent
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            background: Rectangle { 
                                color: Theme.bgHover
                                radius: 4
                                border.color: parent.activeFocus ? Theme.accent : "transparent" 
                            }
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 28
                            horizontalAlignment: TextInput.AlignRight
                            validator: IntValidator { bottom: 2; top: 28 }
                            onEditingFinished: {
                                var val = parseInt(text)
                                if (!isNaN(val) && typeof settingsController !== "undefined") {
                                    settingsController.setPhashThreshold(val)
                                }
                            }
                        }
                    }
                    Text {
                        text: "How different the perceptual hash can be. Higher = catches more similar photos."
                        color: Theme.textMuted
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Slider {
                        id: phashSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        from: 2; to: 28; stepSize: 1
                        value: typeof settingsController !== "undefined" ? settingsController.phashThreshold : 12
                        onMoved: {
                            if (typeof settingsController !== "undefined")
                                settingsController.setPhashThreshold(Math.round(value))
                        }

                        // FIX 5: Handle mouse wheel on slider
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    phashSlider.increase()
                                } else {
                                    phashSlider.decrease()
                                }
                                if (typeof settingsController !== "undefined")
                                    settingsController.setPhashThreshold(Math.round(phashSlider.value))
                            }
                        }

                        background: Rectangle {
                            x: phashSlider.leftPadding
                            y: phashSlider.topPadding + phashSlider.availableHeight / 2 - height / 2
                            width: phashSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Theme.bgHover

                            Rectangle {
                                width: phashSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                            }
                        }
                        handle: Rectangle {
                            x: phashSlider.leftPadding + phashSlider.visualPosition * (phashSlider.availableWidth - width)
                            y: phashSlider.topPadding + phashSlider.availableHeight / 2 - height / 2
                            width: 16; height: 16; radius: 8
                            color: phashSlider.pressed ? Theme.accentHover : Theme.accent
                            border.color: Theme.textPrimary
                            border.width: 1
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Strict (2)"; color: Theme.textMuted; font.pixelSize: 9 }
                        Item { Layout.fillWidth: true }
                        Text { text: "Loose (28)"; color: Theme.textMuted; font.pixelSize: 9 }
                    }
                }

                // ── SSIM Threshold ───────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "SSIM Similarity"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontBody
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                        TextField {
                            id: ssimInput
                            text: typeof settingsController !== "undefined" ? settingsController.ssimThreshold.toFixed(2) : "0.55"
                            color: Theme.accent
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            background: Rectangle { 
                                color: Theme.bgHover
                                radius: 4
                                border.color: parent.activeFocus ? Theme.accent : "transparent" 
                            }
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 28
                            horizontalAlignment: TextInput.AlignRight
                            validator: DoubleValidator { bottom: 0.20; top: 0.95; decimals: 2; notation: DoubleValidator.StandardNotation }
                            onEditingFinished: {
                                var val = parseFloat(text)
                                if (!isNaN(val) && typeof settingsController !== "undefined") {
                                    settingsController.setSsimThreshold(val)
                                }
                            }
                        }
                    }
                    Text {
                        text: "Minimum structural similarity score to group. Lower = groups more different-looking photos."
                        color: Theme.textMuted
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Slider {
                        id: ssimSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        from: 0.20; to: 0.95; stepSize: 0.05
                        value: typeof settingsController !== "undefined" ? settingsController.ssimThreshold : 0.55
                        onMoved: {
                            if (typeof settingsController !== "undefined")
                                settingsController.setSsimThreshold(value)
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    ssimSlider.increase()
                                } else {
                                    ssimSlider.decrease()
                                }
                                if (typeof settingsController !== "undefined")
                                    settingsController.setSsimThreshold(ssimSlider.value)
                            }
                        }

                        background: Rectangle {
                            x: ssimSlider.leftPadding
                            y: ssimSlider.topPadding + ssimSlider.availableHeight / 2 - height / 2
                            width: ssimSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Theme.bgHover

                            Rectangle {
                                width: ssimSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                            }
                        }
                        handle: Rectangle {
                            x: ssimSlider.leftPadding + ssimSlider.visualPosition * (ssimSlider.availableWidth - width)
                            y: ssimSlider.topPadding + ssimSlider.availableHeight / 2 - height / 2
                            width: 16; height: 16; radius: 8
                            color: ssimSlider.pressed ? Theme.accentHover : Theme.accent
                            border.color: Theme.textPrimary
                            border.width: 1
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Loose (0.20)"; color: Theme.textMuted; font.pixelSize: 9 }
                        Item { Layout.fillWidth: true }
                        Text { text: "Strict (0.95)"; color: Theme.textMuted; font.pixelSize: 9 }
                    }
                }

                // ── dHash Threshold ──────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "dHash Distance"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontBody
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                        TextField {
                            id: dhashInput
                            text: typeof settingsController !== "undefined" ? settingsController.dhashThreshold.toString() : "18"
                            color: Theme.accent
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            background: Rectangle { 
                                color: Theme.bgHover
                                radius: 4
                                border.color: parent.activeFocus ? Theme.accent : "transparent" 
                            }
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 28
                            horizontalAlignment: TextInput.AlignRight
                            validator: IntValidator { bottom: 4; top: 30 }
                            onEditingFinished: {
                                var val = parseInt(text)
                                if (!isNaN(val) && typeof settingsController !== "undefined") {
                                    settingsController.setDhashThreshold(val)
                                }
                            }
                        }
                    }
                    Text {
                        text: "Max difference hash distance before rejecting a pair. Higher = more tolerant of detail changes."
                        color: Theme.textMuted
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Slider {
                        id: dhashSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        from: 4; to: 30; stepSize: 1
                        value: typeof settingsController !== "undefined" ? settingsController.dhashThreshold : 18
                        onMoved: {
                            if (typeof settingsController !== "undefined")
                                settingsController.setDhashThreshold(Math.round(value))
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    dhashSlider.increase()
                                } else {
                                    dhashSlider.decrease()
                                }
                                if (typeof settingsController !== "undefined")
                                    settingsController.setDhashThreshold(Math.round(dhashSlider.value))
                            }
                        }

                        background: Rectangle {
                            x: dhashSlider.leftPadding
                            y: dhashSlider.topPadding + dhashSlider.availableHeight / 2 - height / 2
                            width: dhashSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Theme.bgHover

                            Rectangle {
                                width: dhashSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                            }
                        }
                        handle: Rectangle {
                            x: dhashSlider.leftPadding + dhashSlider.visualPosition * (dhashSlider.availableWidth - width)
                            y: dhashSlider.topPadding + dhashSlider.availableHeight / 2 - height / 2
                            width: 16; height: 16; radius: 8
                            color: dhashSlider.pressed ? Theme.accentHover : Theme.accent
                            border.color: Theme.textPrimary
                            border.width: 1
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Strict (4)"; color: Theme.textMuted; font.pixelSize: 9 }
                        Item { Layout.fillWidth: true }
                        Text { text: "Loose (30)"; color: Theme.textMuted; font.pixelSize: 9 }
                    }
                }

                // ── Histogram Threshold ──────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Color Histogram"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontBody
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                        TextField {
                            id: histInput
                            text: typeof settingsController !== "undefined" ? settingsController.histogramThreshold.toFixed(2) : "0.30"
                            color: Theme.accent
                            font.pixelSize: Theme.fontBody
                            font.bold: true
                            background: Rectangle { 
                                color: Theme.bgHover
                                radius: 4
                                border.color: parent.activeFocus ? Theme.accent : "transparent" 
                            }
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 28
                            horizontalAlignment: TextInput.AlignRight
                            validator: DoubleValidator { bottom: 0.10; top: 0.90; decimals: 2; notation: DoubleValidator.StandardNotation }
                            onEditingFinished: {
                                var val = parseFloat(text)
                                if (!isNaN(val) && typeof settingsController !== "undefined") {
                                    settingsController.setHistogramThreshold(val)
                                }
                            }
                        }
                    }
                    Text {
                        text: "Min color distribution match. Lower = tolerates lighting/color changes between photos."
                        color: Theme.textMuted
                        font.pixelSize: 10
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Slider {
                        id: histSlider
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        from: 0.10; to: 0.90; stepSize: 0.05
                        value: typeof settingsController !== "undefined" ? settingsController.histogramThreshold : 0.30
                        onMoved: {
                            if (typeof settingsController !== "undefined")
                                settingsController.setHistogramThreshold(value)
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    histSlider.increase()
                                } else {
                                    histSlider.decrease()
                                }
                                if (typeof settingsController !== "undefined")
                                    settingsController.setHistogramThreshold(histSlider.value)
                            }
                        }

                        background: Rectangle {
                            x: histSlider.leftPadding
                            y: histSlider.topPadding + histSlider.availableHeight / 2 - height / 2
                            width: histSlider.availableWidth
                            height: 4
                            radius: 2
                            color: Theme.bgHover

                            Rectangle {
                                width: histSlider.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: Theme.accent
                            }
                        }
                        handle: Rectangle {
                            x: histSlider.leftPadding + histSlider.visualPosition * (histSlider.availableWidth - width)
                            y: histSlider.topPadding + histSlider.availableHeight / 2 - height / 2
                            width: 16; height: 16; radius: 8
                            color: histSlider.pressed ? Theme.accentHover : Theme.accent
                            border.color: Theme.textPrimary
                            border.width: 1
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Loose (0.10)"; color: Theme.textMuted; font.pixelSize: 9 }
                        Item { Layout.fillWidth: true }
                        Text { text: "Strict (0.90)"; color: Theme.textMuted; font.pixelSize: 9 }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                    Layout.topMargin: Theme.spaceS
                }

                // ── Reset Button ─────────────────────────────────────────
                Button {
                    id: resetBtn
                    text: "Reset to Defaults"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    onClicked: {
                        if (typeof settingsController !== "undefined") {
                            settingsController.resetToDefaults()
                        }
                    }
                    background: Rectangle {
                        radius: Theme.radiusS
                        color: resetBtn.hovered ? Theme.bgHover : Theme.bgPanel
                        border.color: Theme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: Text {
                        text: resetBtn.text
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSmall
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Note
                Text {
                    text: "💡 Changes apply on next \"Find Similar\" run."
                    color: Theme.textMuted
                    font.pixelSize: 10
                    font.italic: true
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // Bottom spacer
                Item { Layout.preferredHeight: Theme.spaceL }
            }
        }
    }
}
