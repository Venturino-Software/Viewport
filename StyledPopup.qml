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

Popup {
    id: root
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    padding: 20 * dpScale

    // Propiedades personalizables
    property color bgColor: "#1a1c2b"
    property color accentColor: "#4fc3f7"
    property int popupRadius: 16

    // Fondo con bordes redondeados (sin DropShadow)
    background: Rectangle {
        radius: root.popupRadius
        color: root.bgColor
        border.width: 2
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3)

        // Simular sombra con gradiente en el borde
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: root.popupRadius + 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.5)
            z: -1
        }

        // Línea decorativa superior
        Rectangle {
            width: parent.width
            height: 3
            radius: 3
            color: root.accentColor
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.92; to: 1; duration: 250; easing: Easing.OutBack }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: 150; easing: Easing.InCubic }
            NumberAnimation { property: "scale"; to: 0.96; duration: 150; easing: Easing.InCubic }
        }
    }

    // Overlay semitransparente
    Overlay.modal: Rectangle {
        color: "#80000000"

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        // Animación al abrir/cerrar
        opacity: root.opened ? 1 : 0
    }
}