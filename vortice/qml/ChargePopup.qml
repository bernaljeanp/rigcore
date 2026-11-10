import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "Icons.js" as Icons

// Panel de configuración de carga de la batería.
Popup {
    id: pop
    property var battery: null           // estado del servicio
    signal apply(string mode, int start, int stop)

    readonly property var info: ({
        "Adaptive":  ["Adaptativa", "Ajusta la carga según cómo usas el equipo"],
        "Standard":  ["Estándar", "Carga completa a ritmo normal"],
        "Express":   ["Rápida", "Carga más deprisa, desgasta más la batería"],
        "PrimAcUse": ["Siempre enchufado", "Ideal si casi nunca usas la batería"],
        "Custom":    ["Personalizada", "Tú eliges cuándo empieza y cuándo para"]
    })
    property string mode: ""
    property int start: 50
    property int stop: 80

    onAboutToShow: {
        if (!battery) return
        mode = battery.mode || "Custom"
        start = battery.start || 50
        stop = battery.stop || 80
    }

    modal: true
    dim: true
    anchors.centerIn: Overlay.overlay
    width: 460
    padding: 26
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle { color: Qt.rgba(0.02, 0.02, 0.04, 0.6) }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 260; easing.type: Easing.OutBack }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 150 } }

    background: Rectangle {
        radius: 26
        color: "#12131A"
        border.color: Qt.rgba(1, 1, 1, 0.1)
        Rectangle {
            anchors { fill: parent; margins: 1 }
            radius: 25
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.29, 0.87, 0.5, 0.08) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 1; shadowOpacity: 0.7; shadowVerticalOffset: 18 }
    }

    contentItem: ColumnLayout {
        spacing: 16

        RowLayout {
            spacing: 12
            Rectangle {
                width: 38; height: 38; radius: 12
                color: Qt.rgba(0.29, 0.87, 0.5, 0.14)
                border.color: Qt.rgba(0.29, 0.87, 0.5, 0.3)
                Icon { anchors.centerIn: parent; path: Icons.battery; size: 18; color: "#4ADE80" }
            }
            Column {
                Layout.fillWidth: true
                Text {
                    text: "Carga de la batería"
                    color: "#F5F6FA"
                    font { family: "Space Grotesk"; pixelSize: 20; weight: Font.Medium }
                }
                Text {
                    text: "Se guarda en el firmware: se mantiene aunque apagues o cambies de sistema"
                    color: "#7E849A"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    font { family: "Inter"; pixelSize: 12 }
                }
            }
        }

        Column {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: pop.battery ? pop.battery.modes : []
                delegate: Rectangle {
                    id: opt
                    required property string modelData
                    readonly property bool active: pop.mode === modelData
                    width: parent.width; height: 54; radius: 15
                    color: active ? Qt.rgba(0.29, 0.87, 0.5, 0.12)
                         : oh.hovered ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.02)
                    border.color: active ? Qt.rgba(0.29, 0.87, 0.5, 0.45) : Qt.rgba(1, 1, 1, 0.05)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: (pop.info[opt.modelData] || [opt.modelData])[0]
                                color: opt.active ? "#FFFFFF" : "#DADDE8"
                                font { family: "Inter"; pixelSize: 14; weight: Font.DemiBold }
                            }
                            Text {
                                text: (pop.info[opt.modelData] || ["", ""])[1]
                                color: "#7E849A"
                                font { family: "Inter"; pixelSize: 11 }
                            }
                        }
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: "transparent"
                            border.width: 1.5
                            border.color: opt.active ? "#4ADE80" : Qt.rgba(1, 1, 1, 0.18)
                            Rectangle {
                                anchors.centerIn: parent
                                width: opt.active ? 8 : 0; height: width; radius: width / 2
                                color: "#4ADE80"
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                            }
                        }
                    }
                    HoverHandler { id: oh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: pop.mode = opt.modelData }
                }
            }
        }

        // Umbrales del modo personalizado.
        ColumnLayout {
            Layout.fillWidth: true
            visible: pop.mode === "Custom" && pop.battery && pop.battery.stop !== null
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Empieza a cargar al"
                    color: "#9A9FB4"
                    font { family: "Inter"; pixelSize: 12 }
                }
                Text {
                    text: range.first + " %"
                    color: "#4ADE80"
                    font { family: "JetBrains Mono"; pixelSize: 12; weight: Font.DemiBold }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Para al"
                    color: "#9A9FB4"
                    font { family: "Inter"; pixelSize: 12 }
                }
                Text {
                    text: range.second + " %"
                    color: "#22D3EE"
                    font { family: "JetBrains Mono"; pixelSize: 12; weight: Font.DemiBold }
                }
            }
            RangeGlowSlider {
                id: range
                Layout.fillWidth: true
                from: 50; to: 100
                firstMin: pop.battery && pop.battery.startRange ? pop.battery.startRange[0] : 50
                firstMax: pop.battery && pop.battery.startRange ? pop.battery.startRange[1] : 95
                secondMin: pop.battery && pop.battery.stopRange ? pop.battery.stopRange[0] : 55
                secondMax: pop.battery && pop.battery.stopRange ? pop.battery.stopRange[1] : 100
                first: pop.start
                second: pop.stop
                onFirstChanged: pop.start = first
                onSecondChanged: pop.stop = second
            }
            Text {
                text: "Recomendado para alargar la vida de la batería: 50 – 80 %"
                color: "#6E7489"
                font { family: "Inter"; pixelSize: 11 }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 10
            Item { Layout.fillWidth: true }
            component Btn: Rectangle {
                id: b
                property string label
                property bool primary: false
                signal clicked()
                implicitWidth: bt.implicitWidth + 36; implicitHeight: 42; radius: 14
                color: primary ? (bh.hovered ? "#5BE590" : "#4ADE80") : (bh.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                border.color: primary ? "transparent" : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color { ColorAnimation { duration: 140 } }
                Text {
                    id: bt
                    anchors.centerIn: parent
                    text: b.label
                    color: b.primary ? "#06240F" : "#DADDE8"
                    font { family: "Inter"; pixelSize: 13; weight: Font.DemiBold }
                }
                HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: b.clicked() }
            }
            Btn { label: "Cancelar"; onClicked: pop.close() }
            Btn {
                label: "Aplicar"
                primary: true
                onClicked: { pop.apply(pop.mode, pop.start, pop.stop); pop.close() }
            }
        }
    }
}
