import QtQuick
import QtQuick.Layouts
import "Theme.js" as T
import "Icons.js" as Icons

// Ajustes: teclado (bloqueo de Fn en la BIOS), inicio y estado de los componentes.
Rectangle {
    id: page
    color: T.rule
    readonly property var helper: hw.helper || ({})
    readonly property var bios: helper.bios || ({})
    readonly property var fnMode: bios.FnLockMode || null
    readonly property var fnLock: bios.FnLock || null
    readonly property var agent: hw.agentInfo || ({})

    component Label: Text {
        color: T.ink2
        font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase }
    }
    component OptionRow: Item {
        id: o
        property string title
        property string desc
        property bool active: false
        property bool enabled_: true
        signal picked()
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        opacity: enabled_ ? 1 : 0.4
        Rectangle { anchors.fill: parent; color: o.active ? T.bgRaised : (oh.hovered && o.enabled_ ? Qt.rgba(1, 1, 1, 0.018) : "transparent") }
        Rectangle { width: 3; height: parent.height; color: T.amber; visible: o.active }
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: T.rule }
        Column {
            anchors { left: parent.left; leftMargin: T.pad; right: parent.right; rightMargin: T.pad; verticalCenter: parent.verticalCenter }
            spacing: 3
            Text { text: o.title; color: o.active ? T.ink : T.ink2; font { family: T.sans; pixelSize: 15; weight: o.active ? Font.DemiBold : Font.Medium } }
            Text { width: parent.width; text: o.desc; color: T.ink3; elide: Text.ElideRight; font { family: T.sans; pixelSize: 12 } }
        }
        HoverHandler { id: oh; cursorShape: o.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: o.enabled_ && !o.active; onTapped: o.picked() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 1

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            color: T.bg
            Column {
                anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                spacing: 4
                Text { text: "Ajustes"; color: T.ink; font { family: T.sans; pixelSize: 22; weight: Font.DemiBold } }
                Text { text: "Teclado, inicio y estado de los componentes de Vórtice."; color: T.ink2; font { family: T.sans; pixelSize: 14 } }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            // ---------- Teclado ----------
            Section {
                Layout.fillWidth: true
                Layout.fillHeight: true
                label: "Teclas de función"
                source: page.fnMode ? "BIOS · FnLockMode" : (page.helper.available ? "no disponible en este equipo" : "requiere servicio")

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: -T.pad
                    anchors.rightMargin: -T.pad
                    spacing: 0
                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
                    OptionRow {
                        title: "Funciones especiales primero"
                        desc: "F6 Boost, F7 Sigilo y F9 Luces sin pulsar Fn; F1–F12 con Fn"
                        active: !!page.fnMode && page.fnMode.value === "EnableSecondary"
                        enabled_: !!page.fnMode
                        onPicked: hw.setBiosOption("FnLockMode", "EnableSecondary")
                    }
                    OptionRow {
                        title: "Teclas F1–F12 primero"
                        desc: "Las funciones especiales se usan con Fn"
                        active: !!page.fnMode && page.fnMode.value === "DisableStandard"
                        enabled_: !!page.fnMode
                        onPicked: hw.setBiosOption("FnLockMode", "DisableStandard")
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56
                        opacity: page.fnLock ? 1 : 0.4
                        Toggle {
                            anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                            label: "Permitir cambiarlo con Fn+Esc"
                            checked: !!page.fnLock && page.fnLock.value === "Enabled"
                            onToggled: on => { if (page.fnLock) hw.setBiosOption("FnLock", on ? "Enabled" : "Disabled") }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }

                    Label { Layout.margins: T.pad; Layout.bottomMargin: 8; text: "Teclas especiales" }
                    Repeater {
                        model: [{ k: "F6", v: "Alterna el modo Rendimiento" },
                                { k: "F7", v: "Sigilo: Silencioso y luces tenues" },
                                { k: "F9", v: "Brillo del teclado: 100 % → 40 % → apagado" }]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.leftMargin: T.pad
                            Layout.rightMargin: T.pad
                            Layout.bottomMargin: 6
                            Rectangle {
                                implicitWidth: 34; implicitHeight: 22; radius: 2
                                color: "transparent"; border.color: T.ruleHi
                                Text { anchors.centerIn: parent; text: modelData.k; color: T.ink; font { family: T.mono; pixelSize: 11 } }
                            }
                            Text { Layout.leftMargin: 8; text: modelData.v; color: T.ink2; font { family: T.sans; pixelSize: 13 } }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        Layout.margins: T.pad
                        text: "Estas opciones se guardan en la BIOS y valen al arrancar. Fn+Esc cambia el modo "
                              + "al momento hasta el próximo reinicio, sin modificar la BIOS: si F6 o F7 solo "
                              + "funcionan con Fn, pulsa Fn+Esc."
                        color: T.ink3
                        wrapMode: Text.WordWrap
                        font { family: T.sans; pixelSize: 13 }
                    }
                }
            }

            // ---------- Inicio y componentes ----------
            Section {
                Layout.preferredWidth: 420
                Layout.fillHeight: true
                label: "Vórtice"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Toggle {
                        label: "Iniciar en la bandeja con la sesión"
                        checked: hw.autostart
                        onToggled: on => hw.setAutostart(on)
                    }
                    Item { Layout.preferredHeight: 24 }
                    Label { text: "Componentes"; Layout.bottomMargin: 10 }
                    Repeater {
                        model: [
                            { k: "Servicio de hardware", v: page.helper.available ? "activo" : "no instalado", ok: !!page.helper.available },
                            { k: "Agente de juegos", v: page.agent.alive ? "activo" : "detenido", ok: !!page.agent.alive },
                            { k: "Controlador de luces", v: (hw.lightsState || {}).available ? (hw.lightsState.device || "detectado") : "no encontrado",
                              ok: !!(hw.lightsState || {}).available },
                            { k: "Driver de plataforma", v: hw.caps.vendor || "—", ok: !!hw.caps.vendor }
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.bottomMargin: 8
                            Text { text: modelData.k; color: T.ink2; Layout.fillWidth: true; font { family: T.sans; pixelSize: 14 } }
                            Text { text: modelData.v; color: modelData.ok ? T.ink : T.amber; font { family: T.mono; pixelSize: 12 } }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: "Vórtice · software libre (GPL-3.0)\n" + hw.caps.model
                        color: T.ink3
                        font { family: T.mono; pixelSize: 11 }
                    }
                }
            }
        }
    }
}
