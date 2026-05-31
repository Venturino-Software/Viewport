/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VNT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import QtMultimedia
import QtQuick.Controls.Material 2.15 // Importá esto

Window {
id: root
// Tamaño adaptable a la pantalla (80% del escritorio, con mínimo)
width: Math.max(900, Screen.desktopAvailableWidth * 0.8)
height: Math.max(650, Screen.desktopAvailableHeight * 0.8)
visible: true
title: qsTr("Viewport Launcher")
color: "#05050a"  // BGCOLOR

Material.theme: Material.Dark
Material.accent: Material.Indigo

function forceOobeRestart() {
        console.log("[VPT] Función puente activada. Despertando Loader...")
        oobeLoader.active = true
        oobeLoader.source = "qrc:/vpt01/FirstStart.qml"
    }

// --- SISTEMA DE ESCALADO DINÁMICO (fZOOM) ---
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

// Coloca esto en cualquier parte de tu contenedor principal en QML
Shortcut {
    sequence: "Ctrl+Alt+Escape"
    context: Qt.ApplicationShortcut // Intenta capturar el atajo en cualquier ventana de tu app

    onActivated: {
        console.log("[QML] Atajo Ctrl+Alt+Esc presionado. Solicitando matar app...")
        if (typeof AppBackend !== "undefined") {
            AppBackend.terminateCurrentApp()
        }
    }
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


function ntftst() {
    // 1. Asegúrate de que la ruta sea correcta. Si están en la misma carpeta, esto está bien.
    var component = Qt.createComponent("StyledNotification.qml");

    // Función auxiliar para instanciar cuando esté listo
    function createAndShow() {
        if (component.status === Component.Ready) {

            // 2. Creamos el objeto. Pasamos mainWindow.contentItem (o null si mainWindow no existe)
            var parentItem = typeof mainWindow !== "undefined" ? mainWindow.contentItem : null;

            var notification = component.createObject(parentItem, {
                "titulo": "¡Hola Mundo!",
                "contenidoResumido": "Esta es una notificación de prueba.",
                "contenidoTotal": "¡Hello World desde QML! Esta es una notificación expandida.",
                "icono": "",
                "playSound": false,
                "duration": 5000,
                "bgColor": "#1a1c2b",
                "accentColor": "#7f99ff",
                "popupRadius": 10
            });

            if (notification !== null) {
                // 3. ¡CRÍTICO! Destruir el Popup cuando se cierre para evitar Memory Leaks
                notification.closed.connect(function() {
                    console.log("[ntftst] Liberando memoria de la notificación...");
                    notification.destroy();
                });

                // 4. Abrimos la notificación
                notification.open();
            } else {
                console.error("[ntftst] Error: createObject devolvió null.");
            }
        } else if (component.status === Component.Error) {
            console.error("[ntftst] Error al compilar el QML:", component.errorString());
        }
    }

    // Comprobamos el estado. Si está listo, lo creamos. Si está cargando, esperamos la señal.
    if (component.status === Component.Ready) {
        createAndShow();
    } else {
        console.log("[ntftst] Componente cargando, esperando señal statusChanged...");
        component.statusChanged.connect(createAndShow);
    }
}

// Función para actualizar el modelo filtrado según el texto
// Función para actualizar el modelo filtrado según el texto
function updateSearchFilter(text) {
    filteredSearchModel.clear()

    if (!text || text === "") {
        // recargar todas las apps (o lo que prefieras)
        for (var i = 0; i < baseSearchModel.count; i++)
            filteredSearchModel.append(baseSearchModel.get(i))
        return
    }
    const PFX = {
        TERMINAL: '$',
        APT: '@',
        SYSTEM: '#'
    }
    var prefix = text.charAt(0)
    var query = text.substring(1).trim()
    var lowerQuery = query.toLowerCase()

    // 1. MODO CONSOLA ($)
    if (prefix === PFX.TERMINAL) {
        var safeQuery = query.replace(/[;&|`$(){}[\]!#~*?<>\\]/g, '')
        filteredSearchModel.append({
            name: "Ejecutar en terminal",
            category: query !== "" ? "> " + safeQuery : "Escribe un comando...",
            icon: "kitty",
            exec: "VPT_CMD|" + safeQuery
        })
        return
    }

    // 2. MODO INSTALADOR (@)
    if (prefix === PFX.APT) {
        var safePackage = query.replace(/[^a-zA-Z0-9.+-]/g, '').substring(0, 100)
        filteredSearchModel.append({
            name: "Instalar paquete (APT)",
            category: query !== "" ? "apt install " + query : "Escribe el nombre de la app...",
            icon: "system-software-install", // O deja uno vacío
            exec: "VPT_APT|" + query
        })
        return
    }

    if (prefix === PFX.SYSTEM) {
        var sysCmds = [
            {n: "Actualizar", c: "Software", e: "VPT_SYS|update"},
            {n: "Version", c: "Sistema", e: "VPT_SYS|vn"},
            {n: "Apagar", c: "Alimentación", e: "VPT_SYS|poweroff"},
            {n: "Reiniciar", c: "Alimentación", e: "VPT_SYS|reboot"},
            {n: "Salir a TTY", c: "Alimentación", e: "VPT_SYS|exit_vpt"},
            {n: "Ajustar Volumen", c: "Audio", e: "VPT_SYS|volume"},
            {n: "Ajustar Brillo", c: "Pantalla", e: "VPT_SYS|brightness"},
            {n: "Redes WiFi", c: "Redes", e: "VPT_SYS|wifi"},
            {n: "tj-hyper Wifi Test", c: "Redes", e: "VPT_SYS|testwifi"},
        ]

        for (var j = 0; j < sysCmds.length; j++) {
            var cmd = sysCmds[j];
            var match = (query === "" ||
                         cmd.n.toLowerCase().includes(lowerQuery) ||
                         cmd.c.toLowerCase().includes(lowerQuery))
            if (match) {
                filteredSearchModel.append({
                    name: cmd.n,
                    category: cmd.c,
                    icon: "",
                    exec: cmd.e
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
    if (filteredSearchModel.count === 0 && text !== "") {
        filteredSearchModel.append({
            name: "Sin resultados",
            category: "",
            icon: "",
            exec: ""  // sin acción
        })
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
        case "update":
            updateManager.open()
            break
        case "notiftest":
            ntftst()
            break
        case "vn":
            versionPopup.open()
            break
        case "testwifi":
            speedTestPopup.open()
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
            searchInput.text = ""
}

function hideAllPopups() {
    terminalPopup.close()
    powerPopup.close()
    volumePopup.close()
    brightnessPopup.close()
    wifiPopup.close()

            // 3. Vaciá el modelo filtrado para borrar los resultados visuales de la RAM
            filteredSearchModel.clear()
    aptPopup.close()
}

function runManualCommand() {
    var rawCmd = cmdInput.text.trim();
    if (rawCmd === "") return;

    var prefix = terminalPrefixCombo.currentText;
    var fullCmd = (prefix === "$") ? rawCmd : prefix.toLowerCase() + " " + rawCmd;

    outputArea.append("\n$ " + fullCmd);
    outputArea.cursorPosition = outputArea.length;

    AppBackend.runCommandWithOutput(fullCmd);

    cmdInput.text = "";
    progressBar.value = 0.0;
    progressBar.visible = false;
}

StyledPopup {
    id: versionPopup
    objectName: "versionPopup"
    width: Math.min(800 * dp, parent ? parent.width * 0.95 : 800)
    height: 550 * dp
    popupRadius: 16 * dp
    fontType: "body"
    title: "ATP System Information"  // Se refleja en la propiedad interna del StyledPopup

    Shortcut {
        sequence: "Ctrl+Alt+V"
        onActivated: versionPopup.visible ? versionPopup.close() : versionPopup.open()
    }

    // El contenido se adapta al padding interno del StyledPopup (24*dp)
    ColumnLayout {
        anchors.fill: parent
        spacing: 16 * dp

        // Logo centrado (usa el color de acento como fondo sutil)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 231
            implicitHeight: 90
            color: versionPopup.bgColor
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)
            border.width: 1 * dp
            clip: true

            Image {
                id: atplogo
                width: 231            // ← tamaño fijo en dp
                height: 90
                anchors.centerIn: parent
                source: "/vpt/bin/src/atp-logo.png"
                sourceSize: Qt.size(64 * dpScale, 64 * dpScale)
                fillMode: Image.PreserveAspectFit
            }
        }
        // Separador decorativo
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40 * dp   // ← Usa la propiedad del layout
            color: "transparent"              // Opcional, pero explícito
            opacity: 0.3
        }

        // Título principal - ¡ELIMINA ESTE BLOQUE COMPLETO!
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "ATP System Information"
            font.family: root.activeFont
            font.pixelSize: 20 * dp
            font.bold: true
            color: versionPopup.accentColor
        }

        // Separador decorativo
        Rectangle {
            Layout.fillWidth: true
            height: 2 * dp
            color: root.accentColor
            opacity: 0.3
        }

        // Grid de información dinámica
        GridLayout {
            columns: 2
            columnSpacing: 16 * dp
            rowSpacing: 8 * dp
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8 * dp

            Repeater {
                model: [
                    { label: "Version:",    value: "26.2.2.orbit" },
                    { label: "Kernel:",     value: "Linux 6.12 LTS" },
                    { label: "Compiler:",   value: "GCC 13.2" },
                    { label: "Viewport: (st)",   value: "v1.2-stable" },
                    { label: "Viewport: (un)",   value: "v1.62-unstable" },
                    { label: "lib-vptcomponents",   value: "v1" },
                    { label: "lib-vptatp",   value: "v1" },
                    { label: "lib-vptversion",   value: "v1.1" },
                    { label: "lib-atpterm",   value: "v2" },
                    { label: "lib-atpcageauto",   value: "v4.62" },
                    { label: "lib-vpticonprovider",   value: "v2" },
                    { label: "lib-vptcommandpill",   value: "v3.12" },
                    { label: "lib-atp-cmdwrap",   value: "v4" },
                    { label: "lib-atp-pkitwcmd",   value: "v2" },
                    { label: "lib-tj-eds",   value: "h" },
                    { label: "lib-atp-parser",   value: "v14" },
                    { label: "lib-atp-loader",   value: "v1" },
                    { label: "lib-vpt-hyper",   value: "v2" },
                    { label: "lib-tj-hyper",   value: "v2" },
                    { label: "lib-pc-portable",   value: "v2" },
                    { label: "lib-pc-mobility",   value: "v1" }
                ]
                delegate: RowLayout {
                    Text {
                        text: modelData.label
                        color: "#aaaaaa"
                        font.pixelSize: 14 * dp
                        font.family: root.activeFont
                    }
                    Text {
                        text: modelData.value
                        color: "#ffffff"
                        font.pixelSize: 14 * dp
                        font.bold: true
                        font.family: root.activeFont
                    }
                }
            }
        }

        // Espaciador flexible (empuja el footer hacia abajo)
        Item { Layout.fillHeight: true }

        // Footer
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "ATP es un entorno modular. Todos los derechos reservados."
            font.pixelSize: 11 * dp
            color: "#666666"
            font.family: root.activeFont
        }
    }
}

StyledPopup {
    id: terminalPopup
    property string command: ""

    width: Math.min(800 * dpScale, parent ? parent.width * 0.95 : 800)
    height: 550 * dpScale
    accentColor: "#00e676"
    popupRadius: 16 * dpScale
    fontType: "body"

    onOpened: {
        outputArea.text = "Ejecutando: " + command + "\n"
        progressBar.value = 0
        progressBar.visible = false
        if (command !== "") {
            AppBackend.runCommandWithOutput(command)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20 * dpScale
        spacing: 12 * dpScale

        // --- CABECERA (ahora con fuente mono) ---
        Text {
            text: "Terminal de Viewport"
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
            FontManager.titleFontFamily : "DejaVu Sans"
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // --- ÁREA DE SALIDA ---
        ScrollView {
            id: scrollArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            TextArea {
                id: outputArea
                readOnly: true
                color: "#ccddee"
                font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.monoFontFamily) ?
                             FontManager.monoFontFamily : "monospace"
                font.pixelSize: 13 * dpScale
                wrapMode: Text.WrapAnywhere

                background: Rectangle {
                    color: "#0e0e18"
                    radius: 8 * dpScale
                    border.color: "#2a2a3a"
                }
                padding: 12 * dpScale
            }
        }

        // --- BARRA DE PROGRESO ---
        ProgressBar {
            id: progressBar
            Layout.fillWidth: true
            height: 6 * dpScale
            visible: false
            value: 0.0

            background: Rectangle {
                color: "#1e1e2e"
                radius: 3 * dpScale
            }
            contentItem: Item {
                Rectangle {
                    width: progressBar.visualPosition * parent.width
                    height: parent.height
                    radius: 3 * dpScale
                    color: terminalPopup.accentColor
                    Behavior on width { NumberAnimation { duration: 150 } }
                }
            }
        }

        // --- INPUT MANUAL (selector + campo + botón) ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * dpScale

            // Selector de prefijo compacto y redondeado
            ComboBox {
                id: terminalPrefixCombo
                model: ["$", "Apt", "Sudo", "Sh"]
                Layout.preferredWidth: 90 * dpScale
                Layout.fillHeight: true

                background: Rectangle {
                    color: "#1e1e2e"
                    radius: 8 * dpScale
                    border.color: terminalPrefixCombo.activeFocus ? terminalPopup.accentColor : "#333344"
                }

                contentItem: Text {
                    text: terminalPrefixCombo.displayText
                    color: terminalPopup.accentColor
                    font.bold: true
                    font.family: outputArea.font.family
                    font.pixelSize: 13 * dpScale
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                popup: Popup {
                    y: -height - (8 * dpScale)
                    width: terminalPrefixCombo.width
                    implicitHeight: contentItem.implicitHeight
                    padding: 4 * dpScale

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: terminalPrefixCombo.popup.visible ? terminalPrefixCombo.delegateModel : null
                        currentIndex: terminalPrefixCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator { }
                    }

                    background: Rectangle {
                        color: "#1e1e2e"
                        radius: 12 * dpScale
                        border.color: terminalPopup.accentColor
                    }
                }

                delegate: ItemDelegate {
                    width: terminalPrefixCombo.width
                    height: 36 * dpScale
                    contentItem: Text {
                        text: modelData
                        color: highlighted ? terminalPopup.accentColor : "#ffffff"
                        font.bold: highlighted
                        font.family: outputArea.font.family
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        color: highlighted ? Qt.darker(terminalPopup.accentColor, 3.0) : "transparent"
                        radius: 8 * dpScale
                    }
                }
            }

            // Campo de comando con detección automática de prefijos
            TextField {
                id: cmdInput
                Layout.fillWidth: true
                placeholderText: "Escribe un comando aquí..."
                color: "#ffffff"
                font.family: outputArea.font.family
                font.pixelSize: 13 * dpScale
                padding: 10 * dpScale

                background: Rectangle {
                    color: "#1e1e2e"
                    radius: 8 * dpScale
                    border.color: cmdInput.activeFocus ? terminalPopup.accentColor : "#333344"
                }

                // LÓGICA DE DETECCIÓN AUTOMÁTICA (heredada de CommandPill)
                property bool _updatingText: false

                onTextChanged: {
                    if (_updatingText) return

                    let t = text
                    let rules = [
                        { keyword: "sudo", index: 2, startOnly: false },
                        { keyword: "apt",  index: 1, startOnly: true  },
                        { keyword: "sh",   index: 3, startOnly: true  }
                    ]

                    for (let r of rules) {
                        let match = null
                        if (r.startOnly) {
                            match = t.match(new RegExp(`^\\s*${r.keyword}(?=\\s|$)`, "i"))
                        } else {
                            match = t.match(new RegExp(`\\b${r.keyword}(?=\\s|$)`, "i"))
                        }

                        if (match) {
                            if (terminalPrefixCombo.currentIndex !== r.index) {
                                _updatingText = true
                                terminalPrefixCombo.currentIndex = r.index
                                let newText = t.slice(0, match.index) + t.slice(match.index + match[0].length)
                                cmdInput.text = newText.trim().replace(/\s+/g, " ")
                                _updatingText = false
                            }
                            break
                        }
                    }
                }

                onAccepted: runManualCommand()
            }

            StyledButton {
                text: "Ejecutar"
                Layout.minimumHeight: cmdInput.height
                onClicked: runManualCommand()
            }
        }

        // --- FOOTER ---
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8 * dpScale
            spacing: 12 * dpScale

            Text {
                text: "⚠️"
                font.family: outputArea.font.family
                font.pixelSize: 18 * dpScale
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: "Viewport tiene permisos infinitos. Use SUDO con cuidado."
                color: "#ffaa00"
                font.family: outputArea.font.family
                font.pixelSize: 12 * dpScale
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            StyledButton {
                text: "Cerrar"
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.minimumHeight: 40 * dpScale
                Layout.preferredWidth: 100 * dpScale
                onClicked: terminalPopup.close()
            }
        }
    }

    // --- CONEXIONES AL BACKEND ---
    Connections {
        target: AppBackend
        function onCommandOutput(output) {
            outputArea.append(output)
            outputArea.cursorPosition = outputArea.length

            var match = output.match(/(\d{1,3})\s*%/);
            if (match && match[1]) {
                var percent = parseInt(match[1]);
                if (percent >= 0 && percent <= 100) {
                    progressBar.visible = true;
                    progressBar.value = percent / 100.0;
                }
            }
        }
    }

    // --- LÓGICA DE EJECUCIÓN UNIFICADA (misma que CommandPill.tryExecute) ---
    function runManualCommand() {
        var rawCmd = cmdInput.text.trim();
        if (rawCmd === "") return;

        var prefix = terminalPrefixCombo.currentText;
        var fullCmd;

        if (prefix === "Sudo") {
            fullCmd = "/usr/bin/pkexec /usr/bin/" + rawCmd;
        } else if (prefix === "Apt") {
            fullCmd = "/usr/bin/pkexec /usr/bin/apt " + rawCmd;
        } else if (prefix === "$") {
            fullCmd = rawCmd;
        } else if (prefix === "Sh") {
            fullCmd = "/usr/bin/sh " + rawCmd;
        } else {
            fullCmd = "/usr/bin/" + prefix.toLowerCase() + " " + rawCmd;
        }

        outputArea.append("\n$ " + fullCmd);
        outputArea.cursorPosition = outputArea.length;

        AppBackend.runCommandWithOutput(fullCmd);

        cmdInput.text = "";
        progressBar.value = 0.0;
        progressBar.visible = false;
    }
}

StyledPopup {
  id: sudoWarningPopup
  property string pendingCommand: ""
  width: Math.min(450 * dpScale, parent.width * 0.9)
  disableDefs: true          // 1. Apaga el centerIn nativo
// 2. Le dice que use la posición alta
  height: 250 * dpScale
  accentColor: "#ff4d4d" // Rojo para advertencia
  popupRadius: 16 * dpScale
  ColumnLayout {
      anchors.fill: parent
      anchors.margins: 20 * dpScale
      spacing: 10 * dpScale

      Text {
          text: "Sudo: Viewport"
          color: "#ffffff"
          font.pixelSize: 20 * dpScale
          font.bold: true
          Layout.alignment: Qt.AlignHCenter
      }

      Text {
          text: "¿Confirmas que quieres hacer esta acción?"
          color: "#ffffff"
          font.pixelSize: 16 * dpScale
          Layout.alignment: Qt.AlignHCenter
      }

      Text {
          text: "Comando: \"" + sudoWarningPopup.pendingCommand + "\""
          color: "#aaaaaa"
          font.pixelSize: 12 * dpScale
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
      }

      Text {
          text: "Te preguntamos esto debido a que viewport tiene permisos infinitos sobre tu sistema, ejecutar comandos peligrosos en viewport puede traer consecuencias graves."
          color: "#aaaaaa"
          font.pixelSize: 12 * dpScale
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
      }

      Item { Layout.fillHeight: true } // Spacer

      RowLayout {
          Layout.fillWidth: true
          spacing: 15 * dpScale

          StyledButton {
              text: "No"
              Layout.fillWidth: true
              onClicked: sudoWarningPopup.close()
              animationId: 2
          }

          StyledButton {
              text: "Sí, ejecutar"
              Layout.fillWidth: true
              buttonColor: "#ff4d4d"
              onClicked: {
                  sudoWarningPopup.close();
                  myCommandPill.runInTerminal(sudoWarningPopup.pendingCommand);
              }
          }
      }
  }
}


/*
  UPDATER
*/
StyledPopup {
    id: updateManager
    width: 500 * dpScale
    height: 400 * dpScale
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    accentColor: "#7f99ff"
    title: "Gestor de actualizaciones VPT"

    // Propiedades internas
    property string selectedChannel: ""
    readonly property string sourcesListPath: "/etc/apt/sources.list.d/viewport.list"
    property var updatesConn: null
    property int pendingUpdatesCount: 0
    property string pendingPackagesList: ""
    property bool checking: false
    property bool updating: false
    property bool updatePopupOpen: false

    // Referencia al componente StyledPopup (se usará para crear popups hijos)
    property var popupComponent: null

    onOpened: {
        // Pequeño retraso para que el backend esté listo
        Qt.callLater(function() {
            readChannelAndInit()
        })
    }

    // Elimina Component.onCompleted (o déjalo solo para cargar popupComponent)
    // Para depuración: imprime quién cierra el popup
    onClosed: {
        console.log("UpdateManager cerrado. Stack: " + new Error().stack)
        timerCheck.stop()
        if (updatesConn) updatesConn.disconnect()
    }

    Component.onCompleted: {
        popupComponent = Qt.createComponent("StyledPopup.qml")
        if (popupComponent.status !== Component.Ready) {
            console.error("No se pudo cargar StyledPopup.qml:", popupComponent.errorString())
        }
    }

    function readChannelAndInit() {
        let content = AppBackend.readFile(sourcesListPath)
        console.log("=== readChannelAndInit ===")
        console.log("Contenido CRUDO del archivo:", JSON.stringify(content))

        if (!content || content === "") {
            console.log("Archivo vacío → mostrar selector de canal")
            showChannelConfigPopup()
            return
        }

        let channel = "desconocido"
        if (content.includes("unstable")) {
            channel = "unstable"
        } else if (content.includes("stable")) {
            channel = "stable"
        }

        console.log("Canal detectado:", channel)
        selectedChannel = channel
        selectedChannelChanged()  // Forzar notificación

        if (selectedChannel !== "" && selectedChannel !== "desconocido") {
            checkForUpdates()

        }
    }
    // ─────────────────────────────────────────────────
    // POPUP DE SELECCIÓN DE CANAL (stable / unstable)
    // ─────────────────────────────────────────────────
    function showChannelConfigPopup() {
        if (!popupComponent || popupComponent.status !== Component.Ready) return

        let configPopup = popupComponent.createObject(Overlay.overlay, {
            width: 400 * dpScale,
            height: 200 * dpScale,
            modal: true,
            closePolicy: Popup.CloseOnEscape,
            accentColor: "#ffaa44",
            title: "Configurar canal de actualizaciones"
        })

        // Crear el contenido a partir del Component estático
        let contentObj = channelConfigContent.createObject(configPopup)
        contentObj.popupRef = configPopup
        configPopup.contentItem = contentObj

        configPopup.open()
    }

    Component {
        id: channelConfigContent
        ColumnLayout {
            property var popupRef: null

            anchors.fill: parent
            anchors.margins: 20 * dpScale
            spacing: 15 * dpScale

            Text {
                text: "Elige el canal de distribución para las actualizaciones del sistema."
                color: "#cccccc"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font.pixelSize: 13 * dpScale
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 15 * dpScale

                StyledButton {
                    text: "CANAL STABLE"
                    buttonColor: "#2ecc71"
                    Layout.fillWidth: true
                    onClicked: {
                        updateManager.configureChannel("stable")  // ← funciona porque updateManager está en contexto
                        popupRef.close()
                    }
                }
                StyledButton {
                    text: "CANAL UNSTABLE"
                    buttonColor: "#e67e22"
                    Layout.fillWidth: true
                    onClicked: {
                        updateManager.configureChannel("unstable")
                        popupRef.close()
                    }
                }
            }
        }
    }
    function configureChannel(channel) {
        selectedChannel = channel
        let repoLine = `deb [signed-by=/etc/apt/keyrings/vpt-archive-keyring.gpg] http://vpt.soyss.cc ${channel} main`
        let cmd = `echo "${repoLine}" | pkexec tee ${sourcesListPath} > /dev/null`
        AppBackend.runPkexec(cmd)
        // Forzar notificación de cambio (por si acaso)
        selectedChannelChanged()
        onSelectedChannelChanged: {
            console.log("selectedChannel cambió a:", selectedChannel)
        }
        // Esperar un momento a que se escriba el archivo y luego comprobar
        timerCheck.start()
    }

    Timer {
        id: timerCheck
        interval: 800
        onTriggered: updateManager.checkForUpdates()
    }

    // ─────────────────────────────────────────────────
    // COMPROBACIÓN DE ACTUALIZACIONES
    // ─────────────────────────────────────────────────
    function checkForUpdates() {
        if (checking) {
            console.log("checkForUpdates: ya en curso")
            return
        }
        checking = true
        // Desconectar conexión anterior de forma segura
        if (updatesConn) {
            AppBackend.updatesAvailable.disconnect(updatesConn)
            updatesConn = null
        }
        updatesConn = function(count, pkgList) {
            checkTimeout.stop()
            checking = false
            pendingUpdatesCount = count
            pendingPackagesList = pkgList
            if (count > 0) {
                showUpdateAvailablePopup(count, pkgList)
                AppBackend.playSound("detail.wav")
            } else {
                showInfoPopup("El sistema está actualizado ✓", 2000)
                AppBackend.playSound("subt-ui.wav")
            }
            // Desconectar esta conexión después de usarla
            AppBackend.updatesAvailable.disconnect(updatesConn)
            updatesConn = null
        }
        AppBackend.updatesAvailable.connect(updatesConn)
        AppBackend.checkForUpdates()
        checkTimeout.start()
    }

    Timer {
        id: checkTimeout
        interval: 30000
        onTriggered: {
            checking = false
            showInfoPopup("Error: la verificación de actualizaciones no respondió.", 5000, "#ff6b6b")
            if (updatesConn) updatesConn.disconnect()
            updatesConn = null
        }
    }

    // Pequeña notificación emergente (info/error)
    function showInfoPopup(message, duration, accent) {
        if (!popupComponent || popupComponent.status !== Component.Ready) return
        let pop = popupComponent.createObject(Overlay.overlay, {
            width: 300 * dpScale,
            height: 80 * dpScale,
            modal: false,
            closePolicy: Popup.NoAutoClose,
            accentColor: accent || "#2ecc71",
            title: "Información"
        })
        pop.contentItem = Qt.createQmlObject(`
            import QtQuick
            Text {
                anchors.centerIn: parent
                text: ${JSON.stringify(message)}
                color: "white"
                wrapMode: Text.WordWrap
                font.pixelSize: 13 * ${dpScale}
            }
        `, pop)
        pop.open()

        // Autocierre
        Qt.createQmlObject(`
            import QtQuick
            Timer {
                interval: ${duration}
                running: true
                onTriggered: {
                    parent.close()
                    destroy()
                }
            }
        `, pop)
    }

    // ─────────────────────────────────────────────────
    // POPUP DE ACTUALIZACIONES DISPONIBLES
    // ─────────────────────────────────────────────────
    function showUpdateAvailablePopup(count, pkgList) {
        if (updatePopupOpen) {
            console.log("Ya hay un popup de actualización abierto")
            return
        }
        if (!popupComponent || popupComponent.status !== Component.Ready) return
            updatePopupOpen = true

        let pop = popupComponent.createObject(Overlay.overlay, {
            width: 450 * dpScale,
            height: 300 * dpScale,
            modal: true,
            closePolicy: Popup.CloseOnEscape,
            accentColor: "#f39c12",
            title: `📦 ${count} actualización(es) disponible(s)`
        })
        pop.onClosed.connect(function() {
            updatePopupOpen = false
        })
        pop.contentItem = Qt.createQmlObject(`
            import QtQuick
            import QtQuick.Layouts

            ColumnLayout {
                property var popupRef: null
                anchors.fill: parent
                anchors.margins: 20 * ${dpScale}
                spacing: 12 * ${dpScale}

                Text {
                    text: "Paquetes: " + ${JSON.stringify(pkgList)}
                    color: "#dddddd"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.pixelSize: 12 * ${dpScale}
                    font.family: "monospace"
                }

                Text {
                    text: "¿Desea instalarlas ahora?"
                    color: "white"
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 15 * ${dpScale}

                    StyledButton {
                        text: "Actualizar ahora"
                        buttonColor: "#2ecc71"
                        Layout.fillWidth: true
                        onClicked: {
                            popupRef.close()
                            updateManager.startUpgrade()
                        }
                    }
                    StyledButton {
                        text: "Recordar más tarde"
                        Layout.fillWidth: true
                        onClicked: popupRef.close()
                    }
                }
            }
        `, pop, "dynamicUpdateLayout")

        pop.contentItem.popupRef = pop
        pop.open()
    }

    // ─────────────────────────────────────────────────
    // POPUP DE ACTUALIZACIÓN (TERMINAL)
    // ─────────────────────────────────────────────────
    function startUpgrade() {
        if (updating) return
        updating = true

        let termPopup = popupComponent.createObject(Overlay.overlay, {
            width: 700 * dpScale,
            height: 500 * dpScale,
            modal: true,
            closePolicy: Popup.CloseOnEscape,
            accentColor: "#2ecc71",
            title: "Actualizando sistema"
        })

        termPopup.contentItem = Qt.createQmlObject(`
            import QtQuick
            import QtQuick.Controls
            import QtQuick.Layouts

            ColumnLayout {
                property var popupRef: null
                property alias progressBar: upgradeProgress
                property alias logArea: logArea

                anchors.fill: parent
                anchors.margins: 20 * ${dpScale}
                spacing: 12 * ${dpScale}

                ProgressBar {
                    id: upgradeProgress
                    Layout.fillWidth: true
                    value: 0
                    visible: false
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    TextArea {
                        id: logArea
                        readOnly: true
                        color: "#ccddee"
                        font.family: "monospace"
                        font.pixelSize: 12 * ${dpScale}
                        background: Rectangle { color: "#0e0e18"; radius: 6 }
                    }
                }
                StyledButton {
                    text: "Cerrar"
                    Layout.alignment: Qt.AlignRight
                    onClicked: popupRef.close()
                }
            }
        `, termPopup, "dynamicTerminalLayout")

        termPopup.contentItem.popupRef = termPopup

        // Conectar salida del comando
        var conn = AppBackend.commandOutput.connect(function(out) {
            if (termPopup.contentItem && termPopup.contentItem.logArea) {
                termPopup.contentItem.logArea.append(out)
                // Detectar porcentaje para la barra
                var match = out.match(/(\d{1,3})\s*%/);
                if (match) {
                    termPopup.contentItem.progressBar.visible = true
                    termPopup.contentItem.progressBar.value = parseInt(match[1]) / 100
                }
            }
        })

        // Ejecutar actualización
        AppBackend.runPkexec("/usr/bin/apt upgrade -y 2>&1")

        // Cuando se cierre el popup, desconectar y reiniciar verificación
        termPopup.onClosed.connect(function() {
            updating = false
            conn.disconnect()
            timerCheck.start()
        })

        termPopup.open()
    }

    // ─────────────────────────────────────────────────
    // UI DEL POPUP PRINCIPAL (mientras se comprueba)
    // ─────────────────────────────────────────────────
    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20 * dpScale
        spacing: 15 * dpScale

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Canal actual: "
                color: "#cccccc"
                font.pixelSize: 14 * dpScale
            }
            Text {
                text: {
                    if (updateManager.selectedChannel === "") return "SIN CONFIGURAR"
                    if (updateManager.selectedChannel === "desconocido") return "DESCONOCIDO"
                    return updateManager.selectedChannel.toUpperCase()
                }
                color: updateManager.accentColor
                font.bold: true
                font.pixelSize: 14 * dpScale
            }
            Item { Layout.fillWidth: true }
            StyledButton {
                text: "Cambiar canal"
                fontSize: 11 * dpScale
                minHeight: 30 * dpScale
                onClicked: updateManager.showChannelConfigPopup()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 120 * dpScale
            color: "#0a0c16"
            radius: 8 * dpScale
            border.color: "#2a2c3a"

            Column {
                anchors.centerIn: parent
                spacing: 8
                BusyIndicator {
                    running: updateManager.checking  // ← usa updateManager.
                    visible: updateManager.checking  // ← usa updateManager.
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: checking ? "Buscando actualizaciones..." :
                           (pendingUpdatesCount > 0 ? `📦 ${pendingUpdatesCount} actualizaciones disponibles` : "✅ Sistema actualizado")
                    color: pendingUpdatesCount > 0 ? "#f1c40f" : "#2ecc71"
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                TextArea {
                    readOnly: true
                    color: "#bbbbbb"
                    font.pixelSize: 11 * dpScale
                    font.family: "monospace"
                    background: Rectangle { color: "transparent" }
                    text: pendingUpdatesCount > 0 ? pendingPackagesList : ""
                    wrapMode: Text.WordWrap
                    width: parent.width - 20
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 15 * dpScale
            StyledButton {
                text: "Buscar actualizaciones"
                buttonColor: if (updateManager.selectedChannel == "unstable") return "#e67e22"; else if (updateManager.selectedChannel == "stable") return "#2ecc71"; else return "#aaaaaa"
                Layout.fillWidth: true
                onClicked: updateManager.checkForUpdates()
            }
            StyledButton {
                text: "Actualizar ahora"
                Layout.fillWidth: true
                buttonColor: pendingUpdatesCount > 0 ? "#2ecc71" : "#555"
                enabled: pendingUpdatesCount > 0 && !updating
                onClicked: updateManager.startUpgrade()
            }
            StyledButton {
                text: "Cerrar"
                Layout.fillWidth: true
                onClicked: updateManager.close()
            }
        }
    }
}

StyledPopup {
  id: powerWarn
  property string pendingCommand: ""
  width: Math.min(450 * dpScale, parent.width * 0.9)
  disableDefs: false       // 1. Apaga el centerIn nativo
// 2. Le dice que use la posición alta
  height: 250 * dpScale
  accentColor: "#ff4d4d" // Rojo para advertencia
  popupRadius: 16 * dpScale
  ColumnLayout {
      anchors.fill: parent
      anchors.margins: 20 * dpScale
      spacing: 10 * dpScale

      Text {
          text: "Viewport"
          color: "#ffffff"
          font.pixelSize: 20 * dpScale
          font.bold: true
          Layout.alignment: Qt.AlignHCenter
      }

      Text {
          text: "¿Confirmas que quieres hacer esta acción?"
          color: "#ffffff"
          font.pixelSize: 16 * dpScale
          Layout.alignment: Qt.AlignHCenter
      }

      Text {
          text: "Asegurate de tener todo guardado, debido a que estas acciones pueden hacer perder tu progreso"
          color: "#aaaaaa"
          font.pixelSize: 12 * dpScale
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
      }

      Item { Layout.fillHeight: true } // Spacer

      RowLayout {
          Layout.fillWidth: true
          spacing: 15 * dpScale

          StyledButton {
              text: "No"
              Layout.fillWidth: true
              onClicked: powerWarn.close()
          }

          StyledButton {
              text: "Sí, ejecutar"
              Layout.fillWidth: true
              onClicked: {
                  powerWarn.close();
                  myCommandPill.runInTerminal(powerWarn.pendingCommand);
              }
          }
      }
  }
}

// --

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
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
            FontManager.titleFontFamily : "DejaVu Sans"
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        StyledButton {
            text: "⏻  Apagar"
            Layout.minimumHeight: 44 * dpScale
            buttonColor: "#d32f2f"
            Layout.fillWidth: true
            onClicked: {
                powerWarn.pendingCommand = "/usr/bin/pkexec /usr/bin/systemctl poweroff"
                powerWarn.open()
            }
        }
        StyledButton {
            text: "↻  Reiniciar"
            Layout.minimumHeight: 44 * dpScale
            buttonColor: "#e65100"
            Layout.fillWidth: true
            onClicked: {
                powerWarn.pendingCommand = "/usr/bin/pkexec /usr/bin/systemctl reboot"
                powerWarn.open()
            }
        }
        StyledButton {
            text: "🔄  Recargar entorno gráfico"
            Layout.minimumHeight: 44 * dpScale
            Layout.fillWidth: true
            onClicked: {
                powerWarn.pendingCommand = "/usr/bin/pkexec /usr/bin/pkill -9 cage"
                powerWarn.open()
            }
        }
        StyledButton {
            text: "Cancelar"
            Layout.minimumHeight: 44 * dpScale
            buttonColor: "#666666"
            Layout.fillWidth: true
            onClicked: powerPopup.close()
            animationId: 2
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
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
                FontManager.titleFontFamily : "DejaVu Sans"
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
            onClicked: AppBackend.playSound("pop.wav")
            animationId: 2
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
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
                FontManager.titleFontFamily : "DejaVu Sans"
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
    width: 450 * dpScale
    height: 550 * dpScale
    accentColor: "#4fc3f7"

    // Paleta de colores Dark Theme integrada
    property color bgColor: "#1e1e2e"
    property color surfaceColor: "#2a2a3a"
    property color surfaceHover: "#3b3b4f"
    property color textColor: "#ffffff"
    property color textMuted: "#a6adc8"

    property string currentInterface: ""

    ListModel { id: interfacesModel }
    ListModel { id: wifiModel }

    onOpened: {
        loadInterfaces()
    }

    function loadInterfaces() {
        interfacesModel.clear()
        var ifaces = AppBackend.getWifiInterfaces()
        for (var i = 0; i < ifaces.length; i++) {
            interfacesModel.append({ "ifaceName": ifaces[i] })
        }

        // Auto-seleccionar la primera antena si existe
        if (ifaces.length > 0) {
            currentInterface = ifaces[0]
            refreshNetworks()
        }
    }

    function refreshNetworks() {
        wifiModel.clear()
        if (currentInterface === "") return;

        var networks = AppBackend.scanWifi(currentInterface)
        for (var i = 0; i < networks.length; i++) {
            wifiModel.append({
                "ssid": networks[i].ssid,
                "encrypted": networks[i].encrypted
            })
        }
    }

    // Fondo base oscuro para el popup (asumiendo que StyledPopup acepta background, si no, usa un Rectangle)
    Rectangle {
        anchors.fill: parent
        color: wifiPopup.bgColor
        radius: 10 * dpScale
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20 * dpScale
        spacing: 16 * dpScale

        // --- ENCABEZADO ---
        Text {
            text: "Conexión Inalámbrica"
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ? FontManager.titleFontFamily : "DejaVu Sans"
            font.pixelSize: 22 * dpScale
            color: wifiPopup.textColor
            font.bold: true
        }

        // --- SELECTOR DE INTERFAZ (ANTENA) ---
        RowLayout {
            Layout.fillWidth: true
            visible: interfacesModel.count > 0

            Text {
                text: "Adaptador:"
                color: wifiPopup.textMuted
                font.pixelSize: 14 * dpScale
            }

            ComboBox {
                Layout.fillWidth: true
                model: interfacesModel
                textRole: "ifaceName"

                // Personalización minimalista para adaptarse al tema
                background: Rectangle {
                    color: wifiPopup.surfaceColor
                    radius: 6 * dpScale
                }
                contentItem: Text {
                    text: parent.currentText
                    color: wifiPopup.accentColor
                    font.pixelSize: 14 * dpScale
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                onCurrentTextChanged: {
                    if (currentText !== "") {
                        wifiPopup.currentInterface = currentText
                        wifiPopup.refreshNetworks()
                    }
                }
            }

            // Botón de recarga (Texto en lugar de icono)
            StyledButton {
                text: "Buscar"
                Layout.preferredHeight: 36 * dpScale
                onClicked: wifiPopup.refreshNetworks()
            }
        }

        // Mensaje si no hay antena
        Text {
            visible: interfacesModel.count === 0
            text: "No se detectaron adaptadores Wi-Fi."
            color: "#f28b82" // Rojo suave
            font.pixelSize: 14 * dpScale
            Layout.alignment: Qt.AlignHCenter
        }

        // --- LISTA DE REDES ---
        ListView {
            id: networkList
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: wifiModel
            clip: true
            spacing: 8 * dpScale

            delegate: ItemDelegate {
                width: ListView.view.width
                height: 60 * dpScale

                background: Rectangle {
                    color: parent.hovered ? wifiPopup.surfaceHover : wifiPopup.surfaceColor
                    radius: 8 * dpScale

                    // Borde sutil al pasar el ratón
                    border.color: parent.hovered ? wifiPopup.accentColor : "transparent"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12 * dpScale
                    spacing: 10 * dpScale

                    // Nombre de la red
                    Text {
                        text: model.ssid
                        color: wifiPopup.textColor
                        font.pixelSize: 16 * dpScale
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Etiqueta de Seguridad (Reemplaza al símbolo del candado)
                    Rectangle {
                        Layout.preferredWidth: securityLabel.width + 16 * dpScale
                        Layout.preferredHeight: securityLabel.height + 8 * dpScale
                        color: model.encrypted ? "#422828" : "#28422e" // Fondo rojo o verde muy oscuro
                        border.color: model.encrypted ? "#f28b82" : "#81c995"
                        border.width: 1
                        radius: 4 * dpScale

                        Text {
                            id: securityLabel
                            anchors.centerIn: parent
                            text: model.encrypted ? "Protegida" : "Abierta"
                            color: model.encrypted ? "#f28b82" : "#81c995"
                            font.pixelSize: 11 * dpScale
                            font.bold: true
                        }
                    }
                }

                onClicked: {
                    if (model.encrypted) {
                        // Importante: Pásale también la interfaz al popup de contraseña
                        wifiPasswordPopup.ssid = model.ssid
                        wifiPasswordPopup.iface = wifiPopup.currentInterface
                        wifiPasswordPopup.open()
                    } else {
                        AppBackend.connectWifi(wifiPopup.currentInterface, model.ssid, "")
                        wifiPopup.close()
                    }
                }
            }

            // Animación al cargar las listas
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
                NumberAnimation { property: "x"; from: -50; to: 0; duration: 300; easing.type: Easing.OutQuad }
            }
        }
    }
}
// Popup para pedir contraseña de red WiFi encriptada
StyledPopup {
    id: wifiPasswordPopup
    property string ssid: ""
    property string iface: ""
    property string securityType: "" // <-- CAMBIO 4: Nueva propiedad receptora

    width: 400 * dpScale
    height: 240 * dpScale
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Forzamos fondo plano Material Dark sin bordes llamativos externos
    background: Rectangle {
        color: "#1e1e2e" // Mismo fondo que el principal
        radius: 12 * dpScale
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24 * dpScale // Margen amplio estilo Material
        spacing: 20 * dpScale

        // Título Material
        Text {
            text: "Introducir contraseña"
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ? FontManager.titleFontFamily : "DejaVu Sans"
            font.pixelSize: 20 * dpScale
            color: "#ffffff"
            font.bold: true
            Layout.fillWidth: true
        }

        // Subtítulo con el nombre de la red
        Text {
            text: "Red: " + wifiPasswordPopup.ssid
            font.pixelSize: 14 * dpScale
            color: "#a6adc8" // Text Muted
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.topMargin: -10 * dpScale // Pegado al título
        }

        // Campo de texto estilo Material Design 3 (Filled + Underline)
        TextField {
            id: wifiPasswordField
            echoMode: TextInput.Password
            placeholderText: "Contraseña"
            placeholderTextColor: "#6c7086"
            Layout.fillWidth: true
            focus: true
            color: "#ffffff"
            font.pixelSize: 16 * dpScale
            leftPadding: 12 * dpScale
            rightPadding: 12 * dpScale
            bottomPadding: 10 * dpScale
            topPadding: 10 * dpScale

            // Contenedor Material: Fondo plano grisáceo, sin bordes laterales
            background: Rectangle {
                color: "#2a2a3a" // surfaceColor
                radius: 4 * dpScale

                // Línea inferior activa/inactiva de Material
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: wifiPasswordField.activeFocus ? 2 * dpScale : 1 * dpScale
                    color: wifiPasswordField.activeFocus ? "#4fc3f7" : "#585b70" // Celeste solo si está escribiendo

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on height { NumberAnimation { duration: 100 } }
                }
            }
        }

        // Botonera alineada a la derecha estilo Material Dialog
        RowLayout {
            Layout.fillWidth: true
            spacing: 8 * dpScale
            Layout.topMargin: 10 * dpScale

            // Espaciador para empujar los botones a la derecha
            Item { Layout.fillWidth: true }

            StyledButton {
                text: "Cancelar"
                Layout.preferredHeight: 40 * dpScale
                Layout.preferredWidth: 100 * dpScale
                buttonColor: "transparent" // Botón plano
                textColor: "#4fc3f7"
                onClicked: wifiPasswordPopup.close()
            }

            StyledButton {
                text: "Conectar"
                Layout.preferredHeight: 40 * dpScale
                Layout.preferredWidth: 110 * dpScale
                buttonColor: "#4fc3f7"
                textColor: "#11111b" // Texto oscuro sobre botón brillante

                onClicked: {
                    if (wifiPasswordField.text === "") return

                    // 1. Guardar el resultado de la conexión (true/false)
                    var success = AppBackend.connectWifi(
                        wifiPasswordPopup.iface,
                        wifiPasswordPopup.ssid,
                        wifiPasswordField.text      // ← sin coma extra, solo 3 argumentos
                    )

                    // 2. Preparar el mensaje según el resultado
                    if (success) {
                        statusPopup.message = "Conexion Establecida"
                    } else {
                        statusPopup.message = "Error de autenticacion: Contra incorrecta"
                    }

                    // 3. Mostrar popup de estado y cerrar los demás
                    statusPopup.open()
                    wifiPasswordPopup.close()
                    wifiPopup.close()
                }
            }
        }
    }

    onClosed: {
        wifiPasswordField.text = ""
    }
}

StyledPopup {
    id: statusPopup
    width: 300 * dpScale
    height: 180 * dpScale
    accentColor: "#4fc3f7"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property string message: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 20 * dpScale

        Text {
            text: statusPopup.message
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
                          FontManager.titleFontFamily : "DejaVu Sans"
            font.pixelSize: 16 * dpScale
            color: "#ffffff"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        StyledButton {
            text: "Aceptar"
            Layout.alignment: Qt.AlignHCenter
            Layout.minimumHeight: 44 * dpScale
            onClicked: statusPopup.close()
        }
    }
}

function reloadApps() {
    console.log("[vpt|FORCE] loading apps")
    var systemApps = AppBackend.loadDesktopApps()
    console.log("[vpt] apps: " + systemApps.length)

    // Limpiar modelos existentes
    baseSearchModel.clear()
    appModel.clear()

    for (var i = 0; i < systemApps.length; i++) {
        var appData = systemApps[i]
        console.log("[vpt] app [" + i + "]: " + appData.name + " -> " + appData.exec)

        // Agregar a la base de búsqueda
        baseSearchModel.append(appData)

        // Agregar las primeras 8 apps al grid principal (o todas, según tu lógica)
        if (i < systemApps.length) {   // <-- nota: esto siempre es true, quiza querías i < 8 ?
            appModel.append(appData)
        }
    }
    updateSearchFilter("") // Inicializa la lista del buscador
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
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
                FontManager.titleFontFamily : "DejaVu Sans"
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
            id: progressBar2
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
                animationId: 2
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
            reloadApps()
            progressBar.visible = false
        }
    }
}

/* STREAMING_CHUNK:Building the main layout and Top Bar... */
// ============= FONDO DINÁMICO =============
Item {
    anchors.fill: parent
    z: -1
    Image {
        id: bg
        source: "orbit.png"
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop // Esto llena todo el espacio
        smooth: true
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
                onPressed: {
                    if (searchOverlay.state !== "VISIBLE") {
                        updateSearchFilter("")
                        searchOverlay.state = "VISIBLE"
                        searchInput.forceActiveFocus()
                    }
                    if (myCommandPill.visible) {
                        myCommandPill.visible = false
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
                RectangularGlow {
                                    id: tileGlow
                                    anchors.fill: parent
                                    glowRadius: 18 * dpScale
                                    spread: 0.1
                                    color: Qt.rgba(0.5, 0.6, 1.0, 0.4) // Glow azul eléctrico
                                    cornerRadius: parent.radius + glowRadius
                                    z: -1
                                    // Solo brilla en hover, se apaga al presionar o salir
                                    opacity: itemTile.state === "HOVER" ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
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


                // REEMPLAZA LA "Sombra simulada" POR ESTO:


                                // REEMPLAZA TUS STATES Y TRANSITIONS POR ESTOS:
                                states: [
                                    State {
                                        name: "HOVER"
                                        when: clickZone.containsMouse && !clickZone.pressed
                                        PropertyChanges { target: itemTile; color: Qt.rgba(1,1,1,0.12); scale: 1.06; border.color: Qt.rgba(0.5,0.6,1.0,0.6) }
                                    },
                                    State {
                                        name: "PRESSED"
                                        when: clickZone.pressed
                                        // Al hacer clic, se hunde (0.90) y se oscurece
                                        PropertyChanges { target: itemTile; color: Qt.rgba(0,0,0,0.3); scale: 0.90; border.color: Qt.rgba(0.5,0.6,1.0,1.0) }
                                    }
                                ]
                                transitions: Transition {
                                    // OutBack con overshoot da el efecto de rebote elástico
                                    NumberAnimation { properties: "scale"; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                                    ColorAnimation { properties: "color, border.color"; duration: 200 }
                                }
            }
        }
    }
}

StyledPopup {
    id: speedTestPopup
    width: 380 * dpScale
    height: 420 * dpScale
    accentColor: "#4fc3f7"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Variables internas
    property bool testing: false
    property real pingValue: 0        // ms
    property real downloadValue: 0    // Mbps
    property real uploadValue: 0      // Mbps
    property string errorMsg: ""

    // Máximo de las barras (para que no se salgan del ancho)
    readonly property real maxSpeed: 1000  // Mbps (ajusta según tu conexión)

    background: Rectangle {
        color: "#1e1e2e"
        radius: 12 * dpScale
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24 * dpScale
        spacing: 16 * dpScale

        Text {
            text: "Test de Velocidad WiFi"
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
                          FontManager.titleFontFamily : "DejaVu Sans"
            font.pixelSize: 20 * dpScale
            font.bold: true
            color: "#ffffff"
            Layout.fillWidth: true
        }

        // ---- Ping ----
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Latencia (PING)"
                color: "#a6adc8"
                font.pixelSize: 14 * dpScale
                Layout.preferredWidth: 120 * dpScale
            }
            Text {
                id: pingText
                text: speedTestPopup.testing ? "..." : (speedTestPopup.pingValue.toFixed(1) + " ms")
                color: "#4fc3f7"
                font.pixelSize: 16 * dpScale
                font.bold: true
            }
        }

        // ---- Descarga ----
        Text {
            text: "Descarga"
            color: "#a6adc8"
            font.pixelSize: 14 * dpScale
        }

        // Barra de descarga
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 20 * dpScale
            color: "#2a2a3a"
            radius: 4 * dpScale
            Rectangle {
                id: downloadBar
                height: parent.height
                width: parent.width * Math.min(speedTestPopup.downloadValue / speedTestPopup.maxSpeed, 1.0)
                color: "#4fc3f7"
                radius: 4 * dpScale
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        Text {
            id: downloadText
            text: speedTestPopup.testing ? "..." : (speedTestPopup.downloadValue.toFixed(2) + " Mbps")
            color: "#ffffff"
            font.pixelSize: 16 * dpScale
            font.bold: true
        }

        // ---- Subida ----
        Text {
            text: "Subida"
            color: "#a6adc8"
            font.pixelSize: 14 * dpScale
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 20 * dpScale
            color: "#2a2a3a"
            radius: 4 * dpScale
            Rectangle {
                id: uploadBar
                height: parent.height
                width: parent.width * Math.min(speedTestPopup.uploadValue / speedTestPopup.maxSpeed, 1.0)
                color: "#4fc3f7"
                radius: 4 * dpScale
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }

        Text {
            id: uploadText
            text: speedTestPopup.testing ? "..." : (speedTestPopup.uploadValue.toFixed(2) + " Mbps")
            color: "#ffffff"
            font.pixelSize: 16 * dpScale
            font.bold: true
        }

        // Mensaje de error (oculto si no hay)
        Text {
            id: errorLabel
            text: speedTestPopup.errorMsg
            color: "#ff5252"
            font.pixelSize: 13 * dpScale
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            visible: speedTestPopup.errorMsg !== ""
        }

        // Botones
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10 * dpScale

            StyledButton {
                text: speedTestPopup.testing ? "Midiendo..." : "Iniciar Test"
                enabled: !speedTestPopup.testing
                Layout.preferredHeight: 44 * dpScale
                Layout.fillWidth: true
                buttonColor: speedTestPopup.testing ? "#555" : "#4fc3f7"
                onClicked: {
                    speedTestPopup.testing = true
                    speedTestPopup.errorMsg = ""
                    // Llama al backend (asíncrono, necesitaremos callback)
                    AppBackend.startSpeedTest()
                }
            }

            StyledButton {
                text: "Cerrar"
                Layout.preferredHeight: 44 * dpScale
                Layout.fillWidth: true
                buttonColor: "transparent"
                textColor: "#4fc3f7"
                onClicked: speedTestPopup.close()
            }
        }
    }

    // Conexión con C++ para recibir resultados
    Connections {
        target: AppBackend
        function onSpeedTestFinished(download, upload, ping) {
            speedTestPopup.testing = false
            speedTestPopup.downloadValue = download
            speedTestPopup.uploadValue = upload
            speedTestPopup.pingValue = ping
        }
        function onSpeedTestError(message) {
            speedTestPopup.testing = false
            speedTestPopup.errorMsg = message
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

        RadialGradient {
            anchors.fill: parent
            horizontalOffset: 0
            verticalOffset: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.02, 0.05, 0.5) } // Centro más claro
                GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.02, 0.05, 0.95) } // Bordes oscuros
            }
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

                RectangularGlow {
                    anchors.fill: parent
                    glowRadius: 35 * dpScale
                    spread: 0.05
                    color: Qt.rgba(0, 0, 0, 0.6)
                    cornerRadius: parent.radius + glowRadius
                    z: -1

                    // La sombra reacciona a la animación de aparición del panel
                    scale: searchPanel.scale
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

                    Glow {
                                                anchors.fill: parent
                                                source: inputBg
                                                radius: 10 * dpScale
                                                samples: 20
                                                color: "#6688ff"
                                                opacity: searchInput.activeFocus ? 0.35 : 0.0
                                                transparentBorder: true
                                                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                                            }

                    onTextChanged: {
                        debounceTimer.restart()
                    }
                    Timer {
                        id: debounceTimer
                        interval: 150
                        onTriggered: updateSearchFilter(searchInput.text)
                    }
                    Keys.onReturnPressed: {
                        if (filteredSearchModel.count > 0) {
                            var firstItem = filteredSearchModel.get(0)
                            if (firstItem.exec && firstItem.exec !== "") {
                                executeSmartAction(firstItem.exec, firstItem.name)
                            }
                        }
                    }
                    Keys.onEscapePressed: {
                        searchInput.text = ""
                        searchOverlay.state = "HIDDEN"
                        filteredSearchModel.clear()
                    }
                    Keys.onPressed: (event) => {
                                            if (event.key === Qt.Key_Down) {
                                                if (searchList.currentIndex < searchList.count - 1)
                                                    searchList.currentIndex++
                                                event.accepted = true
                                            } else if (event.key === Qt.Key_Up) {
                                                if (searchList.currentIndex > 0)
                                                    searchList.currentIndex--
                                                event.accepted = true
                                            }
                                        }
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
                    // CORRECCIÓN UX: Resalta si tiene Hover O si está seleccionado con el teclado
                    property bool isCurrent: ListView.isCurrentItem
                    color: (searchItemArea.containsMouse || isCurrent) ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                                        // Pequeña línea izquierda cosmética si está seleccionado por teclado (estilo premium)
                    border.color: isCurrent ? "#6688ff" : "transparent"
                    border.width: isCurrent ? 1 : 0
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
                    MouseArea {
                        anchors.fill: parent
                        enabled: model.exec !== ""  // ← DESHABILITA si es "Sin resultados"
                        onClicked: {
                            executeSmartAction(model.exec, model.name)
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
            if (state === "VISIBLE") {
                searchInput.forceActiveFocus() // ← ¡BOOM! Foco automático al abrir
                searchList.currentIndex = -1   // Resetea selección
            } else if (state === "HIDDEN") {
                searchInput.text = ""
                updateSearchFilter("")
                if (typeof root !== "undefined") root.contentItem.forceActiveFocus()
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
    myCommandPill.visible = false

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
    myCommandPill.visible = false
    launchAnim.stop()
    cancelAnim.start()
}

Shortcut {
    sequence: "Ctrl+F12"
    onActivated: {
        console.log("Forzando recarga del instalador")
        oobeLoader.active = false
        oobeLoader.active = true
        oobeLoader.source = "FirstStart.qml"
    }
}

Loader {
    id: oobeLoader
    active: AppBackend.isFirstRun  // ← Esto debe ser true
    anchors.fill: parent
    source: "FirstStart.qml"       // ← El nombre debe coincidir EXACTAMENTE
    z: 99999

    onStatusChanged: {
        if (status === Loader.Ready) {
            console.log("✅ FirstStart.qml cargado correctamente")
        } else if (status === Loader.Error) {
            console.error("❌ No se encuentra FirstStart.qml")
        }
    }
}

// En Main.qml, justo antes del último cierre de llave '}'
CommandPill {
    id: myCommandPill
    visible: false
    z: 100
    opacity: 0
    y: 30 * dpScale

    // Asignación de propiedades existentes del componente
    sudoWarningPopup: sudoWarningPopup
    terminalPopup: terminalPopup
    searchOverlayRef: searchOverlay    // Sin "property var" adelante
}
// Shortcut para mostrar/ocultar (Ctrl+T o Meta+R)
Shortcut {
    sequences: ["Ctrl+T", "Meta+R"]
    onActivated: {
        myCommandPill.visible = !myCommandPill.visible
    }
}

// Shortcut para ocultar con Escape
Shortcut {
    sequences: ["Escape"]
    onActivated: {
        myCommandPill.visible = false
    }
}

}