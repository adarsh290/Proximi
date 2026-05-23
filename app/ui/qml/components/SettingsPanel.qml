import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

// Settings overlay panel — VS Code-style grouped sections with slide-in animation
Item {
    id: overlayRoot
    property bool panelVisible: typeof settingsController !== "undefined"
                                ? settingsController.settingsPanelVisible : false

    // ── Inline helper: reusable slider + label row ─────────────────────
    component SettingsSliderRow: ColumnLayout {
        id: ssrRoot
        spacing: 4

        property string label: ""
        property string hint: ""
        property string minLabel: ""
        property string maxLabel: ""
        property real from: 0
        property real to: 1
        property real stepSize: 1
        property real value: 0
        property bool isInt: true
        property var sliderRef: null  // Unused — kept for API compat

        signal valueCommitted(real v)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: ssrRoot.label
                color: Theme.textPrimary
                font.pixelSize: Theme.fontBody
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
            TextField {
                id: ssrInput
                text: ssrRoot.isInt
                      ? Math.round(ssrRoot.value).toString()
                      : ssrRoot.value.toFixed(2)
                color: Theme.accent
                font.pixelSize: Theme.fontBody
                font.bold: true
                background: Rectangle {
                    color: Theme.bgHover; radius: 4
                    border.color: parent.activeFocus ? Theme.accent : "transparent"
                }
                Layout.preferredWidth: 52
                Layout.preferredHeight: 26
                horizontalAlignment: TextInput.AlignRight
                validator: ssrRoot.isInt ? intVal : dblVal
                onEditingFinished: {
                    var v = ssrRoot.isInt ? parseInt(text) : parseFloat(text)
                    if (!isNaN(v)) ssrRoot.valueCommitted(v)
                }
                IntValidator    { id: intVal; bottom: ssrRoot.from; top: ssrRoot.to }
                DoubleValidator { id: dblVal; bottom: ssrRoot.from; top: ssrRoot.to; decimals: 2; notation: DoubleValidator.StandardNotation }
            }
        }

        Text {
            text: ssrRoot.hint
            color: Theme.textMuted; font.pixelSize: 10
            wrapMode: Text.WordWrap; Layout.fillWidth: true
        }

        Slider {
            id: ssrSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            from: ssrRoot.from; to: ssrRoot.to; stepSize: ssrRoot.stepSize
            value: ssrRoot.value
            onMoved: ssrRoot.valueCommitted(ssrRoot.isInt ? Math.round(value) : value)

            MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    // Prevent Slider from eating the wheel event
                    wheel.accepted = true
                    
                    // Manually pass the scroll intent to the parent Flickable
                    var newY = flickable.contentY - wheel.angleDelta.y
                    if (newY < 0) newY = 0
                    if (newY > flickable.contentHeight - flickable.height) {
                        newY = flickable.contentHeight - flickable.height
                    }
                    flickable.contentY = newY
                }
            }

            background: Rectangle {
                x: ssrSlider.leftPadding
                y: ssrSlider.topPadding + ssrSlider.availableHeight / 2 - height / 2
                width: ssrSlider.availableWidth; height: 4; radius: 2
                color: Theme.bgHover
                Rectangle {
                    width: ssrSlider.visualPosition * parent.width
                    height: parent.height; radius: 2; color: Theme.accent
                }
            }
            handle: Rectangle {
                x: ssrSlider.leftPadding + ssrSlider.visualPosition * (ssrSlider.availableWidth - width)
                y: ssrSlider.topPadding + ssrSlider.availableHeight / 2 - height / 2
                width: 16; height: 16; radius: 8
                color: ssrSlider.pressed ? Theme.accentHover : Theme.accent
                border.color: Theme.textPrimary; border.width: 1
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: ssrRoot.minLabel; color: Theme.textMuted; font.pixelSize: 9 }
            Item { Layout.fillWidth: true }
            Text { text: ssrRoot.maxLabel; color: Theme.textMuted; font.pixelSize: 9 }
        }
    }
    // ── End inline component ───────────────────────────────────────────

    visible: panelVisible || panelSlideAnim.running
    anchors.fill: parent
    z: 200

    // ── Backdrop with fade ─────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: overlayRoot.panelVisible ? 0.35 : 0.0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (typeof settingsController !== "undefined")
                    settingsController.closeSettingsPanel()
            }
        }
    }

    // ── Panel ──────────────────────────────────────────────────────────
    Rectangle {
        id: settingsPanel
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: 48
        anchors.bottomMargin: 32
        width: 380
        color: Theme.bgPanel
        border.color: Theme.borderLight
        border.width: 1
        radius: Theme.radiusM

        // Slide in/out from the right
        x: overlayRoot.panelVisible
           ? parent.width - width - Theme.spaceM
           : parent.width + 10
        Behavior on x {
            NumberAnimation {
                id: panelSlideAnim
                duration: Theme.animPage
                easing.type: Easing.OutCubic
            }
        }

        // Left accent bar
        Rectangle {
            width: 3
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.radiusM
            anchors.bottomMargin: Theme.radiusM
            radius: 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accent }
                GradientStop { position: 1.0; color: Theme.accentSubtle }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: "transparent"
                border.color: Theme.border
                border.width: 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceL
                    anchors.rightMargin: Theme.spaceM
                    spacing: Theme.spaceM

                    Text {
                        text: "Settings"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    // Close button
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: closeMouse.containsMouse ? Theme.bgHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: Theme.textSecondary
                            font.pixelSize: 13
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

                // Bottom border
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.border
                }
            }

            // ── Scrollable body ────────────────────────────────────────
            Flickable {
                id: flickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: bodyCol.implicitHeight + Theme.spaceXL
                clip: true
                interactive: true

                property bool anySliderActive: false  // Individual sliders handle their own scroll events

                ScrollBar.vertical: ScrollBar {
                    id: vbarSettings
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true

                    background: Item {}

                    contentItem: Rectangle {
                        implicitWidth: vbarSettings.pressed || vbarSettings.hovered ? 8 : 2
                        radius: width / 2
                        color: Theme.textDisabled
                        opacity: vbarSettings.pressed || vbarSettings.hovered ? 0.8 : 0.4

                        Behavior on implicitWidth { NumberAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }

                ColumnLayout {
                    id: bodyCol
                    // Account for left margin + right margin to prevent clipping
                    width: flickable.width - Theme.spaceL - Theme.spaceM
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceL
                    spacing: 0

                    // ════════════════════════════════════════════════════
                    // SECTION: GENERAL
                    // ════════════════════════════════════════════════════
                    Item { Layout.preferredHeight: Theme.spaceL }

                    Text {
                        text: "GENERAL"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Item { Layout.preferredHeight: Theme.spaceS }

                    // Thumbnail quality
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Thumbnail Quality"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontBody
                                Layout.fillWidth: true
                            }
                            Text {
                                text: (typeof settingsController !== "undefined"
                                       ? settingsController.thumbnailQuality : 85) + "%"
                                color: Theme.accent
                                font.bold: true
                                font.pixelSize: Theme.fontBody
                            }
                        }
                        Text {
                            text: "Higher quality = sharper thumbnails, larger cache size."
                            color: Theme.textMuted
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Slider {
                            id: qualitySlider
                            Layout.fillWidth: true
                            from: 50; to: 100; stepSize: 5
                            value: typeof settingsController !== "undefined"
                                   ? settingsController.thumbnailQuality : 85
                            onMoved: {
                                if (typeof settingsController !== "undefined")
                                    settingsController.setThumbnailQuality(Math.round(value))
                            }
                            background: Rectangle {
                                x: qualitySlider.leftPadding
                                y: qualitySlider.topPadding + qualitySlider.availableHeight / 2 - height / 2
                                width: qualitySlider.availableWidth
                                height: 4; radius: 2
                                color: Theme.bgHover
                                Rectangle {
                                    width: qualitySlider.visualPosition * parent.width
                                    height: parent.height; radius: 2
                                    color: Theme.accent
                                }
                            }
                            handle: Rectangle {
                                x: qualitySlider.leftPadding + qualitySlider.visualPosition * (qualitySlider.availableWidth - width)
                                y: qualitySlider.topPadding + qualitySlider.availableHeight / 2 - height / 2
                                width: 16; height: 16; radius: 8
                                color: qualitySlider.pressed ? Theme.accentHover : Theme.accent
                                border.color: Theme.textPrimary; border.width: 1
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "50%"; color: Theme.textMuted; font.pixelSize: 9 }
                            Item { Layout.fillWidth: true }
                            Text { text: "100%"; color: Theme.textMuted; font.pixelSize: 9 }
                        }
                    }

                    // ── Section Divider ─────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: Theme.spaceL; Layout.bottomMargin: Theme.spaceS }

                    // ════════════════════════════════════════════════════
                    // SECTION: SIMILARITY THRESHOLDS
                    // ════════════════════════════════════════════════════
                    Item { Layout.preferredHeight: Theme.spaceS }

                    Text {
                        text: "SIMILARITY THRESHOLDS"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Item { Layout.preferredHeight: 4 }

                    Text {
                        text: "Controls how aggressively photos are grouped as \"similar\"."
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontCaption
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Item { Layout.preferredHeight: Theme.spaceS }

                    // pHash
                    SettingsSliderRow {
                        id: phashRow
                        Layout.fillWidth: true
                        label: "pHash Distance"
                        hint: "Perceptual hash tolerance. Higher = groups more photos."
                        minLabel: "Strict (2)"; maxLabel: "Loose (28)"
                        from: 2; to: 28; stepSize: 1; isInt: true
                        value: typeof settingsController !== "undefined" ? settingsController.phashThreshold : 12
                        onValueCommitted: (v) => {
                            if (typeof settingsController !== "undefined")
                                settingsController.setPhashThreshold(v)
                        }
                    }

                    // SSIM
                    SettingsSliderRow {
                        id: ssimRow
                        Layout.fillWidth: true
                        label: "SSIM Similarity"
                        hint: "Min structural similarity score. Lower = more tolerant."
                        minLabel: "Loose (0.20)"; maxLabel: "Strict (0.95)"
                        from: 0.20; to: 0.95; stepSize: 0.05; isInt: false
                        value: typeof settingsController !== "undefined" ? settingsController.ssimThreshold : 0.55
                        onValueCommitted: (v) => {
                            if (typeof settingsController !== "undefined")
                                settingsController.setSsimThreshold(v)
                        }
                    }

                    // dHash
                    SettingsSliderRow {
                        id: dhashRow
                        Layout.fillWidth: true
                        label: "dHash Distance"
                        hint: "Difference hash tolerance. Higher = more detail change allowed."
                        minLabel: "Strict (4)"; maxLabel: "Loose (30)"
                        from: 4; to: 30; stepSize: 1; isInt: true
                        value: typeof settingsController !== "undefined" ? settingsController.dhashThreshold : 18
                        onValueCommitted: (v) => {
                            if (typeof settingsController !== "undefined")
                                settingsController.setDhashThreshold(v)
                        }
                    }

                    // Histogram
                    SettingsSliderRow {
                        id: histRow
                        Layout.fillWidth: true
                        label: "Color Histogram"
                        hint: "Min color distribution match. Lower = tolerates lighting changes."
                        minLabel: "Loose (0.10)"; maxLabel: "Strict (0.90)"
                        from: 0.10; to: 0.90; stepSize: 0.05; isInt: false
                        value: typeof settingsController !== "undefined" ? settingsController.histogramThreshold : 0.30
                        onValueCommitted: (v) => {
                            if (typeof settingsController !== "undefined")
                                settingsController.setHistogramThreshold(v)
                        }
                    }

                    Item { Layout.preferredHeight: Theme.spaceS }

                    // Reset button
                    Button {
                        id: resetBtn
                        text: "Reset Thresholds to Defaults"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        onClicked: {
                            if (typeof settingsController !== "undefined")
                                settingsController.resetToDefaults()
                        }
                        background: Rectangle {
                            radius: Theme.radiusS
                            color: resetBtn.hovered ? Theme.bgHover : "transparent"
                            border.color: Theme.border; border.width: 1
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                        contentItem: Text {
                            text: resetBtn.text
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSmall
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        text: "💡 Changes apply on next \"Find Similar\" run."
                        color: Theme.textMuted; font.pixelSize: 10; font.italic: true
                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }

                    // ── Section Divider ─────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: Theme.spaceL; Layout.bottomMargin: Theme.spaceS }

                    // ════════════════════════════════════════════════════
                    // SECTION: SESSION
                    // ════════════════════════════════════════════════════
                    Item { Layout.preferredHeight: Theme.spaceS }

                    Text {
                        text: "SESSION"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Item { Layout.preferredHeight: Theme.spaceS }

                    // Session persistence toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceM

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Remember Sessions"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontBody
                            }
                            Text {
                                text: "Keep scan data between launches. When off, all data is wiped on exit."
                                color: Theme.textMuted
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // Toggle switch
                        Rectangle {
                            id: toggleTrack
                            width: 44; height: 24; radius: 12
                            color: sessionToggle.checked ? Theme.accent : Theme.bgHover
                            Behavior on color { ColorAnimation { duration: Theme.animNormal } }

                            Rectangle {
                                id: toggleThumb
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: sessionToggle.checked ? parent.width - width - 3 : 3
                                color: "white"
                                Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                            }

                            CheckBox {
                                id: sessionToggle
                                anchors.fill: parent
                                checked: typeof settingsController !== "undefined"
                                         && settingsController.sessionPersistence
                                onToggled: {
                                    if (typeof settingsController !== "undefined")
                                        settingsController.setSessionPersistence(checked)
                                }
                                indicator: Item {} // Hidden — visual handled by track/thumb
                                background: Item {}
                            }
                        }
                    }

                    // ── Section Divider ─────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: Theme.spaceL; Layout.bottomMargin: Theme.spaceS }

                    // ════════════════════════════════════════════════════
                    // SECTION: KEYBOARD SHORTCUTS
                    // ════════════════════════════════════════════════════
                    Item { Layout.preferredHeight: Theme.spaceS }

                    Text {
                        text: "KEYBOARD SHORTCUTS"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Item { Layout.preferredHeight: Theme.spaceS }

                    // Shortcut rows
                    Repeater {
                        model: [
                            { key: "→ / D",       action: "Next group" },
                            { key: "← / A",       action: "Previous group" },
                            { key: "Ctrl+Enter",  action: "Execute cleanup" },
                            { key: "Ctrl+Z",      action: "Undo last cleanup" },
                            { key: "Space",       action: "Preview image" },
                            { key: "Esc",         action: "Close preview / panel" },
                        ]
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28

                            Rectangle {
                                radius: 4
                                color: Theme.bgCard
                                border.color: Theme.border
                                border.width: 1
                                Layout.preferredWidth: kbLabel.implicitWidth + 16
                                Layout.preferredHeight: 22
                                Text {
                                    id: kbLabel
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: Theme.textSecondary
                                    font.pixelSize: 10
                                    font.family: "Consolas, monospace"
                                }
                            }

                            Text {
                                text: modelData.action
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSmall
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // ── Section Divider ─────────────────────────────────
                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border; Layout.topMargin: Theme.spaceL; Layout.bottomMargin: Theme.spaceS }

                    // ════════════════════════════════════════════════════
                    // SECTION: ABOUT
                    // ════════════════════════════════════════════════════
                    Item { Layout.preferredHeight: Theme.spaceS }

                    Text {
                        text: "ABOUT"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSmall
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    Item { Layout.preferredHeight: Theme.spaceS }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceS

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Version"; color: Theme.textMuted; font.pixelSize: Theme.fontSmall; Layout.fillWidth: true }
                            Text { text: "0.9.0-alpha"; color: Theme.textSecondary; font.pixelSize: Theme.fontSmall }
                        }

                        // Re-show onboarding
                        Button {
                            id: tutorialBtn
                            text: "Show Tutorial Again"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            onClicked: {
                                if (typeof settingsController !== "undefined") {
                                    settingsController.closeSettingsPanel()
                                    settingsController.resetOnboarding()
                                }
                            }
                            background: Rectangle {
                                radius: Theme.radiusS
                                color: tutorialBtn.hovered ? Theme.bgHover : "transparent"
                                border.color: Theme.border; border.width: 1
                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                            contentItem: Text {
                                text: tutorialBtn.text
                                color: Theme.accent
                                font.pixelSize: Theme.fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Item { Layout.preferredHeight: Theme.spaceXL }
                }
            }
        }
    }
}
