import QtQuick
import "Theme.js" as T

// Interruptor de instrumento: carril rectangular y tirador cuadrado; ámbar al activarse.
Item {
    id: tg
    property bool checked: false
    property string label
    signal toggled(bool on)
    implicitWidth: row.implicitWidth
    implicitHeight: 24

    Row {
        id: row
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            width: 34; height: 18; radius: 2
            color: "transparent"
            border.color: tg.checked ? hw.accent : T.ruleHi
            Rectangle {
                width: 12; height: 12; radius: 1
                y: 3
                x: tg.checked ? parent.width - width - 3 : 3
                color: tg.checked ? hw.accent : T.ink3
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            visible: tg.label !== ""
            text: tg.label
            color: tg.checked ? T.ink : T.ink2
            anchors.verticalCenter: parent.verticalCenter
            font { family: T.sans; pixelSize: 14 }
        }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tg.toggled(!tg.checked) }
}
