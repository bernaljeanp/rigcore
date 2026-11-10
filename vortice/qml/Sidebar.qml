import QtQuick
import QtQuick.Controls
import "Theme.js" as T
import "Icons.js" as Icons

Rectangle {
    id: sb
    property int current: 0
    signal navigate(int index)
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
                { icon: Icons.dashboard, name: "Panel", page: 0 },
                { icon: Icons.gamepad,   name: "Perfiles por juego", page: 1 },
                { icon: Icons.fan,       name: "Curvas de ventilador · pronto" },
                { icon: Icons.sparkles,  name: "Iluminación", page: 2 },
                { icon: Icons.sliders,   name: "Ajustes · pronto" }
            ]
            delegate: Item {
                id: nav
                required property var modelData
                required property int index
                readonly property bool active: modelData.page !== undefined && sb.current === modelData.page
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
                TapHandler { onTapped: if (nav.modelData.page !== undefined) sb.navigate(nav.modelData.page) }
                ToolTip.visible: hh.hovered
                ToolTip.delay: 400
                ToolTip.text: nav.modelData.name
            }
        }
    }
}
