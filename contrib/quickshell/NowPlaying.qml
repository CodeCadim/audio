// Notification-sized now-playing card for cliamp. Visualizer-first.
//
// Layout (top to bottom):
//   - prominent spectrum visualizer
//   - title (bold) + artist (dim)
//   - thin seekable progress bar + time readout
//   - transport row: << play/pause >>
//
// Driven by an MprisPlayer for transport + position. Theme colors come from
// the active Omarchy theme at ~/.config/omarchy/current/theme/colors.toml,
// watched for changes so theme swaps update the widget live.

import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var player: null

    property color bg:     "#181616"
    property color edge:   "#0d0c0c"
    property color fg:     "#c5c9c5"
    property color dim:    "#a6a69c"
    property color accent: "#658594"
    property color green:  "#8a9a7b"
    property color yellow: "#c4b28a"
    property color red:    "#c4746e"

    FileView {
        id: themeFile
        path: (Quickshell.env("HOME") || "") + "/.config/omarchy/current/theme/colors.toml"
        watchChanges: true
        // Omarchy's theme swap does `rm -rf current/theme && mv next-theme current/theme`,
        // so there's a brief window where the file genuinely doesn't exist. Quiet the
        // log and schedule a retry instead of spamming warnings.
        printErrors: false
        onFileChanged: reload()
        onLoaded:      root._applyOmarchyTheme(text())
        onLoadFailed:  reloadTimer.restart()
    }
    Timer {
        id: reloadTimer
        interval: 400
        repeat: false
        onTriggered: themeFile.reload()
    }

    function _applyOmarchyTheme(src) {
        if (!src) return;
        const lines = String(src).split("\n");
        const re = /^\s*([A-Za-z0-9_]+)\s*=\s*"?(#?[0-9A-Fa-f]+)"?\s*$/;
        const t = {};
        for (let i = 0; i < lines.length; ++i) {
            const m = lines[i].match(re);
            if (m) t[m[1]] = m[2];
        }
        if (t.background) root.bg     = t.background;
        if (t.foreground) root.fg = t.foreground;
        if (t.accent)     root.accent = t.accent;
        if (t.color2)     root.green  = t.color2;
        if (t.color3)     root.yellow = t.color3;
        if (t.color1)     root.red    = t.color1;
        if (t.color8)     root.dim    = t.color8;
        else              root.dim    = Qt.darker(root.fg, 1.7);
        // Card border: prefer `selection_background` (subtle dark gray), fall
        // back to `color8` (medium gray), then to a darkened foreground.
        if (t.selection_background) root.edge = t.selection_background;
        else if (t.color8)          root.edge = t.color8;
        else                        root.edge = Qt.darker(root.fg, 3.0);
    }

    readonly property bool ready:   player !== null
    readonly property bool playing: ready && player.isPlaying
    readonly property real len:     ready && player.lengthSupported ? player.length : 0
    property real livePosition: 0

    Timer {
        interval: 250
        running: root.ready && root.playing
        repeat: true
        onTriggered: root.livePosition = root.player.position
    }
    Connections {
        target: root.player
        function onPlaybackStateChanged() { root.livePosition = root.player.position }
        function onTrackTitleChanged()    { root.livePosition = root.player.position }
        function onPositionChanged()      { root.livePosition = root.player.position }
    }

    function fmt(seconds) {
        if (!isFinite(seconds) || seconds < 0) return "--:--";
        const s = Math.floor(seconds);
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    BandStream {
        id: stream
        fps: 30
        enabled: root.ready
    }

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.92)
        border.color: root.edge
        border.width: 1
    }

    Visualizer {
        id: vis
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        height: 40
        bands: stream.bands
        barColor:    root.accent
        accentColor: root.yellow
        warnColor:   root.red
    }

    ColumnLayout {
        anchors.top: vis.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 8
        anchors.topMargin: 6
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MediaIcon {
                shape: root.playing ? "play" : "pause"
                color: root.green
                size: 10
                opacity: root.ready ? 1.0 : 0.35
                Layout.preferredWidth: 12
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.ready ? (root.player.trackTitle || "Unknown title")
                                     : "cliamp: not running"
                    color: root.fg
                    font.family: "monospace"
                    font.pixelSize: 12
                    font.bold: true
                    textFormat: Text.PlainText
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.ready ? (root.player.trackArtist || "")
                                     : ""
                    color: root.dim
                    font.family: "monospace"
                    font.pixelSize: 10
                    visible: text.length > 0
                    textFormat: Text.PlainText
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                id: barWrap
                Layout.fillWidth: true
                Layout.preferredHeight: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 2
                    color: root.dim
                    opacity: 0.5
                    radius: 0
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 2
                    width: parent.width * (root.len > 0 ? Math.min(1, root.livePosition / root.len) : 0)
                    color: root.accent
                    radius: 0
                }
                Rectangle {
                    visible: root.ready && root.len > 0
                    width: 6; height: 6; radius: 0
                    color: root.accent
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(parent.width - width,
                           parent.width * (root.livePosition / root.len) - width / 2))
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.ready && root.player.canSeek && root.len > 0
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: (mouse) => {
                        const frac = Math.max(0, Math.min(1, mouse.x / width));
                        const target = frac * root.len;
                        root.player.position = target;
                        root.livePosition = target;
                    }
                }
            }

            Text {
                text: root.fmt(root.livePosition) + " / " + root.fmt(root.len)
                color: root.dim
                font.family: "monospace"
                font.pixelSize: 9
                Layout.preferredWidth: 76
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Item { Layout.fillWidth: true }
            TransportButton {
                shape: "prev"
                iconSize: 12
                enabled: root.ready && root.player.canGoPrevious
                fgColor: root.fg
                hoverColor: root.yellow
                onActivated: root.player.previous()
            }
            TransportButton {
                shape: root.playing ? "pause" : "play"
                iconSize: 14
                enabled: root.ready && root.player.canTogglePlaying
                fgColor: root.accent
                hoverColor: root.green
                onActivated: root.player.togglePlaying()
            }
            TransportButton {
                shape: "next"
                iconSize: 12
                enabled: root.ready && root.player.canGoNext
                fgColor: root.fg
                hoverColor: root.yellow
                onActivated: root.player.next()
            }
            Item { Layout.fillWidth: true }
        }
    }
}
