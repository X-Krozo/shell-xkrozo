pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
    import qs.components.misc
    import qs.services

Scope {
    id: root

    property alias lock: lock
    property bool suspendPending
    property var savedWorkspaces: ({})
    property var restoreTargets: ({})
    property int restoreAttempts: 0

    function lockSession(): void {
        if (lock.locked)
            return
        ShellState.screenLocked = true
        var next = {}
        var batch = ""
        for (var i = 0; i < Quickshell.screens.length; ++i) {
            var mon = Quickshell.screens[i].name
            var monitors = Hyprland.monitors.values
            var mData = null
            for (var k = 0; k < monitors.length; ++k) {
                if (monitors[k].name === mon) {
                    mData = monitors[k];
                    break;
                }
            }
            if (mData?.activeWorkspace == undefined)
                continue;
            var ws = mData.activeWorkspace.id
            next[mon] = ws
            batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${mon}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${2147483647 - ws}})';`
        }
        root.savedWorkspaces = next
        if (batch.length > 0)
            Quickshell.execDetached(["bash", "-c", batch])
        lockDelay.start()
    }

    Timer {
        id: lockDelay

        interval: 50
        repeat: false
        onTriggered: {
            lock.locked = true
            // Lid close while already locked: surface is already ready, so
            // onReadyChanged may not fire again - trigger suspend directly.
            if (root.suspendPending && surface.ready)
                suspendTimer.restart()
        }
    }

    Timer {
        id: restoreTimer

        interval: 150
        repeat: false
        onTriggered: {
            root.restoreTargets = {}
            root.restoreAttempts = 0
            var batch = ""
            for (var j = 0; j < Quickshell.screens.length; ++j) {
                var monName = Quickshell.screens[j].name
                var wsId = root.savedWorkspaces[monName]
                if (wsId !== undefined) {
                    root.restoreTargets[monName] = wsId
                    batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${monName}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${wsId}})';`
                }
            }
            if (batch.length > 0) {
                Quickshell.execDetached(["bash", "-c", batch])
            }
            root.savedWorkspaces = {}
            ShellState.screenLocked = false
            root.suspendPending = false
            for (var si = 0; si < Quickshell.screens.length; ++si) {
                var st = ShellState.forScreen(Quickshell.screens[si])
                if (st)
                    st.osd = false
                var comp = ShellState.componentsFor(Quickshell.screens[si])
                if (comp && comp.panels && comp.panels.osd)
                    comp.panels.osd.hovered = false
            }
            Qt.callLater(() => {
                Hyprland.refreshMonitors()
                Hyprland.refreshWorkspaces()
                Hyprland.refreshToplevels()
            })
            retryRestoreTimer.start()
        }
    }

    Timer {
        id: retryRestoreTimer
        interval: 200
        repeat: false
        onTriggered: {
            var stillTemp = false
            var monitors = Hyprland.monitors.values
            for (var i = 0; i < monitors.length; ++i) {
                if (monitors[i].activeWorkspace?.id > 100000) {
                    stillTemp = true
                    break
                }
            }
            if (stillTemp) {
                if (root.restoreAttempts >= 5) {
                    root.restoreTargets = {}
                    root.restoreAttempts = 0
                    return
                }
                root.restoreAttempts++
                // Restore raced the suspend/wake cycle - retry the dispatch
                var batch = ""
                for (var mon in root.restoreTargets) {
                    batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${mon}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${root.restoreTargets[mon]}})';`
                }
                if (batch.length > 0)
                    Quickshell.execDetached(["bash", "-c", batch])
                retryRestoreTimer.start()
            } else {
                root.restoreTargets = {}
            }
        }
    }

    WlSessionLock {
        id: lock

        signal unlock

        LockSurface {
            id: surface

            lock: lock
            pam: pam

            onReadyChanged: {
                if (ready && root.suspendPending)
                    suspendTimer.restart();
            }
        }
    }

    Connections {
        target: lock
        function onLockedChanged() {
            if (!lock.locked) {
                restoreTimer.start()
            }
        }
        function onUnlock() {
            restoreTimer.start()
        }
    }

    Pam {
        id: pam

        lock: lock
    }

    Loader {
        asynchronous: true
        active: true
        onLoaded: active = false

        // Force a load of a screencopy so the one in the lock works
        sourceComponent: ScreencopyView {
            captureSource: Quickshell.screens[0]
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "lock"
        description: "Lock the current session"
        onPressed: root.lockSession()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    IpcHandler {
        function lock(): void {
            root.lockSession();
        }

        function unlock(): void {
            lock.unlock();
        }

function lockAndSuspend(): void {
        if (lock.locked) {
            root.suspendPending = false
            Quickshell.execDetached(["systemctl", "suspend"])
            return
        }
        root.suspendPending = true
        root.lockSession()
    }

        function isLocked(): bool {
            return lock.locked;
        }

        target: "lock"
    }

    Timer {
        id: suspendTimer

        interval: 0
        onTriggered: {
            root.suspendPending = false;
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }
}
