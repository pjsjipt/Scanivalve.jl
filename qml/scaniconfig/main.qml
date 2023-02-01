import QtQuick 2.6
import QtQuick.Window 2.1
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.1

ApplicationWindow {
    visible: true
    width: 640
    height: 480
    title: qsTr("Scanivalve")

    header: TabBar {
        id: tab
        width: parent.width
        TabButton {
            text: "Connection"
        }

        TabButton {
            text: "DAQ Config"
        }

        TabButton {
            text: "Channels"
        }

    }
    StackLayout {
        anchors.fill: parent

        currentIndex: tab.currentIndex

        Item {
            id: connectTab
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                RowLayout {
                    Layout.alignment: Qt.AlignTop
                    Label {
                        text: "IP Address: "
                        width: 50
                    }

                    TextField {
                        id: ipaddr
                        text: "191.30.80.130"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                    }
                }

                Button {
                        id: bconnect
                        text: "Connect"
                        Layout.alignment: Qt.AlignBottom
                        Layout.fillWidth: true
                }
            }

        }

        Item {
            id: configTab
            ScaniConfig {

            }

        }

        Item {
            id: channelsTab
            ChannelConfig {

            }
        }

    }

    footer: RowLayout {
        spacing: 5
        anchors.margins: 50
        Label {
            Layout.fillWidth: true
            text: ""
        }

        Button {
            id: bapply
            text: "Apply"
        }
        Button {
            id: bcancel
            text: "Cancel"
            anchors.margins: 5
            Layout.alignment: Qt.AlignRight
        }
    }
}
