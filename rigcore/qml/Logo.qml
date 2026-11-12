import QtQuick

// Emblema de Rigcore: mando con turbina (ver tools/make_icon.py).
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
