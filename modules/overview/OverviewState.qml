pragma Singleton

import QtQuick

QtObject {
    property bool open: false

    readonly property int rows: 2
    readonly property int columns: 4
    readonly property real zoomW: 0.13
    readonly property real zoomH: 0.16
}
