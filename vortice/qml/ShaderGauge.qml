import QtQuick

// Arco dibujado por el shader gauge.frag (una pasada en la GPU, sin geometría en la CPU).
ShaderEffect {
    property real progress: 0
    property real thickness: 14
    property real inset: 28
    property real startAngle: Math.PI * 0.75
    property real sweep: Math.PI * 1.5
    property real ticks: 54
    property real glow: 1
    property color colorA: "#22D3EE"
    property color colorB: "#6366F1"
    readonly property size res: Qt.size(width, height)

    fragmentShader: Qt.resolvedUrl("../shaders/gauge.frag.qsb")
}
