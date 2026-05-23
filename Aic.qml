import QtQuick

Item {
    id: root
    width: 32; height: 32
    z: 9999
    enabled: false // Asegura que el cursor sea "fantasma"

    property string type: "arrow"

    // 1. FALLBACK: Si falla la imagen, esto es lo que verá el usuario.
    // Usamos un color chillón (magenta) para que sea obvio que falta el asset.
    Rectangle {
        id: errorFallback
        anchors.fill: parent
        color: "magenta"
        radius: 4
        visible: false // Solo se activa si falla el Image
    }

    // 2. COMPONENTE IMAGEN
    Image {
        id: cursorImage
        source: "file:///vpt/etc/cursors/" + type + ".png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        asynchronous: true // Carga en segundo plano para no congelar la UI

        onStatusChanged: {
            if (status === Image.Error) {
                console.warn("[AIC] Error cargando: " + source)
                errorFallback.visible = true
                visible = false
            } else if (status === Image.Ready) {
                errorFallback.visible = false
                visible = true
            }
        }
    }
}