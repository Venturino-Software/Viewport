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
            {n: "Apagar", c: "Alimentación", e: "VPT_SYS|poweroff"},
            {n: "Reiniciar", c: "Alimentación", e: "VPT_SYS|reboot"},
            {n: "Salir a TTY", c: "Alimentación", e: "VPT_SYS|exit_vpt"},
            {n: "Ajustar Volumen", c: "Audio", e: "VPT_SYS|volume"},
            {n: "Ajustar Brillo", c: "Pantalla", e: "VPT_SYS|brightness"},
            {n: "Redes WiFi", c: "Redes", e: "VPT_SYS|wifi"},
            {n: "Setup", c: "OOBE", e: "VPT_OOBE|"}
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

    width: Math.min(800 * dpScale, parent ? parent.width * 0.95 : 800)
    height: 550 * dpScale
    accentColor: "#00e676"
    popupRadius: 16 * dpScale // Radio de bordes más redondeado (estilo popup 2)
    fontType: "body"

    // Comentar o descomentar si necesitas centrado manual
    // disableDefs: true

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

        // --- CABECERA ---
        Text {
            text: "Terminal de Viewport"
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
                         FontManager.titleFontFamily : "DejaVu Sans"
            font.pixelSize: 18 * dpScale
            color: "#ffffff"
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // --- ÁREA DE SALIDA (OUTPUT) ---
        ScrollView {
            id: scrollArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            TextArea {
                id: outputArea
                readOnly: true
                color: "#ccddee"
                font.family: typeof FontManager !== "undefined" && FontManager.monoFontFamily ?
                             FontManager.monoFontFamily : "Fira Code, monospace"
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

        // --- BARRA DE PROGRESO (APT / PIP) ---
        ProgressBar {
            id: progressBar
            Layout.fillWidth: true
            height: 6 * dpScale
            visible: false // Se oculta si no hay progreso detectado
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

                    // Animación suave al actualizar porcentaje
                    Behavior on width { NumberAnimation { duration: 150 } }
                }
            }
        }

        // --- INPUT DE COMANDOS MANUALES ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * dpScale

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

                // Ejecutar con la tecla Enter
                onAccepted: AppBackend.runCommandWithOutput(cmdInput.text)
            }

            StyledButton {
                text: "Ejecutar"
                Layout.minimumHeight: cmdInput.height
                onClicked: runManualCommand()
            }
        }

        // --- FOOTER: WARNING Y BOTÓN CERRAR ---
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8 * dpScale
            spacing: 12 * dpScale // Espaciado directo, sin anidar RowLayouts

            Text {
                text: "⚠️"
                font.pixelSize: 18 * dpScale
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: "Viewport tiene permisos infinitos. Use SUDO con cuidado."
                color: "#ffaa00"
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
            // 1. Añadir el texto a la terminal
            outputArea.append(output)

            // 2. FORZAR SCROLL ABAJO SIEMPRE
            outputArea.cursorPosition = outputArea.length

            // 3. CAPTURAR PROGRESO CON REGEX
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

    // Función para manejar el TextField
    function runManualCommand() {
        var newCmd = cmdInput.text.trim();
        if (newCmd !== "") {
            outputArea.append("\n$ " + newCmd);
            outputArea.cursorPosition = outputArea.length;

            AppBackend.runCommandWithOutput(newCmd);

            cmdInput.text = "";
            progressBar.value = 0.0;
            progressBar.visible = false;
        }
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
          }

          StyledButton {
              text: "Sí, ejecutar"
              Layout.fillWidth: true
              onClicked: {
                  sudoWarningPopup.close();
                  myCommandPill.runInTerminal(sudoWarningPopup.pendingCommand);
              }
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
          text: "Te preguntamos esto para prevenir toques accidentales"
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
                powerWarn.pendingCommand = "/user/bin/pkexec /usr/bin/systemctl poweroff"
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
            onClicked: AppBackend.playTestSound()
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
    width: 400 * dpScale
    height: 450 * dpScale
    accentColor: "#4fc3f7"

    ListModel {
        id: wifiModel
        ListElement { ssid: ""; encrypted: false }
    }

    onOpened: {
        wifiModel.clear()
        var networks = AppBackend.scanWifi()
        for (var i = 0; i < networks.length; i++) {
            wifiModel.append({ "ssid": networks[i].ssid, "encrypted": networks[i].encrypted })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12 * dpScale

        Text {
            text: "Redes WiFi disponibles"
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
                FontManager.titleFontFamily : "DejaVu Sans"
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
                text: model.ssid + (model.encrypted ? " 🔒" : "")
                background: Rectangle {
                    color: hovered ? "#2a2a3a" : "transparent"
                    radius: 6
                }
                onClicked: {
                    if (model.encrypted) {
                        // Abrir popup de contraseña
                        wifiPasswordPopup.ssid = model.ssid
                        wifiPasswordPopup.open()
                    } else {
                        AppBackend.connectWifi(model.ssid, "")
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
            animationId: 2
        }
    }
}

// Popup para pedir contraseña de red WiFi encriptada
StyledPopup {
    id: wifiPasswordPopup
    property string ssid: ""
    width: 400 * dpScale
    height: 280 * dpScale
    accentColor: "#4fc3f7"
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    ColumnLayout {
        anchors.fill: parent
        spacing: 15 * dpScale

        Text {
            text: "Contraseña para: " + wifiPasswordPopup.ssid
            font.family: (typeof FontManager !== "undefined" && FontManager && FontManager.titleFontFamily) ?
                FontManager.titleFontFamily : "DejaVu Sans"
            font.pixelSize: 16 * dpScale
            color: "#ffffff"
            font.bold: true
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        TextField {
            id: wifiPasswordField
            echoMode: TextInput.Password
            placeholderText: "Contraseña de la red"
            Layout.fillWidth: true
            background: Rectangle {
                radius: 8
                color: "#1e1e2e"
                border.color: "#4fc3f7"
            }
            color: "#ffffff"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10 * dpScale

            StyledButton {
                text: "Conectar"
                Layout.minimumHeight: 44 * dpScale
                Layout.fillWidth: true
                buttonColor: "#4fc3f7"
                onClicked: {
                    if (wifiPasswordField.text === "") return
                    AppBackend.connectWifi(wifiPasswordPopup.ssid, wifiPasswordField.text)
                    wifiPasswordPopup.close()
                    wifiPopup.close()
                }
            }

            StyledButton {
                text: "Cancelar"
                Layout.minimumHeight: 44 * dpScale
                Layout.fillWidth: true
                onClicked: wifiPasswordPopup.close()
                animationId: 2
            }
        }
    }

    onClosed: {
        wifiPasswordField.text = "" // limpiar contraseña al cerrar
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

/* STREAMING_CHUNK:Implementing the search overlay... */
// ============= OVERLAY DE BÚSQUEDA =============
Item {
    id: searchOverlay
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    z: 50

    // Fondo oscuro
    // REEMPLAZA EL "Fondo oscuro" POR ESTO:
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

        // REEMPLAZA LA "Sombra panel" POR ESTO:
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