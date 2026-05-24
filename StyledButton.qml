/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VPT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
 */

import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: control

    // Propiedades personalizables
    property color buttonColor: "#4fc3f7"      // Color principal
    property color hoverColor: Qt.lighter(buttonColor, 1.15)
    property color pressedColor: Qt.darker(buttonColor, 1.2)
    property color textColor: "#ffffff"
    property int btnRadius: 8
    property int fontSize: 13
    property bool bold: true
    property string buttonIcon: ""             // Renombrado de "icon" a "buttonIcon"

    // Animaciones
    property bool animated: true
    property int minHeight: 44

    // Comportamiento
    flat: false
    hoverEnabled: true

    // Contenido
    contentItem: Row {
        spacing: 8
        anchors.centerIn: parent
        height: control.minHeight * dpScale   // forzar altura

        Text {
            text: control.buttonIcon           // Usar buttonIcon
            font.pixelSize: control.fontSize * 1.2
            color: control.textColor
            visible: control.buttonIcon !== ""  // Usar buttonIcon
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: control.text
            font.pixelSize: control.fontSize * dpScale
            font.bold: control.bold
            font.family: "Segoe UI, Arial, sans-serif"
            color: control.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Fondo del botón
    background: Rectangle {
        radius: control.btnRadius
        color: control.pressed ? control.pressedColor :
               control.hovered ? control.hoverColor : control.buttonColor

        // Borde sutil
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)

        // Sombra interna
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.1) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.1) }
            }
        }

        // Animaciones del color
        Behavior on color {
            enabled: control.animated
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        // Animación de escala al presionar
        scale: control.pressed ? 0.96 : 1.0
        Behavior on scale {
            enabled: control.animated
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }
    }

    // Cursor personalizado
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
        enabled: control.enabled
    }

    // Soporte para atajos de teclado
    Keys.onReturnPressed: control.clicked()
    Keys.onEnterPressed: control.clicked()
    Keys.onSpacePressed: control.clicked()
}