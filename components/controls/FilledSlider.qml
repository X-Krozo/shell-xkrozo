import "../effects"
import QtQuick
import QtQuick.Templates
import Caelestia.Config
import qs.components
import qs.services

Slider {
    id: root
    required property string icon
    property real oldValue
    property bool initialized
    property real maxNormal: 1.0
    property real maxExtended: GlobalConfig.services.maxVolume
    property bool boostEnabled: false
    property bool boostUnlocked: false
    property real externalValue: 0
    readonly property bool boostActive: boostEnabled && value > maxNormal

    orientation: Qt.Vertical
    to: (boostEnabled && boostUnlocked) ? maxExtended : maxNormal
    hoverEnabled: true

    onExternalValueChanged: {
        if (boostEnabled && externalValue >= maxNormal) {
            boostUnlocked = true
        } else if (boostEnabled && !pressed && externalValue <= maxNormal) {
            boostUnlocked = false
        }
    }

    Behavior on to {
        Anim {}
    }

    property bool moving

    onHoveredChanged: updateMoving()

    background: StyledRect {
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Tokens.rounding.full
        StyledRect {
            anchors.left: parent.left
            anchors.right: parent.right
            y: root.handle.y
            implicitHeight: parent.height - y
            color: root.boostActive ? Colours.palette.m3error : Colours.palette.m3secondary
            radius: parent.radius
        }
    }

    handle: Item {
        id: handle
        y: root.visualPosition * (root.availableHeight - height)
        implicitWidth: root.width
        implicitHeight: root.width
        Elevation {
            anchors.fill: parent
            radius: rect.radius
            level: root.hovered ? 2 : 1
        }
        StyledRect {
            id: rect
            anchors.fill: parent
            color: Colours.palette.m3inverseSurface
            radius: Tokens.rounding.full
            Text {
                id: icon
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: root.icon
                color: Colours.palette.m3inverseOnSurface
                font: Tokens.font.icon.medium
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                opacity: root.moving ? 0 : 1
                Behavior on opacity { Anim {} }
            }
            Text {
                id: valueText
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 1
                text: Math.round(root.value * 100)
                color: Colours.palette.m3inverseOnSurface
                font: Tokens.font.body.small
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                opacity: root.moving ? 1 : 0
                Behavior on opacity { Anim {} }
            }
        }
    }

    function updateMoving() {
        moving = hovered || pressed
    }

    onPressedChanged: {
        if (pressed)
            updateMoving()
    }

    onValueChanged: {
        if (boostEnabled)
            if (value > maxNormal)
                boostUnlocked = true
            else if (!pressed && value <= maxNormal)
                boostUnlocked = false
        if (!initialized) {
            initialized = true
            return
        }
        if (Math.abs(value - oldValue) < 0.01)
            return
        oldValue = value
        moving = true
        stateChangeDelay.restart()
    }

    Timer {
        id: stateChangeDelay
        interval: 500
        onTriggered: {
            if (!pressed && !root.hovered)
                moving = false
        }
    }

    Behavior on value {
        Anim {
            type: Anim.StandardLarge
        }
    }
}