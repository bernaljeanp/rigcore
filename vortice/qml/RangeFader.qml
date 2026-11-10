import QtQuick
import "Theme.js" as T

// Fader doble (inicio / fin de carga) con separación mínima entre tiradores.
Item {
    id: r
    property real from: 50
    property real to: 100
    property real first: 50
    property real second: 80
    property real minGap: 5
    property real firstMin: from
    property real firstMax: to
    property real secondMin: from
    property real secondMax: to
    implicitHeight: 30

    function px(v) { return (v - from) / (to - from) * (width - 6) }
    function val(x) { return Math.round(from + Math.max(0, Math.min(1, (x - 3) / (width - 6))) * (to - from)) }

    Repeater {   // marcas cada 10 %
        model: Math.round((r.to - r.from) / 10) + 1
        Rectangle {
            required property int index
            x: 3 + r.px(r.from + index * 10) - 0.5
            y: r.height / 2 + 6
            width: 1; height: 4
            color: T.ruleHi
        }
    }
    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 2
        color: T.ruleHi
    }
    Rectangle {
        x: 3 + r.px(r.first); width: r.px(r.second) - r.px(r.first)
        anchors.verticalCenter: track.verticalCenter
        height: 2
        color: T.amber
    }

    component Knob: Rectangle {
        id: k
        property bool isFirst
        width: 6; height: 18; radius: 1
        y: (r.height - height) / 2
        color: dh.active || hh.hovered ? "#FFFFFF" : T.ink
        HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
        DragHandler {
            id: dh
            target: null
            yAxis.enabled: false
            onCentroidChanged: {
                if (!active) return
                var v = r.val(k.mapToItem(r, centroid.position.x, 0).x)
                if (k.isFirst) r.first = Math.max(r.firstMin, Math.min(v, r.firstMax, r.second - r.minGap))
                else r.second = Math.min(r.secondMax, Math.max(v, r.secondMin, r.first + r.minGap))
            }
        }
    }
    Knob { isFirst: true; x: r.px(r.first) }
    Knob { isFirst: false; x: r.px(r.second) }
}
