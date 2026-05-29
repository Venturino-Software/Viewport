import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15
import Qt5Compat.GraphicalEffects

Popup {
    id: root

    // ───── PROPIEDADES DE LA NOTIFICACIÓN ─────
    property string titulo: ""
    property string contenidoResumido: ""
    property string contenidoTotal: ""
    property url icono: ""                        // Ruta de imagen o icono Adwaita
    property var contenidoInterno: null           // Item o Component para zona interactiva en expandido

    property bool playSound: true
    property int duration: 0                      // 0 = no se cierra sola; >0 ms para autocierre

    // ───── ESTILO (mismos valores por defecto que StyledPopup) ─────
    property color bgColor: "#1a1c2b"
    property color accentColor: "#7f99ff"
    property int popupRadius: 10
    property string fontType: "body"

    // Protección contra ausencia de dpScale
    readonly property real dp: typeof dpScale !== "undefined" ? dpScale : 1.0
    readonly property string activeFont: {
        if (typeof FontManager !== "undefined" && FontManager) {
            switch(fontType) {
                case "title": return FontManager.titleFontFamily
                case "mono":  return FontManager.monoFontFamily || "JetBrains Mono"
                default:      return FontManager.bodyFontFamily
            }
        }
        return fontType === "title" ? "Changa One" : "Nunito"
    }

    // ───── COMPORTAMIENTO ─────
    closePolicy: Popup.NoAutoClose       // Solo se cierra con los botones
    modal: false
    dim: false

    // Posición esquina inferior derecha (respecto al overlay/padre)
    x: parent ? parent.width - width - 20 * dp : 0
    y: parent ? parent.height - height - 20 * dp : 0

    implicitWidth: collapsedContent.implicitWidth + 2 * padding
    implicitHeight: collapsedContent.implicitHeight + 2 * padding
    padding: 16 * dp

    // ───── SONIDO ─────
    SoundEffect {
        id: notifSound
        source: "file:///vnt/sounds/notif.wav"
        volume: 1.0
    }

    Timer {
        id: autoCloseTimer
        interval: duration
        onTriggered: root.close()
    }

    onOpened: {
        if (playSound && notifSound.source != "") notifSound.play()
        if (duration > 0) autoCloseTimer.start()
    }

    // ───── FONDO DE LA VERSIÓN COLAPSADA ─────
    background: Item {
        RectangularGlow {
            id: shadow
            anchors.fill: bgRect
            glowRadius: 12 * dp
            spread: 0.1
            color: Qt.rgba(0, 0, 0, 0.5)
            cornerRadius: bgRect.radius + glowRadius
        }
        Rectangle {
            id: bgRect
            anchors.fill: parent
            radius: root.popupRadius * dp
            border.width: 1 * dp
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.lighter(root.bgColor, 1.1) }
                GradientStop { position: 1.0; color: root.bgColor }
            }
            Rectangle {
                width: parent.width
                height: 4 * dp
                color: root.accentColor
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ───── CONTENIDO COLAPSADO ─────
    contentItem: Item {
        id: collapsedContent
        implicitWidth: rowLayout.implicitWidth
        implicitHeight: rowLayout.implicitHeight

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 10 * dp

            // Icono (si se proporciona)
            Image {
                id: iconImage
                source: root.icono
                width: 24 * dp
                height: 24 * dp
                fillMode: Image.PreserveAspectFit
                visible: root.icono != ""
            }

            // Título + resumen
            Column {
                spacing: 2 * dp
                Text {
                    text: root.titulo
                    font.bold: true
                    font.pixelSize: 14 * dp
                    color: "#ffffff"
                    font.family: root.activeFont
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 200 * dp)
                }
                Text {
                    text: root.contenidoResumido
                    font.pixelSize: 12 * dp
                    color: "#cccccc"
                    font.family: root.activeFont
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    width: 200 * dp
                }
            }

            // Botones con StyledButton
            StyledButton {
                text: "Más..."
                fontSize: 11 * dp
                buttonColor: root.accentColor
                textColor: "#ffffff"
                minHeight: 30 * dp
                onClicked: expandNotification()
            }
            StyledButton {
                text: "Cerrar"
                fontSize: 11 * dp
                buttonColor: "#444444"
                textColor: "#ffffff"
                minHeight: 30 * dp
                onClicked: root.close()
            }
        }
    }

    // ───── COMPONENTE PARA EL POPUP EXPANDIDO ─────
    Component {
        id: expandedContentComponent
        Item {
            anchors.fill: parent
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 * dp }
                spacing: 12 * dp

                // Título grande
                Text {
                    text: root.titulo
                    font.bold: true
                    font.pixelSize: 18 * dp
                    color: "#ffffff"
                    font.family: root.activeFont
                    width: parent.width
                    elide: Text.ElideRight
                }

                // Contenido total (puede tener scroll si es muy largo)
                Flickable {
                    id: flickable
                    width: parent.width
                    height: Math.min(contentText.implicitHeight, 200 * dp)
                    contentHeight: contentText.implicitHeight
                    clip: true
                    Text {
                        id: contentText
                        text: root.contenidoTotal
                        font.pixelSize: 13 * dp
                        color: "#cccccc"
                        font.family: root.activeFont
                        width: flickable.width
                        wrapMode: Text.WordWrap
                    }
                    ScrollBar.vertical: ScrollBar { }
                }

                // Zona para contenido interactivo (placeholder)
                Rectangle {
                    width: parent.width
                    height: 60 * dp
                    color: Qt.rgba(1,1,1,0.05)
                    radius: 6 * dp
                    border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15)
                    visible: root.contenidoInterno != null

                    // Si contenidoInterno es un Item lo reparentamos aquí;
                    // si es un Component lo creamos dinámicamente.
                    Component.onCompleted: {
                        if (root.contenidoInterno) {
                            if (root.contenidoInterno instanceof Item) {
                                root.contenidoInterno.parent = this
                            } else if (typeof root.contenidoInterno.createObject === "function") {
                                var instance = root.contenidoInterno.createObject(this)
                                instance.anchors.fill = this
                            }
                        }
                    }
                }

                // Botón cerrar centrado abajo
                StyledButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Cerrar"
                    fontSize: 13 * dp
                    buttonColor: root.accentColor
                    textColor: "#ffffff"
                    onClicked: if (expandedPopup) expandedPopup.close()
                }
            }
        }
    }

    // ───── FUNCIÓN PARA EXPANDIR ─────
    property var expandedPopup: null

    function expandNotification() {
        root.close()  // ocultamos la notificación colapsada

        // Creamos un StyledPopup (asegúrate de que StyledPopup.qml esté en el mismo directorio)
        var component = Qt.createComponent("StyledPopup.qml")
        if (component.status === Component.Ready) {
            expandedPopup = component.createObject(root.parent || root.Overlay.overlay, {
                "bgColor": root.bgColor,
                "accentColor": root.accentColor,
                "popupRadius": root.popupRadius,
                "fontType": root.fontType,
                "verticalAlignment": "high",       // lo subimos un poco para que no tape la notificación original
                "disableDefs": true                // permitimos posicionamiento manual dentro del overlay
            })

            // Insertamos el contenido expandido dentro del popup
            var content = expandedContentComponent.createObject(expandedPopup.contentItem)
            content.anchors.fill = expandedPopup.contentItem

            expandedPopup.open()
        } else {
            console.error("No se pudo crear StyledPopup. Asegúrate de que el archivo existe.")
        }
    }

    // Al cerrar el popup expandido, no volvemos a mostrar la colapsada (notificación terminada)
    Connections {
        target: expandedPopup
        enabled: expandedPopup !== null
        function onClosed() {
            expandedPopup.destroy()
            expandedPopup = null
        }
    }
}