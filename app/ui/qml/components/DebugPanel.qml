import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Rectangle {
    id: debugRoot

    property bool panelVisible: false
    property var snapshot: ({})

    visible: panelVisible
    width: 320
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    color: "#0F0F0F"
    border.width: 1
    border.color: Theme.border
    z: 100

    // ── Refresh timer (lightweight, only when visible) ────────────
    Timer {
        id: refreshTimer
        interval: 1500
        running: debugRoot.panelVisible && typeof debugController !== "undefined"
        repeat: true
        onTriggered: {
            if (typeof debugController !== "undefined") {
                debugRoot.snapshot = debugController.getSnapshot()
            }
        }
    }

    // Load initial snapshot when shown
    onPanelVisibleChanged: {
        if (panelVisible && typeof debugController !== "undefined") {
            debugRoot.snapshot = debugController.getSnapshot()
        }
    }

    // ── Content ──────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        anchors.margins: 1
        contentHeight: contentCol.height + 16
        clip: true
        flickableDirection: Flickable.VerticalFlick

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.textDisabled
                opacity: 0.4
            }
        }

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 0

            // ── Header ───────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: "#1A1A1A"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8

                    Text {
                        text: "⚙ DEBUG"
                        color: Theme.accent
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.family: "Consolas, monospace"
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "✕"
                        color: Theme.textSecondary
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof debugController !== "undefined")
                                    debugController.toggle()
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // ── Scan Metrics ─────────────────────────────────────
            DebugSection {
                title: "SCAN"
                metrics: [
                    { label: "Status",    value: debugRoot.snapshot.scanStatus || "idle" },
                    { label: "Folder",    value: truncPath(debugRoot.snapshot.scanFolder || "—") },
                    { label: "Scanned",   value: (debugRoot.snapshot.imagesScanned || 0) + " / " + (debugRoot.snapshot.totalDiscovered || 0) },
                    { label: "Skipped",   value: String(debugRoot.snapshot.imagesSkipped || 0) },
                    { label: "Failed",    value: String(debugRoot.snapshot.imagesFailed || 0) },
                    { label: "Duration",  value: (debugRoot.snapshot.scanDuration || 0) + "s" },
                    { label: "Session",   value: "#" + (debugRoot.snapshot.scanSessionId || 0) },
                    { label: "Rate",      value: (debugRoot.snapshot.scanThroughput || 0) + " img/s" }
                ]
            }

            // ── Thumbnail Metrics ────────────────────────────────
            DebugSection {
                title: "THUMBNAILS"
                metrics: [
                    { label: "Generated",   value: String(debugRoot.snapshot.thumbGenerated || 0) },
                    { label: "Cache Hits",  value: String(debugRoot.snapshot.thumbCacheHits || 0) },
                    { label: "Cache Miss",  value: String(debugRoot.snapshot.thumbCacheMisses || 0) },
                    { label: "Failures",    value: String(debugRoot.snapshot.thumbFailures || 0) }
                ]
            }

            // ── Similarity Metrics ───────────────────────────────
            DebugSection {
                title: "SIMILARITY"
                metrics: [
                    { label: "Hashes",      value: String(debugRoot.snapshot.simHashes || 0) },
                    { label: "Candidates",  value: String(debugRoot.snapshot.simCandidates || 0) },
                    { label: "Refined",     value: String(debugRoot.snapshot.simRefined || 0) },
                    { label: "Groups",      value: String(debugRoot.snapshot.simGroups || 0) },
                    { label: "Duration",    value: (debugRoot.snapshot.simDuration || 0) + "s" }
                ]
            }

            // ── Worker Metrics ───────────────────────────────────
            DebugSection {
                title: "WORKERS"
                metrics: [
                    { label: "Active",    value: String(debugRoot.snapshot.activeWorkers || 0) },
                    { label: "Cancelled", value: debugRoot.snapshot.workerCancelled ? "YES" : "no" }
                ]
            }

            // ── Database Metrics ─────────────────────────────────
            DebugSection {
                title: "DATABASE"
                metrics: [
                    { label: "Images",     value: String(debugRoot.snapshot.dbImageCount || 0) },
                    { label: "Sessions",   value: String(debugRoot.snapshot.dbSessionCount || 0) },
                    { label: "Thumb Cache", value: String(debugRoot.snapshot.dbCachedThumbnails || 0) }
                ]
            }

            // ── Runtime ──────────────────────────────────────────
            DebugSection {
                title: "RUNTIME"
                metrics: [
                    { label: "RAM", value: (debugRoot.snapshot.ramUsageMb || 0) > 0
                                          ? debugRoot.snapshot.ramUsageMb + " MB"
                                          : "N/A (psutil)" }
                ]
            }

            // Bottom padding
            Item { Layout.fillWidth: true; height: 8 }
        }
    }

    // ── Helper: truncate long paths ──────────────────────────────
    function truncPath(p) {
        if (!p || p.length <= 30) return p
        return "…" + p.slice(-28)
    }
}
