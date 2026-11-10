import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Icons.js" as Icons

ApplicationWindow {
    id: win
    width: 1320
    height: 860
    minimumWidth: 1120
    minimumHeight: 760
    visible: true
    title: "Vórtice"
    color: "#08090D"
    onVisibilityChanged: (v) => hw.setVisible(v !== Window.Minimized && v !== Window.Hidden)

    readonly property var st: hw.stats || ({})
    readonly property var cpu: st.cpu || ({})
    readonly property var gpu: st.gpu || ({})
    readonly property var fans: st.fans || []
    readonly property var bat: st.battery || ({})
    readonly property var hist: st.history || ({ cpu: [], gpu: [] })
    readonly property var helper: hw.helper || ({ available: false })
    readonly property bool service: !!helper.available
    function helperFanIndex(label) {
        var fl = helper.fans || []
        for (var i = 0; i < fl.length; i++) if (fl[i].label === label) return i
        return -1
    }

    readonly property var accents: ({
        "power-saver": ["#2FD3B0", "#38BDF8"],
        "balanced":    ["#8C7CFF", "#38BDF8"],
        "performance": ["#FF6B3D", "#C026D3"]
    })
    property color accent: (accents[hw.profile] || accents["balanced"])[0]
    property color accent2: (accents[hw.profile] || accents["balanced"])[1]
    Behavior on accent { ColorAnimation { duration: 700 } }
    Behavior on accent2 { ColorAnimation { duration: 700 } }

    function n(v, d) { return (v === undefined || v === null) ? "–" : Number(v).toFixed(d || 0) }
    readonly property string profileName: ({ "power-saver": "Silencioso", "balanced": "Equilibrado",
                                             "performance": "Rendimiento" })[hw.profile] || "—"

    Background { anchors.fill: parent; accent: win.accent; second: win.accent2 }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Sidebar { Layout.fillHeight: true; accent: win.accent }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 30
            Layout.topMargin: 26
            spacing: 22

            // ---------- Cabecera ----------
            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Column {
                    spacing: 4
                    Text {
                        text: "Panel de control"
                        color: "#F5F6FA"
                        font { family: "Space Grotesk"; pixelSize: 30; weight: Font.Medium; letterSpacing: -0.5 }
                    }
                    Text {
                        text: hw.caps.cpuName + "  ·  " + hw.caps.gpuName + "  ·  " + hw.caps.vendor
                        color: "#7E849A"
                        font { family: "Inter"; pixelSize: 13 }
                    }
                }
                Item { Layout.fillWidth: true }

                component Chip: Rectangle {
                    id: chip
                    property string label
                    property string icon
                    property color dot: "transparent"
                    property color tint: "#C9CDDB"
                    implicitHeight: 36; radius: 18
                    implicitWidth: chipRow.implicitWidth + 28
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            visible: chip.dot.a > 0
                            width: 8; height: 8; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: chip.dot
                        }
                        Icon {
                            visible: chip.icon !== ""
                            path: chip.icon; size: 15; color: chip.tint
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: chip.label
                            color: "#DADDE8"
                            anchors.verticalCenter: parent.verticalCenter
                            font { family: "Inter"; pixelSize: 13; weight: Font.Medium }
                        }
                    }
                }

                Chip {
                    label: win.service ? "Servicio activo" : "Servicio no instalado"
                    icon: win.service ? Icons.zap : Icons.lock
                    tint: win.service ? "#4ADE80" : "#F59E0B"
                    visible: true
                }
                Chip { label: "En vivo"; dot: "#4ADE80" }
                Chip {
                    label: win.st.ac ? "Enchufado" : "Batería"
                    icon: win.st.ac ? Icons.plug : Icons.battery
                    tint: "#4ADE80"
                }
                Chip { visible: hw.caps.profiles; label: win.profileName; icon: Icons.zap; tint: win.accent }
            }

            // ---------- Fila principal ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 5
                spacing: 18

                TempCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Procesador"
                    icon: Icons.cpu
                    accent: "#38BDF8"
                    chip: hw.caps.cpuName
                    temp: win.cpu.temp || 0
                    metrics: [
                        { label: "Uso", value: win.n(win.cpu.util), unit: "%" },
                        { label: "Frecuencia", value: win.n(win.cpu.freq, 2), unit: "GHz" }
                    ]
                }
                TempCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    title: "Gráfica"
                    icon: Icons.gpu
                    accent: "#C084FC"
                    chip: hw.caps.gpuName
                    temp: win.gpu.temp || 0
                    asleep: !!win.gpu.asleep
                    notice: hw.caps.gpuKind ? "" : "No se detectó una gráfica compatible"
                    noticeText: "Vórtice lee gráficas NVIDIA (con su driver), AMD e Intel."
                    metrics: [
                        { label: "Uso", value: win.n(win.gpu.util), unit: "%" },
                        { label: "Consumo", value: win.n(win.gpu.power), unit: win.gpu.power_limit ? "/ " + win.n(win.gpu.power_limit) + " W" : "W" },
                        { label: "Reloj", value: win.n(win.gpu.clock), unit: "MHz" }
                    ]
                }
                ProfileCard {
                    Layout.preferredWidth: 360
                    Layout.fillHeight: true
                    current: hw.profile
                    available: hw.caps.profiles
                    manager: hw.caps.profileManager
                    accent: win.accent
                    onPicked: name => hw.setProfile(name)
                }
            }

            // ---------- Fila inferior ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 3
                spacing: 18

                HistoryCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    cpu: win.hist.cpu
                    gpu: win.hist.gpu
                }
                Card {
                    visible: hw.caps.fanCount === 0
                    Layout.preferredWidth: 418
                    Layout.fillHeight: true
                    Notice {
                        anchors.fill: parent
                        icon: Icons.fan
                        title: "Ventiladores no expuestos"
                        text: "Este equipo no informa de sus ventiladores al kernel. Si tu modelo tiene un driver de la comunidad, Vórtice los mostrará al instalarlo."
                    }
                }
                Repeater {
                    // Modelo numérico estable: las tarjetas no se recrean cada segundo.
                    model: hw.caps.fanCount
                    FanCard {
                        required property int index
                        readonly property var f: win.fans[index] || ({})
                        Layout.preferredWidth: 200
                        Layout.fillHeight: true
                        label: (f.label || "").replace("CPU Fan", "VENTILADOR CPU").replace("GPU Fan", "VENTILADOR GPU")
                        rpm: f.rpm || 0
                        maxRpm: f.max || 5400
                        readonly property int hIndex: win.helperFanIndex(f.label)
                        boost: hIndex >= 0 ? win.helper.fans[hIndex].boost : (f.boost === undefined ? null : f.boost)
                        canBoost: win.service && hIndex >= 0
                        onBoostRequested: v => hw.setFanBoost(hIndex, v)
                    }
                }
                Card {
                    visible: !hw.caps.hasBattery
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    Notice {
                        anchors.fill: parent
                        icon: Icons.plug
                        title: "Sin batería"
                        text: "Equipo de escritorio o batería no detectada."
                    }
                }
                BatteryCard {
                    visible: hw.caps.hasBattery
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    capacity: win.bat.capacity || 0
                    status: win.bat.status || ""
                    ac: !!win.st.ac
                    limit: win.bat.limit === undefined ? null : win.bat.limit
                    firmwareLimit: hw.caps.firmwareBattery
                    service: win.service ? win.helper.battery : null
                    onConfigure: chargePopup.open()
                }
            }
        }
    }

    ChargePopup {
        id: chargePopup
        battery: win.helper.battery || null
        onApply: (mode, start, stop) => hw.setCharge(mode, start, stop)
    }

    // Aviso flotante.
    Rectangle {
        id: toast
        property bool ok: true
        property alias text: toastText.text
        anchors.horizontalCenter: parent.horizontalCenter
        y: shown ? parent.height - height - 28 : parent.height + 10
        property bool shown: false
        Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutExpo } }
        width: toastRow.implicitWidth + 36; height: 46; radius: 23
        color: "#16171F"
        border.color: ok ? Qt.rgba(0.29, 0.87, 0.5, 0.45) : Qt.rgba(0.97, 0.44, 0.44, 0.5)
        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                width: 8; height: 8; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: toast.ok ? "#4ADE80" : "#F87171"
            }
            Text {
                id: toastText
                color: "#E8EAF2"
                anchors.verticalCenter: parent.verticalCenter
                font { family: "Inter"; pixelSize: 13; weight: Font.Medium }
            }
        }
        Timer { id: toastTimer; interval: 3200; onTriggered: toast.shown = false }
        Connections {
            target: hw
            function onNotify(msg, ok) {
                toast.text = msg; toast.ok = ok; toast.shown = true; toastTimer.restart()
            }
        }
    }
}
