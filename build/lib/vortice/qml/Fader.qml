import QtQuick
import "Theme.js" as T

// Fader de instrumento: pista fina, relleno sólido y tirador rectangular.
// Emite committed() al soltar, no en cada píxel, para no saturar el firmware.
Item {
    id: s
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property color fill: T.ink
    readonly property bool pressed: drag.active || tap.pressed
    signal committed(real value)

    implicitHeight: 26
    opacity: enabled ? 1 : 0.35

    readonly property real frac: (value - from) / (to - from)

    function setFromX(x) {
        var f = Math.max(0, Math.min(1, (x - knob.width / 2) / (width - knob.width)))
        value = Math.round((from + f * (to - from)) / stepSize) * stepSize
    }

    // Marcas cada 25 %.
    Repeater {
        model: 5
        Rectangle {
            required property int index
            x: knob.width / 2 + index / 4 * (s.width - knob.width) - 0.5
            y: s.height / 2 + 6
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
        anchors { left: track.left; verticalCenter: track.verticalCenter }
        height: 2
        width: knob.x + knob.width / 2
        color: s.fill
    }
    Rectangle {
        id: knob
        width: 6; height: 18; radius: 1
        y: (s.height - height) / 2
        x: s.frac * (s.width - width)
        color: s.pressed || hov.hovered ? "#FFFFFF" : T.ink
        Behavior on x { enabled: !s.pressed; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: tap
        onTapped: (ev) => { s.setFromX(ev.position.x); s.committed(s.value) }
    }
    DragHandler {
        id: drag
        target: null
        yAxis.enabled: false
        onCentroidChanged: if (active) s.setFromX(centroid.position.x)
        onActiveChanged: if (!active) s.committed(s.value)
    }
}
