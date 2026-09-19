pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia
import Caelestia.Images
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.bar as Bar
import "../dashboard/media"

FocusScope {
    id: root

    required property ScreenState screenState
    required property Bar.BarWrapper bar
    required property real borderThickness

    readonly property bool shouldBeActive: root.screenState.mediaFullscreen
    readonly property bool appearanceActive: root.shouldBeActive || root.offsetScale < 1
    property real offsetScale: shouldBeActive ? 0 : 1

    readonly property real margin: Tokens.padding.extraExtraLarge
    readonly property real spacing: Tokens.spacing.extraExtraLarge
    readonly property real visualiserSize: Math.min(root.height * 0.6, (root.width - 2 * root.margin) * 0.36)
    readonly property real coverSize: Math.round(root.visualiserSize * 0.42)
    readonly property real controlsWidth: Math.min(root.width - 2 * root.margin, 980)
    readonly property int seekStep: 10

    readonly property string appName: Players.active ? Players.getIdentity(Players.active) : ""
    property var appStream: Audio.getAppStream(root.appName)

    readonly property var selectablePlayers: Players.list.filter(p => (p as MprisPlayer).dbusName !== "org.mpris.MediaPlayer2.playerctld")

    readonly property string artSource: {
        const url = Players.getArtUrl(Players.active);
        if (!url)
            return "";
        return url.startsWith("file://") ? url.substring(7) : url;
    }
    readonly property bool hasArt: analyser.luminance > 0

    function blend(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    readonly property color topColour: root.hasArt ? root.blend(analyser.dominantColour, Colours.palette.m3surface, 0.35) : Colours.palette.m3surfaceContainerHighest
    readonly property color bottomColour: root.hasArt ? root.blend(analyser.dominantColour, Colours.palette.m3scrim, 0.72) : Colours.palette.m3scrim

    property color gradTop: root.topColour
    property color gradBottom: root.bottomColour

    anchors.fill: parent
    anchors.leftMargin: root.bar.implicitWidth + root.borderThickness
    anchors.topMargin: root.borderThickness
    anchors.rightMargin: root.borderThickness
    anchors.bottomMargin: root.borderThickness
    visible: offsetScale < 1
    opacity: 1 - offsetScale
    transform: Translate {
        id: slide
        y: -root.parent.height * root.offsetScale
    }

    Keys.onEscapePressed: root.screenState.mediaFullscreen = false
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space) {
            const active = Players.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            const active = Players.active;
            if (active?.canSeek && active?.positionSupported)
                active.position = Math.max(0, (active.position ?? 0) - root.seekStep);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            const active = Players.active;
            if (active?.canSeek && active?.positionSupported) {
                const pos = active.position ?? 0;
                if (pos + root.seekStep >= active.length)
                    active.next();
                else
                    active.position = pos + root.seekStep;
            }
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            Audio.incrementVolume();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            Audio.decrementVolume();
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            const sink = Audio.sink;
            if (sink?.ready && sink?.audio)
                sink.audio.muted = !sink.audio.muted;
            event.accepted = true;
        }
    }
    onVisibleChanged: {
        if (visible)
            forceActiveFocus();
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on gradTop {
        CAnim {}
    }

    Behavior on gradBottom {
        CAnim {}
    }

    ImageAnalyser {
        id: analyser

        source: root.artSource
        rescaleSize: 64
    }

    onTopColourChanged: root.gradTop = root.topColour
    onBottomColourChanged: root.gradBottom = root.bottomColour

    ClippingRectangle {
        anchors.fill: parent

        radius: Config.border.rounding
        color: "transparent"

        Item {
            anchors.fill: parent

            Image {
                id: artImage

                anchors.fill: parent
                source: root.artSource
                sourceSize: Qt.size(Math.round(root.width), Math.round(root.height))
                fillMode: Image.PreserveAspectCrop
                visible: root.hasArt
                opacity: root.hasArt ? 0.45 : 0

                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 0.6
                    blurMax: 32
                    blurMultiplier: 1
                }

                Behavior on opacity {
                    Anim {}
                }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: root.gradTop
                    }
                    GradientStop {
                        position: 1
                        color: root.gradBottom
                    }
                }
                opacity: root.hasArt ? 0.9 : 1

                Behavior on opacity {
                    Anim {}
                }
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: root.margin

            ColumnLayout {
                anchors.fill: parent
                spacing: root.spacing

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        width: root.visualiserSize
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        CoverVisualiser {
                            width: root.visualiserSize
                            height: root.visualiserSize
                            anchors.centerIn: parent
                            coverSize: root.coverSize
                        }
                    }

                    ColumnLayout {
                        width: Math.min(root.controlsWidth, (root.width - 2 * root.margin) * 0.4)
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Tokens.spacing.extraExtraLarge
                        spacing: Tokens.spacing.medium

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: "lyrics"
                                fontStyle: Tokens.font.icon.medium
                            }

                            StyledText {
                                text: qsTr("Lyrics")
                                font: Tokens.font.title.medium
                            }

                            Item {
                                Layout.preferredWidth: 325
                            }

                            LyricsInfo {}

                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        LyricList {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    ColumnLayout {
                        id: layout

                        Layout.preferredWidth: root.controlsWidth
                        Layout.maximumWidth: root.controlsWidth
                        Layout.fillWidth: false
                        spacing: Tokens.spacing.large

                        Details {
                            Layout.fillWidth: true
                            screenState: root.screenState
                            stretchPlay: false
                            centerTransport: true
                            controlScale: 1.15
                            sliderMaxWidth: root.controlsWidth * 0.55
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight
                        Layout.fillWidth: false
                        spacing: Tokens.spacing.large

                        SplitButton {
                            Layout.alignment: Qt.AlignRight

                            type: SplitButton.Tonal
                            disabled: !Players.list.length
                            active: menuItems.find(m => m.modelData === Players.active) ?? menuItems[0] ?? null
                            menu.onItemSelected: item => Players.manualActive = (item as PlayerItem).modelData

                            menuItems: playerList.instances
                            fallbackIcon: "music_off"
                            fallbackText: qsTr("No players")

                            minLeftWidth: Math.round(Tokens.sizes.dashboard.mediaSectionWidth / 2)
                            label.Layout.maximumWidth: root.minLeftWidth - iconLabel.implicitWidth - textRow.spacing
                            label.elide: Text.ElideRight

                            stateLayer.disabled: true
                            menuOnTop: true
                            menuParentOverride: root
                            menuElevated: true

                            Variants {
                                id: playerList

                                model: root.selectablePlayers

                                PlayerItem {}
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            Layout.preferredHeight: volumeSlider.implicitHeight
                            spacing: Tokens.spacing.medium

                            CustomMouseArea {
                                Layout.preferredWidth: volIcon.implicitWidth
                                Layout.preferredHeight: volIcon.implicitHeight
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    const stream = Audio.getAppStream(root.appName);
                                    if (stream?.ready && stream?.audio)
                                        stream.audio.muted = !stream.audio.muted;
                                }

                                MaterialIcon {
                                    id: volIcon

                                    anchors.centerIn: parent
                                    text: Icons.getVolumeIcon(Audio.getStreamVolume(appStream), appStream?.audio?.muted ?? false)
                                    fontStyle: Tokens.font.icon.medium
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }

                            StyledSlider {
                                id: volumeSlider

                                Layout.preferredWidth: Tokens.sizes.dashboard.mediaSectionWidth
                                Layout.fillWidth: false

                                value: Audio.getStreamVolume(appStream)
                                onInteraction: value => {
                                    const stream = Audio.getAppStream(root.appName);
                                    if (stream)
                                        Audio.setStreamVolume(stream, value);
                                }
                            }
                        }
                    }
                }
            }
        }

        StyledRect {
            id: closeBtnRect

            anchors.top: parent.top
            anchors.right: parent.right

            color: "transparent"
            radius: Tokens.rounding.medium

            implicitWidth: closeBtn.implicitWidth + Tokens.padding.extraSmall
            implicitHeight: closeBtn.implicitHeight + Tokens.padding.extraSmall

            IconButton {
                id: closeBtn

                anchors.centerIn: closeBtnRect
                icon: "close"
                type: IconButton.Text
                label.fill: 0
                inactiveOnColour: hovered ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                stateLayer.opacity: 0
                onClicked: root.screenState.mediaFullscreen = false

                label.scale: pressed ? 0.8 : 1
                label.renderType: Text.QtRendering

                Behavior on label.scale {
                    Anim {}
                }
            }
        }
    }

    component PlayerItem: MenuItem {
        required property MprisPlayer modelData

        icon: modelData === Players.active ? "check" : ""
        text: Players.getIdentity(modelData)
        activeIcon: "animated_images"
    }
}