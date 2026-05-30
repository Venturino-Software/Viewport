/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VNT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15

Rectangle {
    id: welcomeRoot
    anchors.fill: parent
    color: "#050505"
    z: 99999

    // === PALETA DE COLORES UNIFICADA ===
    readonly property color accentColor: "#7f99ff"
    readonly property color surfaceColor: "#1a1c2b"
    readonly property color surfaceDark: "#121418"
    readonly property color surfaceDarker: "#111111"

    property bool closing: false
    property string selectedChannel: ""
    readonly property string sourcesListPath: "/etc/apt/sources.list.d/viewport.list"

    // ------------------------------------------------------------
    // 1. SISTEMA DE ESCALADO DINÁMICO
    // ------------------------------------------------------------
    readonly property real refWidth: 1920
    readonly property real scaleFactor: Math.min(width / refWidth, height / (refWidth * 9 / 16))
    readonly property real dp: scaleFactor
    readonly property real baseFontSize: 16
    readonly property real titleFontSize: baseFontSize * dp * 2.2

    // Dimensiones de los paneles de configuración
    readonly property real panelWidth: 420 * dp
    readonly property real panelHeight: 520 * dp

    states: [
        State {
            name: "videoMode"
            PropertyChanges { target: videoStage; opacity: 1; visible: true }
            PropertyChanges { target: configStage; opacity: 0; visible: false }
        },
        State {
            name: "configMode"
            PropertyChanges { target: videoStage; opacity: 0; visible: false }
            PropertyChanges { target: configStage; opacity: 1; visible: true }
        }
    ]
    state: "videoMode"

    Behavior on opacity {
        NumberAnimation {
            duration: 400
            easing.type: Easing.InOutQuad
            onRunningChanged: {
                if (!running && welcomeRoot.opacity === 0) {
                    if (typeof AppBackend !== "undefined") {
                        AppBackend.markSetupAsDone()
                    }
                }
            }
        }
    }

    function readChannelAndInit() {
        let content = AppBackend.readFile(sourcesListPath)
        console.log("=== readChannelAndInit ===")
        console.log("Contenido CRUDO del archivo:", JSON.stringify(content))

        let channel = "desconocido"
        if (content.includes("unstable")) {
            channel = "unstable"
        } else if (content.includes("stable")) {
            channel = "stable"
        }

        console.log("Canal detectado:", channel)
        selectedChannel = channel

        if (selectedChannel !== "" && selectedChannel !== "desconocido") {
            checkForUpdates()

        }
    }

    // ------------------------------------------------------------
    // 2. LOGICA DE CONFIGURACIÓN DE REPOSITORIOS
    // ------------------------------------------------------------
    function configureChannel(channel) {
        selectedChannel = channel
        let repoLine = `deb [signed-by=/etc/apt/keyrings/vpt-archive-keyring.gpg] http://vpt.soyss.cc ${channel} main`
        let cmd = `echo "${repoLine}" | pkexec tee ${sourcesListPath} > /dev/null`

        if (typeof AppBackend !== "undefined") {
            AppBackend.runPkexec(cmd)
        } else {
            console.log("[Mock] Ejecutando: " + cmd)
        }
        timerCheck.start()
    }

    Timer {
        id: timerCheck
        interval: 1000
        repeat: false
        onTriggered: {
            console.log("Verificación de canal completada para:", selectedChannel)
            popupNotification.popupText = "Canal '" + selectedChannel + "' configurado con éxito."
            popupNotification.open()
        }
    }

    // Inicialización del Volumen desde C++ al cargar
    Component.onCompleted: {
        if (typeof AppBackend !== "undefined") {
            volumeSlider.value = AppBackend.getVolume()
        }
        readChannelAndInit()
    }

    // ------------------------------------------------------------
    // ETAPA 1: VÍDEO DE FONDO Y BIENVENIDA
    // ------------------------------------------------------------
    Item {
        id: videoStage
        anchors.fill: parent

        Video {
            id: welcomeVideo
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectCrop
            source: "file:///vpt/share/media/helloworld.mp4"
            autoPlay: true
            loops: MediaPlayer.Infinite
        }

        Rectangle {
            anchors.fill: parent
            color: "#A6000000"
            z: 1
        }

        Item {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 80 * dp
            width: 240 * dp
            height: 60 * dp
            z: 2

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: startBtnArea.pressed ? surfaceDarker : (startBtnArea.containsMouse ? surfaceColor : "#0d0d0d")
                border.width: 1.5 * dp
                border.color: startBtnArea.containsMouse ? welcomeRoot.accentColor : "#333333"
            }

            Text {
                anchors.centerIn: parent
                text: "CONFIGURAR"
                color: startBtnArea.containsMouse ? welcomeRoot.accentColor : "#FFFFFF"
                font.pixelSize: baseFontSize * dp * 1.2
                font.bold: true
                font.letterSpacing: 2 * dp
            }

            MouseArea {
                id: startBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    welcomeVideo.stop()
                    welcomeRoot.state = "configMode"
                }
            }
        }
    }

    // ------------------------------------------------------------
    // ETAPA 2: CENTRAL DE CONFIGURACIÓN (DASHBOARD)
    // ------------------------------------------------------------
    Item {
        id: configStage
        anchors.fill: parent
        opacity: 0

        Rectangle {
            anchors.fill: parent
            color: "#0b0c10"
        }

        Text {
            id: titleText
            text: "Ajustes Iniciales del Entorno"
            color: "#ffffff"
            font.pixelSize: titleFontSize
            font.bold: true
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 60 * dp
        }

        // GRID DE CONFIGURACIONES TRIPLE
        Row {
            spacing: 40 * dp
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 30 * dp

            // --- PANEL 1: PANTALLA Y ENTORNO ---
            Rectangle {
                width: panelWidth; height: panelHeight
                radius: 16 * dp
                color: surfaceDark
                border.color: "#2a2d35"; border.width: 1 * dp

                Column {
                    anchors.fill: parent; anchors.margins: 24 * dp
                    spacing: 20 * dp

                    Text { text: "🖥️ Monitor & DPI"; color: "white"; font.pixelSize: baseFontSize * dp * 1.3; font.bold: true }

                    // Input Dispositivo
                    Column {
                        spacing: 6 * dp; width: parent.width
                        Text { text: "Dispositivo de Display:"; color: "#95a5a6"; font.pixelSize: baseFontSize * dp * 0.9 }
                        TextField {
                            id: displayInput
                            width: parent.width; height: 40 * dp
                            text: "eDP-1"
                            color: "white"
                            background: Rectangle { color: surfaceDarker; radius: 6 * dp; border.color: parent.activeFocus ? welcomeRoot.accentColor : "#333" }
                        }
                    }

                    // Slider Escala
                    Column {
                        spacing: 6 * dp; width: parent.width
                        Text { text: `Escala de Renderizado: ${scaleSlider.value.toFixed(2)}`; color: "#95a5a6"; font.pixelSize: baseFontSize * dp * 0.9 }
                        Slider {
                            id: scaleSlider
                            width: parent.width; from: 1.0; to: 2.5; value: 1.0
                        }
                    }

                    // Tasa de Refresco
                    Column {
                        spacing: 6 * dp; width: parent.width
                        Text { text: "Tasa de Refresco (Hz):"; color: "#95a5a6"; font.pixelSize: baseFontSize * dp * 0.9 }
                        ComboBox {
                            id: hzInput
                            width: parent.width; height: 40 * dp
                            model: ["60", "75", "124", "144", "240"]
                        }
                    }

                    Item { width: 1; height: 10 * dp } // Espaciador

                    StyledButton {
                        text: "Aplicar Pantalla"
                        width: parent.width
                        buttonColor: welcomeRoot.accentColor
                        textColor: "#000000"
                        animationId: 1
                        onClicked: {
                            let cmd = `wlr-randr --output ${displayInput.text} --scale ${scaleSlider.value.toFixed(2)} --mode ${hzInput.currentText}Hz`
                            if (typeof AppBackend !== "undefined") AppBackend.runPkexec(cmd)
                            console.log("Ejecutando escalado:", cmd)
                        }
                    }
                }
            }

            // --- PANEL 2: CONFIGURACIÓN DE AUDIO ---
            Rectangle {
                width: panelWidth; height: panelHeight
                radius: 16 * dp
                color: surfaceDark
                border.color: "#2a2d35"; border.width: 1 * dp

                Column {
                    anchors.fill: parent; anchors.margins: 24 * dp
                    spacing: 24 * dp

                    Text { text: "Sistema de Audio"; color: "white"; font.pixelSize: baseFontSize * dp * 1.3; font.bold: true }
                    Text {
                        text: "Configura el volumen maestro inicial del servidor de audio PipeWire de forma directa."
                        color: "#95a5a6"; font.pixelSize: baseFontSize * dp * 0.95; wrapMode: Text.WordWrap; width: parent.width
                    }

                    Item { width: 1; height: 20 * dp }

                    // Slider de Volumen Inteligente
                    Column {
                        spacing: 12 * dp; width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: `Volumen General: ${Math.round(volumeSlider.value)}%`
                            color: "white"; font.pixelSize: baseFontSize * dp * 1.1; font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Slider {
                            id: volumeSlider
                            width: parent.width; from: 0; to: 100; value: 50
                            stepSize: 1
                            onMoved: {
                                if (typeof AppBackend !== "undefined") {
                                    AppBackend.setVolume(value)
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 30 * dp }

                    StyledButton {
                        text: "Probar Sonido"
                        width: parent.width
                        buttonColor: surfaceColor
                        animationId: 2
                        onClicked: {
                            if (typeof AppBackend !== "undefined") AppBackend.playSound("pop.wav")
                        }
                    }
                }
            }

            // --- PANEL 3: CANAL DE DISTRIBUCIÓN ---
            Rectangle {
                width: panelWidth; height: panelHeight
                radius: 16 * dp
                color: surfaceDark
                border.color: "#2a2d35"; border.width: 1 * dp

                Column {
                    anchors.fill: parent; anchors.margins: 24 * dp
                    spacing: 16 * dp

                    Text { text: "Rama de Software"; color: "white"; font.pixelSize: baseFontSize * dp * 1.3; font.bold: true }
                    Text {
                        text: "Selecciona el origen de los paquetes de actualización APT para Viewport OS."
                        color: "#95a5a6"; font.pixelSize: baseFontSize * dp * 0.95; wrapMode: Text.WordWrap; width: parent.width
                    }

                    Item { width: 1; height: 10 * dp }

                    StyledButton {
                        text: "Rama Unstable"
                        width: parent.width
                        buttonColor: selectedChannel === "unstable" ? welcomeRoot.accentColor : surfaceColor
                        textColor: selectedChannel === "unstable" ? "#000" : "#fff"
                        onClicked: configureChannel("unstable")
                    }
                    // Selector de canales utilizando StyledButton
                    StyledButton {
                        text: "Rama Estable"
                        width: parent.width
                        buttonColor: selectedChannel === "stable" ? welcomeRoot.accentColor : surfaceColor
                        textColor: selectedChannel === "stable" ? "#000" : "#fff"
                        onClicked: configureChannel("stable")
                    }
                }
            }
        }

        // BOTÓN INFERIOR DE FINALIZACIÓN
        StyledButton {
            text: "FINALIZAR SETUP"
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 40 * dp
            width: 280 * dp
            buttonColor: "#27ae60"
            textColor: "white"
            animationId: 2
            onClicked: {
                if (!closing) {
                    closing = true;
                    welcomeRoot.opacity = 0;
                }
            }
        }
    }

    // ------------------------------------------------------------
    // NOTIFICACIÓN POPUP (Basado en tu StyledPopup)
    // ------------------------------------------------------------
    StyledPopup {
        id: popupNotification
        width: 400 * dp
        height: 200 * dp
        title: "Ecosistema Viewport"
        property string popupText: ""

        Column {
            anchors.centerIn: parent
            spacing: 20 * dp
            width: parent.width - 40 * dp

            Text {
                text: popupNotification.popupText
                color: "white"
                font.pixelSize: baseFontSize * dp
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }

            StyledButton {
                text: "Entendido"
                width: 120 * dp
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: popupNotification.close()
            }
        }
    }
}