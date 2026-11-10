import QtQuick
import QtQuick.Layouts
import "Theme.js" as T

// Zona del panel. No es una tarjeta: las divisiones las dibuja la rejilla de 1 px.
Rectangle {
    id: sec
    default property alias content: body.data
    property alias headerRight: right.data
    property string label
    property string source          // de dónde sale el dato (sensor / driver)
    property real pad: T.pad

    color: T.bg

    RowLayout {
        id: header
        visible: sec.label !== ""
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: sec.pad; rightMargin: sec.pad; topMargin: 16 }
        spacing: 10
        Text {
            text: sec.label
            color: T.ink2
            font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase }
        }
        Text {
            visible: sec.source !== ""
            text: sec.source
            color: T.ink3
            elide: Text.ElideRight
            Layout.fillWidth: true
            font { family: T.mono; pixelSize: 11 }
        }
        Item { visible: sec.source === ""; Layout.fillWidth: true }
        Row { id: right; spacing: 14 }
    }

    Item {
        id: body
        anchors { fill: parent; margins: sec.pad; topMargin: sec.label !== "" ? 48 : sec.pad }
    }
}
