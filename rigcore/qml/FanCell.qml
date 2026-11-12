import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "Theme.js" as T
import "Icons.js" as Icons

// Un ventilador: RPM, medidor horizontal y fader de boost.
Item {
    id: fc
    property string label: qsTr("Ventilador")
    property real rpm: 0
    property real maxRpm: 5400
    property string unit: "RPM"       // MSI (msi-ec) informa en %
    property var boost: null          // 0-255 según el kernel
    property bool canBoost: false
    property string kind: "boost"     // boost | pwm | mode | toggle | acer (ver fans.py)
    property var temp: null           // temperatura que vigila este ventilador
    property string watches: ""       // "CPU" / "GPU"
    property bool curveOn: false      // la curva de Rigcore lo controla
    property var curvePct: null       // % que pide la curva ahora
    readonly property bool onOff: kind === "mode" || kind === "toggle"
    signal boostRequested(int value)

    readonly property real frac: Math.min(1, rpm / Math.max(maxRpm, 1))
    property real shownFrac: frac
    Behavior on shownFrac { SmoothedAnimation { velocity: 0.4 } }
    readonly property bool boosted: (boost || 0) > 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            spacing: 8
            // Glifo que gira a la velocidad real (pausado si la ventana no se ve).
            Item {
                id: glyph
                width: 14; height: 14
                property real speed: fc.rpm * 0.08
                Behavior on speed { NumberAnimation { duration: 1200 } }
                readonly property bool onScreen: Window.window !== null
                    && Window.window.visibility !== Window.Minimized
                    && Window.window.visibility !== Window.Hidden
                Icon {
                    anchors.centerIn: parent
                    path: Icons.fan; size: 14; stroke: 1.6
                    color: fc.rpm > 0 ? (fc.boosted ? hw.accent : T.ink) : T.ink3
                    rotation: glyph.angle
                }
                property real angle: 0
                // 30 fps bastan para un glifo de 14 px (no 240 en una pantalla de 240 Hz).
                Timer {
                    interval: 33
                    repeat: true
                    running: glyph.speed > 0.5 && glyph.onScreen
                    onTriggered: glyph.angle = (glyph.angle + glyph.speed * 0.033) % 360
                }
            }
            Text {
                text: fc.label
                color: T.ink2
                font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase }
            }
        }

        Item { Layout.preferredHeight: 14 }

        Row {
            spacing: 6
            Text {
                id: rpmText
                text: Math.round(fc.rpm)
                color: fc.rpm > 0 ? T.ink : T.ink3
                font { family: T.display; pixelSize: 40; weight: Font.Medium }
            }
            Text {
                text: fc.unit === "%" ? "%" : qsTr("RPM")
                color: T.ink2
                anchors.baseline: rpmText.baseline
                font { family: T.mono; pixelSize: 12 }
            }
        }
        Text {
            text: fc.rpm === 0 ? qsTr("parado") : fc.unit === "%" ? qsTr("velocidad") : Math.round(fc.frac * 100) + qsTr(" % del máximo")
            color: T.ink3
            font { family: T.mono; pixelSize: 11 }
        }

        Item { Layout.fillHeight: true }

        // Qué vigila y quién manda: firmware o la curva de Rigcore.
        RowLayout {
            visible: fc.temp !== null && fc.temp !== undefined
            Layout.fillWidth: true
            spacing: 0
            Column {
                spacing: 3
                Text {
                    text: qsTr("Vigila") + (fc.watches ? " · " + fc.watches : "")
                    color: T.ink3
                    font { family: T.sans; pixelSize: 11; weight: Font.Medium; letterSpacing: 0.8; capitalization: Font.AllUppercase }
                }
                Row {
                    spacing: 3
                    Text {
                        id: tv
                        text: Math.round(fc.temp || 0)
                        color: (fc.temp || 0) >= 90 ? T.warn : T.ink
                        font { family: T.display; pixelSize: 22; weight: Font.Medium }
                    }
                    Text { text: "°C"; color: T.ink2; anchors.baseline: tv.baseline; font { family: T.mono; pixelSize: 11 } }
                }
            }
            Item { Layout.fillWidth: true }
            Column {
                spacing: 3
                Text {
                    anchors.right: parent.right
                    text: qsTr("Control")
                    color: T.ink3
                    font { family: T.sans; pixelSize: 11; weight: Font.Medium; letterSpacing: 0.8; capitalization: Font.AllUppercase }
                }
                Text {
                    anchors.right: parent.right
                    text: fc.curveOn ? qsTr("curva") + (fc.curvePct !== null && fc.curvePct !== undefined ? " → " + Math.round(fc.curvePct) + " %" : "")
                                     : fc.boosted ? qsTr("manual") : qsTr("firmware")
                    color: fc.curveOn || fc.boosted ? hw.accent : T.ink2
                    font { family: T.mono; pixelSize: 13 }
                }
            }
        }

        Item { Layout.preferredHeight: 16 }

        // Medidor horizontal de RPM.
        Item {
            Layout.fillWidth: true
            height: 10
            Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter } height: 2; color: T.ruleHi }
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                height: 2
                width: parent.width * fc.shownFrac
                color: fc.boosted ? hw.accent : T.ink
            }
            Repeater {
                model: 11
                Rectangle {
                    required property int index
                    x: index / 10 * (parent.width - 1)
                    y: index % 5 === 0 ? 0 : 3
                    width: 1; height: index % 5 === 0 ? 10 : 4
                    color: index / 10 <= fc.shownFrac && fc.rpm > 0 ? (fc.boosted ? hw.accent : T.ink2) : T.ruleHi
                }
            }
        }

        Item { Layout.preferredHeight: 18 }

        RowLayout {
            Layout.fillWidth: true
            Text {
                // Alienware suma sobre el firmware ("boost"); otros fijan una velocidad.
                text: fc.onOff ? qsTr("Velocidad") : fc.kind === "boost" ? qsTr("Boost") : qsTr("Velocidad mínima")
                color: T.ink2
                font { family: T.sans; pixelSize: 13; weight: Font.Medium }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: !fc.canBoost ? qsTr("requiere servicio")
                      : fc.onOff ? (fc.boosted ? qsTr("máximo") : qsTr("auto"))
                      : fader.value === 0 ? qsTr("auto") : Math.round(fader.value) + " %"
                color: (fc.onOff ? fc.boosted : fader.value > 0) && fc.canBoost ? hw.accent : T.ink3
                font { family: T.mono; pixelSize: 11 }
            }
        }
        // Ventiladores con solo automático / máximo (ASUS, HP Omen, MSI).
        Toggle {
            visible: fc.onOff
            enabled: fc.canBoost
            opacity: enabled ? 1 : 0.35
            label: qsTr("Máximo")
            checked: fc.boosted
            onToggled: on => fc.boostRequested(on ? 255 : 0)
        }
        Fader {
            id: fader
            visible: !fc.onOff
            Layout.fillWidth: true
            enabled: fc.canBoost
            from: 0; to: 100; stepSize: 5
            fill: value > 0 ? hw.accent : T.ink
            Binding on value { when: !fader.pressed; value: Math.round((fc.boost || 0) / 2.55 / 5) * 5; restoreMode: Binding.RestoreNone }
            onCommitted: v => fc.boostRequested(Math.round(v * 2.55))
        }
    }
}
