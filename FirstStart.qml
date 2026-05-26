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
    color: "#050505" // Fondo negro puro como base de fallback
    z: 99999

    // === PALETA DE COLORES UNIFICADA (Coherencia con tu ecosistema) ===
    readonly property color accentColor: "#7f99ff"   // El color protagonista
    readonly property color surfaceColor: "#1a1c2b"  // Igual al bgColor de StyledPopup
    readonly property color surfaceDark: "#121418"
    readonly property color surfaceDarker: "#111111"

    // ------------------------------------------------------------
    // 1. SISTEMA DE ESCALADO DINÁMICO (DPI / RESOLUCIÓN)
    // ------------------------------------------------------------
    readonly property real refWidth: 1920
    readonly property real scaleFactor: Math.min(
        width / refWidth,
        height / (refWidth * 9 / 16)
    )

    // Tamaños base reajustados para estética premium
    readonly property real dp: scaleFactor
    readonly property real baseFontSize: 18
    readonly property real titleFontSize: baseFontSize * dp * 2.2
    readonly property real buttonFontSize: baseFontSize * dp * 1.2

    // Tarjetas más proporcionadas
    readonly property real cardWidth: 320 * dp
    readonly property real cardHeight: 240 * dp

    // ------------------------------------------------------------
    // 2. ESTADOS Y TRANSICIONES
    // ------------------------------------------------------------

    states: [
        State {
            name: "videoMode"
            PropertyChanges { target: videoStage; opacity: 1; visible: true }
            PropertyChanges { target: installStage; opacity: 0; visible: false }
        },
        State {
            name: "installMode"
            PropertyChanges { target: videoStage; opacity: 0; visible: false }
            PropertyChanges { target: installStage; opacity: 1; visible: true }
        }
    ]
    state: "videoMode"

    // Animación de opacidad general del componente raíz
    Behavior on opacity {
        NumberAnimation {
            duration: 400
            easing.type: Easing.InOutQuad

            // ¡ESTA ES LA MAGIA! Cuando la animación de desvanecimiento TERMINA:
            onRunningChanged: {
                if (!running && welcomeRoot.opacity === 0) {
                    console.log("[VPT] Desvanecimiento listo. Destruyendo interfaz de instalación...")
                    // Validación por seguridad para evitar crasheos si el backend no está listo
                    if (typeof AppBackend !== "undefined") {
                        AppBackend.markSetupAsDone()
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------
    // 3. ETAPA 1: VÍDEO DE FONDO Y BIENVENIDA
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

        // Overlay con gradiente simulado para hundir el video en la oscuridad
        Rectangle {
            anchors.fill: parent
            color: "#A6000000" // 65% de opacidad para dar protagonismo al botón
            z: 1
        }

        // Botón "Comenzar"
        // (Usa Rectangles nativos para evadir GraphicalEffects y asegurar 100% estabilidad)
        Item {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 80 * dp
            width: 240 * dp
            height: 60 * dp
            z: 2

            Rectangle {
                id: startBtnBg
                anchors.fill: parent
                radius: height / 2 // Píldora perfecta

                // Transiciones coherentes con el Surface Color de tus Popups
                color: startBtnArea.pressed ? surfaceDarker : (startBtnArea.containsMouse ? surfaceColor : "#0d0d0d")
                border.width: 1.5 * dp
                border.color: startBtnArea.containsMouse ? welcomeRoot.accentColor : "#333333"

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 250 } }
            }

            Text {
                anchors.centerIn: parent
                text: "COMENZAR"
                color: startBtnArea.containsMouse ? welcomeRoot.accentColor : "#FFFFFF"
                font.pixelSize: buttonFontSize
                font.bold: true
                font.letterSpacing: 2 * dp
                font.family: "Segoe UI, Arial, sans-serif"

                Behavior on color { ColorAnimation { duration: 250 } }
            }

            MouseArea {
                id: startBtnArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    welcomeVideo.stop()
                    welcomeRoot.state = "installMode"
                }
            }

            scale: startBtnArea.pressed ? 0.95 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }

    // ------------------------------------------------------------
    // 4. ETAPA 2: INSTALADOR DE HERRAMIENTAS
    // ------------------------------------------------------------
    Item {
        id: installStage
        anchors.fill: parent
        opacity: 0

        // Fondo difuminado para el instalador
        Rectangle {
            anchors.fill: parent
            color: "#0b0c10"
        }

        Text {
            id: titleText
            text: "¿Cómo instalamos ATP?"
            color: "#ffffff"
            font.pixelSize: titleFontSize
            font.bold: true
            font.family: "Segoe UI, Arial, sans-serif"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 100 * dp
        }

        // --- MODELO DE DATOS ---
        ListModel {
            id: cardsModel
            ListElement {
                cardTitle: "Perfil CERO"
                cardDesc: "Solo ATP Tools básicas.\nMáximo rendimiento, cero bloatware."
                cardIcon: "⚙️"
                scriptTarget: ""
            }
            ListElement {
                cardTitle: "Perfil MÍNIMO"
                cardDesc: "Herramientas de red + utilidades extra.\nEl arsenal completo."
                cardIcon: "🛠️"
                scriptTarget: "/vpt/adm/bin/insmin.sh"
            }
            ListElement {
                cardTitle: "Perfil TODO"
                cardDesc: "Suites ofimáticas...\nBloatware..."
                cardIcon: "📦"
                scriptTarget: "/vpt/adm/bin/insall.sh"
            }
        }

        // --- RENDERIZADOR DE TARJETAS ---
        Row {
            spacing: 50 * dp
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 20 * dp

            Repeater {
                model: cardsModel
                delegate: Item {
                    width: cardWidth
                    height: cardHeight

                    // Sombra falsa estable (Simula Glow sin importar GraphicalEffects)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4 * dp
                        radius: 18 * dp
                        color: "transparent"
                        border.width: 1.5 * dp
                        border.color: cardArea.containsMouse ? welcomeRoot.accentColor : "transparent"
                        opacity: cardArea.containsMouse ? 0.35 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                    }

                    // Tarjeta Principal
                    Rectangle {
                        anchors.fill: parent
                        radius: 16 * dp

                        // Adaptando el Glassmorphism oscuro a la paleta de StyledPopup
                        color: cardArea.pressed ? surfaceDarker : (cardArea.containsMouse ? surfaceColor : surfaceDark)
                        border.width: 1 * dp
                        border.color: cardArea.containsMouse ? welcomeRoot.accentColor : "#2a2d35"

                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 15 * dp
                            width: parent.width - (40 * dp)

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: model.cardIcon
                                font.pixelSize: 54 * dp
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: model.cardTitle
                                font.pixelSize: baseFontSize * dp * 1.4
                                font.bold: true
                                color: cardArea.containsMouse ? welcomeRoot.accentColor : "white"

                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: model.cardDesc
                                font.pixelSize: baseFontSize * dp * 0.95
                                color: "#95a5a6"
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                                lineHeight: 1.3
                            }
                        }
                    }

                    MouseArea {
                        id: cardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof AppBackend !== "undefined") {
                                AppBackend.runGenericScript(model.scriptTarget)
                            }
                            finalizeSetup()
                        }
                    }

                    // Escala táctil fluida
                    scale: cardArea.pressed ? 0.96 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                }
            }
        }

        Text {
            text: "El sistema aplicará las configuraciones en segundo plano."
            color: "#555555"
            font.pixelSize: baseFontSize * dp * 0.85
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 40 * dp
        }
    }

    // ------------------------------------------------------------
    // 5. FUNCIÓN FINAL
    // ------------------------------------------------------------
    function finalizeSetup() {
        // Al poner la opacidad en 0, se dispara el 'Behavior on opacity' que armamos arriba.
        // Cuando termina de hacerse invisible (400ms), se borra todo de la RAM automáticamente.
        welcomeRoot.opacity = 0
    }
}