pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root
    clip: true

    property string source: Wallpapers.current
    property CachingImage current
    property bool completed

    onSourceChanged: {
        if (!source)
            current = null;
        else
            current = imgComp.createObject(this, {
                path: source
            });
    }

    Component.onCompleted: {
        if (source)
            Qt.callLater(() => {
                current = imgComp.createObject(this, {
                    path: source
                });
                completed = true;
            });
    }

    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image files")
                            filters: Images.validImageExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    Component {
        id: imgComp

        CachingImage {
            id: img

            anchors.fill: parent

            property int transitionType: Math.floor(Math.random() * 3)
            property real slideOffset: (Math.random() < 0.5 ? -1 : 1) * width * 0.08

            opacity: 0
            scale: transitionType === 1 ? 1.08 : 1
            x: transitionType === 2 ? slideOffset : 0

            onStatusChanged: {
                if (status === Image.Ready)
                    anim.start();
            }

            ParallelAnimation {
                id: anim

                Anim {
                    target: img
                    property: "opacity"
                    from: 0
                    to: 1
                    type: Anim.SlowEffects
                }

                Anim {
                    target: img
                    property: "scale"
                    from: img.transitionType === 1 ? 1.08 : 1
                    to: 1
                    type: Anim.DefaultSpatial
                }

                Anim {
                    target: img
                    property: "x"
                    from: img.transitionType === 2 ? img.slideOffset : 0
                    to: 0
                    type: Anim.DefaultSpatial
                }
            }

            Timer {
                running: root.current !== img && root.current?.status === Image.Ready
                interval: Tokens.anim.durations.expressiveSlowEffects
                onTriggered: img.destroy()
            }
        }
    }
}
