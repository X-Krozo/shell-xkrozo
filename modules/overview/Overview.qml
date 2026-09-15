pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components
import qs.components.effects
import qs.components.misc
import qs.services

Scope {
    id: root

    Variants {
        model: Screens.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: modelData
            visible: OverviewState.open || closing
            color: "transparent"

            property bool closing: false

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "caelestia-overview"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: OverviewState.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // ii-style focus grab: keeps keyboard while open, closes when focus escapes (also fixes ESC)
            HyprlandFocusGrab {
                windows: [win]
                active: OverviewState.open
                onCleared: () => OverviewState.open = false
            }

            // Click outside closes
            MouseArea {
                anchors.fill: parent
                onClicked: () => OverviewState.open = false
            }

            Item {
                id: panelWrapper

                anchors.centerIn: parent
                width: panel.width
                height: panel.height
                visible: opacity > 0
                // ii-style: appear crisply, no scale morph — only a fast fade
                opacity: OverviewState.open ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.FastEffects
                    }
                }

                Elevation {
                    anchors.fill: panel
                    level: 3
                }

                StyledRect {
                    id: panel

                    anchors.centerIn: parent
                    implicitWidth: grid.width
                    implicitHeight: grid.height
                    radius: Tokens.rounding.extraLarge
                    color: Colours.tPalette.m3surfaceContainer

                    WorkspaceGrid {
                        id: grid

                        anchors.fill: parent
                        screen: win.modelData
                    }

                    Keys.onEscapePressed: () => OverviewState.open = false
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_W && event.modifiers & Qt.ControlModifier)
                            OverviewState.open = false;
                    }

                    Component.onCompleted: forceActiveFocus()

                    Connections {
                        target: OverviewState
                        function onOpenChanged() {
                            if (OverviewState.open)
                                panel.forceActiveFocus();
                        }
                    }
                }
            }

            // Keep window alive during close fade, then hide
            Timer {
                id: closeTimer

                interval: Tokens.anim.durations.expressiveFastEffects
                onTriggered: win.closing = false
            }
        }
    }

    CustomShortcut {
        name: "overviewToggle"
        description: "Toggle overview"

        onPressed: OverviewState.open = !OverviewState.open
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            OverviewState.open = !OverviewState.open;
        }
        function open(): void {
            OverviewState.open = true;
        }
        function close(): void {
            OverviewState.open = false;
        }
        function isOpen(): string {
            return OverviewState.open ? "1" : "0";
        }
    }
}
