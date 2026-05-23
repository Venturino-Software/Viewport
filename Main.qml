/* STREAMING_CHUNK:Configuring root window and properties... */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

Window {
id: root
// Tamaño adaptable a la pantalla (80% del escritorio, con mínimo)
width: Math.max(900, Screen.desktopAvailableWidth * 0.8)
height: Math.max(650, Screen.desktopAvailableHeight * 0.8)
visible: true
title: qsTr("Viewport Launcher")
color: "#05050a"  // BGCOLOR

// Factor de escala basado en densidad de píxeles (referencia 96 dpi)
readonly property real dpScale: Math.max(1.0, Screen.pixelDensity / 96.0)

/* STREAMING_CHUNK:Defining AppIcon component... */
// ============= COMPONENTE APPICON =============
component AppIcon: Item {
    id: iconRoot
    property string iconName: ""
    property string appName: "X"

    // Círculo de fondo sutil
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.08)
        border.color: Qt.rgba(1, 1, 1, 0.12)
    }

    // Texto fallback para cuando no hay imagen
    Text {
        anchors.centerIn: parent
        text: iconRoot.appName.length > 0 ? iconRoot.appName.charAt(0).toUpperCase() : ""
        color: "#ffffff"
        font.pixelSize: parent.height * 0.6
        font.weight: Font.Bold
        visible: img.status !== Image.Ready
        opacity: 0.8
    }

    Image {
        id: img
        anchors.fill: parent
        anchors.margins: 10 * dpScale // Margen interno para el icono
        source: iconName !== "" ? ("qrc:/" + iconName + ".png") : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: status === Image.Ready
        onStatusChanged: {
            if (status === Image.Error && iconName !== "") {
                // Silenciamos advertencias excesivas, el fallback (Text) se encargará
                console.log("Icon not found, using fallback for:", source)
            }
        }
    }
}

Connections {
    target: AppBackend

    // Esta función se ejecuta automáticamente cuando el C++ emite "emit appClosed();"
    function onAppClosed() {
        console.log("El backend reporta que la app se cerró. Restaurando UI...")
        cancelLaunch() // Llamamos a la animación de regreso
    }
}

/* STREAMING_CHUNK:Initializing models for grid and search... */
// ============= MODELOS =============
// ============= MODELOS =============
ListModel {
    id: appModel
    // Se llenará dinámicamente desde C++ al inicio
}

// Modelo base para búsqueda
ListModel {
    id: baseSearchModel
    // Se llenará dinámicamente desde C++ al inicio
}

// Modelo filtrado para búsqueda (dinámico)
ListModel {
    id: filteredSearchModel
}

// ============= CARGA DINÁMICA DE APPS DESDE EL OS =============
Component.onCompleted: {
    console.log("[vpt] Indexando aplicaciones del sistema...")
    var systemApps = AppBackend.loadDesktopApps()

    for (var i = 0; i < systemApps.length; i++) {
        var appData = systemApps[i]
        // Agregamos a la base de búsqueda
        baseSearchModel.append(appData)

        // Agregamos las primeras 8 apps al grid principal (o puedes filtrarlas por categoría)
        if (i < 8) {
            appModel.append(appData)
        }
    }
    updateSearchFilter("") // Inicializa la lista del buscador
}

// Función para actualizar el modelo filtrado según el texto
// Función para actualizar el modelo filtrado según el texto
function updateSearchFilter(text) {
    filteredSearchModel.clear()
    var lowerText = text.toLowerCase()
    for (var i = 0; i < baseSearchModel.count; i++) {
        var item = baseSearchModel.get(i)
        if (item.name.toLowerCase().includes(lowerText) || item.category.toLowerCase().includes(lowerText)) {
            filteredSearchModel.append(item)
        }
    }
}

/* STREAMING_CHUNK:Building the main layout and Top Bar... */
// ============= FONDO DINÁMICO =============
Item {
    anchors.fill: parent
    z: -1
    Rectangle {
        anchors.fill: parent
        color: "#0a0a14"
    }
}

// ============= INTERFAZ PRINCIPAL =============
Item {
    id: mainInterface
    anchors.fill: parent

    // Barra superior
    Item {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 100 * dpScale

        // Botón de búsqueda mejorado
        Rectangle {
            id: searchButton
            width: searchOverlay.state === "VISIBLE" ? 380 * dpScale : 350 * dpScale
            height: 45 * dpScale
            anchors.centerIn: parent
            color: searchClickArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
            radius: height / 2
            border.color: searchClickArea.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on border.color { ColorAnimation { duration: 250 } }
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutElastic } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15 * dpScale
                spacing: 12 * dpScale

                Text {
                    text: ">"
                    font.pixelSize: 14 * dpScale
                    color: "#a0a0b0"
                    opacity: 0.7
                }
                Text {
                    text: "Buscar aplicaciones..."
                    color: "#a0a0b0"
                    font.pixelSize: 14 * dpScale
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                id: searchClickArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (searchOverlay.state !== "VISIBLE") {
                        updateSearchFilter("")   // Mostrar todos inicialmente
                        searchOverlay.state = "VISIBLE"
                        searchInput.forceActiveFocus()
                    }
                }
            }
        }
    }

    /* STREAMING_CHUNK:Rendering the main app grid... */
    // Grid de aplicaciones principales
    GridView {
        id: mainGrid
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 40 * dpScale
        cellWidth: 180 * dpScale
        cellHeight: 180 * dpScale
        model: appModel
        boundsBehavior: Flickable.DragAndOvershootBounds
        clip: true // Ayuda a que los items no se desborden arriba/abajo

        // Animación de entrada en cascada
        populate: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 600 }
            NumberAnimation { property: "scale"; from: 0.3; to: 1; duration: 700; easing.type: Easing.OutBack }
            NumberAnimation { property: "y"; duration: 600; easing.type: Easing.OutExpo }
        }

        delegate: Item {
            width: 180 * dpScale
            height: 180 * dpScale

            Rectangle {
                id: itemTile
                width: 140 * dpScale
                height: 140 * dpScale
                anchors.centerIn: parent
                color: Qt.rgba(1, 1, 1, 0.05)
                radius: 28 * dpScale
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                // Se hace transparente si es la app que estamos lanzando
                opacity: (transitionCard.visible && transitionCard.sourceIndex === index) ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                // Sombra simulada
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    z: -1
                    radius: parent.radius + 2
                    color: Qt.rgba(0,0,0,0.15)
                    visible: itemTile.state === "HOVER" || itemTile.state === "PRESSED"
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 16 * dpScale

                    AppIcon {
                        width: 60 * dpScale
                        height: 60 * dpScale
                        anchors.horizontalCenter: parent.horizontalCenter
                        appName: name
                        iconName: model.icon
                    }

                    Text {
                        text: name
                        color: "#ffffff"
                        font.pixelSize: 14 * dpScale
                        font.weight: Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: clickZone
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                    var pos = itemTile.mapToItem(root.contentItem, 0, 0)
                    // AHORA PASAMOS EL COMANDO REAL 'model.exec'
                    launchApp(pos.x, pos.y, name, model.exec, index, model.icon)
                    }
                }

                              // Estados hover/pressed con animaciones más ricas


                // Estados hover/pressed
                states: [
                    State {
                        name: "HOVER"
                        when: clickZone.containsMouse && !clickZone.pressed
                        PropertyChanges { target: itemTile; color: Qt.rgba(1,1,1,0.12); scale: 1.08; border.color: Qt.rgba(0.5,0.6,1.0,0.6) }
                    },
                    State {
                        name: "PRESSED"
                        when: clickZone.pressed
                        PropertyChanges { target: itemTile; color: Qt.rgba(0,0,0,0.2); scale: 0.92; border.color: Qt.rgba(0.5,0.6,1.0,1.0) }
                    }
                ]
                transitions: Transition {
                    NumberAnimation { properties: "scale"; duration: 350; easing.type: Easing.OutBack }
                    ColorAnimation { properties: "color, border.color"; duration: 200 }
                }
            }
        }
    }
}

/* STREAMING_CHUNK:Implementing the search overlay... */
// ============= OVERLAY DE BÚSQUEDA =============
Item {
    id: searchOverlay
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    z: 50

    // Fondo oscuro
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.05, 0.8)
        MouseArea {
            anchors.fill: parent
            onClicked: searchOverlay.state = "HIDDEN"
        }
    }

    // Atajos de teclado
    Shortcut {
        sequence: "Esc"
        enabled: searchOverlay.visible
        onActivated: searchOverlay.state = "HIDDEN"
    }
    Shortcut {
            sequence: "Return"
            enabled: searchOverlay.visible && searchList.currentIndex >= 0
            onActivated: {
                var item = filteredSearchModel.get(searchList.currentIndex)
                if (item) {
                    console.log("[vpt] Lanzado desde búsqueda con Enter: " + item.name)
                    AppBackend.openApp(item.exec) // <-- Ejecutando el comando real
                    searchOverlay.state = "HIDDEN"
                }
            }
        }


    Rectangle {
        id: searchPanel
        width: Math.min(650 * dpScale, parent.width * 0.85)
        height: Math.min(550 * dpScale, parent.height * 0.85)
        anchors.centerIn: parent
        color: Qt.rgba(0.1, 0.1, 0.15, 0.75)
        radius: 24 * dpScale
        border.color: Qt.rgba(1, 1, 1, 0.2)
        border.width: 1
        clip: true

        // Sombra panel
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            z: -1
            radius: parent.radius + 2
            color: Qt.rgba(0,0,0,0.3)
        }

        MouseArea { anchors.fill: parent } // evita clics traspasados

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25 * dpScale
            spacing: 20 * dpScale

            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * dpScale

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    height: 55 * dpScale
                    font.pixelSize: 18 * dpScale
                    color: "#ffffff"
                    placeholderText: "Buscar aplicaciones..."
                    placeholderTextColor: "#707080"

                    background: Rectangle {
                        color: Qt.rgba(0, 0, 0, 0.4)
                        radius: 14 * dpScale
                        border.color: searchInput.activeFocus ? "#6688ff" : Qt.rgba(1, 1, 1, 0.15)
                        border.width: searchInput.activeFocus ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                    }

                    onTextChanged: updateSearchFilter(text)
                }

                Rectangle {
                    width: 40 * dpScale
                    height: 40 * dpScale
                    radius: 20 * dpScale
                    color: closeBtnArea.containsMouse ? Qt.rgba(1,1,1,0.15) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#ffffff"
                        font.pixelSize: 18 * dpScale
                    }
                    MouseArea {
                        id: closeBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: searchOverlay.state = "HIDDEN"
                    }
                }
            }

            ListView {
                id: searchList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: filteredSearchModel
                clip: true
                spacing: 8 * dpScale
                currentIndex: -1
                highlightMoveDuration: 200

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
                    NumberAnimation { property: "x"; from: -20 * dpScale; to: 0; duration: 300; easing.type: Easing.OutQuad }
                }
                displaced: Transition {
                    NumberAnimation { property: "y"; duration: 200 }
                }

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 65 * dpScale
                    color: searchItemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    radius: 12 * dpScale
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12 * dpScale
                        spacing: 15 * dpScale

                        AppIcon {
                            width: 32 * dpScale
                            height: 32 * dpScale
                            appName: name
                            iconName: model.icon
                        }

                        Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                text: name
                                color: "#ffffff"
                                font.pixelSize: 16 * dpScale
                                font.weight: Font.Medium
                            }
                            Text {
                                text: category
                                color: "#888899"
                                font.pixelSize: 13 * dpScale
                            }
                        }
                    }

                    MouseArea {
                        id: searchItemArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: {
                                                    console.log("[vpt] Lanzado desde búsqueda: " + name)
                                                    AppBackend.openApp(model.exec) // <-- Ejecutando el comando real
                                                    searchOverlay.state = "HIDDEN"
                                                }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: filteredSearchModel.count === 0 ? "Sin resultados" : ""
                color: "#888899"
                font.pixelSize: 16 * dpScale
                visible: filteredSearchModel.count === 0
            }
        }
    }

    states: [
        State { name: "VISIBLE"; PropertyChanges { target: searchOverlay; opacity: 1.0 } },
        State { name: "HIDDEN"; PropertyChanges { target: searchOverlay; opacity: 0.0 } }
    ]

    transitions: Transition {
        NumberAnimation { properties: "opacity"; duration: 250; easing.type: Easing.InOutQuad }
        NumberAnimation { target: searchPanel; property: "scale"; from: 0.9; to: 1.0; duration: 300; easing.type: Easing.OutBack }
    }

    onStateChanged: {
        if (state === "HIDDEN") {
            searchInput.text = ""
            updateSearchFilter("")
            root.contentItem.forceActiveFocus()
        }
    }
}

/* STREAMING_CHUNK:Creating the transition card and loading animations... */
// ============= PANTALLA DE CARGA =============
Rectangle {
    id: loadingScreen
    anchors.fill: parent
    color: "#05050a"
    opacity: 0.0
    visible: opacity > 0
    z: 100
    MouseArea {
        anchors.fill: parent
        onClicked: cancelLaunch() // Click en el fondo cancela
    }
}

// Tarjeta de transición (animación de lanzamiento)
Item {
    id: transitionCard
    width: 140 * dpScale
    height: 140 * dpScale
    visible: false
    z: 110

    // PROPIEDADES MOVIDAS AQUÍ: ¡Éste era el principal causante del Bug!
    property real originalX: 0
    property real originalY: 0
    property string appName: ""
    property string appIcon: ""
    property int sourceIndex: -1

    transform: Rotation {
        id: cardRotation
        origin.x: transitionCard.width / 2
        origin.y: transitionCard.height / 2
        axis { x: 0; y: 1; z: 0 }
        angle: 0
    }

    // Cara frontal
    Rectangle {
        id: cardFront
        anchors.fill: parent
        color: Qt.rgba(1, 1, 1, 0.12)
        radius: 28 * dpScale
        border.color: Qt.rgba(0.5, 0.6, 1.0, 0.5)
        border.width: 1
        visible: cardRotation.angle < 90

        Column {
            anchors.centerIn: parent
            spacing: 16 * dpScale
            AppIcon {
                width: 60 * dpScale
                height: 60 * dpScale
                anchors.horizontalCenter: parent.horizontalCenter
                appName: transitionCard.appName
                iconName: transitionCard.appIcon
            }
            Text {
                text: transitionCard.appName
                color: "#ffffff"
                font.pixelSize: 14 * dpScale
                font.weight: Font.Medium
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Cara trasera (spinner)
    Rectangle {
        id: cardBack
        anchors.fill: parent
        color: "transparent"
        visible: cardRotation.angle >= 90

        transform: Rotation {
            origin.x: cardBack.width / 2
            origin.y: cardBack.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: 180
        }

        Item {
            width: 60 * dpScale
            height: 60 * dpScale
            anchors.centerIn: parent

            Repeater {
                model: 8
                Rectangle {
                    width: 8 * dpScale
                    height: 8 * dpScale
                    radius: width/2
                    color: "#6688ff"
                    x: parent.width/2 + Math.cos(index * Math.PI/4) * 22 * dpScale - width/2
                    y: parent.height/2 + Math.sin(index * Math.PI/4) * 22 * dpScale - height/2

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: cardBack.visible
                        PauseAnimation { duration: index * 80 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 200; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.0; to: 0.3; duration: 400; easing.type: Easing.InOutQuad }
                    }
                }
            }

            RotationAnimator on rotation {
                from: 0; to: 360
                duration: 1200
                loops: Animation.Infinite
                running: cardBack.visible
                easing.type: Easing.Linear
            }
        }
    }

    // MouseArea invisible encima de la tarjeta para capturar clics extras o cancelar
    MouseArea {
        anchors.fill: parent
        onClicked: cancelLaunch()
    }
}

/* STREAMING_CHUNK:Fixing launch and cancel logic... */
// Animación de lanzamiento
ParallelAnimation {
    id: launchAnim
    NumberAnimation { target: loadingScreen; property: "opacity"; to: 1.0; duration: 400; easing.type: Easing.OutQuad }
    NumberAnimation {
        target: transitionCard; property: "x"
        to: root.width / 2 - transitionCard.width / 2
        duration: 500; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        target: transitionCard; property: "y"
        to: root.height / 2 - transitionCard.height / 2
        duration: 500; easing.type: Easing.OutCubic
    }
    NumberAnimation {
        // NOTA: 'from' eliminado para permitir interrupción suave si se cancela a medias
        target: cardRotation; property: "angle"
        to: 180
        duration: 600; easing.type: Easing.InOutBack
    }
    NumberAnimation {
        target: transitionCard; property: "scale"
        to: 1.3
        duration: 500; easing.type: Easing.OutQuad
    }
}

// Animación de retorno estable
ParallelAnimation {
    id: cancelAnim
    NumberAnimation { target: loadingScreen; property: "opacity"; to: 0.0; duration: 300 }
    NumberAnimation {
        target: transitionCard; property: "x"
        to: transitionCard.originalX; duration: 400; easing.type: Easing.InBack
    }
    NumberAnimation {
        target: transitionCard; property: "y"
        to: transitionCard.originalY; duration: 400; easing.type: Easing.InBack
    }
    NumberAnimation {
        target: cardRotation; property: "angle"
        to: 0; duration: 400; easing.type: Easing.InOutQuad
    }
    NumberAnimation {
        target: transitionCard; property: "scale"
        to: 1.0; duration: 400; easing.type: Easing.InBack // Retorna a escala 1.0 (tamaño original de grid) en lugar de 0.5
    }

    // El uso nativo de 'onFinished' previene Memory Leaks y bugs de estado lógico
    onFinished: {
        transitionCard.visible = false
        transitionCard.sourceIndex = -1
    }
}

// ============= FUNCIONES =============
function launchApp(startX, startY, name, execCommand, index, iconName) {
    if (launchAnim.running) return // Evita multi-clic

    AppBackend.openApp(execCommand) // <-- Llamada al sistema a través de C++

    transitionCard.appName = name
    transitionCard.appIcon = iconName
    transitionCard.sourceIndex = index

    // Seteo imperativo sin animación inicial
    transitionCard.x = startX
    transitionCard.y = startY
    transitionCard.originalX = startX
    transitionCard.originalY = startY
    transitionCard.scale = 1.0
    cardRotation.angle = 0
    transitionCard.visible = true

    cancelAnim.stop() // Detiene cancelación en curso si existe
    launchAnim.start()
}

function cancelLaunch() {
    // Ignora si no está visible o si YA se está cancelando
    if (!transitionCard.visible || cancelAnim.running) return
    function onAppClosed() {
            console.log("El backend reporta que la app se cerró. Restaurando UI...")
            // Llama aquí a tu función de restauración
            cancelLaunch()
        }
    launchAnim.stop()
    cancelAnim.start()
}


}