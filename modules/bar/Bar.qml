pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

GridLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    required property bool horizontal
    readonly property int axisPadding: Tokens.padding.large

    // Centered-bar support: entries around a spacer-delimited "workspaces" entry
    // are split into left / center / right groups when horizontal.
    readonly property var enabledEntries: root.Config.bar.entries.filter(e => e.enabled ?? true)
    readonly property int wsIdx: {
        for (let i = 0; i < enabledEntries.length; i++)
            if (enabledEntries[i].id === "workspaces")
                return i;
        return -1;
    }
    readonly property bool centered: horizontal && wsIdx >= 1 && wsIdx < enabledEntries.length - 1 && enabledEntries[wsIdx - 1].id === "spacer" && enabledEntries[wsIdx + 1].id === "spacer"
    readonly property var leftEntries: centered ? enabledEntries.slice(0, wsIdx) : []
    readonly property var centerEntries: centered ? [enabledEntries[wsIdx]] : []
    readonly property var rightEntries: centered ? enabledEntries.slice(wsIdx + 2) : []
    readonly property list<Item> groupContainers: centered ? [leftGroup, centerGroup, rightGroup] : [root]

    function allWrappers(): var {
        const out = [];
        for (let c = 0; c < groupContainers.length; c++) {
            const container = groupContainers[c];
            for (let i = 0; i < container.children.length; i++) {
                const w = container.children[i];
                if (w instanceof EntryWrapper)
                    out.push(w);
            }
        }
        return out;
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        const wrappers = allWrappers();
        for (let i = 0; i < wrappers.length; i++) {
            const tray = wrappers[i].item as Tray;
            if (tray)
                tray.expanded = false;
        }
    }

    function axisCenterOf(item: Item): real {
        const c = item.mapToItem(root, item.implicitWidth / 2, item.implicitHeight / 2);
        return horizontal ? c.x : c.y;
    }

    function wrapperAt(x: real, y: real): EntryWrapper {
        for (let c = 0; c < groupContainers.length; c++) {
            const container = groupContainers[c];
            const pos = container.mapFromItem(root, x, y);
            const ch = container.childAt(pos.x, pos.y);
            if (ch instanceof EntryWrapper)
                return ch;
        }
        return null;
    }

    function entryAt(pos: real): string {
        const ch = horizontal ? wrapperAt(pos, height / 2) : wrapperAt(width / 2, pos);
        return ch?.entryId ?? "";
    }

    // Open a popout, or close it if it's already the open one (toggle).
    function togglePopout(name: string, center: Item): void {
        if (popouts.hasCurrent && popouts.currentName === name) {
            popouts.hasCurrent = false;
            return;
        }
        popouts.currentName = name;
        if (center)
            popouts.currentCenter = Qt.binding(() => axisCenterOf(center));
        popouts.hasCurrent = true;
    }

    // Toggle a specific tray item's context-menu popout (used on tray right-click).
    function toggleTrayMenu(item: var, trayItem: Item): void {
        const name = `traymenu${item.id}`;
        if (popouts.hasCurrent && popouts.currentName === name) {
            popouts.hasCurrent = false;
            return;
        }
        popouts.currentName = name;
        popouts.currentCenter = Qt.binding(() => axisCenterOf(trayItem));
        popouts.hasCurrent = true;
    }

    // Tray apps whose SNI "Activate" does nothing (e.g. SDL appindicator items like
    // Tauon). Keyed by tray item id/title -> how to focus-or-launch them.
    readonly property var trayLaunchers: ({
        // title/id: { command list, window classes to focus if running }
        "tauonmb": { command: ["tauonmb"], classes: ["tauon"] }
    })

    // Left-click on a tray item: open the app. Falls back to Hyprland focus/launch
    // for apps in trayLaunchers (whose tray "Activate" does nothing).
    function openTrayApp(item: var, trayItem: Item, index: int): void {
        const entry = trayLaunchers[item.title] ?? trayLaunchers[item.id] ?? null;
        if (entry && entry.command) {
            const classes = entry.classes ?? [];
            const toplevel = Hypr.toplevels.values.find(t => classes.some(c => (t.lastIpcObject.class ?? "").toLowerCase().includes(c.toLowerCase())));
            if (toplevel) {
                if (Hypr.usingLua)
                    Hypr.dispatch(`hl.dsp.focus({ window = "address:0x${toplevel.address}" })`);
                else
                    Hypr.dispatch(`focuswindow address:0x${toplevel.address}`);
            } else {
                Quickshell.execDetached(entry.command);
            }
        } else if (item.onlyMenu) {
            toggleTrayMenu(item, trayItem);
        } else {
            item.activate();
        }
    }

    function checkPopout(pos: real): void {
        const ch = horizontal ? wrapperAt(pos, height / 2) : wrapperAt(width / 2, pos);

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const rootPos = ch.mapToItem(root, 0, 0);
        const start = horizontal ? rootPos.x : rootPos.y;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = horizontal ? items.childAt(mapToItem(items, pos, 0).x, items.height / 2) : items.childAt(items.width / 2, mapToItem(items, 0, pos).y);
            if (icon)
                togglePopout(icon.name, icon);
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(horizontal ? mapToItem(tray.expandIcon, pos, tray.implicitHeight / 2) : mapToItem(tray.expandIcon, tray.implicitWidth / 2, pos)))) {
                const index = Math.floor(((pos - start - tray.padding * 2 + tray.spacing) / (horizontal ? tray.layout.implicitWidth : tray.layout.implicitHeight)) * tray.items.count);
                const trayItem = tray.items.itemAt(index) as TrayItem;
                if (trayItem?.modelData) {
                    togglePopout(`traymenu${trayItem.modelData.id}`, trayItem);
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            togglePopout(id.toLowerCase(), ch.item as Item);
        } else if (id === "power" && horizontal) {
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const ch = horizontal ? wrapperAt(pos, height / 2) : wrapperAt(width / 2, pos);
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (pos < (horizontal ? screen.width : screen.height) / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on top/left half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom/right half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    columns: horizontal ? -1 : 1
    rowSpacing: Tokens.spacing.medium
    columnSpacing: Tokens.spacing.medium

    // Wrapper so the three groups can use anchors without fighting the bar's layout
    Item {
        visible: root.centered
        Layout.fillWidth: true
        implicitHeight: Math.max(leftGroup.implicitHeight, centerGroup.implicitHeight, rightGroup.implicitHeight)

        RowLayout {
            id: leftGroup

            visible: root.centered
            spacing: root.columnSpacing
            anchors.left: parent.left
            anchors.leftMargin: root.axisPadding
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: ScriptModel {
                    values: root.leftEntries
                }

                delegate: BarChooser {}
            }
        }

        RowLayout {
            id: centerGroup

            visible: root.centered
            spacing: root.columnSpacing
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: ScriptModel {
                    values: root.centerEntries
                }

                delegate: BarChooser {}
            }
        }

        RowLayout {
            id: rightGroup

            visible: root.centered
            spacing: root.columnSpacing
            anchors.right: parent.right
            anchors.rightMargin: root.axisPadding
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: ScriptModel {
                    values: root.rightEntries
                }

                delegate: BarChooser {}
            }
        }
    }

    Repeater {
        id: repeater

        model: ScriptModel {
            values: root.centered ? [] : root.enabledEntries
        }

        delegate: BarChooser {}
    }

    component BarChooser: DelegateChooser {
        role: "id"

        DelegateChoice {
            roleValue: "spacer"
            delegate: EntryWrapper {
                implicitWidth: root.centered ? root.columnSpacing : 0
                Layout.fillHeight: !root.horizontal
                Layout.fillWidth: root.horizontal && !root.centered
            }
        }
        DelegateChoice {
            roleValue: "logo"
            delegate: EntryWrapper {
                OsIcon {
                    objectName: "taskbarLogo"
                }
            }
        }
        DelegateChoice {
            roleValue: "workspaces"
            delegate: EntryWrapper {
                Workspaces {
                    objectName: "taskbarWorkspaces"
                    screen: root.screen
                    fullscreen: root.fullscreen
                    horizontal: root.horizontal
                }
            }
        }
        DelegateChoice {
            roleValue: "activeWindow"
            delegate: EntryWrapper {
                visible: false
                implicitWidth: 0
                implicitHeight: 0

                ActiveWindow {
                    objectName: "taskbarActiveWindow"
                    bar: root
                    horizontal: root.horizontal
                    visible: false
                }
            }
        }
        DelegateChoice {
            roleValue: "tray"
            delegate: EntryWrapper {
                Tray {
                    objectName: "taskbarTray"
                    horizontal: root.horizontal
                    bar: root
                }
            }
        }
        DelegateChoice {
            roleValue: "clock"
            delegate: EntryWrapper {
                Clock {
                    objectName: "taskbarClock"
                    horizontal: root.horizontal
                }
            }
        }
        DelegateChoice {
            roleValue: "statusIcons"
            delegate: EntryWrapper {
                StatusIcons {
                    objectName: "taskbarStatusIcons"
                    horizontal: root.horizontal
                }
            }
        }
        DelegateChoice {
            roleValue: "power"
            delegate: EntryWrapper {
                Power {
                    objectName: "taskbarPowerButton"
                    screenState: root.screenState
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.topMargin: !root.horizontal && index === 0 ? root.axisPadding : 0
        Layout.bottomMargin: !root.horizontal && index === repeater.count - 1 ? root.axisPadding : 0
        Layout.alignment: root.horizontal ? Qt.AlignVCenter : Qt.AlignHCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
