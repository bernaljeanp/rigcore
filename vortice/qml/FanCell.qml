import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "Theme.js" as T
import "Icons.js" as Icons

// Un ventilador: RPM, medidor horizontal y fader de boost.
Item {
    id: fc
    property string label: "Ventilador"
    property real rpm: 0
    property real maxRpm: 5400
    property var boost: null          // 0-255 según el kernel
    property bool canBoost: false
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
                    color: fc.rpm > 0 ? (fc.boosted ? T.amber : T.ink) : T.ink3
                    rotation: glyph.angle
                }
                property real angle: 0
                FrameAnimation {
                    id: spin
                    running: glyph.speed > 0.5 && glyph.onScreen
                    onTriggered: {
                        var dt = Math.min(spin.frameTime, 0.1)
                        if (dt > 0) glyph.angle = (glyph.angle + glyph.speed * dt) % 360
                    }
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
                font { family: T.mono; pixelSize: 40; weight: Font.Light }
            }
            Text {
                text: "RPM"
                color: T.ink2
                anchors.baseline: rpmText.baseline
                font { family: T.mono; pixelSize: 12 }
            }
        }
        Text {
            text: fc.rpm === 0 ? "parado" : Math.round(fc.frac * 100) + " % del máximo"
            color: T.ink3
            font { family: T.mono; pixelSize: 11 }
        }

        Item { Layout.fillHeight: true }

        // Medidor horizontal de RPM.
        Item {
            Layout.fillWidth: true
            height: 10
            Rectangle { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter } height: 2; color: T.ruleHi }
            Rectangle {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                height: 2
                width: parent.width * fc.shownFrac
                color: fc.boosted ? T.amber : T.ink
            }
            Repeater {
                model: 11
                Rectangle {
                    required property int index
                    x: index / 10 * (parent.width - 1)
                    y: index % 5 === 0 ? 0 : 3
                    width: 1; height: index % 5 === 0 ? 10 : 4
                    color: index / 10 <= fc.shownFrac && fc.rpm > 0 ? (fc.boosted ? T.amber : T.ink2) : T.ruleHi
                }
            }
        }

        Item { Layout.preferredHeight: 18 }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Boost"
                color: T.ink2
                font { family: T.sans; pixelSize: 13; weight: Font.Medium }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: !fc.canBoost ? "requiere servicio"
                      : fader.value === 0 ? "auto" : Math.round(fader.value) + " %"
                color: fader.value > 0 && fc.canBoost ? T.amber : T.ink3
                font { family: T.mono; pixelSize: 11 }
            }
        }
        Fader {
            id: fader
            Layout.fillWidth: true
            enabled: fc.canBoost
            from: 0; to: 100; stepSize: 5
            fill: value > 0 ? T.amber : T.ink
            Binding on value { when: !fader.pressed; value: Math.round((fc.boost || 0) / 2.55 / 5) * 5; restoreMode: Binding.RestoreNone }
            onCommitted: v => fc.boostRequested(Math.round(v * 2.55))
        }
    }
}
