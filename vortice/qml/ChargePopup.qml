import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as T

// Panel de configuración de carga de la batería.
Popup {
    id: pop
    property var battery: null
    signal apply(string mode, int start, int stop)

    readonly property var info: ({
        "Adaptive":  [qsTr("Adaptativa"), qsTr("Ajusta la carga según cómo usas el equipo")],
        "Standard":  [qsTr("Estándar"), qsTr("Carga completa a ritmo normal")],
        "Express":   [qsTr("Rápida"), qsTr("Carga más deprisa; desgasta más la batería")],
        "PrimAcUse": [qsTr("Siempre enchufado"), qsTr("Para equipos que casi nunca usan la batería")],
        "Custom":    [qsTr("Personalizada"), qsTr("Tú eliges cuándo empieza y cuándo para")],
        "Conservation": [qsTr("Conservación"), qsTr("Lenovo: mantiene la batería en torno al 60 %")],
        "Limit80":   [qsTr("Limitar al 80 %"), qsTr("Acer: deja de cargar al 80 %")]
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
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    Overlay.modal: Rectangle { color: Qt.rgba(0.04, 0.04, 0.05, 0.72) }

    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140 } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 100 } }

    background: Rectangle { color: T.bg; border.color: T.ruleHi; radius: 2 }

    contentItem: ColumnLayout {
        spacing: 0

        Column {
            Layout.fillWidth: true
            Layout.margins: T.pad
            spacing: 4
            Text {
                text: qsTr("Carga de la batería")
                color: T.ink
                font { family: T.sans; pixelSize: 20; weight: Font.DemiBold }
            }
            Text {
                width: parent.width
                text: qsTr("Se guarda en el firmware: se mantiene aunque apagues o cambies de sistema.")
                color: T.ink2
                wrapMode: Text.WordWrap
                font { family: T.sans; pixelSize: 13 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
        Repeater {
            model: pop.battery ? pop.battery.modes : []
            delegate: Item {
                id: opt
                required property string modelData
                readonly property bool active: pop.mode === modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                Rectangle { anchors.fill: parent; color: opt.active ? T.bgRaised : (oh.hovered ? Qt.rgba(1, 1, 1, 0.018) : "transparent") }
                Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 3; color: hw.accent; visible: opt.active }
                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: T.rule }
                Column {
                    anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text {
                        text: (pop.info[opt.modelData] || [opt.modelData])[0]
                        color: opt.active ? T.ink : T.ink2
                        font { family: T.sans; pixelSize: 15; weight: opt.active ? Font.DemiBold : Font.Medium }
                    }
                    Text {
                        text: (pop.info[opt.modelData] || ["", ""])[1]
                        color: T.ink3
                        font { family: T.sans; pixelSize: 12 }
                    }
                }
                HoverHandler { id: oh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: pop.mode = opt.modelData }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: T.pad
            visible: pop.mode === "Custom" && !!pop.battery && pop.battery.stop !== null
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Empieza a cargar al"); color: T.ink2; font { family: T.sans; pixelSize: 13 } }
                Text { text: range.first + " %"; color: T.ink; font { family: T.mono; pixelSize: 13 } }
                Item { Layout.fillWidth: true }
                Text { text: qsTr("Para al"); color: T.ink2; font { family: T.sans; pixelSize: 13 } }
                Text { text: range.second + " %"; color: hw.accent; font { family: T.mono; pixelSize: 13 } }
            }
            RangeFader {
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
                text: qsTr("Para alargar la vida de la batería: 50–80 %")
                color: T.ink3
                font { family: T.mono; pixelSize: 11 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 16
            spacing: 8
            Item { Layout.fillWidth: true }
            component Btn: Rectangle {
                id: b
                property string label
                property bool primary: false
                signal clicked()
                implicitWidth: bt.implicitWidth + 32; implicitHeight: 38
                color: "transparent"
                Chamfer {
                    anchors.fill: parent
                    fill: b.primary ? (bh.hovered ? Qt.lighter(hw.accent, 1.15) : hw.accent) : (bh.hovered ? T.bgRaised : "transparent")
                    stroke: b.primary ? "transparent" : T.ruleHi
                }
                Text {
                    id: bt
                    anchors.centerIn: parent
                    text: b.label
                    color: b.primary ? T.bg : T.ink
                    font { family: T.sans; pixelSize: 14; weight: Font.DemiBold }
                }
                HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: b.clicked() }
            }
            Btn { label: qsTr("Cancelar"); onClicked: pop.close() }
            Btn { label: qsTr("Aplicar"); primary: true; onClicked: { pop.apply(pop.mode, pop.start, pop.stop); pop.close() } }
        }
    }
}
