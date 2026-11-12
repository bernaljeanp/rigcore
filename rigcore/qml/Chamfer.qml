import QtQuick
import QtQuick.Shapes

// Rectángulo con dos esquinas cortadas en ángulo (arriba a la derecha y abajo a la
// izquierda), como el chasis de un portátil gaming.
Shape {
    id: c
    property color fill: "transparent"
    property color stroke: "transparent"
    property real cut: 7
    property real strokeWidth: 1
    readonly property real h: strokeWidth / 2

    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        fillColor: c.fill
        strokeColor: c.stroke
        strokeWidth: c.strokeWidth
        joinStyle: ShapePath.MiterJoin
        startX: c.h; startY: c.h
        PathLine { x: c.width - c.cut; y: c.h }
        PathLine { x: c.width - c.h; y: c.cut }
        PathLine { x: c.width - c.h; y: c.height - c.h }
        PathLine { x: c.cut; y: c.height - c.h }
        PathLine { x: c.h; y: c.height - c.cut }
        PathLine { x: c.h; y: c.h }
    }
}
