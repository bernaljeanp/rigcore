import QtQuick
import QtQuick.Layouts
import "Theme.js" as T

// Sección de un procesador: temperatura en el indicador y lecturas debajo.
Section {
    id: tc
    property real temp: 0
    property var metrics: []        // [{label, value, unit}]
    property bool asleep: false     // gráfica dedicada apagada (modo híbrido)
    property bool noSensor: false   // el driver no informa de temperatura (p. ej. Intel integrada)
    property string notice: ""
    property string noticeText: ""
    property string noticeIcon: ""

    readonly property string level: asleep ? qsTr("En reposo") : noSensor ? qsTr("Sin sensor") : temp >= 92 ? qsTr("Crítica")
                                  : temp >= 82 ? qsTr("Alta") : temp >= 55 ? qsTr("Normal") : qsTr("Fría")

    Notice {
        anchors.fill: parent
        visible: tc.notice !== ""
        icon: tc.noticeIcon
        title: tc.notice
        text: tc.noticeText
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: -tc.pad   // las lecturas tocan el borde inferior
        anchors.leftMargin: -tc.pad
        anchors.rightMargin: -tc.pad
        spacing: 0
        visible: tc.notice === ""

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ArcGauge {
                id: gauge
                anchors.centerIn: parent
                width: Math.min(parent.width - 20, parent.height * 1.1)
                height: width
                value: tc.temp
                dim: tc.asleep || tc.noSensor
            }

            Column {
                anchors.centerIn: gauge
                anchors.verticalCenterOffset: 4
                spacing: 4
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    Text {
                        id: big
                        text: tc.asleep || tc.noSensor ? "—" : Math.round(gauge.shown)
                        color: tc.asleep || tc.noSensor ? T.ink3 : gauge.animTint
                        font { family: T.mono; pixelSize: Math.max(46, gauge.width * 0.17); weight: Font.Light }
                    }
                    Text {
                        visible: !tc.asleep && !tc.noSensor
                        text: qsTr("°C")
                        color: T.ink2
                        y: big.height * 0.18
                        font { family: T.mono; pixelSize: 15 }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tc.level
                    color: tc.asleep || tc.noSensor ? T.ink3 : (tc.temp >= 82 ? gauge.animTint : T.ink2)
                    font { family: T.sans; pixelSize: 12; weight: Font.Medium; letterSpacing: 0.9; capitalization: Font.AllUppercase }
                }
            }
        }

        // Lecturas: celdas separadas por líneas, pegadas al borde inferior.
        Rectangle { Layout.fillWidth: true; height: 1; color: T.rule }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false        // los layouts anidados se expanden por defecto
            Layout.preferredHeight: 66
            Layout.maximumHeight: 66
            spacing: 0
            Repeater {
                model: tc.metrics.length
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property var m: tc.metrics[index] || ({})
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Rectangle {
                        visible: cell.index > 0
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 1; color: T.rule
                    }
                    Column {
                        anchors { left: parent.left; leftMargin: T.pad; verticalCenter: parent.verticalCenter }
                        spacing: 3
                        Text {
                            text: cell.m.label || ""
                            color: T.ink3
                            font { family: T.sans; pixelSize: 11; weight: Font.Medium; letterSpacing: 0.8; capitalization: Font.AllUppercase }
                        }
                        Row {
                            spacing: 4
                            Text {
                                id: v
                                text: cell.m.value || "—"
                                color: T.ink
                                font { family: T.mono; pixelSize: 20 }
                            }
                            Text {
                                text: cell.m.unit || ""
                                color: T.ink2
                                anchors.baseline: v.baseline
                                font { family: T.mono; pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }
    }
}
