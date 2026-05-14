// Winamp 2-inspired spectrum analyzer: stacked LED segments per band with
// falling peak caps. Three-tone gradient drawn over each bar (low / mid /
// high) so the column "lights up" the way the classic skin did.
//
// Driven by 10-band frames from BandStream. Colors come from the active
// Omarchy theme via NowPlaying.qml.

import QtQuick

Item {
    id: root
    property var bands: []

    // Three-tone color stack. Bottom -> top: barColor (low), accentColor
    // (mid), warnColor (top). The user passes the active theme accent,
    // yellow, and red into these.
    property color barColor:    "#a9b665"
    property color accentColor: "#d8a657"
    property color warnColor:   "#ea6962"

    // Segment geometry. `segH` and `segGap` define the LED-stack look — keep
    // segGap >= 1 so the dark line between segments stays visible.
    property int segH:   3
    property int segGap: 1

    implicitWidth: 320
    implicitHeight: 56

    property var peaks: Array(10).fill(0)

    Timer {
        // Drives peak decay independent of band update rate. Skips the state
        // write when nothing moved so a paused player doesn't allocate and
        // emit a peaksChanged signal at 30 Hz.
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            const cur = root.peaks;
            const next = cur.slice();
            let dirty = false;
            for (let i = 0; i < next.length; ++i) {
                const v = root.bands[i] || 0;
                const nv = v > next[i] ? v : Math.max(0, next[i] - 0.018);
                if (nv !== cur[i]) dirty = true;
                next[i] = nv;
            }
            if (dirty) {
                root.peaks = next;
                canvas.requestPaint();
            }
        }
    }

    onBandsChanged:       canvas.requestPaint()
    onBarColorChanged:    canvas.requestPaint()
    onAccentColorChanged: canvas.requestPaint()
    onWarnColorChanged:   canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const b = root.bands || [];
            const n = b.length || 10;

            // Bar geometry: fill the full width, tight gaps.
            const gap = 2;
            const bw  = Math.max(2, Math.floor((w - gap * (n - 1)) / n));
            const xStart = Math.max(0, Math.floor((w - (bw * n + gap * (n - 1))) / 2));

            // Number of LED rows that fit. Cap at 24-ish for the classic
            // Winamp density.
            const rows = Math.max(4, Math.floor(h / (root.segH + root.segGap)));
            const lowRows  = Math.round(rows * 0.55);
            const midRows  = Math.round(rows * 0.30);

            // Build the per-row color stack once.
            const rowColors = new Array(rows);
            for (let r = 0; r < rows; ++r) {
                if (r < lowRows)              rowColors[r] = root.barColor;
                else if (r < lowRows + midRows) rowColors[r] = root.accentColor;
                else                          rowColors[r] = root.warnColor;
            }

            // Draw stacks.
            for (let i = 0; i < n; ++i) {
                const v = Math.max(0, Math.min(1, b[i] || 0));
                const lit = Math.round(v * rows);
                const x = xStart + i * (bw + gap);
                for (let r = 0; r < lit; ++r) {
                    const y = h - (r + 1) * (root.segH + root.segGap) + root.segGap;
                    if (y < 0) break;
                    ctx.fillStyle = rowColors[r];
                    ctx.fillRect(x, y, bw, root.segH);
                }
            }

            // Peak caps: one bright segment, theme-yellow, sitting at the
            // top of the peak position.
            ctx.fillStyle = root.accentColor;
            for (let i = 0; i < n; ++i) {
                const p = Math.max(0, Math.min(1, root.peaks[i] || 0));
                if (p <= 0) continue;
                const peakRow = Math.max(1, Math.round(p * rows));
                const y = h - peakRow * (root.segH + root.segGap) + root.segGap;
                if (y < 0) continue;
                const x = xStart + i * (bw + gap);
                ctx.fillRect(x, y, bw, root.segH);
            }
        }
    }
}
