pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Repeater workspaces
    required property var occupied
    required property var wsIds
    required property bool horizontal

    readonly property color colour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
    property list<var> pills: []

    // Builds a merged pill per contiguous run of occupied cells, mirroring v2.5.0's
    // behaviour of grouping adjacent occupied workspaces into a single rounded rect.
    onOccupiedChanged: rebuild()
    onWsIdsChanged: rebuild()
    Component.onCompleted: rebuild()

    function rebuild(): void {
        for (const p of root.pills)
            p.destroy();
        root.pills = [];

        const ids = root.wsIds;
        let run = null;
        for (let i = 0; i < ids.length; ++i) {
            const occupied = root.occupied[ids[i]] ?? false;
            if (occupied) {
                if (!run) {
                    run = pillComp.createObject(root, {
                        start: i,
                        end: i
                    });
                    root.pills.push(run);
                } else {
                    run.end = i;
                }
            } else {
                run = null;
            }
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.pills.filter(p => p)
        }

        StyledRect {
            required property var modelData

            // qmllint disable incompatible-type
            readonly property Workspace start: root.workspaces.itemAt(modelData.start) ?? null
            readonly property Workspace end: root.workspaces.itemAt(modelData.end) ?? null
            // qmllint enable incompatible-type

            anchors.horizontalCenter: root.horizontal ? undefined : root.horizontalCenter
            anchors.verticalCenter: root.horizontal ? root.verticalCenter : undefined

            x: root.horizontal ? (start?.x ?? 0) - 1 : 0
            y: root.horizontal ? 0 : (start?.y ?? 0) - 1
            implicitWidth: root.horizontal ? (start && end ? end.x + end.size - start.x + 2 : 0) : Tokens.sizes.bar.innerWidth - Tokens.padding.small + 2
            implicitHeight: root.horizontal ? Tokens.sizes.bar.innerWidth - Tokens.padding.small + 2 : (start && end ? end.y + end.size - start.y + 2 : 0)

            color: root.colour
            radius: Tokens.rounding.full

            scale: 0
            Component.onCompleted: scale = 1

            Behavior on scale {
                Anim {
                    easing: Tokens.anim.standardDecel
                }
            }

            Behavior on y {
                enabled: !root.horizontal

                Anim {}
            }

            Behavior on x {
                enabled: root.horizontal

                Anim {}
            }

            Behavior on implicitHeight {
                enabled: !root.horizontal

                Anim {}
            }

            Behavior on implicitWidth {
                enabled: root.horizontal

                Anim {}
            }
        }
    }

    Component {
        id: pillComp

        Pill {}
    }

    component Pill: QtObject {
        property int start: -1
        property int end: -1
    }
}