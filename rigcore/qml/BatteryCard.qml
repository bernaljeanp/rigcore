import QtQuick
import QtQuick.Layouts
import "Theme.js" as T
import "Icons.js" as Icons

Section {
    id: bc
    label: qsTr("Batería")

    property int capacity: 0
    property string status: ""
    property bool ac: false
    property var limit: null
    property bool firmwareLimit: false
    property var service: null
    property var health: null         // % de la capacidad de fábrica
    property var cycles: null
    property var designWh: null
    signal configure()

    source: firmwareLimit ? "dell-wmi-sysman" : (limit !== null && limit !== undefined ? "power_supply" : "")

    readonly property string statusText: status === "Charging" ? qsTr("Cargando")
        : status === "Full" ? qsTr("Completa")
        : status === "Not charging" ? qsTr("En pausa por el límite")
        : status === "Discharging" ? qsTr("Usando batería") : status

    readonly property var modeNames: ({ "Adaptive": qsTr("Adaptativa"), "Standard": qsTr("Estándar"),
        "Express": qsTr("Rápida"), "PrimAcUse": qsTr("Siempre enchufado"), "Custom": qsTr("Personalizada"),
        "Conservation": qsTr("Conservación"), "Limit80": qsTr("Hasta 80 %") })
    readonly property var stopAt: service && service.mode === "Custom" ? service.stop
                                : (limit !== null && limit !== undefined ? limit : null)
    readonly property string summary: service
        ? (service.mode === "Custom" && service.stop
            ? (service.start ? service.start + "–" + service.stop + " %" : qsTr("hasta ") + service.stop + " %")
            : (modeNames[service.mode] || service.mode || "—"))
        : firmwareLimit ? qsTr("en la BIOS") : qsTr("no disponible")

    property real shown: capacity
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: -bc.pad
        spacing: 0

        Row {
            spacing: 4
            Text {
                id: pct
                text: Math.round(bc.shown)
                color: T.ink
                font { family: T.display; pixelSize: 48; weight: Font.Medium }
            }
            Text {
                text: "%"
                color: T.ink2
                anchors.baseline: pct.baseline
                font { family: T.mono; pixelSize: 15 }
            }
        }
        Text {
            text: (bc.ac ? qsTr("Enchufado · ") : "") + bc.statusText
            color: T.ink2
            font { family: T.sans; pixelSize: 13 }
        }

        Item { Layout.preferredHeight: 18 }

        // Barra de carga con marca del límite.
        Item {
            Layout.fillWidth: true
            height: 34
            Rectangle { id: bar; y: 6; width: parent.width; height: 8; color: T.rule }
            Rectangle { y: 6; height: 8; width: bar.width * bc.shown / 100; color: T.ink }
            Rectangle {
                visible: bc.stopAt !== null
                x: bar.width * (bc.stopAt || 0) / 100 - 1
                y: 0; width: 2; height: 20
                color: hw.accent
            }
            Text {
                visible: bc.stopAt !== null
                x: Math.min(bar.width * (bc.stopAt || 0) / 100 - width / 2, bar.width - width)
                y: 22
                text: qsTr("límite ") + bc.stopAt
                color: hw.accent
                font { family: T.mono; pixelSize: 10 }
            }
        }

        Item { Layout.fillHeight: true }

        // Salud: cuánto conserva la batería de su capacidad original.
        RowLayout {
            visible: bc.health !== null
            Layout.fillWidth: true
            Layout.bottomMargin: 18
            spacing: 0
            Repeater {
                model: [
                    { k: qsTr("Salud"), v: bc.health, u: "%", hl: true },
                    { k: qsTr("Ciclos"), v: bc.cycles, u: "" },
                    { k: qsTr("De fábrica"), v: bc.designWh, u: "Wh" }
                ]
                delegate: Column {
                    required property var modelData
                    required property int index
                    visible: modelData.v !== null && modelData.v !== undefined
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        text: modelData.k
                        color: T.ink3
                        font { family: T.sans; pixelSize: 11; weight: Font.Medium; letterSpacing: 0.8; capitalization: Font.AllUppercase }
                    }
                    Row {
                        spacing: 3
                        Text {
                            id: hv
                            text: modelData.v === null || modelData.v === undefined ? "" : modelData.v
                            color: modelData.hl && modelData.v < 70 ? T.warn : T.ink
                            font { family: T.display; pixelSize: 22; weight: Font.Medium }
                        }
                        Text { text: modelData.u; color: T.ink2; anchors.baseline: hv.baseline; font { family: T.mono; pixelSize: 11 } }
                    }
                }
            }
        }

        // Fila de configuración (abre el panel de carga).
        Item {
            id: cfg
            Layout.fillWidth: true
            Layout.leftMargin: -bc.pad
            Layout.rightMargin: -bc.pad
            Layout.preferredHeight: 56
            readonly property bool live: bc.service !== null && bc.service !== undefined
            Rectangle { anchors.fill: parent; color: cfg.live && ch.hovered ? T.bgRaised : "transparent" }
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: T.rule }
            RowLayout {
                anchors { fill: parent; leftMargin: T.pad; rightMargin: T.pad }
                spacing: 10
                Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: qsTr("Límite de carga")
                        color: T.ink
                        font { family: T.sans; pixelSize: 14; weight: Font.Medium }
                    }
                    Text {
                        text: bc.summary + (cfg.live ? "" : qsTr(" · requiere servicio"))
                        color: T.ink3
                        font { family: T.mono; pixelSize: 11 }
                    }
                }
                Icon {
                    path: cfg.live ? "M9 18l6-6-6-6" : Icons.lock
                    size: 16; stroke: 1.6
                    color: cfg.live ? T.ink2 : T.ink3
                }
            }
            HoverHandler { id: ch; cursorShape: cfg.live ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { enabled: cfg.live; onTapped: bc.configure() }
        }
    }
}
