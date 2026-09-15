pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.components.effects
import qs.services
import qs.utils

StyledRect {
    id: root

    required property var toplevel // HyprlandToplevel
    // Fresh IPC data from HyprlandData (refreshed on every event) so geometry is accurate
    // right after move/float dispatches. Falls back to the stale lastIpcObject when absent.
    property var windowData: null
    readonly property var ipc: windowData ?? toplevel?.lastIpcObject ?? null
    readonly property string address: ipc?.address ?? ""

    property real zoom: 1
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 10
    property real targetHeight: 10
    property bool dimmed: false

    // Grid context for drag/drop (set by the delegate in WorkspaceGrid)
    property var grid: null
    // Monitor context for imperative position recomputation (ii-style updateWindowPosition)
    property var monData: null
    property var reserved: [0, 0, 0, 0]

    readonly property bool dragging: mouse.drag.active

    // Required for DropAreas to see the internal drag (ii-style)
    Drag.active: dragging
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    // ii-style slot derivation from fresh data: within-card position + card offset separate
    readonly property int wsId: ipc?.workspace?.id ?? 1
    readonly property bool isSpecial: (ipc?.workspace?.name ?? "").startsWith("special:")
    readonly property int magicRowIdx: OverviewState.rows - 1
    readonly property int magicColIdx: OverviewState.columns - 1
    readonly property real monX: monData ? (monData.x ?? 0) : (ipc?.monitor?.x ?? 0)
    readonly property real monY: monData ? (monData.y ?? 0) : (ipc?.monitor?.y ?? 0)
    readonly property real initX: Math.max((ipc?.at?.[0] ?? 0) - monX - reserved[0], 0) * OverviewState.zoomW
    readonly property real initY: Math.max((ipc?.at?.[1] ?? 0) - monY - reserved[1], 0) * OverviewState.zoomH
    readonly property real xOffset: isSpecial
        ? magicColIdx * (root.grid?.cardWidth + root.grid?.cardSpacing)
        : wsCol(wsId) * (root.grid?.cardWidth + root.grid?.cardSpacing)
    readonly property real yOffset: isSpecial
        ? magicRowIdx * (root.grid?.cardHeight + root.grid?.cardSpacing)
        : wsRow(wsId) * (root.grid?.cardHeight + root.grid?.cardSpacing)

    function wsCol(w: int): int {
        const perPageRegular = OverviewState.rows * OverviewState.columns - 1;
        return Math.floor((w - 1) % perPageRegular) % OverviewState.columns;
    }
    function wsRow(w: int): int {
        const perPageRegular = OverviewState.rows * OverviewState.columns - 1;
        return Math.floor(Math.floor((w - 1) % perPageRegular) / OverviewState.columns);
    }

    // Geometry is owned imperatively by computeTarget() (ii-style updateWindowPosition):
    // the drag/screencopy moves x/y at runtime, so bindings would be broken anyway.
    function computeTarget(): void {
        if (root.dragging) return;
        const cw = root.grid?.cardWidth ?? 10;
        const ch = root.grid?.cardHeight ?? 10;
        const tX = root.initX + root.xOffset;
        const tY = root.initY + root.yOffset;
        const tW = Math.max(Math.min((root.ipc?.size?.[0] ?? 0) * OverviewState.zoomW, cw - root.initX - 2), 8);
        const tH = Math.max(Math.min((root.ipc?.size?.[1] ?? 0) * OverviewState.zoomH, ch - root.initY - 2), 8);
        root.targetX = tX;
        root.targetY = tY;
        root.targetWidth = tW;
        root.targetHeight = tH;
        root.x = Math.round(tX);
        root.y = Math.round(tY);
        root.width = Math.round(tW);
        root.height = Math.round(tH);
    }

    radius: Tokens.rounding.small
    color: Colours.tPalette.m3surfaceContainerHigh
    opacity: dimmed ? 0.35 : 1
    // ii-style stacking: fullscreen > floating > tiled
    z: dragging ? 20 : ((ipc?.fullscreen ?? false) ? 3 : ((ipc?.floating ?? false) ? 2 : 1))

    // Clip screencopy content to the rounded card shape
    layer.enabled: true
    layer.effect: Mask {
        maskSource: mask
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: root.radius
        }
    }

    // Always-on: gives the trailing follow feel while dragging (ii elementMoveEnter)
    Behavior on x {
        NumberAnimation {
            duration: 400
            easing: Tokens.anim.emphasizedDecel
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 400
            easing: Tokens.anim.emphasizedDecel
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: 400
            easing: Tokens.anim.emphasizedDecel
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: 400
            easing: Tokens.anim.emphasizedDecel
        }
    }

    ScreencopyView {
        anchors.fill: parent
        captureSource: root.toplevel?.wayland ?? null // qmllint disable unresolved-type
        live: root.visible && OverviewState.open
    }

    // Hairline definition around each window (ii-style)
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.12)
    }

    Image {
        anchors.centerIn: parent
        visible: parent.width < 90 || parent.height < 70
        width: Math.min(parent.width, parent.height) * 0.4
        height: width
        source: Icons.getAppIcon(root.ipc?.class ?? "", "image-missing")
        asynchronous: true
        mipmap: true
    }

    // Wait for Hyprland IPC to reflect the move, then fly to the new slot (ii-style race guard)
    Timer {
        id: posTimer

        interval: 20
        onTriggered: root.computeTarget()
    }

    StateLayer {
        id: mouse

        anchors.fill: parent
        radius: root.radius
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        // ii-style native drag: MouseArea drags the preview item directly
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.minimumX: -root.width
        drag.maximumX: root.grid ? root.grid.width : 0
        drag.minimumY: -root.height
        drag.maximumY: root.grid ? root.grid.height : 0

        onReleased: event => {
            if (!root.grid || !drag.active)
                return;

            const g = root.grid;
            const targetWs = g.dragTargetWs;
            const curWs = root.wsId;

            if (targetWs === g.magicWsValue) {
                // Dropped on the magic (special) card: silently send the window there
                Hypr.dispatch(Hypr.usingLua
                    ? `hl.dsp.window.move({ workspace = "special:magic", follow = false, window = "address:${root.address}" })`
                    : `movetoworkspacesilent special:magic,address:${root.address}`);
                posTimer.restart();
            } else if (targetWs !== g.nowhereWsValue && targetWs !== curWs) {
                // Cross-workspace: dispatch move, then re-sync from fresh data after the move
                Hypr.dispatch(`hl.dsp.window.move({ workspace = ${targetWs}, follow = false, window = "address:${root.address}" })`);
                posTimer.restart();
            } else if (targetWs !== g.nowhereWsValue && targetWs === curWs && (ipc?.floating ?? false)) {
                // Floating dropped back on same card: reposition card-relative (ii-style)
                const pctX = (root.x - root.xOffset) / (g.cardWidth || 1);
                const pctY = (root.y - root.yOffset) / (g.cardHeight || 1);
                Hypr.dispatch(`hl.dsp.window.move({ x = "${pctX * g.logicalWidth}", y = "${pctY * g.logicalHeight}", window = "address:${root.address}" })`);
            } else if (targetWs !== g.nowhereWsValue && targetWs === curWs) {
                // Tiled same-card: reorder by swapping with the tile under the drop point.
                // swapwindow warps the cursor (Actions::swapWith -> warpCursor), and
                // follow_mouse=1 then shifts focus to the swapped window. Never let the
                // pointer leave the drop point: suppress ALL cursor warps for the swap.
                // (keyword is not allowed under the Lua-superset parser — use eval + hl.config)
                const cx = root.x + root.width / 2;
                const cy = root.y + root.height / 2;
                const slotAddr = g.windowAddressAt(cx, cy, curWs, root.address);
                if (slotAddr !== "") {
                    Hypr.extras.batchMessage([
                        "eval hl.config({ cursor = { no_warps = true } })",
                        `dispatch hl.dsp.window.swap({ window = "address:${root.address}", target = "address:${slotAddr}" })`,
                        "eval hl.config({ cursor = { no_warps = false } })",
                    ]);
                }
                posTimer.restart();
            } else {
                // Tiled same-card fly-back / nowhere drop: glide back with no dispatch (ii-style)
                posTimer.restart();
            }
            g.dragTargetWs = g.nowhereWsValue;
        }

        onClicked: event => {
            if (!root.ipc)
                return;

            if (event.button === Qt.LeftButton) {
                Hypr.dispatch(`hl.dsp.focus({ window = "address:${root.address}" })`);
                root.grid.activated();
                event.accepted = true;
            } else if (event.button === Qt.MiddleButton) {
                Hypr.dispatch(`hl.dsp.window.close({ window = "address:${root.address}" })`);
                event.accepted = true;
            } else if (event.button === Qt.RightButton) {
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.float({ window = "address:${root.address}" })` : `togglefloating address:${root.address}`);
                event.accepted = true;
            }
        }
    }
}