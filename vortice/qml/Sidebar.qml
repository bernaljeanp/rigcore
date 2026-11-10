import QtQuick
import QtQuick.Controls
import "Icons.js" as Icons

Rectangle {
    id: sb
    property color accent: "#8C7CFF"
    property int current: 0
    width: 84
    color: Qt.rgba(1, 1, 1, 0.018)

    Rectangle {   // separador
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 1
        color: Qt.rgba(1, 1, 1, 0.06)
    }

    Logo {
        id: logo
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 24 }
        size: 42
    }

    Column {
        anchors { horizontalCenter: parent.horizontalCenter; top: logo.bottom; topMargin: 40 }
        spacing: 10
        Repeater {
            model: [
                { icon: Icons.dashboard, name: "Panel" },
                { icon: Icons.gamepad,   name: "Perfiles por juego · próximamente" },
                { icon: Icons.fan,       name: "Curvas de ventilador · próximamente" },
                { icon: Icons.sparkles,  name: "Iluminación · próximamente" },
                { icon: Icons.sliders,   name: "Ajustes · próximamente" }
            ]
            delegate: Item {
                id: nav
                required property var modelData
                required property int index
                readonly property bool active: sb.current === index
                width: 48; height: 48

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: nav.active ? Qt.rgba(sb.accent.r, sb.accent.g, sb.accent.b, 0.16)
                         : hh.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    border.color: nav.active ? Qt.rgba(sb.accent.r, sb.accent.g, sb.accent.b, 0.35) : "transparent"
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
                Rectangle {   // marcador lateral
                    visible: nav.active
                    x: -18; anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 20; radius: 2
                    color: sb.accent
                }
                Icon {
                    anchors.centerIn: parent
                    path: nav.modelData.icon
                    size: 20
                    color: nav.active ? Qt.lighter(sb.accent, 1.35) : hh.hovered ? "#D5D8E4" : "#6E7489"
                }
                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                ToolTip.visible: hh.hovered
                ToolTip.delay: 400
                ToolTip.text: nav.modelData.name
            }
        }
    }
}
