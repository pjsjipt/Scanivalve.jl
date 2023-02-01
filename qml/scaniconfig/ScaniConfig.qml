import QtQuick 2.6
import QtQuick.Window 2.1
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.0

Item {
    anchors.fill: parent

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5

        RowLayout {
            //Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Label {
                text: "FPS"
                width: 200
            }
            TextField {
                id: txtfps
                text: "1"
                IntValidator {
                    bottom: 0
                    top: 1000000
                }
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Label {
                text: "PERIOD"
            }
            TextField {
                id: txtperiod
                text: "500"
                IntValidator {
                    bottom: 150
                    top: 65000
                }
                Layout.fillWidth: true
            }
        }
        RowLayout {

            Label {
                text: "    AVG"
            }
            TextField {
                id: txtavg
                text: "1"
                IntValidator {
                    bottom: 1
                    top: 240
                }
                ToolTip{
                    text: "Number of samples that are averaged"
                    parent: txtavg.handle
                }
                Layout.fillWidth: true
            }
        }
        Label {
            Layout.fillHeight: true
        }
        Button {
            id: breadconfig
            Layout.fillWidth: true
            text: "Read Configuration"
        }

        Button {
            id: bconfig
            text: "Configure"
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
        }
    }
}
