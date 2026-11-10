import QtQuick
import QtQuick.Effects

// Deslizador doble (inicio / fin) con separación mínima entre tiradores.
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
    property color colorA: "#4ADE80"
    property color colorB: "#22D3EE"
    implicitHeight: 34

    function px(v) { return (v - from) / (to - from) * (width - 20) }
    function val(x) { return Math.round(from + Math.max(0, Math.min(1, (x - 10) / (width - 20))) * (to - from)) }

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                  leftMargin: 10; rightMargin: 10 }
        height: 6; radius: 3
        color: Qt.rgba(1, 1, 1, 0.07)
    }
    Rectangle {
        id: fill
        x: 10 + r.px(r.first); width: r.px(r.second) - r.px(r.first)
        anchors.verticalCenter: track.verticalCenter
        height: 6; radius: 3
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: r.colorA }
            GradientStop { position: 1; color: r.colorB }
        }
    }
    MultiEffect {
        source: fill; anchors.fill: fill
        blurEnabled: true; blur: 0.8; blurMax: 16; opacity: 0.8
    }

    component Knob: Rectangle {
        id: k
        property bool isFirst
        property color glow
        width: 20; height: 20; radius: 10
        y: (r.height - height) / 2
        color: "#FFFFFF"
        scale: dh.active ? 1.2 : hh.hovered ? 1.1 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: k.glow; shadowBlur: 0.8; shadowOpacity: 0.9 }
        HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
        DragHandler {
            id: dh
            target: null
            yAxis.enabled: false
            onCentroidChanged: {
                if (!active) return
                var p = k.mapToItem(r, centroid.position.x, 0).x
                var v = r.val(p)
                if (k.isFirst) r.first = Math.max(r.firstMin, Math.min(v, r.firstMax, r.second - r.minGap))
                else r.second = Math.min(r.secondMax, Math.max(v, r.secondMin, r.first + r.minGap))
            }
        }
    }

    Knob { isFirst: true; glow: r.colorA; x: r.px(r.first) }
    Knob { isFirst: false; glow: r.colorB; x: r.px(r.second) }
}
