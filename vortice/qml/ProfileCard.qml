import QtQuick
import QtQuick.Layouts
import "Theme.js" as T
import "Icons.js" as Icons

// Selector de modo: filas con marca lateral ámbar en la activa. Teclas 1, 2, 3.
Section {
    id: pc
    label: qsTr("Modo")
    property string current: ""
    property bool available: true
    property string manager: ""
    property var details: ({})
    signal picked(string name)

    readonly property var modes: [
        { id: "power-saver", name: qsTr("Silencioso"),  desc: qsTr("Ventiladores al mínimo, más autonomía") },
        { id: "balanced",    name: qsTr("Equilibrado"), desc: qsTr("Para el día a día") },
        { id: "performance", name: qsTr("Rendimiento"), desc: qsTr("Toda la potencia para jugar") }
    ]

    Notice {
        anchors.fill: parent
        visible: !pc.available
        icon: Icons.gauge
        title: pc.manager ? qsTr("Tu sistema usa ") + pc.manager : qsTr("Modos no disponibles")
        text: pc.manager
              ? pc.manager + qsTr(" gestiona la energía de este equipo. Cambia de modo desde ") + pc.manager + qsTr(" para no interferir con él.")
              : qsTr("Instala power-profiles-daemon (viene por defecto en KDE y GNOME) para cambiar de modo desde aquí.")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: -pc.pad
        anchors.rightMargin: -pc.pad
        visible: pc.available
        spacing: 0

        Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
        Repeater {
            model: pc.modes
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool active: pc.current === modelData.id
                Layout.fillWidth: true
                Layout.preferredHeight: 68

                Rectangle {
                    anchors.fill: parent
                    color: row.active ? T.bgRaised : (hov.hovered ? Qt.rgba(1, 1, 1, 0.018) : "transparent")
                }
                Rectangle {   // marca de selección
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 3
                    color: hw.accent
                    opacity: row.active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1; color: T.rule
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: T.pad; rightMargin: T.pad }
                    spacing: 12
                    Column {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: row.modelData.name
                            color: row.active ? T.ink : T.ink2
                            font { family: T.sans; pixelSize: 17; weight: row.active ? Font.DemiBold : Font.Medium }
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.desc
                            elide: Text.ElideRight
                            color: T.ink3
                            font { family: T.sans; pixelSize: 13 }
                        }
                    }
                    Rectangle {   // atajo de teclado
                        width: 22; height: 22; radius: 2
                        color: "transparent"
                        border.color: row.active ? hw.accent : T.ruleHi
                        Text {
                            anchors.centerIn: parent
                            text: row.index + 1
                            color: row.active ? hw.accent : T.ink3
                            font { family: T.mono; pixelSize: 11 }
                        }
                    }
                }
                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: if (!row.active) pc.picked(row.modelData.id) }
            }
        }
        Item { Layout.fillHeight: true }

        // Qué hay debajo del modo (datos reales del sistema).
        Text {
            Layout.leftMargin: T.pad
            Layout.bottomMargin: 8
            text: qsTr("Debajo de este modo")
            color: T.ink3
            font { family: T.sans; pixelSize: 11; weight: Font.Medium; letterSpacing: 0.8; capitalization: Font.AllUppercase }
        }
        Repeater {
            model: [
                { k: qsTr("tuned"), v: pc.details.tuned },
                { k: qsTr("firmware"), v: pc.details.firmware ? pc.details.firmware + "  (" + pc.details.firmwareDriver + ")" : undefined },
                { k: qsTr("servicio"), v: qsTr("power-profiles") }
            ]
            delegate: RowLayout {
                required property var modelData
                visible: modelData.v !== undefined && modelData.v !== ""
                Layout.fillWidth: true
                Layout.leftMargin: T.pad
                Layout.rightMargin: T.pad
                Layout.bottomMargin: 4
                Text { text: modelData.k; color: T.ink3; Layout.preferredWidth: 72; font { family: T.mono; pixelSize: 11 } }
                Text { text: modelData.v || ""; color: T.ink2; elide: Text.ElideRight; Layout.fillWidth: true; font { family: T.mono; pixelSize: 11 } }
            }
        }
    }
}
