import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "Theme.js" as T
import "Icons.js" as Icons

// Iluminación del teclado (controlador Alienware AW-ELC).
Rectangle {
    id: page
    color: T.rule
    readonly property var ls: hw.lightsState || ({})
    readonly property string effect: ls.effect || "static"
    readonly property string color_: ls.color || "FFFFFF"
    readonly property int brightness: ls.brightness === undefined ? 100 : ls.brightness
    readonly property bool usable: !!ls.available && ls.via !== "none"

    function send(effect, color, brightness) { hw.setLights(effect, color, brightness) }

    readonly property var swatches: ["FFFFFF", "FFB020", "FF6A1F", "FF2D2D", "FF2E88", "B04DFF",
                                     "4D6BFF", "2EC4FF", "1FE0B0", "3DDC5A", "C8FF2E", "FFE14D"]

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
                    Text { text: qsTr("Iluminación"); color: T.ink; font { family: T.sans; pixelSize: 22; weight: Font.DemiBold } }
                    Text {
                        text: qsTr("Color, efecto y brillo del teclado. Se guarda en Vórtice, no en una app del fabricante.")
                        color: T.ink2
                        font { family: T.sans; pixelSize: 14 }
                    }
                }
                component Cell: Item {
                    property string label
                    property string value
                    property color tint: T.ink
                    Layout.fillHeight: true
                    implicitWidth: col.implicitWidth + 2 * T.pad
                    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: T.rule }
                    Column {
                        id: col
                        anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text { text: parent.parent.label; color: T.ink3
                               font { family: T.sans; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase } }
                        Text { text: parent.parent.value; color: parent.parent.tint; font { family: T.mono; pixelSize: 13 } }
                    }
                }
                Cell {
                    label: qsTr("Controlador")
                    value: page.ls.available ? page.ls.device + " · " + (page.ls.path || "").replace("/dev/", "") : qsTr("no encontrado")
                    tint: page.ls.available ? T.ink : T.amber
                }
                Cell {
                    label: qsTr("Al reiniciar o suspender")
                    value: page.ls.via === "service" ? qsTr("se reaplica") : page.ls.via === "direct" ? qsTr("se pierde · instala el servicio") : "—"
                    tint: page.ls.via === "service" ? T.ink : T.amber
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            // ---------- Vista previa ----------
            Section {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: qsTr("Vista previa")
                source: page.effect === "aurora" ? "aurora" : page.effect === "off" ? qsTr("apagado")
                        : "#" + page.color_ + " · " + page.brightness + " %"

                Notice {
                    anchors.fill: parent
                    visible: !page.ls.available
                    icon: Icons.sparkles
                    title: qsTr("No se encontró un controlador de luces compatible")
                    text: qsTr("Vórtice controla teclados Alienware (AW-ELC), ASUS TUF/ROG, Acer de 4 zonas (con Linuwu-Sense), RGB estándar y el brillo de cualquier teclado retroiluminado.")
                }

                // Color mostrado (animado según el efecto, solo con la página visible).
                Item {
                    id: shown
                    property color c: "#" + page.color_
                    property real level: page.effect === "off" ? 0 : page.brightness / 100
                    // Animación a 24 fps calculada por tiempo: una pantalla de 240 Hz no
                    // necesita 240 redibujados por segundo para una transición de 2 s.
                    property real pulse: 1
                    property color aurora: "#19FF7A"
                    readonly property var auroraColors: (page.ls.aurora || ["19FF7A"]).map(h => Qt.color("#" + h))
                    Timer {
                        interval: 42
                        repeat: true
                        running: page.visible && (page.effect === "breathe" || page.effect === "aurora")
                        onRunningChanged: if (!running) shown.pulse = 1
                        onTriggered: {
                            var t = Date.now()
                            if (page.effect === "breathe") {
                                shown.pulse = 0.5 + 0.5 * Math.cos(t / 4000 * 2 * Math.PI)
                            } else {
                                var pal = shown.auroraColors, n = pal.length
                                var x = (t / 2000) % n, i = Math.floor(x), f = x - i
                                var a = pal[i], b = pal[(i + 1) % n]
                                shown.aurora = Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1)
                            }
                        }
                    }
                    readonly property color base: page.effect === "aurora" ? aurora : c
                    readonly property real k: level * pulse
                }

                Item {
                    id: kb
                    visible: page.ls.available
                    anchors.centerIn: parent
                    readonly property real u: Math.min(parent.width / 15.6, parent.height / 7.2)
                    readonly property real gap: u * 0.12
                    width: u * 15; height: u * 6.2
                    // Filas del teclado en unidades (1 u = una tecla normal); cada fila suma 15 u.
                    readonly property var rows: [
                        { h: 0.7, keys: [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1] },
                        { h: 1, keys: [1,1,1,1,1,1,1,1,1,1,1,1,1,2] },
                        { h: 1, keys: [1.5,1,1,1,1,1,1,1,1,1,1,1,1,1.5] },
                        { h: 1, keys: [1.75,1,1,1,1,1,1,1,1,1,1,1,2.25] },
                        { h: 1, keys: [2.25,1,1,1,1,1,1,1,1,1,1,2.75] },
                        { h: 1, keys: [1.25,1,1.25,1.25,5,1.25,1,1,1,1] }
                    ]

                    // Todas las teclas forman UN solo trazado: cambiar el color (aurora) o la
                    // opacidad (brillo, respirar) es una única operación, no una por tecla.
                    readonly property string keysPath: {
                        var d = "", y = 0
                        for (var r = 0; r < rows.length; r++) {
                            var x = 0, h = u * rows[r].h - gap
                            for (var k = 0; k < rows[r].keys.length; k++) {
                                var w = u * rows[r].keys[k] - gap
                                d += "M" + x.toFixed(1) + " " + y.toFixed(1) + "h" + w.toFixed(1)
                                     + "v" + h.toFixed(1) + "h" + (-w).toFixed(1) + "z"
                                x += u * rows[r].keys[k]
                            }
                            y += u * rows[r].h
                        }
                        return d
                    }
                    component KeysShape: Shape {
                        id: ks
                        property color fill
                        anchors.fill: parent
                        ShapePath { fillColor: ks.fill; strokeColor: "transparent"; PathSvg { path: kb.keysPath } }
                    }
                    KeysShape { fill: "#1C1D20" }                                  // teclas apagadas
                    KeysShape { fill: shown.base; opacity: shown.k * 0.9 }          // luz
                }
            }

            // ---------- Controles ----------
            Section {
                Layout.preferredWidth: 420
                Layout.fillHeight: true
                label: qsTr("Ajustes")
                enabled: page.usable
                opacity: enabled ? 1 : 0.4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: -T.pad
                    anchors.rightMargin: -T.pad
                    spacing: 0

                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
                    Repeater {
                        // Solo los efectos que soporta este teclado.
                        model: [
                            { id: "static",  name: page.ls.hasColor !== false ? qsTr("Fijo") : qsTr("Encendido"), desc: page.ls.hasColor !== false ? qsTr("Un color constante") : qsTr("Luz a un brillo fijo") },
                            { id: "breathe", name: qsTr("Respirar"), desc: qsTr("El color se enciende y se apaga despacio") },
                            { id: "aurora",  name: page.ls.kind === "acer4" ? qsTr("Onda") : (page.ls.kind === "asus" || page.ls.kind === "legion4") ? qsTr("Ciclo de color") : qsTr("Aurora"),
                              desc: page.ls.kind === "awelc" ? qsTr("Recorre verdes, azules y violetas") : qsTr("Efecto de color del propio teclado") },
                            { id: "off",     name: qsTr("Apagado"),  desc: qsTr("Sin luz") }
                        ].filter(e => (page.ls.effects || ["static", "breathe", "aurora", "off"]).indexOf(e.id) >= 0)
                        delegate: Item {
                            id: opt
                            required property var modelData
                            readonly property bool active: page.effect === modelData.id
                            Layout.fillWidth: true
                            Layout.preferredHeight: 54
                            Rectangle { anchors.fill: parent; color: opt.active ? T.bgRaised : (oh.hovered ? Qt.rgba(1, 1, 1, 0.018) : "transparent") }
                            Rectangle { width: 3; height: parent.height; color: T.amber; visible: opt.active }
                            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: T.rule }
                            Column {
                                anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text { text: opt.modelData.name; color: opt.active ? T.ink : T.ink2
                                       font { family: T.sans; pixelSize: 15; weight: opt.active ? Font.DemiBold : Font.Medium } }
                                Text { text: opt.modelData.desc; color: T.ink3; font { family: T.sans; pixelSize: 12 } }
                            }
                            HoverHandler { id: oh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.send(opt.modelData.id, page.color_, Math.max(page.brightness, opt.modelData.id === "off" ? 0 : 10)) }
                        }
                    }

                    // Color (oculto si el teclado solo admite brillo)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: T.pad
                        spacing: 12
                        visible: page.ls.hasColor !== false
                        enabled: page.effect === "static" || page.effect === "breathe"
                        opacity: enabled ? 1 : 0.35

                        Text { text: qsTr("Color"); color: T.ink2
                               font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase } }

                        Grid {
                            columns: 6
                            spacing: 8
                            Repeater {
                                model: page.swatches
                                Rectangle {
                                    required property string modelData
                                    readonly property bool current: page.color_ === modelData
                                    width: 52; height: 30; radius: 2
                                    color: "#" + modelData
                                    border.width: current ? 2 : 1
                                    border.color: current ? T.ink : Qt.rgba(0, 0, 0, 0.4)
                                    Rectangle {   // marca de selección
                                        visible: parent.current
                                        anchors { left: parent.left; bottom: parent.bottom; margins: 4 }
                                        width: 6; height: 6; color: "#121315"
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: page.send(page.effect, parent.modelData, page.brightness) }
                                }
                            }
                        }

                        // Tira de tono: arrastra para elegir cualquier color.
                        Item {
                            id: hueStrip
                            Layout.fillWidth: true
                            height: 26
                            function hex(h) {
                                var c = Qt.hsva(h, 1, 1, 1)
                                function p(x) { var s = Math.round(x * 255).toString(16).toUpperCase(); return s.length < 2 ? "0" + s : s }
                                return p(c.r) + p(c.g) + p(c.b)
                            }
                            function pick(x) { page.send(page.effect, hex(Math.max(0, Math.min(0.999, x / width))), page.brightness) }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                height: 12
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#FF0000" }
                                    GradientStop { position: 0.17; color: "#FFFF00" }
                                    GradientStop { position: 0.33; color: "#00FF00" }
                                    GradientStop { position: 0.5; color: "#00FFFF" }
                                    GradientStop { position: 0.67; color: "#0000FF" }
                                    GradientStop { position: 0.83; color: "#FF00FF" }
                                    GradientStop { position: 1.0; color: "#FF0000" }
                                }
                            }
                            Rectangle {   // marcador del tono actual
                                readonly property real h: Qt.color("#" + page.color_).hsvHue
                                visible: h >= 0 && Qt.color("#" + page.color_).hsvSaturation > 0.2
                                x: h * (hueStrip.width - width)
                                width: 4; height: parent.height
                                color: T.ink
                                border.color: "#121315"
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: (ev) => hueStrip.pick(ev.position.x) }
                            DragHandler {
                                target: null
                                yAxis.enabled: false
                                onCentroidChanged: if (active) hueStrip.pick(centroid.position.x)
                            }
                        }

                        RowLayout {
                            spacing: 8
                            Text { text: "#"; color: T.ink3; font { family: T.mono; pixelSize: 13 } }
                            TextField {
                                id: hexField
                                Layout.preferredWidth: 110
                                text: page.color_
                                color: T.ink
                                maximumLength: 6
                                validator: RegularExpressionValidator { regularExpression: /[0-9A-Fa-f]{6}/ }
                                font { family: T.mono; pixelSize: 13; capitalization: Font.AllUppercase }
                                background: Rectangle { color: "transparent"; border.color: hexField.activeFocus ? T.ink2 : T.ruleHi; radius: 2 }
                                onAccepted: page.send(page.effect, text.toUpperCase(), page.brightness)
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }

                    // Brillo
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: T.pad
                        spacing: 6
                        enabled: page.effect !== "off"
                        opacity: enabled ? 1 : 0.35
                        RowLayout {
                            Text { text: qsTr("Brillo"); color: T.ink2
                                   font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase } }
                            Item { Layout.fillWidth: true }
                            Text { text: Math.round(bri.value) + " %"; color: T.ink; font { family: T.mono; pixelSize: 12 } }
                        }
                        Fader {
                            id: bri
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 5
                            Binding on value { when: !bri.pressed; value: page.brightness; restoreMode: Binding.RestoreNone }
                            onCommitted: v => page.send(page.effect, page.color_, Math.round(v))
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
