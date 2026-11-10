import QtQuick

// Emblema de Vórtice: remolino de tres aspas con ojo central.
Image {
    id: logo
    property real size: 40
    width: size
    height: size
    source: "icon.svg"
    sourceSize: Qt.size(size * 2, size * 2)
    smooth: true
    mipmap: true
}
