import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as T
import "Icons.js" as Icons

// Perfiles por juego: biblioteca a la izquierda, ajustes del juego elegido a la derecha.
Rectangle {
    id: page
    color: T.rule
    property bool service: false          // servicio root instalado (para el boost)
    property string selectedId: startGame || "default"

    readonly property var cfg: hw.gamesConfig || ({})
    readonly property var agent: hw.agentInfo || ({})
    readonly property var list: hw.gamesList || []
    readonly property var running: agent.running || []
    readonly property var modeNames: ({ "power-saver": qsTr("Silencioso"), "balanced": qsTr("Equilibrado"),
                                        "performance": qsTr("Rendimiento"), "none": qsTr("Sin cambios") })

    function gameById(id) {
        for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
        return null
    }
    function nameOf(id) { var g = gameById(id); return g ? g.name : id }
    readonly property var selected: selectedId === "default"
        ? { id: "default", name: qsTr("Resto de juegos"), detail: qsTr("Cualquier juego sin perfil propio"),
            mode: cfg.defaultMode, boost: cfg.defaultBoost, kind: "default" }
        : (gameById(selectedId) || { id: selectedId, name: selectedId, detail: "", mode: "", boost: 0 })

    ColumnLayout {
        anchors.fill: parent
        spacing: 1

        // ---------- Cabecera de la página ----------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            color: T.bg
            RowLayout {
                anchors { fill: parent; leftMargin: T.pad }
                spacing: 0
                Column {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: qsTr("Perfiles por juego")
                        color: T.ink
                        font { family: T.sans; pixelSize: 22; weight: Font.DemiBold }
                    }
                    Text {
                        text: qsTr("Al abrir un juego, Vórtice aplica su modo; al cerrarlo, restaura el anterior.")
                        color: T.ink2
                        font { family: T.sans; pixelSize: 14 }
                    }
                }
                component Cell: Item {
                    default property alias content: inner.data
                    Layout.fillHeight: true
                    implicitWidth: inner.childrenRect.width + 2 * T.pad
                    Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: T.rule }
                    Item { id: inner; anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                           height: childrenRect.height }
                }
                Cell {
                    Column {
                        spacing: 3
                        Text { text: qsTr("Ahora"); color: T.ink3
                               font { family: T.sans; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase } }
                        Text {
                            text: page.agent.active ? page.nameOf(page.agent.active) + " · "
                                                      + (page.modeNames[(page.agent.applied || {}).mode] || "").toLowerCase()
                                  : page.running.length ? page.nameOf(page.running[0]) + qsTr(" · sin cambios")
                                  : qsTr("ningún juego abierto")
                            color: page.agent.active ? T.amber : T.ink2
                            font { family: T.mono; pixelSize: 13 }
                        }
                    }
                }
                Cell {
                    Column {
                        spacing: 3
                        Text { text: qsTr("Agente"); color: T.ink3
                               font { family: T.sans; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase } }
                        Text {
                            text: page.agent.alive ? qsTr("activo") : qsTr("detenido")
                            color: page.agent.alive ? T.ink : T.amber
                            font { family: T.mono; pixelSize: 13 }
                        }
                    }
                }
                Cell {
                    Column {
                        spacing: 6
                        Toggle { label: qsTr("Automático"); checked: !!page.cfg.enabled; onToggled: on => hw.setGamesEnabled(on) }
                        Toggle { label: qsTr("Solo con cargador"); checked: !!page.cfg.acOnly; onToggled: on => hw.setAcOnly(on) }
                    }
                }
            }
        }

        // ---------- Aviso de servicio en conflicto ----------
        Repeater {
            model: (page.agent.conflicts || []).filter(u => u === "modo-juego-auto.service")
            Rectangle {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: T.bg
                Rectangle { width: 3; height: parent.height; color: T.amber }
                RowLayout {
                    anchors { fill: parent; leftMargin: T.pad + 3; rightMargin: T.pad }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.replace(".service", "") + qsTr(" también cambia el modo al jugar. Si los dos están activos, competirán.")
                        color: T.ink
                        elide: Text.ElideRight
                        font { family: T.sans; pixelSize: 14 }
                    }
                    Rectangle {
                        implicitWidth: dt.implicitWidth + 28; implicitHeight: 32; radius: 2
                        color: dh.hovered ? "#FFC04D" : T.amber
                        Text { id: dt; anchors.centerIn: parent; text: qsTr("Desactivarlo"); color: "#1A1406"
                               font { family: T.sans; pixelSize: 13; weight: Font.DemiBold } }
                        HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: hw.disableConflict(modelData) }
                    }
                }
            }
        }

        // ---------- Biblioteca + detalle ----------
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 1

            // Biblioteca
            Rectangle {
                Layout.preferredWidth: 430
                Layout.fillHeight: true
                color: T.bg

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        Layout.leftMargin: T.pad
                        Layout.rightMargin: T.pad
                        Text { text: qsTr("Biblioteca"); color: T.ink2
                               font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase } }
                        Text { text: page.list.length + qsTr(" juegos"); color: T.ink3; font { family: T.mono; pixelSize: 11 } }
                        Item { Layout.fillWidth: true }
                        Icon {
                            path: "M21 12a9 9 0 1 1-3-6.7L21 8 M21 3v5h-5"
                            size: 15; stroke: 1.6; color: rh.hovered ? T.ink : T.ink3
                            HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: hw.refreshGames() }
                            ToolTip.visible: rh.hovered; ToolTip.text: qsTr("Volver a leer la biblioteca")
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }

                    ListView {
                        id: lv
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: [{ id: "default" }].concat(page.list)
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Item {
                            id: row
                            required property var modelData
                            readonly property bool isDefault: modelData.id === "default"
                            readonly property var g: isDefault ? { name: qsTr("Resto de juegos"), detail: qsTr("juegos sin perfil propio") }
                                                               : modelData
                            readonly property bool active: page.selectedId === modelData.id
                            readonly property bool playing: page.running.indexOf(modelData.id) >= 0
                            readonly property string mode: isDefault ? page.cfg.defaultMode : (modelData.mode || "")
                            width: lv.width
                            height: 76
                            Rectangle { anchors.fill: parent; color: row.active ? T.bgRaised : (rhov.hovered ? Qt.rgba(1, 1, 1, 0.018) : "transparent") }
                            Rectangle { width: 3; height: parent.height; color: T.amber; visible: row.active }
                            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: T.rule }
                            RowLayout {
                                anchors { fill: parent; leftMargin: T.pad; rightMargin: T.pad }
                                spacing: 14
                                Rectangle {   // carátula
                                    width: 38; height: 56
                                    color: T.rule
                                    Image {
                                        anchors.fill: parent
                                        source: row.modelData.cover || row.modelData.icon || ""
                                        fillMode: row.modelData.cover ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                        anchors.margins: row.modelData.cover ? 0 : 6
                                        sourceSize: Qt.size(76, 112)
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }
                                    Icon {
                                        visible: !row.modelData.cover && !row.modelData.icon
                                        anchors.centerIn: parent
                                        path: row.isDefault ? Icons.sliders : Icons.gamepad
                                        size: 16; stroke: 1.5; color: T.ink3
                                    }
                                }
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 3
                                    Text {
                                        width: parent.width
                                        text: row.g.name
                                        color: row.active ? T.ink : T.ink2
                                        elide: Text.ElideRight
                                        font { family: T.sans; pixelSize: 15; weight: row.active ? Font.DemiBold : Font.Medium }
                                    }
                                    Text {
                                        width: parent.width
                                        text: row.playing ? qsTr("jugando ahora") : (row.g.detail || "")
                                        color: row.playing ? T.amber : T.ink3
                                        elide: Text.ElideRight
                                        font { family: T.mono; pixelSize: 11 }
                                    }
                                }
                                Text {
                                    text: row.mode === "" ? qsTr("predet.") : (page.modeNames[row.mode] || row.mode).toLowerCase()
                                    color: row.mode === "performance" ? T.amber : row.mode === "" ? T.ink3 : T.ink2
                                    font { family: T.mono; pixelSize: 11 }
                                }
                            }
                            HoverHandler { id: rhov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.selectedId = row.modelData.id }
                        }
                    }

                    // Añadir un juego que no es de Steam, por nombre de proceso.
                    Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        Layout.leftMargin: T.pad
                        Layout.rightMargin: T.pad
                        spacing: 10
                        TextField {
                            id: procField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Proceso de otro juego (ej. sober, wine64)")
                            placeholderTextColor: T.ink3
                            color: T.ink
                            font { family: T.mono; pixelSize: 12 }
                            maximumLength: 15
                            background: Rectangle { color: "transparent"; border.color: procField.activeFocus ? T.ink2 : T.ruleHi; radius: 2 }
                            onAccepted: { hw.addProcess(text); text = "" }
                        }
                        Rectangle {
                            implicitWidth: at.implicitWidth + 24; implicitHeight: 32; radius: 2
                            color: ah.hovered ? T.bgRaised : "transparent"
                            border.color: T.ruleHi
                            Text { id: at; anchors.centerIn: parent; text: qsTr("Añadir"); color: T.ink
                                   font { family: T.sans; pixelSize: 13; weight: Font.Medium } }
                            HoverHandler { id: ah; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { hw.addProcess(procField.text); procField.text = "" } }
                        }
                    }
                }
            }

            // Detalle del juego elegido
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: T.bg
                clip: true

                // Arte de fondo del juego (contenido real, atenuado).
                Image {
                    id: hero
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 220
                    source: page.selected.hero || ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 1400
                    asynchronous: true
                    opacity: 0.35
                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 221
                    visible: hero.visible
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0.07, 0.075, 0.08, 0.2) }
                        GradientStop { position: 1; color: T.bg }
                    }
                }

                RowLayout {
                    anchors { fill: parent; margins: 32; topMargin: 40 }
                    spacing: 32

                    Rectangle {   // carátula grande
                        visible: page.selectedId !== "default"
                        Layout.alignment: Qt.AlignTop
                        width: 200; height: 300
                        color: T.rule
                        border.color: T.ruleHi
                        Image {
                            anchors.fill: parent
                            anchors.margins: page.selected.cover ? 1 : 40
                            source: page.selected.cover || page.selected.icon || ""
                            fillMode: page.selected.cover ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                            sourceSize: Qt.size(400, 600)
                            asynchronous: true
                        }
                        Icon {
                            visible: !page.selected.cover && !page.selected.icon
                            anchors.centerIn: parent
                            path: page.selectedId === "default" ? Icons.sliders : Icons.gamepad
                            size: 40; stroke: 1.2; color: T.ink3
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: page.selected.name
                            color: T.ink
                            elide: Text.ElideRight
                            font { family: T.sans; pixelSize: 30; weight: Font.DemiBold }
                        }
                        Text {
                            Layout.topMargin: 4
                            text: page.selected.detail || ""
                            color: T.ink3
                            font { family: T.mono; pixelSize: 12 }
                        }

                        Text {
                            Layout.topMargin: 28
                            Layout.bottomMargin: 10
                            text: qsTr("Modo al jugar")
                            color: T.ink2
                            font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
                        Repeater {
                            model: (page.selectedId === "default" ? [] : [{ id: "", name: qsTr("Predeterminado"),
                                     desc: qsTr("Lo mismo que el resto de juegos: ") + (page.modeNames[page.cfg.defaultMode] || "").toLowerCase() }])
                                   .concat([
                                     { id: "power-saver", name: qsTr("Silencioso"), desc: qsTr("Para juegos ligeros o con batería") },
                                     { id: "balanced", name: qsTr("Equilibrado"), desc: qsTr("Menos ruido, rendimiento suficiente") },
                                     { id: "performance", name: qsTr("Rendimiento"), desc: qsTr("Toda la potencia") },
                                     { id: "none", name: qsTr("Sin cambios"), desc: qsTr("Vórtice no toca nada con este juego") }])
                            delegate: Item {
                                id: opt
                                required property var modelData
                                readonly property bool active: (page.selected.mode || "") === modelData.id
                                Layout.fillWidth: true
                                Layout.preferredHeight: 52
                                Rectangle { anchors.fill: parent; color: opt.active ? T.bgRaised : (oh.hovered ? Qt.rgba(1, 1, 1, 0.018) : "transparent") }
                                Rectangle { width: 3; height: parent.height; color: T.amber; visible: opt.active }
                                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: T.rule }
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                                    Text {
                                        text: opt.modelData.name
                                        color: opt.active ? T.ink : T.ink2
                                        Layout.preferredWidth: 150
                                        font { family: T.sans; pixelSize: 15; weight: opt.active ? Font.DemiBold : Font.Medium }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: opt.modelData.desc
                                        color: T.ink3
                                        elide: Text.ElideRight
                                        font { family: T.sans; pixelSize: 13 }
                                    }
                                }
                                HoverHandler { id: oh; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: page.selectedId === "default"
                                              ? hw.setDefault(opt.modelData.id, page.cfg.defaultBoost || 0)
                                              : hw.setGameMode(page.selectedId, opt.modelData.id)
                                }
                            }
                        }

                        // Boost de ventiladores para este juego.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 26
                            Text {
                                text: qsTr("Boost de ventiladores")
                                color: T.ink2
                                font { family: T.sans; pixelSize: T.labelSize; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: !page.service ? qsTr("requiere servicio")
                                      : boostFader.value === 0 ? qsTr("automático") : Math.round(boostFader.value) + " %"
                                color: boostFader.value > 0 && page.service ? T.amber : T.ink3
                                font { family: T.mono; pixelSize: 11 }
                            }
                        }
                        Fader {
                            id: boostFader
                            Layout.fillWidth: true
                            Layout.maximumWidth: 520
                            Layout.topMargin: 6
                            enabled: page.service && page.selected.mode !== "none"
                            from: 0; to: 100; stepSize: 5
                            fill: value > 0 ? T.amber : T.ink
                            Binding on value { when: !boostFader.pressed; value: Math.round((page.selected.boost || 0) / 2.55 / 5) * 5; restoreMode: Binding.RestoreNone }
                            onCommitted: v => page.selectedId === "default"
                                         ? hw.setDefault(page.cfg.defaultMode, Math.round(v * 2.55))
                                         : hw.setGameBoost(page.selectedId, Math.round(v * 2.55))
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Al cerrar el juego se restaura el modo anterior y los ventiladores vuelven a automático. ")
                                  + qsTr("Si cambias el modo a mano durante la partida, se respeta.")
                            color: T.ink3
                            wrapMode: Text.WordWrap
                            font { family: T.sans; pixelSize: 13 }
                        }
                        Text {
                            visible: page.selected.kind === "process"
                            Layout.topMargin: 10
                            text: qsTr("Quitar de la lista")
                            color: qh.hovered ? T.red : T.ink3
                            font { family: T.sans; pixelSize: 13; underline: qh.hovered }
                            HoverHandler { id: qh; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { hw.removeProcess(page.selectedId); page.selectedId = "default" } }
                        }
                    }
                }
            }
        }
    }
}
