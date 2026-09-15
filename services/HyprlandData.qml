pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * Fresh, event-driven view of Hyprland IPC data.
 *
 * Quickshell's HyprlandToplevel.lastIpcObject is only refreshed on
 * configreloaded / monitoraddedv2, so window geometry (at/size/floating)
 * goes stale after moves, float toggles etc. This service re-polls
 * hyprctl on every raw Hyprland event so the overview can read accurate
 * positions right after a drag-and-drop.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []

    function updateWindowList(): void {
        getClients.running = true;
    }

    function updateMonitors(): void {
        getMonitors.running = true;
    }

    function updateWorkspaces(): void {
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateAll(): void {
        updateWindowList();
        updateMonitors();
        updateWorkspaces();
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (["openlayer", "closelayer", "screencast"].includes(event.name))
                return;
            root.updateAll();
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                if (clientsCollector.text.trim() === "")
                    return;
                root.windowList = JSON.parse(clientsCollector.text);
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    const win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                if (monitorsCollector.text.trim() === "")
                    return;
                root.monitors = JSON.parse(monitorsCollector.text);
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                if (workspacesCollector.text.trim() === "")
                    return;
                const rawWorkspaces = JSON.parse(workspacesCollector.text);
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (let ws of root.workspaces)
                    tempWorkspaceById[ws.id] = ws;
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                if (activeWorkspaceCollector.text.trim() === "")
                    return;
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
            }
        }
    }
}