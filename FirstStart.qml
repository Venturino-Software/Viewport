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
import QtQuick.Controls.Material 2.15

Rectangle {
    id: welcomeRoot
    anchors.fill: parent
    color: "#050505"
    z: 99999
    Material.theme: Material.Dark
    Material.accent: Material.Indigo

    // === PALETA DE COLORES UNIFICADA ===
    readonly property color accentColor: "#7f99ff"
    readonly property color surfaceColor: "#1a1c2b"
    readonly property color surfaceDark: "#121418"
    readonly property color surfaceDarker: "#111111"

    property bool closing: false
    property string selectedChannel: ""
    readonly property string sourcesListPath: "/etc/apt/sources.list.d/viewport.list"

    // Variable para controlar la página actual del OOBE (0 a 3)
    property int currentPage: 0

    // ------------------------------------------------------------
    // 1. SISTEMA DE ESCALADO DINÁMICO
    // ------------------------------------------------------------
    readonly property real refWidth: 1920
    readonly property real scaleFactor: Math.min(width / refWidth, height / (refWidth * 9 / 16))
    readonly property real dp: scaleFactor
    readonly property real baseFontSize: 16
    readonly property real titleFontSize: baseFontSize * dp * 2.2

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
        if (typeof AppBackend === "undefined") return;

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

    Component.onCompleted: {
        if (typeof AppBackend !== "undefined") {
            volumeSlider.value = AppBackend.getVolume()
        }
        readChannelAndInit()
    }

    // ------------------------------------------------------------
    // ETAPA 1: VÍDEO DE FONDO Y BIENVENIDA (Mantenido intacto)
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
    // ETAPA 2: CENTRAL DE CONFIGURACIÓN (DASHBOARD TIPO OOBE WIN11)
    // ------------------------------------------------------------
    Item {
        id: configStage
        anchors.fill: parent
        opacity: 0

        // Fondo oscuro para resaltar la tarjeta central
        Rectangle {
            anchors.fill: parent
            color: "#0b0c10"
        }

        // Tarjeta Central (70% de la pantalla)
        Rectangle {
            id: oobeCard
            width: parent.width * 0.70
            height: parent.height * 0.70
            anchors.centerIn: parent
            radius: 24 * dp
            color: surfaceDark
            border.color: "#2a2d35"
            border.width: 1 * dp

            // --- CONTENEDOR DE PÁGINAS ---
            Item {
                anchors.fill: parent
                anchors.margins: 60 * dp // Magnitud generosa solicitada
                anchors.bottomMargin: 100 * dp // Espacio extra para el footer de navegación

                // ==========================================
                // PÁGINA 1: PANTALLA Y ENTORNO
                // ==========================================
                Column {
                    anchors.fill: parent
                    spacing: 30 * dp
                    visible: currentPage === 0

                    Text {
                        text: "Configuración de Pantalla"
                        color: "white"
                        font.pixelSize: titleFontSize
                        font.bold: true
                    }

                    Text {
                        text: "Ajusta la resolución y la escala para que la interfaz se adapte perfectamente a tu monitor."
                        color: "#95a5a6"
                        font.pixelSize: baseFontSize * dp * 1.1
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Grid {
                        columns: 2
                        spacing: 40 * dp
                        width: parent.width

                        // Columna Izquierda
                        Column {
                            spacing: 20 * dp
                            width: (parent.width - 40 * dp) / 2

                            Column {
                                spacing: 8 * dp; width: parent.width
                                Text { text: "Dispositivo de Display:"; color: "#95a5a6"; font.pixelSize: baseFontSize * dp }
                                TextField {
                                    id: displayInput
                                    width: parent.width; height: 60 * dp
                                    text: "eDP-1"
                                    color: "white"
                                    background: Rectangle { color: surfaceDarker; radius: 8 * dp; border.color: parent.activeFocus ? welcomeRoot.accentColor : "#333" }
                                }
                            }

                            Column {
                                spacing: 14 * dp; width: parent.width
                                Text { text: `Escala de Renderizado: ${scaleSlider.value.toFixed(2)}`; color: "#95a5a6"; font.pixelSize: baseFontSize * dp }
                                Slider {
                                    id: scaleSlider
                                    width: parent.width; from: 1.0; to: 2.5; value: 1.0
                                }
                            }
                        }

                        // Columna Derecha
                        Column {
                            spacing: 20 * dp
                            width: (parent.width - 40 * dp) / 2

                            Column {
                                spacing: 8 * dp; width: parent.width
                                Text { text: "Tasa de Refresco (Hz):"; color: "#95a5a6"; font.pixelSize: baseFontSize * dp }
                                ComboBox {
                                    id: hzInput
                                    width: parent.width; height: 60 * dp
                                    model: ["24", "30", "42", "60", "75", "124", "144", "240", "360", "520"]
                                }
                            }

                            Column {
                                spacing: 8 * dp; width: parent.width
                                Text { text: "Resolución:"; color: "#95a5a6"; font.pixelSize: baseFontSize * dp }
                                ComboBox {
                                    id: resInput
                                    width: parent.width; height: 60 * dp
                                    textRole: "text"
                                    valueRole: "value"
                                    model: [
                                        { text: "4K (3840x2160)",  value: "3840x2160" },
                                        { text: "QHD (2560x1440)",  value: "2560x1440" },
                                        { text: "FHD (1920x1080)",     value: "1920x1080" },
                                        { text: "HD (1280x720)",           value: "1280x720" },
                                        { text: "SD 16:9 (854x480)", value: "854x480" },
                                        { text: "SD (640x360)",            value: "640x360" }
                                    ]
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 10 * dp } // Espaciador

                    StyledButton {
                        text: "Aplicar Pantalla"
                        width: 250 * dp
                        buttonColor: surfaceColor
                        textColor: welcomeRoot.accentColor
                        animationId: 1
                        onClicked: {
                            let resolucion = resInput.currentValue
                            let hz = hzInput.currentText
                            let cmd = `wlr-randr --output ${displayInput.text} --scale ${scaleSlider.value.toFixed(2)} --mode ${resolucion}@${hz}Hz`
                            if (typeof AppBackend !== "undefined") AppBackend.runPkexec(cmd)
                            console.log("Ejecutando escalado:", cmd)
                        }
                    }
                }

                // ==========================================
                // PÁGINA 2: CONFIGURACIÓN DE AUDIO
                // ==========================================
                Column {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    spacing: 40 * dp
                    visible: currentPage === 1

                    Text {
                        text: "Sistema de Audio"
                        color: "white"
                        font.pixelSize: titleFontSize
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Configura el volumen maestro inicial del servidor de audio PipeWire. Puedes probar el sonido antes de continuar."
                        color: "#95a5a6"
                        font.pixelSize: baseFontSize * dp * 1.1
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    Column {
                        spacing: 20 * dp; width: parent.width

                        Text {
                            text: `Volumen General: ${Math.round(volumeSlider.value)}%`
                            color: "white"
                            font.pixelSize: baseFontSize * dp * 1.4
                            font.bold: true
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

                    StyledButton {
                        text: "Probar Sonido"
                        width: 250 * dp
                        anchors.horizontalCenter: parent.horizontalCenter
                        buttonColor: surfaceColor
                        animationId: 2
                        onClicked: {
                            if (typeof AppBackend !== "undefined") AppBackend.playSound("pop.wav")
                        }
                    }
                }

                // ==========================================
                // PÁGINA 3: CANAL DE PAQUETES
                // ==========================================
                Column {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    spacing: 40 * dp
                    visible: currentPage === 2

                    Text {
                        text: "Rama de Software"
                        color: "white"
                        font.pixelSize: titleFontSize
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Selecciona el origen de los paquetes de actualización APT para Viewport OS. Puedes elegir la estabilidad absoluta o lo último en características."
                        color: "#95a5a6"
                        font.pixelSize: baseFontSize * dp * 1.1
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                    }

                    Row {
                        spacing: 30 * dp
                        anchors.horizontalCenter: parent.horizontalCenter

                        StyledButton {
                            text: "Rama Unstable"
                            width: 220 * dp
                            height: 80 * dp
                            buttonColor: selectedChannel === "unstable" ? welcomeRoot.accentColor : surfaceColor
                            textColor: selectedChannel === "unstable" ? "#000" : "#fff"
                            onClicked: configureChannel("unstable")
                        }

                        StyledButton {
                            text: "Rama Estable"
                            width: 220 * dp
                            height: 80 * dp
                            buttonColor: selectedChannel === "stable" ? welcomeRoot.accentColor : surfaceColor
                            textColor: selectedChannel === "stable" ? "#000" : "#fff"
                            onClicked: configureChannel("stable")
                        }
                    }
                }

                // ==========================================
                // PÁGINA 4: FINALIZACIÓN
                // ==========================================
                Column {
                    anchors.centerIn: parent
                    spacing: 50 * dp
                    visible: currentPage === 3

                    AnimatedImage {
                        id: finishAnim
                        source: "file:///vpt/bin/src/finish.gif"
                        width: 250 * dp
                        height: 250 * dp
                        anchors.horizontalCenter: parent.horizontalCenter

                        // Controlamos el estado inicial: solo juega si estamos en la pagina 3
                        playing: currentPage === 3

                        onCurrentFrameChanged: {
                            // frameCount es el total de cuadros del GIF
                            // currentFrame es el cuadro actual (base 0)
                            if (playing && currentFrame === frameCount - 1) {
                                playing = false
                            }
                        }
                    }

                    Text {
                        text: "Viewport se configuro correctamente"
                        color: "white"
                        font.pixelSize: titleFontSize
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledButton {
                        text: "Listo"
                        width: 280 * dp
                        height: 70 * dp
                        anchors.horizontalCenter: parent.horizontalCenter
                        buttonColor: welcomeRoot.accentColor
                        textColor: "#000"
                        animationId: 2
                        onClicked: {
                            if (!closing) {
                                closing = true;
                                welcomeRoot.opacity = 0;
                            }
                        }
                    }
                }
            }

            // --- NAVEGACIÓN INFERIOR (FOOTER) ---
            Item {
                id: navigationFooter
                height: 80 * dp
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 40 * dp
                // Ocultar el footer en la página 4 (Finalización) ya que tiene su propio botón "Listo"
                visible: currentPage < 3

                StyledButton {
                    text: "Atrás"
                    width: 160 * dp
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    buttonColor: "transparent"
                    textColor: "#95a5a6"
                    visible: currentPage > 0
                    onClicked: currentPage--
                }

                StyledButton {
                    text: "Siguiente"
                    width: 180 * dp
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    buttonColor: welcomeRoot.accentColor
                    textColor: "#000"
                    onClicked: {
                        if (currentPage < 3) {
                            currentPage++
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // NOTIFICACIÓN POPUP
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