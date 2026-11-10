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
        Rectangle { width: 3; height: parent.height; color: hw.accent; visible: o.active }
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
                Text { text: qsTr("Ajustes"); color: T.ink; font { family: T.sans; pixelSize: 22; weight: Font.DemiBold } }
                Text { text: qsTr("Teclado, inicio y estado de los componentes de Vórtice."); color: T.ink2; font { family: T.sans; pixelSize: 14 } }
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
                label: qsTr("Teclas de función")
                source: page.fnMode ? "BIOS · FnLockMode" : (page.helper.available ? qsTr("no disponible en este equipo") : qsTr("requiere servicio"))

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: -T.pad
                    anchors.rightMargin: -T.pad
                    spacing: 0
                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
                    OptionRow {
                        title: qsTr("Funciones especiales primero")
                        desc: qsTr("F6 Boost, F7 Sigilo y F9 Luces sin pulsar Fn; F1–F12 con Fn")
                        active: !!page.fnMode && page.fnMode.value === "EnableSecondary"
                        enabled_: !!page.fnMode
                        onPicked: hw.setBiosOption("FnLockMode", "EnableSecondary")
                    }
                    OptionRow {
                        title: qsTr("Teclas F1–F12 primero")
                        desc: qsTr("Las funciones especiales se usan con Fn")
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
                            label: qsTr("Permitir cambiarlo con Fn+Esc")
                            checked: !!page.fnLock && page.fnLock.value === "Enabled"
                            onToggled: on => { if (page.fnLock) hw.setBiosOption("FnLock", on ? "Enabled" : "Disabled") }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }

                    Label { Layout.margins: T.pad; Layout.bottomMargin: 8; text: qsTr("Teclas especiales") }
                    Repeater {
                        model: [{ k: qsTr("F6"), v: qsTr("Alterna el modo Rendimiento") },
                                { k: qsTr("F7"), v: qsTr("Sigilo: Silencioso y luces tenues") },
                                { k: qsTr("F9"), v: qsTr("Brillo del teclado: 100 % → 40 % → apagado") }]
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
                        text: qsTr("Estas opciones se guardan en la BIOS y valen al arrancar. Fn+Esc cambia el modo ")
                              + qsTr("al momento hasta el próximo reinicio, sin modificar la BIOS: si F6 o F7 solo ")
                              + qsTr("funcionan con Fn, pulsa Fn+Esc.")
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
                label: qsTr("Vórtice")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    Toggle {
                        label: qsTr("Iniciar en la bandeja con la sesión")
                        checked: hw.autostart
                        onToggled: on => hw.setAutostart(on)
                    }
                    Item { Layout.preferredHeight: 24 }
                    Label { text: qsTr("Idioma"); Layout.bottomMargin: 8 }
                    Row {
                        spacing: 8
                        Repeater {
                            // Los nombres de idioma van en su propio idioma (convención habitual).
                            model: [{ id: "system", name: qsTr("Sistema") }, { id: "es", name: "Español" }, { id: "en", name: "English" }]
                            delegate: Rectangle {
                                id: lb
                                required property var modelData
                                property bool active: lang.current === modelData.id
                                implicitWidth: lt.implicitWidth + 24; implicitHeight: 32
                                color: "transparent"
                                Chamfer {
                                    anchors.fill: parent
                                    fill: lb.active ? T.bgRaised : (lh.hovered ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
                                    stroke: lb.active ? hw.accent : T.ruleHi
                                }
                                Text { id: lt; anchors.centerIn: parent; text: lb.modelData.name
                                       color: lb.active ? T.ink : T.ink2; font { family: T.sans; pixelSize: 13; weight: Font.Medium } }
                                HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { lang.current = lb.modelData.id; hw.setLang(lb.modelData.id) } }
                            }
                        }
                        QtObject { id: lang; property string current: hw.langSetting }
                    }
                    Item { Layout.preferredHeight: 24 }
                    Label { text: qsTr("Color de acento"); Layout.bottomMargin: 8 }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [{ id: "brand", name: qsTr("Marca del portátil") },
                                    { id: "lights", name: qsTr("Luces del teclado") },
                                    { id: "amber", name: qsTr("Ámbar") }]
                            delegate: Item {
                                id: ab
                                required property var modelData
                                readonly property bool active: hw.accentMode === modelData.id
                                implicitWidth: at.implicitWidth + 26; implicitHeight: 32
                                Chamfer {
                                    anchors.fill: parent
                                    fill: ab.active ? T.bgRaised : (ah2.hovered ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
                                    stroke: ab.active ? hw.accent : T.ruleHi
                                }
                                Text { id: at; anchors.centerIn: parent; text: ab.modelData.name
                                       color: ab.active ? T.ink : T.ink2; font { family: T.sans; pixelSize: 13; weight: Font.Medium } }
                                HoverHandler { id: ah2; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: hw.setAccentMode(ab.modelData.id) }
                            }
                        }
                    }
                    Item { Layout.preferredHeight: 24 }
                    Label { text: qsTr("Componentes"); Layout.bottomMargin: 10 }
                    Repeater {
                        model: [
                            { k: qsTr("Servicio de hardware"), v: page.helper.available ? qsTr("activo") : qsTr("no instalado"), ok: !!page.helper.available },
                            { k: qsTr("Agente de juegos"), v: hw.inFlatpak ? qsTr("no disponible en Flatpak") : page.agent.alive ? qsTr("activo") : qsTr("detenido"),
                              ok: hw.inFlatpak || !!page.agent.alive },
                            { k: qsTr("Controlador de luces"), v: (hw.lightsState || {}).available ? (hw.lightsState.device || qsTr("detectado")) : qsTr("no encontrado"),
                              ok: !!(hw.lightsState || {}).available },
                            { k: qsTr("Driver de plataforma"), v: hw.caps.vendor || "—", ok: !!hw.caps.vendor }
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.bottomMargin: 8
                            Text { text: modelData.k; color: T.ink2; Layout.fillWidth: true; font { family: T.sans; pixelSize: 14 } }
                            Text { text: modelData.v; color: modelData.ok ? T.ink : T.warn; font { family: T.mono; pixelSize: 12 } }
                        }
                    }
                    // Instalar o actualizar el servicio de hardware (pide la contraseña).
                    Item {
                        id: svcBtn
                        visible: hw.canInstallService
                        property bool busy: false
                        Layout.topMargin: 14
                        implicitWidth: svcText.implicitWidth + 32; implicitHeight: 36
                        Connections { target: hw; function onServiceInstalling(b) { svcBtn.busy = b } }
                        Chamfer {
                            anchors.fill: parent
                            fill: page.helper.available ? (sh.hovered ? T.bgRaised : "transparent")
                                                        : (sh.hovered ? Qt.lighter(hw.accent, 1.15) : hw.accent)
                            stroke: page.helper.available ? T.ruleHi : "transparent"
                        }
                        Text {
                            id: svcText
                            anchors.centerIn: parent
                            text: svcBtn.busy ? qsTr("Instalando…")
                                  : page.helper.available ? qsTr("Actualizar servicio") : qsTr("Instalar servicio")
                            color: page.helper.available ? T.ink : T.bg
                            font { family: T.sans; pixelSize: 13; weight: Font.DemiBold }
                        }
                        HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { enabled: !svcBtn.busy; onTapped: hw.installService() }
                    }
                    Text {
                        visible: hw.inFlatpak && !page.helper.available
                        Layout.fillWidth: true
                        Layout.topMargin: 14
                        wrapMode: Text.WordWrap
                        text: qsTr("Para ventiladores, batería y luces persistentes, instala el servicio de Vórtice fuera de Flatpak: con el instalador universal (./install.sh) o el paquete de tu distro.")
                        color: T.warn
                        font { family: T.sans; pixelSize: 13 }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Vórtice · software libre (GPL-3.0)\n") + hw.caps.model
                        color: T.ink3
                        font { family: T.mono; pixelSize: 11 }
                    }
                }
            }
        }
    }
}
