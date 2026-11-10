import QtQuick
import "Theme.js" as T
import "Icons.js" as Icons

// Insignia de marca propia: nombre en mayúsculas con el color característico de la
// marca e icono genérico. No usa logos oficiales (son marcas registradas).
Item {
    id: b
    property string text
    property color tint: T.ink2
    property string icon: Icons.cpu
    implicitWidth: row.implicitWidth + 18
    implicitHeight: 22

    Chamfer {
        anchors.fill: parent
        cut: 6
        fill: Qt.rgba(b.tint.r, b.tint.g, b.tint.b, 0.12)
        stroke: Qt.rgba(b.tint.r, b.tint.g, b.tint.b, 0.55)
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5
        Icon {
            visible: b.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            path: b.icon; size: 12; stroke: 1.6; color: b.tint
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: b.text
            color: b.tint
            font { family: T.sans; pixelSize: 11; weight: Font.Bold; letterSpacing: 1.2; capitalization: Font.AllUppercase }
        }
    }
}
