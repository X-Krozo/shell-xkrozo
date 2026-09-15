pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property ScreenState screenState
    property real osdOffset: 0

    readonly property bool shouldBeActive: root.screenState.appVolumes
    property real offsetScale: shouldBeActive ? 0 : 1

    readonly property string hoveredName: {
        const delegate = hoveredIndex >= 0 ? sliders.itemAt(hoveredIndex) : null;
        return delegate?.modelData ? Audio.getStreamName(delegate.modelData) ?? "" : "";
    }

    property real tooltipExtent: hoveredName.length > 0 ? tooltip.implicitHeight + Tokens.spacing.medium : 0

    visible: offsetScale < 1
    anchors.rightMargin: (-implicitWidth - 5 - osdOffset) * offsetScale
    implicitWidth: body.implicitWidth + Tokens.padding.large * 2
    implicitHeight: body.implicitHeight + Tokens.padding.large * 2 + tooltipExtent
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on tooltipExtent {
        Anim {}
    }

    StyledRect {
        id: body

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.large

        implicitWidth: layout.implicitWidth + Tokens.padding.large * 2
        implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerLow

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Tokens.spacing.medium

            StyledText {
                visible: Audio.streams.length === 0
                Layout.alignment: Qt.AlignCenter
                text: qsTr("No apps")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }

            Repeater {
                id: sliders

                model: Audio.streams

                delegate: ColumnLayout {
                    id: column

                    required property PwNode modelData
                    required property int index

                    spacing: Tokens.spacing.extraSmall

                    // Literal copy of the OSD slider block (osd/Content.qml)
                    CustomMouseArea {
                        function onWheel(event: WheelEvent) {
                            const current = Audio.getStreamVolume(column.modelData);
                            if (event.angleDelta.y > 0)
                                Audio.setStreamVolume(column.modelData, Math.min(1.0, current + GlobalConfig.services.audioIncrement));
                            else if (event.angleDelta.y < 0)
                                Audio.setStreamVolume(column.modelData, Math.max(0, current - GlobalConfig.services.audioIncrement));
                        }

                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Tokens.sizes.osd.sliderWidth
                        implicitHeight: Tokens.sizes.osd.sliderHeight

                        FilledSlider {
                            id: streamSlider

                            objectName: "appvol"
                            anchors.fill: parent

                            icon: Icons.getVolumeIcon(value, column.modelData?.audio?.muted ?? false)
                            value: column.modelData?.audio?.volume ?? 0
                            externalValue: column.modelData?.audio?.volume ?? 0
                            onMoved: Audio.setStreamVolume(column.modelData, value)
                            onHoveredChanged: {
                                if (streamSlider.hovered)
                                    root.hoveredIndex = column.index;
                                else if (root.hoveredIndex === column.index)
                                    root.hoveredIndex = -1;
                            }
                        }
                    }

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Tokens.sizes.osd.sliderWidth * 0.55
                        Layout.preferredHeight: Tokens.sizes.osd.sliderWidth * 0.55
                        source: Icons.getAppIcon(Audio.getStreamName(column.modelData), "image-missing")
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }
            }
        }
    }

    property int hoveredIndex: -1

    StyledRect {
        id: tooltip

        anchors.bottom: body.top
        anchors.bottomMargin: 0
        anchors.horizontalCenter: body.horizontalCenter

        implicitWidth: label.implicitWidth + Tokens.padding.large * 2
        implicitHeight: (label.implicitHeight + Tokens.padding.medium * 2) * 0.75

        visible: opacity > 0
        opacity: root.hoveredName.length > 0 ? 1 : 0
        scale: root.hoveredName.length > 0 ? 1 : 0.85
        color: "transparent"
        radius: Tokens.rounding.large
        transformOrigin: Item.Bottom

        Behavior on opacity {
            Anim {}
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on implicitHeight {
            Anim {}
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: root.hoveredName
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.builders.medium.scale(0.9).build()
        }
    }
}