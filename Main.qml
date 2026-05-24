/*

  Viewport Main QML

  idk

*/
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

function forceOobeRestart() {
        console.log("[VPT] Función puente activada. Despertando Loader...")
        oobeLoader.active = true
        oobeLoader.source = "qrc:/vpt01/FirstStart.qml"
    }

// --- SISTEMA DE ESCALADO DINÁMICO (ZOOM) ---
property real zoomFactor: 1.0
property real baseDpScale: Math.max(1.0, Screen.pixelDensity / 96.0)
property real dpScale: baseDpScale * zoomFactor // Ahora es dinámico, ¡escala toda la UI junta!

// Variable global para trackear la posición
property point mousePos: Qt.point(0, 0)

Shortcut {
    sequence: "Ctrl++"
    onActivated: if (root.zoomFactor < 2.5) root.zoomFactor += 0.1
}
Shortcut {
    sequence: "Ctrl+-"
    onActivated: if (root.zoomFactor > 0.5) root.zoomFactor -= 0.1
}
Shortcut {
    sequence: "Ctrl+0" // Resetear zoom
    onActivated: root.zoomFactor = 1.0
}


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

    // Texto fallback
    Text {
        anchors.centerIn: parent
        text: iconRoot.appName.length > 0 ? iconRoot.appName.charAt(0).toUpperCase() : ""
        color: "#ffffff"
        font.pixelSize: parent.height * 0.6
        font.weight: Font.Bold
        // Si el IconImage no encuentra nada, el estado será 'Null' o 'Error'
        visible: img.status !== Image.Ready
        opacity: 0.8
    }

    // AHORA USAMOS IconImage EN LUGAR DE Image
    Image {
            id: img
            anchors.fill: parent
            anchors.margins: 10 * dpScale

            // LÓGICA INTELIGENTE:
            // Si empieza con '/', tratamos el string como ruta absoluta (file://)
            // Si no, es un nombre de icono del sistema
            source: iconName.startsWith("/") ? ("file://" + iconName) : ("image://icon/" + iconName)

            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }

        // Text fallback si no carga
        Text {
            anchors.centerIn: parent
            text: iconRoot.appName.charAt(0).toUpperCase()
            visible: img.status !== Image.Ready // Solo muestra la letra si la imagen falló
            color: "#ffffff"
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
    console.log("[vpt] Apps encontradas: " + systemApps.length)
        for (var x = 0; x < systemApps.length; x++) {
            console.log("[vpt] App " + x + ": " + systemApps[x].name + " -> " + systemApps[x].exec)
        }

    for (var i = 0; i < systemApps.length; i++) {
        var appData = systemApps[i]
        // Agregamos a la base de búsqueda
        baseSearchModel.append(appData)

        // Agregamos las primeras 8 apps al grid principal (o puedes filtrarlas por categoría)
        if (i < systemApps.length) {
            appModel.append(appData)
        }
    }
    updateSearchFilter("") // Inicializa la lista del buscador
}

// Función para actualizar el modelo filtrado según el texto
// Función para actualizar el modelo filtrado según el texto
function updateSearchFilter(text) {
    filteredSearchModel.clear()

    if (text === "") {
        for (var i = 0; i < baseSearchModel.count; i++) filteredSearchModel.append(baseSearchModel.get(i))
        return
    }

    var prefix = text.charAt(0)
    var query = text.substring(1).trim()
    var lowerQuery = query.toLowerCase()

    // 1. MODO CONSOLA ($)
    if (prefix === '$') {
        filteredSearchModel.append({
            name: "Ejecutar en terminal",
            category: query !== "" ? "> " + query : "Escribe un comando...",
            icon: "kitty", // Usa el ícono de terminal que tengas
            exec: "VPT_CMD|" + query
        })
        return
    }

    // 2. MODO INSTALADOR (@)
    if (prefix === '@') {
        filteredSearchModel.append({
            name: "Instalar paquete (APT)",
            category: query !== "" ? "apt install " + query : "Escribe el nombre de la app...",
            icon: "system-software-install", // O deja uno vacío
            exec: "VPT_APT|" + query
        })
        return
    }

    if (prefix === '#') {
        var sysCmds = [
            {n: "Apagar", c: "Alimentación", e: "VPT_SYS|poweroff"},
            {n: "Reiniciar", c: "Alimentación", e: "VPT_SYS|reboot"},
            {n: "Salir a TTY", c: "Alimentación", e: "VPT_SYS|exit_vpt"},
            {n: "Ajustar Volumen", c: "Audio", e: "VPT_SYS|volume"},
            {n: "Ajustar Brillo", c: "Pantalla", e: "VPT_SYS|brightness"},
            {n: "Redes WiFi", c: "Redes", e: "VPT_SYS|wifi"},
            {n: "Setup", c: "OOBE", e: "VPT_OOBE|"}
        ]

        for (var j = 0; j < sysCmds.length; j++) {
            if (query === "" || sysCmds[j].n.toLowerCase().includes(lowerQuery)) {
                filteredSearchModel.append({
                    name: sysCmds[j].n,
                    category: sysCmds[j].c,
                    icon: "",
                    exec: sysCmds[j].e
                })
            }
        }
        return
    }

    // MODO NORMAL (Búsqueda de Apps)
    var lowerText = text.toLowerCase()
    for (var k = 0; k < baseSearchModel.count; k++) {
        var item = baseSearchModel.get(k)
        if (item.name.toLowerCase().includes(lowerText) || item.category.toLowerCase().includes(lowerText)) {
            filteredSearchModel.append(item)
        }
    }
}

// MAIN.qml – función executeSmartAction (dentro del scope de la Window)
function executeSmartAction(execString, appName) {
    console.log("[vpt] Acción inteligente:", execString)
    hideAllPopups()

    if (execString.startsWith("VPT_CMD|")) {
        var cmd = execString.substring(8)
        if (cmd.length > 0) {
            terminalPopup.command = cmd
            terminalPopup.open()
        }
    }
    else if (execString.startsWith("VPT_APT|")) {
        var pkg = execString.substring(8)
        if (pkg.length > 0) {
            aptPopup.packageName = pkg
            aptPopup.open()
        }
    }
    else if (execString.startsWith("VPT_SYS|")) {
        var sysCmd = execString.substring(8)

        // ⚠️ Aquí usamos switch/case con los valores reales que generamos
        switch(sysCmd) {
        case "poweroff":
        case "reboot":
        case "exit_vpt":
            powerPopup.action = sysCmd
            powerPopup.open()
            break
        case "volume":
            volumePopup.open()
            break
        case "brightness":
            brightnessPopup.open()
            break
        case "wifi":
            wifiPopup.open()
            break
        default:
            // Cualquier otro comando directo (ej: kitty -e nmtui)
            AppBackend.openApp(sysCmd)
            break
        }
    }
    // 1. En el lugar donde procesás el clic del buscador:
    else if (execString.startsWith("VPT_OOBE|")) {
        console.log("[VPT] Ejecutando comando especial de OOBE...")
            AppBackend.resetSetup()
            oobeLoader.active = true // ¡Ahora sí existe y se puede activar!
    }
    else {
        // App normal
        AppBackend.openApp(execString)
    }

    searchOverlay.state = "HIDDEN"

            // 2. Limpiá el texto del input para que la próxima vez arranque vacío
            // Cambiá 'idDelInputText' por el ID real de tu TextField de búsqueda
            idDelInputText.text = ""

            // 3. Vaciá el modelo filtrado para borrar los resultados visuales de la RAM
            filteredSearchModel.clear()
}

function hideAllPopups() {
    terminalPopup.close()
    powerPopup.close()
    volumePopup.close()
    brightnessPopup.close()
    wifiPopup.close()
    aptPopup.close()
}

StyledPopup {
    id: terminalPopup
    property string command: ""
    width: Math.min(700 * dpScale, root.width * 0.9)
    height: 400 * dpScale
    accentColor: "#00e676"
    popupRadius: 12

    onOpened: {
        outputArea.text = "Ejecutando: " + command + "\n"
        AppBackend.runCommandWithOutput(command)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 15 * dpScale

        // Cabecera
        Text {
            text: "Resultado del comando"
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
        }

        // Área de salida
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            TextArea {
                id: outputArea
                readOnly: true
                color: "#ccddee"
                font.family: "Fira Code, monospace"
                font.pixelSize: 13 * dpScale
                background: Rectangle {
                    color: "#0e0e18"
                    radius: 8
                    border.color: "#2a2a3a"
                }
                padding: 10
            }
        }

        // Botón estilizado
        StyledButton {
            text: "Cerrar"
            Layout.minimumHeight: 44 * dpScale
            Layout.alignment: Qt.AlignRight
            onClicked: terminalPopup.close()
        }
    }

    Connections {
        target: AppBackend
        function onCommandOutput(output) {
            outputArea.append(output)
        }
    }
}

StyledPopup {
    id: powerPopup
    property string action: ""
    width: 300 * dpScale
    height: 280 * dpScale
    accentColor: "#ff5252"
    popupRadius: 16

    ColumnLayout {
        anchors.fill: parent
        spacing: 12 * dpScale

        Text {
            text: "Opciones de energía"
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        StyledButton {
            text: "⏻  Apagar"
            Layout.minimumHeight: 44 * dpScale
            buttonColor: "#ff5252"
            Layout.fillWidth: true
            onClicked: {
                AppBackend.openApp("loginctl poweroff")
                powerPopup.close()
            }
        }
        StyledButton {
            text: "↻  Reiniciar"
            Layout.minimumHeight: 44 * dpScale
            buttonColor: "#ffa726"
            Layout.fillWidth: true
            onClicked: {
                AppBackend.openApp("loginctl reboot")
                powerPopup.close()
            }
        }
        StyledButton {
            text: "↩  Salir a TTY"
            Layout.minimumHeight: 44 * dpScale
            Layout.fillWidth: true
            onClicked: {
                AppBackend.openApp("loginctl terminate-session $XDG_SESSION_ID")
                powerPopup.close()
            }
        }
        StyledButton {
            text: "Cancelar"
            Layout.minimumHeight: 44 * dpScale
            buttonColor: "#666666"
            Layout.fillWidth: true
            onClicked: powerPopup.close()
        }
    }
}

StyledPopup {
    id: volumePopup
    width: 350 * dpScale
    height: 200 * dpScale
    accentColor: "#29b6f6"

    onOpened: {
        volSlider.value = AppBackend.getVolume()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 15 * dpScale

        Text {
            text: "Ajustar volumen"
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "🔈"
                font.pixelSize: 20 * dpScale
            }
            Slider {
                id: volSlider
                from: 0; to: 100; stepSize: 1
                Layout.fillWidth: true
                background: Rectangle {
                    x: volSlider.leftPadding
                    y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200
                    implicitHeight: 4
                    width: volSlider.availableWidth
                    height: implicitHeight
                    radius: 2
                    color: "#3a3a4a"
                    Rectangle {
                        width: volSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#29b6f6"
                        radius: 2
                    }
                }
                onValueChanged: AppBackend.setVolume(value)
            }
            Text {
                text: "🔊"
                font.pixelSize: 20 * dpScale
            }
            Text {
                text: Math.round(volSlider.value) + "%"
                color: "#ffffff"
                font.bold: true
                Layout.preferredWidth: 40 * dpScale
            }
        }

        StyledButton {
            text: "Probar sonido"
            Layout.minimumHeight: 44 * dpScale
            Layout.alignment: Qt.AlignHCenter
            onClicked: AppBackend.playTestSound()
        }
    }
}

StyledPopup {
    id: brightnessPopup
    width: 350 * dpScale
    height: 180 * dpScale
    accentColor: "#ffd54f"

    onOpened: {
        briSlider.value = AppBackend.getBrightness()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 15 * dpScale

        Text {
            text: "Ajustar brillo"
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
        }

        RowLayout {
            Layout.fillWidth: true
            Text { text: "☀️"; font.pixelSize: 20 * dpScale }
            Slider {
                id: briSlider
                from: 0; to: 100; stepSize: 1
                Layout.fillWidth: true
                background: Rectangle {
                    x: briSlider.leftPadding
                    y: briSlider.topPadding + briSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200; implicitHeight: 4
                    width: briSlider.availableWidth; height: implicitHeight
                    radius: 2; color: "#3a3a4a"
                    Rectangle {
                        width: briSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#ffd54f"; radius: 2
                    }
                }
                onValueChanged: AppBackend.setBrightness(value)
            }
            Text {
                text: Math.round(briSlider.value) + "%"
                color: "#ffffff"
                font.bold: true
                Layout.preferredWidth: 40 * dpScale
            }
        }
    }
}

StyledPopup {
    id: wifiPopup
    width: 400 * dpScale
    height: 450 * dpScale
    accentColor: "#4fc3f7"

    ListModel { id: wifiModel }

    onOpened: {
        var networks = AppBackend.scanWifi()
        wifiModel.clear()
        for (var i = 0; i < networks.length; i++) {
            wifiModel.append(networks[i])
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12 * dpScale

        Text {
            text: "Redes WiFi disponibles"
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: wifiModel
            clip: true
            delegate: ItemDelegate {
                width: ListView.view.width
                text: modelData.ssid + (modelData.encrypted ? " 🔒" : "")
                background: Rectangle {
                    color: hovered ? "#2a2a3a" : "transparent"
                    radius: 6
                }
                onClicked: {
                    if (modelData.encrypted) {
                                        // Pedir contraseña
                    } else {
                        AppBackend.connectWifi(modelData.ssid, "")
                        wifiPopup.close()
                    }
                }
            }
        }

        StyledButton {
            text: "Configurar adaptador WiFi"
            Layout.minimumHeight: 44 * dpScale
            Layout.fillWidth: true
            onClicked: AppBackend.openApp("/vpt/adm/bin/netconfig.sh")
        }
    }
}

StyledPopup {
    id: aptPopup
    property string packageName: ""
    width: 500 * dpScale
    height: 400 * dpScale
    closePolicy: Popup.NoClose
    accentColor: "#ce93d8"

    ColumnLayout {
        anchors.fill: parent
        spacing: 15 * dpScale

        Text {
            text: "Instalar paquete: " + aptPopup.packageName
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
        }

        TextField {
            id: passwordField
            echoMode: TextInput.Password
            placeholderText: "Contraseña de sudo"
            Layout.fillWidth: true
            background: Rectangle {
                radius: 8
                color: "#1e1e2e"
                border.color: "#4fc3f7"
            }
            color: "#ffffff"
        }

        ProgressBar {
            id: progressBar
            from: 0; to: 100
            value: 0
            Layout.fillWidth: true
            visible: false
            background: Rectangle {
                implicitWidth: 200; implicitHeight: 6
                color: "#3a3a4a"
                radius: 3
            }
            contentItem: Item {
                Rectangle {
                    width: progressBar.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: "#ce93d8"
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            TextArea {
                id: aptLog
                readOnly: true
                color: "#ccddee"
                font.family: "monospace"
                font.pixelSize: 12 * dpScale
                background: Rectangle {
                    color: "#0e0e18"
                    radius: 8
                    border.color: "#2a2a3a"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            StyledButton {
                text: "Instalar"
                Layout.minimumHeight: 44 * dpScale
                buttonColor: "#ce93d8"
                onClicked: {
                    if (passwordField.text === "") return
                    aptLog.text = "Iniciando instalación...\n"
                    progressBar.visible = true
                    AppBackend.aptInstall(aptPopup.packageName, passwordField.text)
                }
            }
            StyledButton {
                text: "Cerrar"
                Layout.minimumHeight: 44 * dpScale
                onClicked: aptPopup.close()
            }
        }
    }

    Connections {
        target: AppBackend
        function onAptProgress(percent, line) {
            progressBar.value = percent
            aptLog.append(line)
        }
        function onAptFinished(success) {
            aptLog.append(success ? "Instalación completada." : "Error en la instalación.")
            progressBar.visible = false
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
                // Al usar onPressed, el buscador salta apenas el dedo toca el vidrio
                onPressed: {
                    if (searchOverlay.state !== "VISIBLE") {
                        updateSearchFilter("")
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
                if (item) executeSmartAction(item.exec, item.name)
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
                                                    console.log("[vpt] Clic en resultado: " + name)
                                                    executeSmartAction(model.exec, name)
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

    launchAnim.stop()
    cancelAnim.start()
}

Loader {
        id: oobeLoader
        // Se activa automáticamente cuando tu C++ dice que es el primer arranque
        active: AppBackend.isFirstRun
        anchors.fill: parent
        source: "qrc:/vpt01/FirstStart.qml"
        z: 99999 // Fuerza a que la interfaz de setup tape TODO el escritorio
    }
}