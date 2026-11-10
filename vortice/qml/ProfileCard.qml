import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "Icons.js" as Icons

// Selector de modo con indicador deslizante.
Card {
    id: pc
    title: "Modo de rendimiento"
    icon: Icons.gauge

    property string current: ""
    property bool available: true
    property string manager: ""     // "TLP", "auto-cpufreq"...
    signal picked(string name)

    readonly property var modes: [
        { id: "power-saver", name: "Silencioso",  desc: "Ventiladores al mínimo, máxima autonomía", icon: Icons.leaf,  color: "#2FD3B0" },
        { id: "balanced",    name: "Equilibrado", desc: "El punto justo para el día a día",          icon: Icons.activity, color: "#8C7CFF" },
        { id: "performance", name: "Rendimiento", desc: "Toda la potencia para jugar",               icon: Icons.flame, color: "#FF6B3D" }
    ]
    readonly property int index: Math.max(0, modes.findIndex(m => m.id === current))

    Notice {
        anchors.fill: parent
        z: 10
        visible: !pc.available
        icon: Icons.gauge
        title: pc.manager ? "Tu sistema usa " + pc.manager : "Modos no disponibles"
        text: pc.manager
              ? pc.manager + " gestiona la energía de este equipo. Los modos se cambian desde " + pc.manager + " para no pelearse con él."
              : "Instala power-profiles-daemon (viene por defecto en KDE y GNOME) para cambiar de modo desde aquí."
    }

    Item {
        anchors.fill: parent
        visible: pc.available

        Column {
            id: list
            anchors { left: parent.left; right: parent.right; top: parent.top }
            spacing: 10

            Repeater {
                id: rep
                model: pc.modes
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool active: pc.current === modelData.id
                    width: list.width
                    height: 74

                    Rectangle {
                        anchors.fill: parent
                        radius: 18
                        color: hover.hovered && !row.active ? Qt.rgba(1, 1, 1, 0.03) : "transparent"
                        border.color: row.active ? "transparent" : Qt.rgba(1, 1, 1, 0.05)
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                        spacing: 14
                        Rectangle {
                            width: 42; height: 42; radius: 14
                            color: row.active ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.04)
                            Behavior on color { ColorAnimation { duration: 300 } }
                            Icon {
                                anchors.centerIn: parent
                                path: row.modelData.icon
                                size: 20
                                color: row.active ? "#FFFFFF" : row.modelData.color
                            }
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: row.modelData.name
                                color: row.active ? "#FFFFFF" : "#DADDE8"
                                font { family: "Inter"; pixelSize: 15; weight: Font.DemiBold }
                            }
                            Text {
                                width: parent.width
                                text: row.modelData.desc
                                elide: Text.ElideRight
                                color: row.active ? Qt.rgba(1, 1, 1, 0.78) : "#7E849A"
                                font { family: "Inter"; pixelSize: 12 }
                            }
                        }
                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: "transparent"
                            border.width: 1.5
                            border.color: row.active ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.18)
                            Rectangle {
                                anchors.centerIn: parent
                                width: row.active ? 8 : 0; height: width; radius: width / 2
                                color: "#FFFFFF"
                                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            }
                        }
                    }

                    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: if (!row.active) pc.picked(row.modelData.id) }
                }
            }
        }

        // Indicador deslizante del modo activo (detrás de las filas).
        Rectangle {
            id: pill
            z: -1
            x: 0; width: list.width; height: 74
            y: pc.index * (74 + list.spacing)
            radius: 18
            visible: pc.current !== ""
            readonly property color c: pc.modes[pc.index].color
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.darker(pill.c, 1.25) }
                GradientStop { position: 1; color: Qt.rgba(pill.c.r, pill.c.g, pill.c.b, 0.55) }
            }
            border.color: Qt.rgba(1, 1, 1, 0.18)
            Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }

            Rectangle {   // brillo superior
                anchors { fill: parent; margins: 1 }
                radius: parent.radius - 1
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                    GradientStop { position: 0.5; color: "transparent" }
                }
            }
        }
        // Halo bajo el indicador.
        Item {
            id: haloSrc
            visible: false
            width: list.width; height: 74 + 60
            Rectangle {
                x: 30; y: 40; width: parent.width - 60; height: 54; radius: 27
                color: pill.c
            }
        }
        MultiEffect {
            z: -2
            source: haloSrc
            x: 0; y: pill.y - 10
            width: haloSrc.width; height: haloSrc.height
            visible: pill.visible
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            opacity: 0.45
        }

        Row {
            anchors { left: parent.left; bottom: parent.bottom }
            spacing: 8
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: "#4ADE80"
            }
            Text {
                text: "Sincronizado con KDE y tuned"
                color: "#7E849A"
                font { family: "Inter"; pixelSize: 11 }
            }
        }
    }
}
