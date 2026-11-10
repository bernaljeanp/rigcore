import QtQuick
import QtQuick.Layouts
import "Icons.js" as Icons

// Historial térmico de los últimos 90 s, con áreas en degradado.
Card {
    id: hc
    title: "Historial térmico"
    icon: Icons.thermo
    accent: "#F472B6"

    property var cpu: []
    property var gpu: []
    readonly property var series: [
        { name: "CPU", data: cpu, color: "#38BDF8" },
        { name: "GPU", data: gpu, color: "#C084FC" }
    ]
    onCpuChanged: chart.requestPaint()

    headerRight: [
        Repeater {
            model: hc.series
            Row {
                required property var modelData
                spacing: 6
                Rectangle { width: 14; height: 3; radius: 2; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: modelData.name
                    color: "#9A9FB4"
                    font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
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

        readonly property real lo: 25
        readonly property real hi: 100
        readonly property int span: 90

        function hex2rgba(h, a) {
            var c = Qt.color(h)
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + ","
                   + Math.round(c.b * 255) + "," + a + ")"
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var left = 34, bottom = height - 6, top = 6
            var w = width - left, h = bottom - top
            function Y(v) { return bottom - (Math.max(lo, Math.min(hi, v)) - lo) / (hi - lo) * h }
            function X(i) { return left + w * i / (span - 1) }

            // Rejilla.
            ctx.font = "10px 'JetBrains Mono'"
            ctx.textBaseline = "middle"
            ;[40, 60, 80, 100].forEach(function (v) {
                var y = Y(v)
                ctx.strokeStyle = "rgba(255,255,255,0.05)"
                ctx.lineWidth = 1
                ctx.setLineDash([3, 5])
                ctx.beginPath(); ctx.moveTo(left, y); ctx.lineTo(width, y); ctx.stroke()
                ctx.setLineDash([])
                ctx.fillStyle = "rgba(160,166,190,0.55)"
                ctx.fillText(v + "°", 0, y)
            })

            hc.series.forEach(function (s) {
                var d = s.data
                if (!d || d.length < 2) return
                var off = span - d.length
                // Tramos continuos: un null (sin lectura) corta la línea.
                var segs = [], cur = []
                for (var i = 0; i < d.length; i++) {
                    if (d[i] === null || d[i] === undefined) { if (cur.length) segs.push(cur); cur = [] }
                    else cur.push(i)
                }
                if (cur.length) segs.push(cur)

                segs.forEach(function (seg) {
                    if (seg.length < 2) return
                    function trace() {
                        ctx.moveTo(X(off + seg[0]), Y(d[seg[0]]))
                        for (var k = 1; k < seg.length; k++) {
                            var a = seg[k - 1], b = seg[k]
                            var x0 = X(off + a), x1 = X(off + b), mx = (x0 + x1) / 2
                            ctx.bezierCurveTo(mx, Y(d[a]), mx, Y(d[b]), x1, Y(d[b]))
                        }
                    }
                    var g = ctx.createLinearGradient(0, top, 0, bottom)
                    g.addColorStop(0, hex2rgba(s.color, 0.28))
                    g.addColorStop(1, hex2rgba(s.color, 0.0))
                    ctx.beginPath(); trace()
                    ctx.lineTo(X(off + seg[seg.length - 1]), bottom); ctx.lineTo(X(off + seg[0]), bottom)
                    ctx.closePath()
                    ctx.fillStyle = g; ctx.fill()

                    ctx.beginPath(); trace()
                    ctx.strokeStyle = hex2rgba(s.color, 0.18); ctx.lineWidth = 7; ctx.stroke()
                    ctx.strokeStyle = s.color; ctx.lineWidth = 2.2; ctx.stroke()
                })

                var last = d[d.length - 1]
                if (last === null || last === undefined) return
                var lx = X(span - 1), ly = Y(last)
                ctx.fillStyle = hex2rgba(s.color, 0.25)
                ctx.beginPath(); ctx.arc(lx - 4, ly, 7, 0, Math.PI * 2); ctx.fill()
                ctx.fillStyle = "#FFFFFF"
                ctx.beginPath(); ctx.arc(lx - 4, ly, 3, 0, Math.PI * 2); ctx.fill()
            })
        }
    }
}
