import QtQuick
import QtQuick.Effects

// Deslizador con relleno en degradado y tirador luminoso.
// Emite committed() al soltar (no en cada píxel) para no saturar el firmware.
Item {
    id: s
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property color colorA: "#38BDF8"
    property color colorB: "#8C7CFF"
    readonly property bool pressed: drag.active || tap.pressed
    signal committed(real value)

    implicitHeight: 28
    opacity: enabled ? 1 : 0.35
    Behavior on opacity { NumberAnimation { duration: 200 } }

    readonly property real frac: (value - from) / (to - from)

    function setFromX(x) {
        var f = Math.max(0, Math.min(1, (x - knob.width / 2) / (width - knob.width)))
        var v = from + f * (to - from)
        value = Math.round(v / stepSize) * stepSize
    }

    Rectangle {   // pista
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 6; radius: 3
        color: Qt.rgba(1, 1, 1, 0.07)
    }
    Rectangle {   // relleno
        id: fill
        anchors { left: track.left; verticalCenter: track.verticalCenter }
        height: 6; radius: 3
        width: knob.x + knob.width / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: s.colorA }
            GradientStop { position: 1; color: s.colorB }
        }
    }
    MultiEffect {   // halo del relleno
        source: fill
        anchors.fill: fill
        visible: s.frac > 0.01
        blurEnabled: true; blur: 0.8; blurMax: 16
        opacity: 0.8
    }

    Rectangle {
        id: knob
        width: 18; height: 18; radius: 9
        y: (s.height - height) / 2
        x: s.frac * (s.width - width)
        color: "#FFFFFF"
        scale: s.pressed ? 1.2 : hov.hovered ? 1.1 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
        Behavior on x { enabled: !s.pressed; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.centerIn: parent
            width: 6; height: 6; radius: 3
            color: s.colorB
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: s.colorB
            shadowBlur: 0.8
            shadowOpacity: 0.9
        }
    }

    HoverHandler { id: hov; enabled: s.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler {
        id: tap
        enabled: s.enabled
        onTapped: (ev) => { s.setFromX(ev.position.x); s.committed(s.value) }
    }
    DragHandler {
        id: drag
        enabled: s.enabled
        target: null
        xAxis.enabled: true; yAxis.enabled: false
        onCentroidChanged: if (active) s.setFromX(centroid.position.x)
        onActiveChanged: if (!active) s.committed(s.value)
    }
}
