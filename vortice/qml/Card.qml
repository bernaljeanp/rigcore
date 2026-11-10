import QtQuick
import QtQuick.Layouts

// Superficie de cristal: base translúcida, brillo superior y borde fino.
Rectangle {
    id: card
    default property alias content: body.data
    property alias headerRight: right.data
    property string title
    property string icon
    property color accent: "#8C7CFF"
    property real pad: 22

    radius: 24
    color: Qt.rgba(1, 1, 1, 0.032)
    border.color: Qt.rgba(1, 1, 1, 0.075)
    border.width: 1

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: Math.min(parent.height * 0.55, 180)
        radius: card.radius - 1
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.045) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    // Línea de luz en el borde superior.
    Rectangle {
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width: parent.width * 0.5; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.16) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    RowLayout {
        id: header
        visible: card.title !== ""
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: card.pad; rightMargin: card.pad; topMargin: card.pad - 2 }
        spacing: 10
        Rectangle {
            visible: card.icon !== ""
            width: 30; height: 30; radius: 10
            color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.13)
            border.color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.25)
            Icon { anchors.centerIn: parent; path: card.icon; size: 16; color: card.accent }
        }
        Text {
            text: card.title.toUpperCase()
            color: "#9A9FB4"
            font { family: "Inter"; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 1.6 }
        }
        Item { Layout.fillWidth: true }
        Row { id: right; spacing: 8 }
    }

    Item {
        id: body
        anchors { fill: parent; margins: card.pad
                  topMargin: card.title !== "" ? card.pad + 46 : card.pad }
    }
}
