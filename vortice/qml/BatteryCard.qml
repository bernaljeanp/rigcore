import QtQuick
import QtQuick.Layouts
import "Icons.js" as Icons

Card {
    id: bc
    title: "Batería"
    icon: Icons.battery
    accent: "#4ADE80"
    pad: 20

    property int capacity: 0
    property string status: ""
    property bool ac: false
    property var limit: null
    property bool firmwareLimit: false
    property var service: null        // estado de batería desde el servicio
    signal configure()

    readonly property var modeNames: ({ "Adaptive": "Adaptativa", "Standard": "Estándar",
        "Express": "Rápida", "PrimAcUse": "Siempre enchufado", "Custom": "Personalizada" })
    readonly property string summary: service
        ? (service.mode === "Custom" && service.stop
            ? (service.start ? service.start + " – " + service.stop + " %" : "Hasta " + service.stop + " %")
            : (modeNames[service.mode] || service.mode || "—"))
        : firmwareLimit ? "En la BIOS · requiere servicio" : "No disponible"

    readonly property string statusText: status === "Charging" ? "Cargando"
        : status === "Full" ? "Completa"
        : status === "Not charging" ? "En pausa · límite de carga"
        : status === "Discharging" ? "Usando batería" : status

    property real shown: capacity
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Row {
            spacing: 4
            Text {
                id: pct
                text: Math.round(bc.shown)
                color: "#F5F6FA"
                font { family: "Space Grotesk"; pixelSize: 46; weight: Font.Medium }
            }
            Text {
                text: "%"
                color: "#7E849A"
                anchors.baseline: pct.baseline
                font { family: "Space Grotesk"; pixelSize: 18; weight: Font.Medium }
            }
        }

        RowLayout {
            spacing: 8
            Icon { path: bc.ac ? Icons.plug : Icons.battery; size: 14; color: "#4ADE80" }
            Text {
                text: bc.statusText
                color: "#B4B9CB"
                font { family: "Inter"; pixelSize: 12; weight: Font.Medium }
            }
        }

        // Barra segmentada.
        Item {
            Layout.fillWidth: true
            height: 14
            Row {
                id: segs
                anchors.fill: parent
                spacing: 3
                Repeater {
                    model: 20
                    Rectangle {
                        required property int index
                        width: (segs.width - 19 * segs.spacing) / 20
                        height: segs.height
                        radius: 3
                        readonly property bool on: (index + 1) * 5 <= bc.shown + 0.01
                        color: on ? Qt.hsla(0.36 - (19 - index) * 0.004, 0.75, 0.55, 1)
                                  : Qt.rgba(1, 1, 1, 0.06)
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            id: chargeBtn
            Layout.fillWidth: true
            height: 50; radius: 14
            readonly property bool live: bc.service !== null && bc.service !== undefined
            color: live && ch.hovered ? Qt.rgba(0.29, 0.87, 0.5, 0.1) : Qt.rgba(1, 1, 1, 0.03)
            border.color: live && ch.hovered ? Qt.rgba(0.29, 0.87, 0.5, 0.4) : Qt.rgba(1, 1, 1, 0.06)
            Behavior on color { ColorAnimation { duration: 160 } }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 10
                Icon { path: chargeBtn.live ? Icons.sliders : Icons.lock; size: 14
                       color: chargeBtn.live ? "#4ADE80" : "#7E849A" }
                Column {
                    Layout.fillWidth: true
                    Text {
                        text: "Límite de carga"
                        color: "#DADDE8"
                        font { family: "Inter"; pixelSize: 12; weight: Font.DemiBold }
                    }
                    Text {
                        text: bc.summary
                        color: "#7E849A"
                        font { family: "Inter"; pixelSize: 11 }
                    }
                }
                Text {
                    visible: chargeBtn.live
                    text: "›"
                    color: "#9A9FB4"
                    font { family: "Inter"; pixelSize: 20 }
                }
            }
            HoverHandler { id: ch; cursorShape: chargeBtn.live ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { enabled: chargeBtn.live; onTapped: bc.configure() }
        }
    }
}
