import QtQuick

// Indicador de temperatura de 270°. Lo pinta un shader: animar solo cambia `progress`.
Item {
    id: g
    property real value: 0
    property real minValue: 20
    property real maxValue: 100
    property color colorA: "#22D3EE"
    property color colorB: "#6366F1"
    property real thickness: 14

    // Animación suave entre lecturas: casi gratis porque solo cambia un uniform.
    property real shown: value
    Behavior on shown { SmoothedAnimation { velocity: 18; reversingMode: SmoothedAnimation.Sync } }
    Behavior on colorA { ColorAnimation { duration: 700 } }
    Behavior on colorB { ColorAnimation { duration: 700 } }

    ShaderGauge {
        // Lienzo más grande que el indicador para que el halo no se corte.
        anchors.fill: parent
        anchors.margins: -48
        progress: Math.max(0, Math.min(1, (g.shown - g.minValue) / (g.maxValue - g.minValue)))
        thickness: g.thickness
        inset: g.thickness + 14 + 48
        colorA: g.colorA
        colorB: g.colorB
    }
}
