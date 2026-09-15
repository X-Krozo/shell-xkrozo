pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1
    property bool useLiveHeight: false
    property real frozenHeight: 0
    property real liveContentHeight: 0
    property Item contentItem: content.item

    onContentItemChanged: {
        if (contentItem)
            liveContentHeight = contentItem.implicitHeight;
    }

    Connections {
        target: root.contentItem
        function onImplicitHeightChanged() {
            root.liveContentHeight = root.contentItem.implicitHeight;
        }
    }

    onShouldBeActiveChanged: {
        if (shouldBeActive) {
            useLiveHeight = true;
        } else {
            frozenHeight = (root.contentItem ? root.contentItem.implicitHeight : content.implicitHeight);
            useLiveHeight = false;
        }
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: useLiveHeight ? liveContentHeight + (content.item?.showingGrid ? 17 : 0) : frozenHeight
    implicitWidth: content.implicitWidth || 630 // Hard coded fallback for first open
    opacity: 1 - offsetScale

    Component.onCompleted: Qt.callLater(() => Apps) // Load apps on init

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screen: root.screen
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight
        }
    }
}
