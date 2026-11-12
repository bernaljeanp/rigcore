import QtQuick
import QtQuick.Layouts
import "Theme.js" as T
import "Icons.js" as Icons

// Curvas de ventilador: temperatura -> boost, editables arrastrando los puntos.
Rectangle {
    id: page
    color: T.rule
    property bool service: false

    readonly property var cfg: hw.fanCurve || ({})
    readonly property var fanNames: Object.keys(cfg.fans || {})
    property string fan: "CPU Fan"
    readonly property var live: (cfg.live || {})[fan] || ({})
    readonly property bool linked: cfg.linked !== false

    // Copia local mientras se arrastra (se envía al soltar).
    property var points: []
    function syncPoints() {
        var src = (cfg.fans || {})[fan]
        points = src ? src.map(p => [p[0], p[1]]) : []
        chart.requestPaint()
    }
    onCfgChanged: if (!chart.dragging) syncPoints()
    onFanChanged: syncPoints()
    Component.onCompleted: syncPoints()

    function label(f) { return f.replace("CPU Fan", qsTr("Ventilador CPU")).replace("GPU Fan", qsTr("Ventilador GPU")) }

    function commit(changes) {
        var fans = {}
        for (var i = 0; i < fanNames.length; i++) {
            var n = fanNames[i]
            fans[n] = (n === fan || (changes.linked !== undefined ? changes.linked : linked)) ? points : cfg.fans[n]
        }
        var out = { enabled: changes.enabled !== undefined ? changes.enabled : !!cfg.enabled,
                    linked: changes.linked !== undefined ? changes.linked : linked, fans: fans }
        hw.setFanCurve(JSON.stringify(out))
    }

    function evaluate(pts, t) {
        if (!pts.length) return 0
        if (t <= pts[0][0]) return pts[0][1]
        for (var i = 1; i < pts.length; i++)
            if (t <= pts[i][0]) return pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * (t - pts[i - 1][0]) / (pts[i][0] - pts[i - 1][0])
        return pts[pts.length - 1][1]
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 1

        // ---------- Cabecera ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            color: T.bg
            RowLayout {
                anchors { fill: parent; leftMargin: T.pad }
                spacing: 0
                Column {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: qsTr("Curvas de ventilador"); color: T.ink; font { family: T.sans; pixelSize: 22; weight: Font.DemiBold } }
                    Text {
                        text: qsTr("El boost sube con la temperatura según la curva. Sin curva, decide el firmware.")
                        color: T.ink2
                        font { family: T.sans; pixelSize: 14 }
                    }
                }
                Item {
                    Layout.fillHeight: true
                    implicitWidth: st.implicitWidth + 2 * T.pad
                    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: T.rule }
                    Column {
                        id: st
                        anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text { text: qsTr("Control"); color: T.ink3
                               font { family: T.sans; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase } }
                        Text {
                            text: !page.service ? qsTr("requiere servicio") : page.cfg.enabled ? qsTr("curva de Rigcore") : qsTr("firmware")
                            color: !page.service ? T.warn : page.cfg.enabled ? hw.accent : T.ink
                            font { family: T.mono; pixelSize: 13 }
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                    implicitWidth: tg.implicitWidth + 2 * T.pad
                    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: T.rule }
                    Toggle {
                        id: tg
                        anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                        label: qsTr("Curva activa")
                        checked: !!page.cfg.enabled
                        onToggled: on => page.commit({ enabled: on })
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            // ---------- Editor ----------
            Section {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: page.label(page.fan)
                source: page.live.temp !== undefined && page.live.temp !== null
                        ? Math.round(page.live.temp) + qsTr(" °C · curva ") + Math.round(page.evaluate(page.points, page.live.temp)) + " %"
                        : qsTr("arrastra los puntos")

                Canvas {
                    id: chart
                    anchors.fill: parent
                    renderStrategy: Canvas.Cooperative
                    property bool dragging: false
                    property int drag: -1
                    readonly property real padL: 44
                    readonly property real baseY: height - 26
                    readonly property real tlo: 30
                    readonly property real thi: 100
                    function px(t) { return padL + (t - tlo) / (thi - tlo) * (width - padL - 8) }
                    function py(b) { return baseY - b / 100 * (baseY - 8) }
                    function tempAt(x) { return tlo + (x - padL) / (width - padL - 8) * (thi - tlo) }
                    function boostAt(y) { return (baseY - y) / (baseY - 8) * 100 }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Connections { target: page; function onLiveChanged() { chart.requestPaint() } }

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        ctx.font = "11px '" + T.mono + "'"
                        ctx.lineWidth = 1
                        // Rejilla
                        for (var t = 30; t <= 100; t += 10) {
                            var x = Math.round(px(t)) + 0.5
                            ctx.strokeStyle = T.rule
                            ctx.beginPath(); ctx.moveTo(x, 8); ctx.lineTo(x, baseY); ctx.stroke()
                            ctx.fillStyle = T.ink3
                            var lbl = t + "°"
                            ctx.fillText(lbl, Math.min(x - 10, width - ctx.measureText(lbl).width), height - 6)
                        }
                        for (var b = 0; b <= 100; b += 25) {
                            var y = Math.round(py(b)) + 0.5
                            ctx.strokeStyle = T.rule
                            ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(width - 8, y); ctx.stroke()
                            ctx.fillStyle = T.ink3
                            ctx.fillText(b + "%", 0, y + 4)
                        }
                        var pts = page.points
                        if (!pts.length) return
                        // Curva (con tramos planos hasta los bordes)
                        ctx.strokeStyle = T.ink
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        ctx.moveTo(px(tlo), py(pts[0][1]))
                        for (var i = 0; i < pts.length; i++) ctx.lineTo(px(pts[i][0]), py(pts[i][1]))
                        ctx.lineTo(px(thi), py(pts[pts.length - 1][1]))
                        ctx.stroke()
                        // Temperatura actual
                        var lt = page.live.temp
                        if (lt !== undefined && lt !== null) {
                            var lx = px(Math.max(tlo, Math.min(thi, lt)))
                            ctx.strokeStyle = hw.accent
                            ctx.lineWidth = 1
                            ctx.setLineDash([4, 4])
                            ctx.beginPath(); ctx.moveTo(lx, 8); ctx.lineTo(lx, baseY); ctx.stroke()
                            ctx.setLineDash([])
                            ctx.fillStyle = hw.accent
                            ctx.fillRect(lx - 4, py(page.evaluate(pts, lt)) - 4, 8, 8)
                        }
                        // Puntos
                        for (var j = 0; j < pts.length; j++) {
                            var ptx = px(pts[j][0]), pty = py(pts[j][1])
                            ctx.fillStyle = j === drag ? "#FFFFFF" : T.bg
                            ctx.strokeStyle = T.ink
                            ctx.lineWidth = 2
                            ctx.fillRect(ptx - 6, pty - 6, 12, 12)
                            ctx.strokeRect(ptx - 6, pty - 6, 12, 12)
                            if (j === drag) {
                                ctx.fillStyle = T.ink
                                ctx.fillText(Math.round(pts[j][0]) + "° · " + Math.round(pts[j][1]) + "%", ptx + 10, pty - 10)
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        function nearest(mx, my) {
                            var best = -1, bd = 18 * 18
                            for (var i = 0; i < page.points.length; i++) {
                                var dx = chart.px(page.points[i][0]) - mx, dy = chart.py(page.points[i][1]) - my
                                if (dx * dx + dy * dy < bd) { bd = dx * dx + dy * dy; best = i }
                            }
                            return best
                        }
                        cursorShape: chart.drag >= 0 || nearest(mouseX, mouseY) >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: (m) => { chart.drag = nearest(m.x, m.y); chart.dragging = chart.drag >= 0 }
                        onPositionChanged: (m) => {
                            if (chart.drag < 0) return
                            var i = chart.drag, pts = page.points
                            var lo = i > 0 ? pts[i - 1][0] + 1 : 20, hi = i < pts.length - 1 ? pts[i + 1][0] - 1 : 105
                            pts[i] = [Math.round(Math.max(lo, Math.min(hi, chart.tempAt(m.x)))),
                                      Math.round(Math.max(0, Math.min(100, chart.boostAt(m.y))) / 5) * 5]
                            page.points = pts
                            chart.requestPaint()
                        }
                        onReleased: {
                            if (chart.drag >= 0) page.commit({})
                            chart.drag = -1
                            chart.dragging = false
                            chart.requestPaint()
                        }
                    }
                }
            }

            // ---------- Lateral ----------
            Section {
                Layout.preferredWidth: 340
                Layout.fillHeight: true
                label: qsTr("Ventilador")

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: -T.pad
                    anchors.rightMargin: -T.pad
                    spacing: 0

                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
                    Repeater {
                        model: page.fanNames
                        delegate: Item {
                            id: frow
                            required property string modelData
                            readonly property bool active: page.fan === modelData
                            readonly property var lv: (page.cfg.live || {})[modelData] || ({})
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            Rectangle { anchors.fill: parent; color: frow.active ? T.bgRaised : (fh.hovered ? Qt.rgba(1, 1, 1, 0.018) : "transparent") }
                            Rectangle { width: 3; height: parent.height; color: hw.accent; visible: frow.active }
                            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: T.rule }
                            RowLayout {
                                anchors { fill: parent; leftMargin: T.pad; rightMargin: T.pad }
                                Text { text: page.label(frow.modelData); color: frow.active ? T.ink : T.ink2; Layout.fillWidth: true
                                       font { family: T.sans; pixelSize: 15; weight: frow.active ? Font.DemiBold : Font.Medium } }
                                Text {
                                    text: frow.lv.temp !== undefined && frow.lv.temp !== null
                                          ? Math.round(frow.lv.temp) + "° · " + Math.round((frow.lv.boost || 0) / 2.55) + "%" : ""
                                    color: T.ink3
                                    font { family: T.mono; pixelSize: 11 }
                                }
                            }
                            HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.fan = frow.modelData }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        Toggle {
                            anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                            label: qsTr("Misma curva para todos")
                            checked: page.linked
                            onToggled: on => page.commit({ linked: on })
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
                    Text {
                        Layout.margins: T.pad
                        Layout.bottomMargin: 8
                        text: qsTr("Punto de partida")
                        color: T.ink2
                        font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase }
                    }
                    Repeater {
                        model: [{ id: "silenciosa", name: qsTr("Silenciosa"), desc: qsTr("Arranca tarde, por encima de 80 °C") },
                                { id: "equilibrada", name: qsTr("Equilibrada"), desc: qsTr("Empieza a 70 °C, al máximo a 90 °C") },
                                { id: "agresiva", name: qsTr("Agresiva"), desc: qsTr("Temperaturas bajas a costa de ruido") }]
                        delegate: Item {
                            id: prow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            Rectangle { anchors.fill: parent; color: ph.hovered ? Qt.rgba(1, 1, 1, 0.018) : "transparent" }
                            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: T.rule }
                            Column {
                                anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text { text: prow.modelData.name; color: T.ink2; font { family: T.sans; pixelSize: 15; weight: Font.Medium } }
                                Text { text: prow.modelData.desc; color: T.ink3; font { family: T.sans; pixelSize: 12 } }
                            }
                            HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    page.points = (page.cfg.presets || {})[prow.modelData.id].map(p => [p[0], p[1]])
                                    page.commit({})
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        Layout.margins: T.pad
                        text: !page.service
                              ? qsTr("Puedes preparar la curva ahora; se aplicará cuando instales el servicio de Rigcore.")
                              : (hw.helper || {}).hardwareCurve
                              ? qsTr("Este equipo guarda la curva en su firmware: Rigcore la escribe allí al guardarla y funciona aunque el servicio se detenga.")
                              : qsTr("Si un perfil de juego pide más refuerzo, se usa el mayor de los dos. Al detener el servicio, los ventiladores vuelven a automático.")
                        color: page.service ? T.ink3 : T.warn
                        wrapMode: Text.WordWrap
                        font { family: T.sans; pixelSize: 13 }
                    }
                }
            }
        }
    }
}
