import QtQuick
import "Theme.js" as T

// Indicador de temperatura de 270° con escala numerada. Lo pinta un shader:
// animar solo cambia `progress`.
Item {
    id: g
    property real value: 0
    property real minValue: 20
    property real maxValue: 100
    property bool dim: false          // gráfica en reposo

    property real shown: value
    Behavior on shown { SmoothedAnimation { velocity: 18; reversingMode: SmoothedAnimation.Sync } }
    readonly property color tint: dim ? T.ink3 : T.tempColor(shown)
    property color animTint: tint
    Behavior on animTint { ColorAnimation { duration: 400 } }

    readonly property real margin: 40   // espacio para los números de la escala
    readonly property real radius: Math.min(width, height) / 2 - margin - 16

    ShaderGauge {
        anchors.fill: parent
        progress: g.dim ? 0 : Math.max(0, Math.min(1, (g.shown - g.minValue) / (g.maxValue - g.minValue)))
        thickness: 4
        inset: g.margin + 16
        ticks: 40
        majorEvery: 10
        valueColor: g.animTint
    }

    // Números de la escala en las marcas mayores.
    Repeater {
        model: 5
        Text {
            required property int index
            readonly property real a: (135 + 270 * index / 4) * Math.PI / 180
            readonly property real rr: g.radius + 2 + 6 + 10 + 16
            x: g.width / 2 + Math.cos(a) * rr - width / 2
            y: g.height / 2 + Math.sin(a) * rr - height / 2
            text: g.minValue + index * (g.maxValue - g.minValue) / 4
            color: T.ink3
            font { family: T.mono; pixelSize: 11 }
        }
    }
}
