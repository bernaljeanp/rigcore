import QtQuick
import "Theme.js" as T

// Historial térmico de 90 s: líneas finas sobre rejilla, como un registrador.
Section {
    id: hc
    label: qsTr("Historial")
    source: "90 s"

    property var cpu: []
    property var gpu: []
    readonly property var series: [
        { name: qsTr("CPU"), data: cpu, color: hw.accent, area: true },
        { name: qsTr("GPU"), data: gpu, color: T.steel }
    ]
    onCpuChanged: chart.requestPaint()
    Connections { target: hw; function onAccentChanged() { chart.requestPaint() } }

    headerRight: [
        Repeater {
            model: hc.series
            Row {
                required property var modelData
                spacing: 6
                Rectangle { width: 12; height: 2; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: {
                        var d = modelData.data, v = d && d.length ? d[d.length - 1] : null
                        return modelData.name + (v === null || v === undefined ? "" : "  " + Math.round(v) + "°")
                    }
                    color: T.ink2
                    font { family: T.mono; pixelSize: 11 }
                }
            }
        }
    ]

    Canvas {
        id: chart
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        readonly property real lo: 30
        readonly property real hi: 100
        readonly property int span: 90

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var left = 30, bottom = height - 16, top = 4
            var w = width - left, h = bottom - top
            function Y(v) { return bottom - (Math.max(lo, Math.min(hi, v)) - lo) / (hi - lo) * h }
            function X(i) { return left + w * i / (span - 1) }

            ctx.font = "11px '" + T.mono + "'"
            ctx.textBaseline = "middle"
            ctx.lineWidth = 1
            ;[40, 60, 80, 100].forEach(function (v) {
                var y = Math.round(Y(v)) + 0.5
                ctx.strokeStyle = v === 80 ? "rgba(255,176,32,0.22)" : T.rule
                ctx.beginPath(); ctx.moveTo(left, y); ctx.lineTo(width, y); ctx.stroke()
                ctx.fillStyle = T.ink3
                ctx.fillText(v, 0, y)
            })
            // Eje de tiempo.
            ctx.textBaseline = "alphabetic"
            ;[[0, qsTr("-90 s")], [45, qsTr("-45 s")], [89, qsTr("ahora")]].forEach(function (p) {
                var x = X(p[0])
                ctx.fillStyle = T.ink3
                var tw = ctx.measureText(p[1]).width
                ctx.fillText(p[1], Math.min(Math.max(x - tw / 2, left), width - tw), height - 2)
            })

            hc.series.forEach(function (s) {
                var d = s.data
                if (!d || d.length < 2) return
                var off = span - d.length
                if (s.area) {
                    // Área bajo la curva, del acento a transparente.
                    var c = Qt.color(s.color)
                    var g = ctx.createLinearGradient(0, top, 0, bottom)
                    g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0.22))
                    g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0))
                    ctx.fillStyle = g
                    ctx.beginPath()
                    var started = false, lastX = 0, firstX = 0
                    for (var j = 0; j < d.length; j++) {
                        if (d[j] === null || d[j] === undefined) continue
                        var ax = X(off + j), ay = Y(d[j])
                        if (!started) { ctx.moveTo(ax, bottom); ctx.lineTo(ax, ay); firstX = ax; started = true }
                        else ctx.lineTo(ax, ay)
                        lastX = ax
                    }
                    if (started) { ctx.lineTo(lastX, bottom); ctx.closePath(); ctx.fill() }
                }
                ctx.strokeStyle = s.color
                ctx.lineWidth = 1.5
                ctx.lineJoin = "round"
                ctx.beginPath()
                var pen = false
                for (var i = 0; i < d.length; i++) {
                    if (d[i] === null || d[i] === undefined) { pen = false; continue }
                    var x = X(off + i), y = Y(d[i])
                    if (pen) ctx.lineTo(x, y); else { ctx.moveTo(x, y); pen = true }
                }
                ctx.stroke()
            })
        }
    }
}
