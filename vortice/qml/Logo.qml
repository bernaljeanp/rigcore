import QtQuick

// Emblema de Vórtice (escudo biselado con aspas en espiral).
Image {
    id: logo
    property real size: 40
    width: size
    height: size * 1.0
    source: "icon.svg"
    sourceSize: Qt.size(size * 2, size * 2)
    smooth: true
    mipmap: true
}
