import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import themes 1.0

Item {
    id: root
    
    property int personId: -1
    property string personName: ""
    property var photos: []
    
    signal backRequested()
    
    onPersonIdChanged: {
        if (personId !== -1 && typeof faceController !== "undefined") {
            photos = faceController.getPhotosForPerson(personId)
        }
    }
    
    Rectangle {
        anchors.fill: parent
        color: Theme.bgApp
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceL
            spacing: Theme.spaceM
            
            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceM
                
                Button {
                    text: "← Back to People"
                    onClicked: root.backRequested()
                    background: Rectangle {
                        color: parent.hovered ? Theme.bgHover : "transparent"
                        radius: Theme.radiusS
                        border.color: Theme.border
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontMedium
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Text {
                    text: root.personName
                    color: Theme.textPrimary
                    font.pixelSize: 24
                    font.bold: true
                    Layout.fillWidth: true
                }
                
                Text {
                    text: root.photos.length + " photos"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontMedium
                }
            }
            
            // Grid
            GridView {
                id: photoGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Theme.thumbnailSize + Theme.spaceM
                cellHeight: Theme.thumbnailSize + Theme.spaceM
                
                model: root.photos
                
                delegate: ImageCard {
                    width: Theme.thumbnailSize
                    height: Theme.thumbnailSize
                    thumbnailSource: modelData.thumbnailPath || ""
                    fileName: ""
                    imageId: modelData.id || -1
                    displayRotation: modelData.displayRotation || 0
                    
                    onRequestPreview: {
                        if (typeof globalPreviewModal !== "undefined") {
                            // Convert the gallery photos array into the format expected by the modal
                            var list = []
                            for (var i = 0; i < root.photos.length; i++) {
                                list.push({
                                    source: root.photos[i].originalPath,
                                    fileName: root.photos[i].fileName || ""
                                })
                            }
                            globalPreviewModal.openPreviewList(list, index)
                        }
                    }
                }
            }
        }
    }
}
