import QtQuick
import QtQuick.Layouts
import "Icons.js" as Icons

// Tarjeta principal de un procesador: temperatura en el indicador y métricas.
Card {
    id: tc
    property string chip: ""
    property real temp: 0
    property var metrics: []   // [{label, value, unit}]
    property bool asleep: false     // gráfica dedicada apagada (modo híbrido)
    property string notice: ""      // título del aviso si no hay datos
    property string noticeText: ""

    // Paleta térmica: frío → templado → caliente.
    readonly property var heat: asleep ? ["#4B5165", "#6E7489"]
                              : temp < 55 ? ["#2DD4BF", "#38BDF8"]
                              : temp < 75 ? ["#818CF8", "#C084FC"]
                              : temp < 88 ? ["#F59E0B", "#F97316"]
                                          : ["#F97316", "#EF4444"]
    readonly property string level: asleep ? "En reposo · ahorrando batería" : temp < 55 ? "Fresco" : temp < 75 ? "Normal"
                                  : temp < 88 ? "Alto" : "Crítico"

    headerRight: Rectangle {
        visible: tc.notice === ""
        height: 24; width: chipText.implicitWidth + 20; radius: 12
        color: Qt.rgba(1, 1, 1, 0.05)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        Text {
            id: chipText
            anchors.centerIn: parent
            text: tc.chip
            color: "#C9CDDB"
            font { family: "JetBrains Mono"; pixelSize: 11; weight: Font.Medium }
        }
    }

    Notice {
        anchors.fill: parent
        visible: tc.notice !== ""
        icon: tc.icon
        title: tc.notice
        text: tc.noticeText
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6
        visible: tc.notice === ""

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ArcGauge {
                id: gauge
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * 1.12)
                height: width
                value: tc.temp
                colorA: tc.heat[0]
                colorB: tc.heat[1]
            }

            Column {
                anchors.centerIn: gauge
                anchors.verticalCenterOffset: -4
                spacing: 2
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text {
                        id: big
                        text: tc.asleep ? "–" : Math.round(gauge.shown)
                        color: "#F5F6FA"
                        font { family: "Space Grotesk"; pixelSize: Math.max(44, gauge.width * 0.2); weight: Font.Medium }
                    }
                    Text {
                        visible: !tc.asleep
                        text: "°C"
                        color: "#7E849A"
                        y: big.height * 0.16
                        font { family: "Space Grotesk"; pixelSize: big.font.pixelSize * 0.32; weight: Font.Medium }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 22; width: stateRow.implicitWidth + 18; radius: 11
                    color: Qt.rgba(1, 1, 1, 0.04)
                    Row {
                        id: stateRow
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            width: 6; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: tc.heat[1]
                            Behavior on color { ColorAnimation { duration: 600 } }
                        }
                        Text {
                            text: tc.level
                            color: "#B4B9CB"
                            font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                        }
                    }
                }
            }
        }

        // Métricas inferiores.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: tc.metrics.length
                delegate: Rectangle {
                    required property int index
                    readonly property var modelData: tc.metrics[index] || ({})
                    Layout.fillWidth: true
                    height: 62; radius: 16
                    color: Qt.rgba(1, 1, 1, 0.028)
                    border.color: Qt.rgba(1, 1, 1, 0.055)
                    Column {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text {
                            text: modelData.label
                            color: "#7E849A"
                            font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                        }
                        Row {
                            spacing: 3
                            Text {
                                text: modelData.value
                                color: "#EDEFF5"
                                font { family: "Space Grotesk"; pixelSize: 20; weight: Font.Medium }
                            }
                            Text {
                                text: modelData.unit
                                color: "#7E849A"
                                anchors.baseline: parent.children[0].baseline
                                font { family: "Inter"; pixelSize: 11; weight: Font.Medium }
                            }
                        }
                    }
                }
            }
        }
    }
}
