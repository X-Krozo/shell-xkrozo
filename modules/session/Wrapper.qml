pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ScreenState screenState
    required property bool sidebarVisible
    readonly property real nonAnimWidth: content.implicitWidth

    readonly property bool shouldBeActive: screenState.session && Config.session.enabled
    property real offsetScale: shouldBeActive ? 0 : 1
    property real sidebarOffset: sidebarVisible ? 14 : 0
    readonly property string hoveredTooltip: (content.item as Content)?.hoveredTooltip ?? ""
    property real tooltipExtent: hoveredTooltip.length > 0 ? tooltip.implicitHeight + Tokens.spacing.medium : 0

    visible: offsetScale < 1
    anchors.rightMargin: (-implicitWidth - 5 - sidebarOffset) * offsetScale
    implicitWidth: content.implicitWidth
    implicitHeight: (content.implicitHeight || 510) + tooltipExtent // Hard coded fallback for first open
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on tooltipExtent {
        Anim {}
    }

    Loader {
        id: content

        anchors.bottom: parent.bottom
        anchors.left: parent.left

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screenState: root.screenState
        }
    }

    StyledRect {
        id: tooltip

        anchors.bottom: content.top
        anchors.bottomMargin: 0
        anchors.horizontalCenter: content.horizontalCenter

        implicitWidth: label.implicitWidth + Tokens.padding.large * 2
        implicitHeight: (label.implicitHeight + Tokens.padding.medium * 2) * 0.75
        visible: opacity > 0
        opacity: root.hoveredTooltip.length > 0 ? 1 : 0
        scale: root.hoveredTooltip.length > 0 ? 1 : 0.85
        color: "transparent"
        radius: Tokens.rounding.large
        transformOrigin: Item.Bottom

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on implicitHeight {
            Anim {}
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: root.hoveredTooltip
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.builders.medium.scale(0.9).build()
        }
    }
}
