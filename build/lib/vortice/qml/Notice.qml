import QtQuick
import "Theme.js" as T

// Aviso para cuando una función no está disponible en este equipo.
Item {
    id: n
    property string icon
    property string title
    property string text

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 16, 300)
        spacing: 8
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            path: n.icon; size: 22; color: T.ink3; stroke: 1.5
        }
        Item { width: 1; height: 4 }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: n.title
            color: T.ink
            wrapMode: Text.WordWrap
            font { family: T.sans; pixelSize: 15; weight: Font.Medium }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: n.text
            color: T.ink2
            wrapMode: Text.WordWrap
            lineHeight: 1.25
            font { family: T.sans; pixelSize: 13 }
        }
    }
}
