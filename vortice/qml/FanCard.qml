import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Shapes
import "Icons.js" as Icons

// Ventilador: aspas que giran a la velocidad real y anillo de carga.
Card {
    id: fc
    property string label: "Ventilador"
    property real rpm: 0
    property real maxRpm: 5400
    property var boost: null          // 0-255 según el kernel
    property bool canBoost: false     // servicio instalado
    signal boostRequested(int value)
    pad: 20

    readonly property real frac: Math.min(1, rpm / Math.max(maxRpm, rpm, 1))
    property real shownFrac: frac
    Behavior on shownFrac { SmoothedAnimation { velocity: 0.35 } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: fc.label
                color: "#9A9FB4"
                font { family: "Inter"; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.6 }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: fc.boost !== null && fc.boost !== undefined
                height: 20; width: boostText.implicitWidth + 14; radius: 10
                color: fc.boost > 0 ? Qt.rgba(1, 0.42, 0.24, 0.18) : Qt.rgba(1, 1, 1, 0.05)
                Text {
                    id: boostText
                    anchors.centerIn: parent
                    text: fc.boost > 0 ? "BOOST " + Math.round(fc.boost / 2.55) + "%" : "AUTO"
                    color: fc.boost > 0 ? "#FF8A5C" : "#7E849A"
                    font { family: "JetBrains Mono"; pixelSize: 9; weight: Font.DemiBold }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: dial
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - 6
                height: width

                // Anillo de RPM (shader, sin geometría en la CPU).
                ShaderGauge {
                    anchors.fill: parent
                    anchors.margins: -26
                    progress: fc.shownFrac
                    thickness: 6
                    inset: 29
                    startAngle: -Math.PI / 2
                    sweep: Math.PI * 2 - 0.0001
                    ticks: 0
                    glow: 0.8
                    colorA: "#22D3EE"
                    colorB: fc.boost > 0 ? "#FF6B3D" : "#38BDF8"
                }

                // Aspas.
                Item {
                    id: blades
                    anchors.centerIn: parent
                    width: dial.width * 0.5; height: width
                    property real speed: fc.rpm * 0.09   // grados por segundo
                    property real angle: 0
                    rotation: angle
                    // Pausa el giro con la ventana minimizada u oculta.
                    readonly property bool onScreen: Window.window !== null
                        && Window.window.visibility !== Window.Minimized
                        && Window.window.visibility !== Window.Hidden
                    Behavior on speed { NumberAnimation { duration: 1200 } }
                    Icon {
                        anchors.centerIn: parent
                        path: Icons.fan
                        size: parent.width
                        stroke: 1.6
                        color: fc.rpm > 0 ? "#DDE7FF" : "#5C6278"
                    }
                    FrameAnimation {
                        id: spin
                        running: blades.speed > 0.5 && blades.onScreen
                        onTriggered: {
                            var dt = Math.min(spin.frameTime, 0.1)
                            if (dt > 0) blades.angle = (blades.angle + blades.speed * dt) % 360
                        }
                    }
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            Text {
                id: rpmText
                text: fc.rpm.toLocaleString(Qt.locale("es_ES"), "f", 0)
                color: "#F5F6FA"
                font { family: "Space Grotesk"; pixelSize: 26; weight: Font.Medium }
            }
            Text {
                text: "RPM"
                color: "#7E849A"
                anchors.baseline: rpmText.baseline
                font { family: "Inter"; pixelSize: 11; weight: Font.DemiBold }
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: fc.rpm === 0 ? "Parado · modo silencioso" : Math.round(fc.frac * 100) + "% de su máximo"
            color: "#7E849A"
            font { family: "Inter"; pixelSize: 11 }
        }

        Item { Layout.preferredHeight: 14 }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "Boost"
                color: "#B4B9CB"
                font { family: "Inter"; pixelSize: 12; weight: Font.DemiBold }
            }
            Item { Layout.fillWidth: true }
            Icon { visible: !fc.canBoost; path: Icons.lock; size: 12; color: "#7E849A" }
            Text {
                text: !fc.canBoost ? "Sin servicio"
                      : slider.value === 0 ? "Automático" : Math.round(slider.value) + " %"
                color: slider.value > 0 && fc.canBoost ? "#FF8A5C" : "#7E849A"
                font { family: "JetBrains Mono"; pixelSize: 11; weight: Font.Medium }
            }
        }
        GlowSlider {
            id: slider
            Layout.fillWidth: true
            enabled: fc.canBoost
            from: 0; to: 100; stepSize: 5
            colorA: "#38BDF8"; colorB: "#FF6B3D"
            // Sigue al valor real salvo mientras se arrastra.
            Binding on value { when: !slider.pressed; value: Math.round((fc.boost || 0) / 2.55 / 5) * 5; restoreMode: Binding.RestoreNone }
            onCommitted: v => fc.boostRequested(Math.round(v * 2.55))
        }
    }
}
