import QtQuick 2.0
import QtQuick.Layouts 1.3
import QtQuick.Controls 2.1

Rectangle {
    anchors.fill: parent

    ListModel {
        id: listModel
        ListElement {chan: "01"; name: "P01"; use: true}
        ListElement {chan: "02"; name: "P02"; use: true}
        ListElement {chan: "03"; name: "P03"; use: true}
        ListElement {chan: "04"; name: "P04"; use: true}
        ListElement {chan: "05"; name: "P05"; use: true}
        ListElement {chan: "06"; name: "P06"; use: true}
        ListElement {chan: "07"; name: "P07"; use: true}
        ListElement {chan: "08"; name: "P08"; use: true}
        ListElement {chan: "09"; name: "P09"; use: true}
        ListElement {chan: "10"; name: "P10"; use: true}
        ListElement {chan: "11"; name: "P11"; use: true}
        ListElement {chan: "12"; name: "P12"; use: true}
        ListElement {chan: "13"; name: "P13"; use: true}
        ListElement {chan: "14"; name: "P14"; use: true}
        ListElement {chan: "15"; name: "P15"; use: true}
        ListElement {chan: "16"; name: "P16"; use: true}

    }

    Component {

        id: nameDelegate

        RowLayout {
            spacing: 5
            anchors {
                left: parent.left
                right: parent.right
                margins: 5
            }

            Label {
                id: idchan
                text: model.chan
                //Layout.alignment:
                //anchors.left: parent.left
            }
            TextField {
                id: chan
                text: model.name
                Layout.fillWidth: true
            }
            CheckBox {
                id: usechan
                text: "Use channel"
                checked: model.use
                }
            }
        }
        /*
        Rectangle {
            implicitHeight: chan.implicitHeight
            anchors {
                left: parent.left; right: parent.right
            }
            Label {
                id: idchan
                text: model.chan
                anchors.left: parent.left
            }
            TextField {
                id: chan
                text: model.name

                anchors.left: idchan.right
            }
            CheckBox {
                id: usechan
                text: "Use channel"
                checked: model.use
                anchors.left: chan.right
                }
            }
*/
    ListView {
        id: lv
        anchors.fill: parent
        model: listModel
        delegate: nameDelegate
        clip: true
    }

}
