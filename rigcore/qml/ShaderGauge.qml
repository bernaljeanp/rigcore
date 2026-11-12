import QtQuick
import "Theme.js" as T

// Arco dibujado por el shader gauge.frag (una pasada en la GPU, sin geometría en la CPU).
ShaderEffect {
    property real progress: 0
    property real thickness: 4
    property real inset: 30
    property real startAngle: Math.PI * 0.75
    property real sweep: Math.PI * 1.5
    property real ticks: 40
    property real majorEvery: 10
    property real glow: 0
    property real needle: 1
    property color valueColor: T.ink
    property color trackColor: T.ruleHi
    property color tickColor: Qt.rgba(0.6, 0.59, 0.56, 0.55)
    readonly property size res: Qt.size(width, height)

    fragmentShader: Qt.resolvedUrl("../shaders/gauge.frag.qsb")
}
