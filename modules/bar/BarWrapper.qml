pragma ComponentBehavior: Bound

import QtQuick
import "components"
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    required property string position

    readonly property bool horizontal: position !== "left"
    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property int clampedExtent: Math.max(Config.border.minThickness, extent)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentThickness: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? contentThickness : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    property bool isHovered
    property real extent: fullscreen ? 0 : Config.border.thickness

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(pos: real): void {
        (content.item as Bar)?.checkPopout(pos);
    }

    function entryAt(pos: real): string {
        return (content.item as Bar)?.entryAt(pos) ?? "";
    }

    function handleWheel(pos: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(pos, angleDelta);
    }

    clip: true
    visible: extent > Config.border.thickness
    implicitWidth: extent
    implicitHeight: extent

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.extent: root.contentThickness
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "extent"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "extent"
                type: Anim.Emphasized
            }
        }
    ]

    Loader {
        id: content

        anchors.top: root.position !== "top" ? parent.top : undefined
        anchors.bottom: root.position !== "bottom" ? parent.bottom : undefined
        anchors.left: root.horizontal ? parent.left : undefined
        anchors.right: parent.right

        width: root.contentThickness
        height: root.contentThickness

        active: root.shouldBeVisible

        sourceComponent: Bar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
            horizontal: root.horizontal
        }
    }

    ActiveWindow {
        id: fixedActiveWindow

        objectName: "fixedTaskbarActiveWindow"
        bar: content.item as Bar
        horizontal: root.horizontal
        maxSizeOverride: root.horizontal ? width : height
        forceMouseArea: true

        anchors.left: root.horizontal ? parent.left : undefined
        anchors.top: root.horizontal ? undefined : parent.top
        anchors.leftMargin: root.horizontal ? root.padding + 36 : 0
        anchors.topMargin: root.horizontal ? 0 : root.padding

        width: root.horizontal ? Math.min(320, Math.max(0, parent.width - root.padding * 2)) : root.contentThickness
        height: root.horizontal ? root.contentThickness : Math.min(320, Math.max(0, parent.height - root.padding * 2))
        visible: root.shouldBeVisible && content.status === Loader.Ready
    }
}
