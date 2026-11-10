import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Theme.js" as T
import "Icons.js" as Icons

ApplicationWindow {
    id: win
    width: 1320
    height: 860
    minimumWidth: 1120
    minimumHeight: 760
    visible: true
    title: "Vórtice"
    color: T.rule   // el color de fondo hace de líneas divisorias entre zonas
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
    function n(v, d) { return (v === undefined || v === null) ? "—" : Number(v).toFixed(d || 0) }
    readonly property var profileNames: ({ "power-saver": "Silencioso", "balanced": "Equilibrado", "performance": "Rendimiento" })

    // Atajos 1, 2, 3 para cambiar de modo.
    Shortcut { sequence: "Ctrl+1"; onActivated: pages.currentIndex = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: pages.currentIndex = 1 }
    Shortcut { sequence: "Ctrl+3"; onActivated: pages.currentIndex = 2 }
    Shortcut { sequence: "Ctrl+4"; onActivated: pages.currentIndex = 3 }
    Shortcut { sequence: "Ctrl+5"; onActivated: pages.currentIndex = 4 }
    Shortcut { sequence: "1"; enabled: hw.caps.profiles; onActivated: hw.setProfile("power-saver") }
    Shortcut { sequence: "2"; enabled: hw.caps.profiles; onActivated: hw.setProfile("balanced") }
    Shortcut { sequence: "3"; enabled: hw.caps.profiles; onActivated: hw.setProfile("performance") }

    RowLayout {
        anchors.fill: parent
        spacing: 1

        Sidebar {
            Layout.fillHeight: true
            current: pages.currentIndex
            onNavigate: i => pages.currentIndex = i
        }

      StackLayout {
        id: pages
        currentIndex: startPage
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            spacing: 1

            // ---------- Cabecera ----------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: T.bg
                RowLayout {
                    anchors { fill: parent; leftMargin: T.pad; rightMargin: 0 }
                    spacing: 0
                    Text {
                        text: "Vórtice"
                        color: T.ink
                        font { family: T.sans; pixelSize: 20; weight: Font.DemiBold }
                    }
                    Text {
                        Layout.leftMargin: 14
                        text: hw.caps.model
                        color: T.ink2
                        font { family: T.sans; pixelSize: 14 }
                    }
                    Item { Layout.fillWidth: true }

                    component Status: Item {
                        id: stt
                        property string label
                        property string value
                        property color tint: T.ink
                        Layout.fillHeight: true
                        implicitWidth: col.implicitWidth + 2 * T.pad
                        Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 1; color: T.rule }
                        Column {
                            id: col
                            anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                            spacing: 2
                            Text {
                                text: stt.label
                                color: T.ink3
                                font { family: T.sans; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.9; capitalization: Font.AllUppercase }
                            }
                            Text {
                                text: stt.value
                                color: stt.tint
                                font { family: T.mono; pixelSize: 13 }
                            }
                        }
                    }

                    Status { label: "Corriente"; value: win.st.ac ? "enchufado" : "batería" }
                    Status {
                        label: "Servicio"
                        value: win.service ? "activo" : "no instalado"
                        tint: win.service ? T.ink : T.amber
                    }
                    Status {
                        visible: hw.caps.profiles
                        label: "Modo"
                        value: (win.profileNames[hw.profile] || "—").toLowerCase()
                        tint: hw.profile === "performance" ? T.amber : T.ink
                    }
                }
            }

            // ---------- Fila principal ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 5
                spacing: 1

                TempCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "CPU"
                    source: "coretemp · " + hw.caps.cpuName
                    temp: win.cpu.temp || 0
                    metrics: [
                        { label: "Uso", value: win.n(win.cpu.util), unit: "%" },
                        { label: "Frecuencia", value: win.n(win.cpu.freq, 2), unit: "GHz" }
                    ]
                }
                TempCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    label: "GPU"
                    source: (hw.caps.gpuKind === "nvidia" ? "nvml" : hw.caps.gpuKind === "amd" ? "amdgpu" : hw.caps.gpuKind)
                            + (hw.caps.gpuKind ? " · " + hw.caps.gpuName : "")
                    temp: win.gpu.temp || 0
                    asleep: !!win.gpu.asleep
                    noSensor: !!win.st.t && !!hw.caps.gpuKind && !win.gpu.asleep && (win.gpu.temp === undefined || win.gpu.temp === null)
                    notice: hw.caps.gpuKind ? "" : "No se detectó una gráfica compatible"
                    noticeText: "Vórtice lee gráficas NVIDIA (con su driver), AMD e Intel."
                    noticeIcon: Icons.gpu
                    metrics: [
                        { label: "Uso", value: win.n(win.gpu.util), unit: "%" },
                        { label: "Consumo", value: win.n(win.gpu.power),
                          unit: win.gpu.power_limit ? "/ " + win.n(win.gpu.power_limit) + " W" : "W" },
                        { label: "Reloj", value: win.n(win.gpu.clock), unit: "MHz" }
                    ]
                }
                ProfileCard {
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true
                    current: hw.profile
                    available: hw.caps.profiles
                    manager: hw.caps.profileManager
                    details: hw.profileDetails
                    onPicked: name => hw.setProfile(name)
                }
            }

            // ---------- Fila inferior ----------
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 3
                spacing: 1

                HistoryCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    cpu: win.hist.cpu
                    gpu: win.hist.gpu
                }

                Section {
                    Layout.preferredWidth: hw.caps.fanCount > 0 ? 220 * hw.caps.fanCount + 1 : 420
                    Layout.fillHeight: true
                    pad: 0
                    Notice {
                        anchors.fill: parent
                        visible: hw.caps.fanCount === 0
                        icon: Icons.fan
                        title: "Ventiladores no expuestos"
                        text: "Este equipo no informa de sus ventiladores al kernel. Si tu modelo tiene un driver de la comunidad, Vórtice los mostrará al instalarlo."
                    }
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: hw.caps.fanCount
                            Item {
                                id: fanSlot
                                required property int index
                                readonly property var f: win.fans[index] || ({})
                                readonly property int hIndex: win.helperFanIndex(f.label)
                                width: 220; height: parent.height
                                Rectangle { visible: fanSlot.index > 0; width: 1; height: parent.height; color: T.rule }
                                FanCell {
                                    anchors { fill: parent; margins: T.pad; topMargin: 16 }
                                    label: (fanSlot.f.label || "").replace("CPU Fan", "Ventilador CPU").replace("GPU Fan", "Ventilador GPU")
                                    rpm: fanSlot.f.rpm || 0
                                    maxRpm: fanSlot.f.max || 5400
                                    boost: fanSlot.hIndex >= 0 ? win.helper.fans[fanSlot.hIndex].boost
                                                               : (fanSlot.f.boost === undefined ? null : fanSlot.f.boost)
                                    canBoost: win.service && fanSlot.hIndex >= 0
                                    kind: fanSlot.hIndex >= 0 ? (win.helper.fans[fanSlot.hIndex].kind || "boost") : "boost"
                                    onBoostRequested: v => hw.setFanBoost(fanSlot.hIndex, v)
                                }
                            }
                        }
                    }
                }

                Section {
                    visible: !hw.caps.hasBattery
                    Layout.preferredWidth: 340
                    Layout.fillHeight: true
                    label: "Batería"
                    Notice { anchors.fill: parent; icon: Icons.plug; title: "Sin batería"; text: "Equipo de escritorio o batería no detectada." }
                }
                BatteryCard {
                    visible: hw.caps.hasBattery
                    Layout.preferredWidth: 340
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

        GamesPage {
            service: win.service
        }

        LightsPage {}

        FanCurvePage {
            service: win.service
        }

        SettingsPage {}
      }
    }

    ChargePopup {
        id: chargePopup
        battery: win.helper.battery || null
        onApply: (mode, start, stop) => hw.setCharge(mode, start, stop)
    }

    // Aviso inferior: barra sobria con marca de estado.
    Rectangle {
        id: toast
        property bool ok: true
        property bool shown: false
        property alias text: toastText.text
        x: 60 + 1 + T.pad
        y: shown ? parent.height - height - T.pad : parent.height + 8
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        width: toastText.implicitWidth + 2 * T.pad + 3; height: 42
        color: T.bgRaised
        border.color: T.ruleHi
        Rectangle { width: 3; height: parent.height; color: toast.ok ? T.ok : T.red }
        Text {
            id: toastText
            anchors { left: parent.left; leftMargin: T.pad + 3; verticalCenter: parent.verticalCenter }
            color: T.ink
            font { family: T.sans; pixelSize: 14 }
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
