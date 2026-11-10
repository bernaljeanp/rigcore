import QtQuick

// Aviso centrado para cuando una función no está disponible en este equipo.
Item {
    id: n
    property string icon
    property string title
    property string text
    property color tint: "#9A9FB4"

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 16, 300)
        spacing: 10
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 52; height: 52; radius: 18
            color: Qt.rgba(n.tint.r, n.tint.g, n.tint.b, 0.1)
            border.color: Qt.rgba(n.tint.r, n.tint.g, n.tint.b, 0.25)
            Icon { anchors.centerIn: parent; path: n.icon; size: 24; color: n.tint }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: n.title
            color: "#E8EAF2"
            wrapMode: Text.WordWrap
            font { family: "Inter"; pixelSize: 15; weight: Font.DemiBold }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: n.text
            color: "#7E849A"
            wrapMode: Text.WordWrap
            lineHeight: 1.25
            font { family: "Inter"; pixelSize: 12 }
        }
    }
}
