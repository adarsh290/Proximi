pragma Singleton
import QtQuick

QtObject {
    // Colors - Premium Layered Dark Theme
    readonly property color bgApp: "#0A0A0F"
    readonly property color bgSidebar: "#111118"
    readonly property color bgPanel: "#161620"
    readonly property color bgHover: "#1F1F2E"
    readonly property color bgGlass: "#CC161620"

    readonly property color accent: "#7C3AED" // Vivid Violet
    readonly property color accentHover: "#6D28D9"
    readonly property color accentDisabled: "#4C1D95"
    readonly property color accentSubtle: "#5B21B6"

    readonly property color textPrimary: "#FFFFFF"
    readonly property color textSecondary: "#A1A1AA"
    readonly property color textDisabled: "#52525B"
    readonly property color textMuted: "#71717A"

    readonly property color border: "#27272A"
    readonly property color borderLight: "#3F3F46"
    readonly property color bgElevated: "#18181B"

    // Card colors
    readonly property color bgCard: "#12121A"
    readonly property color bgCardHover: "#1C1C26"
    readonly property color accentGlow: "#7C3AED40" // Violet with alpha
    readonly property color shadowColor: "#40000000" // Dark shadow

    // Status colors
    readonly property color success: "#22C55E"
    readonly property color warning: "#F59E0B"
    readonly property color error: "#EF4444"

    // Spacing
    readonly property int spaceXS: 4
    readonly property int spaceS: 8
    readonly property int spaceM: 16
    readonly property int spaceL: 24
    readonly property int spaceXL: 32

    // Radius
    readonly property int radiusS: 4
    readonly property int radiusM: 8
    readonly property int radiusL: 12
    readonly property int radiusXL: 20
    readonly property int radiusXXL: 28

    // Typography
    readonly property int fontDisplay: 28
    readonly property int fontTitle: 20
    readonly property int fontHeader: 16
    readonly property int fontBody: 14
    readonly property int fontMedium: 13
    readonly property int fontSmall: 12
    readonly property int fontCaption: 11

    // Grid
    readonly property int thumbnailSize: 180
    readonly property int gridSpacing: 8
}
