import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Item {
    id: root
    visible: false
    opacity: 0
    
    property string imageSource: ""

    function openPreview(src) {
        imageSource = src;
        visible = true;
        opacity = 1;
        focusItem.forceActiveFocus();
    }

    function closePreview() {
        opacity = 0;
    }
    
    Behavior on opacity {
        NumberAnimation { 
            duration: 150 
            onRunningChanged: {
                if (!running && root.opacity === 0) {
                    root.visible = false;
                }
            }
        }
    }

    // Dim background
    Rectangle {
        anchors.fill: parent
        color: "#E6000000" // 90% black
        
        MouseArea {
            anchors.fill: parent
            onClicked: root.closePreview()
        }
    }

    // Image
    Image {
        id: previewImage
        anchors.fill: parent
        anchors.margins: Theme.spaceL
        source: root.imageSource
        fillMode: Image.PreserveAspectFit
        autoTransform: true
        asynchronous: true
        smooth: true
        mipmap: true
    }

    // Close button (top right)
    Button {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Theme.spaceL
        text: "✕"
        
        contentItem: Text {
            text: parent.text
            color: "white"
            font.pixelSize: 24
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        
        background: Rectangle {
            color: parent.hovered ? "#33FFFFFF" : "transparent"
            radius: width / 2
            implicitWidth: 40
            implicitHeight: 40
        }
        
        onClicked: root.closePreview()
    }

    // Keyboard capture
    Item {
        id: focusItem
        focus: root.visible
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_F) {
                root.closePreview()
                event.accepted = true
            }
        }
    }
}
