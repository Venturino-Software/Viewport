/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VNT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
 *
 * lib-vptcomponents
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects
import QtQuick.Window 2.15   // <--- ESTO ES LO QUE FALTA

Popup {
    id: root
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    // Protección global del escalado (dpScale)
    readonly property real dp: typeof dpScale !== "undefined" ? dpScale : 1.0
    padding: 24 * dp
    property string title: ""
    property string fontType: "body"  // "title", "body" o "mono"
    readonly property string activeFont: {
        if (typeof FontManager !== "undefined" && FontManager) {
            switch(fontType) {
                case "title": return FontManager.titleFontFamily
                case "mono": return FontManager.monoFontFamily || "JetBrains Mono"
                default: return FontManager.bodyFontFamily
            }
        }
        return fontType === "title" ? "Changa One" : "Nunito"
    }

    // =================== PROPIEDADES ===================
    // Cambia tus propiedades en los archivos donde definas el estilo
    property color bgColor: "#1a1c2b"      // Mantenemos este fondo oscuro para contraste
    property color accentColor: "#7f99ff" // Este es el nuevo color central
    property int popupRadius: 16

    // Control interno para animaciones ambientales
    property bool isOpened: false

    property bool disableDefs: false
    property string verticalAlignment: "center" // "center" o "high"

    onOpened: {
        isOpened = true
        console.log("Popup opened. Overlay size:",
                    root.Overlay.overlay ? root.Overlay.overlay.width : "no overlay",
                    "Popup pos:", x, y,
                    "Parent:", parent)
    }
    onClosed: isOpened = false

    // Si disableDefs es true, se vuelve null y libera el posicionamiento manual
    anchors.centerIn: disableDefs ? null : parent

    x: {
        if (disableDefs && root.Overlay.overlay) {
            return (root.Overlay.overlay.width - width) / 2
        }
        return undefined
    }
    y: {
        if (disableDefs && root.Overlay.overlay) {
            var baseY = (root.Overlay.overlay.height - height) / 2
            if (verticalAlignment === "high")
                baseY -= 120 * dp
            return baseY
        }
        return undefined
    }

    // =================== FONDO Y EFECTOS ===================
    background: Item {
        id: bgContainer

        // 1. Sombra exterior realista y optimizada
        RectangularGlow {
            id: popupShadow
            anchors.fill: bgRect
            glowRadius: 25 * dp
            spread: 0.05
            color: Qt.rgba(0, 0, 0, 0.5)
            cornerRadius: bgRect.radius + glowRadius

            // La sombra crece suavemente al abrir el popup
            scale: root.scale
            opacity: root.opacity
        }

        // 2. Fondo principal con degradado
        Rectangle {
            id: bgRect
            anchors.fill: parent
            radius: root.popupRadius * dp
            border.width: 1 * dp
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2)
            clip: true // Evita que los elementos internos salgan de las curvas

gradient: Gradient {
    orientation: Gradient.Vertical
    GradientStop { position: 0.0; color: Qt.lighter(root.bgColor, 1.1) }
    GradientStop { position: 1.0; color: root.bgColor }
}
            // 3. Línea decorativa superior
            Rectangle {
                id: topAccent
                width: parent.width
                height: 4 * dp
                color: root.accentColor
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Brillo emitiendo de la línea superior (Efecto Neón)
            Glow {
                anchors.fill: topAccent
                source: topAccent
                radius: 12 * dp
                samples: 25
                color: root.accentColor
                transparentBorder: true
                opacity: 0.6

                // Efecto de "respiración" para el brillo
                SequentialAnimation on opacity {
                    running: root.isOpened
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 1500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.8; duration: 1500; easing.type: Easing.InOutSine }
                }
            }
        }
    }
    // =================== OVERLAY (Fondo de pantalla modal) ===================
    Overlay.modal: Item {
        // En lugar de un color sólido, usamos un degradado radial (Viñeta)
        // Esto crea un "foco de luz" virtual detrás del popup
        RadialGradient {
            anchors.fill: parent
            horizontalOffset: 0
            verticalOffset: 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.4) } // Centro más claro
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) } // Bordes oscuros
            }
        }

        // Transición de opacidad al abrir/cerrar
        opacity: root.opened ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // =================== ANIMACIONES DE ENTRADA Y SALIDA ===================
    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0.0; to: 1.0
                duration: 250
                easing.type: Easing.OutSine
            }
            NumberAnimation {
                property: "scale"
                from: 0.85; to: 1.0
                duration: 400
                // OutBack le da un ligero "rebote" al terminar de agrandarse
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1.0; to: 0.0
                duration: 200
                easing.type: Easing.InSine
            }
            NumberAnimation {
                property: "scale"
                from: 1.0; to: 0.9
                duration: 250
                easing.type: Easing.InBack
                easing.overshoot: 1.0
            }
        }
    }

}