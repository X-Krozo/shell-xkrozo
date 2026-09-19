pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Repeater workspaces
    required property int wsSpacing
    required property bool horizontal

    AnimatedRepeater {
        model: ScriptModel {
            values: root.workspaces.count > 0 ? Array.from({
                length: root.workspaces.count
            }, (_, i) => i) : []
        }

        removeDuration: Tokens.anim.durations.expressiveDefaultEffects

        StyledRect {
            required property int modelData

            readonly property Workspace ws: root.workspaces.itemAt(modelData) ?? null // qmllint disable incompatible-type
            readonly property Workspace prevWs: modelData > 0 ? root.workspaces.itemAt(modelData - 1) ?? null : null // qmllint disable incompatible-type

            property real shift: {
                if (modelData === 0)
                    return 0;
                if (ws?.focused)
                    return -root.wsSpacing / 2 - (root.horizontal ? implicitWidth : implicitHeight);
                return prevWs?.focused ? root.wsSpacing / 2 : 0;
            }

            anchors.left: root.horizontal ? undefined : parent?.left
            anchors.right: root.horizontal ? undefined : parent?.right
            anchors.top: root.horizontal ? parent?.top : undefined
            anchors.bottom: root.horizontal ? parent?.bottom : undefined
            anchors.margins: Tokens.padding.extraSmall

            x: root.horizontal ? (ws?.x ?? 0) - root.wsSpacing / 2 + shift : 0
            y: root.horizontal ? 0 : (ws?.y ?? 0) - root.wsSpacing / 2 + shift
            implicitWidth: root.horizontal ? 1 : 0
            implicitHeight: root.horizontal ? 0 : 1
            color: Colours.palette.m3outline

            opacity: modelData === 0 || !ws || prevWs?.ws === ws?.ws - 1 ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on shift {
                Anim {}
            }

            Behavior on x {
                enabled: root.horizontal

                Anim {}
            }

            Behavior on y {
                enabled: !root.horizontal

                Anim {}
            }
        }
    }
}