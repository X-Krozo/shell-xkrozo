pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.components.misc
import qs.services
import qs.utils

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen
    required property bool horizontal

    property bool showNumbers: false
    property bool heldTooLong: false
    property int _lastButton: Qt.NoButton

    Connections {
        target: ShellState
        function onScreenLockedChanged() {
            if (!ShellState.screenLocked) {
                root.showNumbers = false
                root.heldTooLong = false
            }
        }
    }

    CustomShortcut {
        name: "workspaceNumbers"

        onPressed: {
            root.heldTooLong = false;
            holdTimer.restart();
            showNumbersTimer.restart();
            // Reset the launcher-interrupt counter at the start of every Super
            // press. workspaceNumbers fires reliably (unlike the launcher release,
            // which hyprland suppresses after chorded use), so a stale interrupt
            // from a previous long hold can never leak into this new press.
            ShellState.launcherInterrupts = 0;
        }

        onReleased: {
            holdTimer.stop();
            showNumbersTimer.stop();
            root.showNumbers = false;
        }
    }

    Timer {
        id: showNumbersTimer

        interval: 100
        onTriggered: root.showNumbers = true
    }

    Timer {
        id: holdTimer

        interval: 500
        onTriggered: {
            root.heldTooLong = true;
            // Suppress the launcher toggle bound to Super release after a long hold
            // (hyprslua parses dispatch strings as Lua, so use its dispatcher API)
            Hyprland.dispatch('hl.dsp.global("caelestia:launcherInterrupt")');
        }
    }

    component WsIcon: Item {
        id: wsIcon

        required property int index
        required property int activeWsId
        required property var occupiedMap
        required property int groupOffset
        required property bool showNumbers

        readonly property int cellSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small
        readonly property int ws: groupOffset + index + 1
        readonly property bool isOccupied: occupiedMap[ws] ?? false
        readonly property bool isActive: activeWsId === ws
        readonly property bool hasIcon: mainClass !== ""
        readonly property string mainClass: {
            const wins = Hypr.toplevels.values.filter(c => c.workspace?.id === ws && (c.lastIpcObject.class?.length ?? 0) > 0);
            const active = Hypr.activeToplevel;
            if (active && active.workspace?.id === ws)
                return active.lastIpcObject.class ?? "";
            return wins[0]?.lastIpcObject.class ?? "";
        }

        implicitWidth: cellSize
        implicitHeight: cellSize

        Image {
            id: icon

            readonly property real fullSize: Math.round(parent.height * 0.68)
            readonly property real subSize: Math.round(parent.height * 0.45)

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: parent.showNumbers ? Math.round(parent.width * 0.24) : 0
            anchors.verticalCenterOffset: parent.showNumbers ? -Math.round(parent.height * 0.24) : 0
            visible: opacity > 0
            opacity: parent.isOccupied && parent.hasIcon ? 1 : 0
            source: parent.mainClass ? Icons.getAppIcon(parent.mainClass, "image-missing") : ""
            asynchronous: true
            mipmap: true
            smooth: true
            fillMode: Image.PreserveAspectFit
            width: parent.showNumbers ? subSize : fullSize
            height: width

            Behavior on width {
                Anim {}
            }
            Behavior on opacity {
                Anim {}
            }
            Behavior on anchors.horizontalCenterOffset {
                Anim {}
            }
            Behavior on anchors.verticalCenterOffset {
                Anim {}
            }
        }
    }

    readonly property bool onSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name !== ""
    readonly property int _rawActiveWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen).activeWorkspace?.id ?? 1) : Hypr.activeWsId
    readonly property bool isTempWs: _rawActiveWsId > 100000
    readonly property int activeWsId: (ShellState.screenLocked || isTempWs) ? root._frozenWsId : root._rawActiveWsId
    property int _frozenWsId: 0

    on_RawActiveWsIdChanged: {
        if (!ShellState.screenLocked && !isTempWs)
            root._frozenWsId = root._rawActiveWsId
    }

    Component.onCompleted: root._frozenWsId = root._rawActiveWsId

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hypr.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    property real blur: onSpecial ? 1 : 0

    implicitWidth: horizontal ? layout.implicitWidth + Tokens.padding.small : Tokens.sizes.bar.innerWidth
    implicitHeight: horizontal ? Tokens.sizes.bar.innerWidth : layout.implicitHeight + Tokens.padding.small

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            asynchronous: true
            active: Config.bar.workspaces.occupiedBg

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: OccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: root.groupOffset
                horizontal: root.horizontal
            }
        }

        GridLayout {
            id: layout

            anchors.centerIn: parent
            columns: root.horizontal ? -1 : 1
            rowSpacing: Math.floor(Tokens.spacing.extraSmall)
            columnSpacing: Math.floor(Tokens.spacing.extraSmall)

            Repeater {
                id: workspaces

                model: Config.bar.workspaces.shown

                Workspace {
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    groupOffset: root.groupOffset
                    horizontal: root.horizontal
                    showNumbers: root.showNumbers
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.horizontalCenter: root.horizontal ? undefined : parent.horizontalCenter
            anchors.verticalCenter: root.horizontal ? parent.verticalCenter : undefined
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: ActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
                fullscreen: root.fullscreen
                horizontal: root.horizontal
            }
        }

        // App icons rendered above the active-indicator pill so they keep their colours
        Grid {
            id: iconLayer

            anchors.centerIn: parent
            columns: root.horizontal ? -1 : 1
            rows: root.horizontal ? 1 : -1
            rowSpacing: Math.floor(Tokens.spacing.extraSmall)
            columnSpacing: Math.floor(Tokens.spacing.extraSmall)
            visible: !root.fullscreen

            Repeater {
                model: Config.bar.workspaces.shown

                WsIcon {
                    activeWsId: root.activeWsId
                    occupiedMap: root.occupied
                    groupOffset: root.groupOffset
                    showNumbers: root.showNumbers
                }
            }
        }

        MouseArea {
            anchors.fill: layout
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: event => root._lastButton = event.button
            onClicked: event => {
                if (root._lastButton === Qt.RightButton) {
                    const screenState = ShellState.forActive();
                    screenState.launcher = !screenState.launcher;
                    return;
                }
                const ws = (layout.childAt(event.x, event.y) as Workspace)?.ws;
                if (!ws)
                    return;
                if (Hypr.activeWsId !== ws)
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
                else
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.workspace.toggle_special("special")' : "togglespecialworkspace special");
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: specialWs

        asynchronous: true

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
            horizontal: root.horizontal
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
