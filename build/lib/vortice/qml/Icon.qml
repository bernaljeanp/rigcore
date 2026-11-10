import QtQuick
import QtQuick.Shapes

// Icono vectorial de trazo, nítido a cualquier tamaño.
Item {
    id: root
    property string path
    property color color: "#E8EAF2"
    property real size: 20
    property real stroke: 1.8

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24; height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.stroke * 24 / root.size
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.path }
        }
    }
}
