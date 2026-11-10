import QtQuick
import QtQuick.Controls
import "Theme.js" as T
import "Icons.js" as Icons

Rectangle {
    id: sb
    property int current: 0
    width: 60
    color: T.bg

    Logo {
        id: logo
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 18 }
        size: 30
    }

    Column {
        anchors { left: parent.left; right: parent.right; top: logo.bottom; topMargin: 28 }
        Repeater {
            model: [
                { icon: Icons.dashboard, name: "Panel" },
                { icon: Icons.gamepad,   name: "Perfiles por juego · pronto" },
                { icon: Icons.fan,       name: "Curvas de ventilador · pronto" },
                { icon: Icons.sparkles,  name: "Iluminación · pronto" },
                { icon: Icons.sliders,   name: "Ajustes · pronto" }
            ]
            delegate: Item {
                id: nav
                required property var modelData
                required property int index
                readonly property bool active: sb.current === index
                width: sb.width; height: 52

                Rectangle {
                    anchors.fill: parent
                    color: hh.hovered && !nav.active ? Qt.rgba(1, 1, 1, 0.02) : "transparent"
                }
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 14; bottomMargin: 14 }
                    width: 2
                    color: T.amber
                    visible: nav.active
                }
                Icon {
                    anchors.centerIn: parent
                    path: nav.modelData.icon
                    size: 20; stroke: 1.6
                    color: nav.active ? T.ink : hh.hovered ? T.ink2 : T.ink3
                }
                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                ToolTip.visible: hh.hovered
                ToolTip.delay: 400
                ToolTip.text: nav.modelData.name
            }
        }
    }
}
