import QtQuick 2.15
import QtQuick.Controls 2.15
import Qt5Compat.GraphicalEffects

Button {
    id: control

    // =================== PROTECCIÓN DE GLOBALES ===================
    // Si dpScale no existe en tu entorno, usa 1.0 por defecto para que no falle.
    readonly property real dp: typeof dpScale !== "undefined" ? dpScale : 1.0

    // =================== PROPIEDADES ===================
    property color buttonColor: "#1a1c2b"
    property color textColor: "#ffffff"
    property color glowColor: Qt.rgba(buttonColor.r, buttonColor.g, buttonColor.b, 0.4)

    property int btnRadius: 10
    property int fontSize: 13
    property bool bold: true
    property string buttonIcon: ""
    property bool animated: true
    property int minHeight: 44

    property int animationId: 1                 // 0: normal, 1: sweep, 2: pulso
    property real pulseScale: 1.0               // Controlado por la animación de pulso

    // Detección robusta del modo oscuro
    property bool darkMode: {
        try {
            if (typeof AppBackend !== "undefined" && AppBackend.fileExists)
                return AppBackend.fileExists(Qt.application.dirPath + "/.dark")
        } catch(e) {}
        return false
    }

    property color hoverColor: darkMode ? Qt.darker(buttonColor, 1.15) : Qt.lighter(buttonColor, 1.15)
    property color pressedColor: Qt.darker(buttonColor, 1.25)

    flat: false
    hoverEnabled: true

    implicitHeight: Math.max(minHeight * dp, contentItem.implicitHeight + topPadding + bottomPadding)
    implicitWidth: Math.max(80 * dp, contentItem.implicitWidth + leftPadding + rightPadding)

    topPadding: 10 * dp
    bottomPadding: 10 * dp
    leftPadding: 16 * dp
    rightPadding: 16 * dp

    // Animación de escala global del botón
    scale: control.pressed ? 0.95 : pulseScale
    Behavior on scale {
        enabled: control.animated
        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
    }

    // =================== CONTENIDO (icono + texto) ===================
    contentItem: Row {
        spacing: 8 * dp
        anchors.centerIn: parent

        Loader {
            active: control.buttonIcon !== ""
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: {
                if (control.buttonIcon.includes("/") || control.buttonIcon.includes("."))
                    return iconImageComponent
                else
                    return iconTextComponent
            }
        }

        Component {
            id: iconImageComponent
            Image {
                source: control.buttonIcon
                width: control.fontSize * 1.6 * dp
                height: width
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }

        Component {
            id: iconTextComponent
            Text {
                text: control.buttonIcon
                font.pixelSize: control.fontSize * 1.4 * dp
                color: control.textColor
                font.family: control.activeFontFamily
            }
        }

        Text {
            text: control.text
            font.pixelSize: control.fontSize * dp
            font.bold: control.bold
            font.family: control.activeFontFamily
            color: control.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // =================== FONDO ===================
    background: Item {
        id: bgContainer

        // Glow externo al hacer hover
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4 * dp
            radius: control.btnRadius + (4 * dp)
            color: "transparent"
            border.width: control.hovered && !control.pressed ? 3 * dp : 0
            border.color: control.glowColor
            opacity: control.hovered && !control.pressed ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: 250 } }
        }

        // Rectángulo principal base
        Rectangle {
            id: baseRect
            anchors.fill: parent
            radius: control.btnRadius
            color: control.pressed ? control.pressedColor :
                   control.hovered ? control.hoverColor : control.buttonColor
            border.width: 1 * dp
            border.color: Qt.rgba(1, 1, 1, 0.2)

            Behavior on color {
                enabled: control.animated
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
        }

        // Máscara para evitar que los efectos internos se salgan de las esquinas redondeadas
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: bgContainer.width
                    height: bgContainer.height
                    radius: control.btnRadius
                }
            }

            // Sombra interna superior para dar sutil volumen
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.1) }
                    GradientStop { position: 0.3; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.08) }
                }
            }

            // ---------- Efecto Ripple (Ondulación al hacer clic) ----------
            Rectangle {
                id: ripple
                color: Qt.rgba(1, 1, 1, 0.4)
                width: Math.max(bgContainer.width, bgContainer.height) * 2.5
                height: width
                radius: width / 2
                scale: 0
                opacity: 0
                transformOrigin: Item.Center
                // Las posiciones X e Y se asigan desde Javascript

                ParallelAnimation {
                    id: rippleAnim
                    NumberAnimation { target: ripple; property: "scale"; from: 0; to: 1; duration: 400; easing.type: Easing.OutQuart }
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.6; to: 0; duration: 400; easing.type: Easing.InQuad }
                }
            }

            // ---------- Efecto Sweep (animationId == 1) ----------
            Rectangle {
                id: sweepRect
                width: bgContainer.width * 0.8
                height: bgContainer.height * 2.5
                y: -bgContainer.height * 0.5
                rotation: 25 // Le da ese aspecto clásico inclinado de luz que pasa
                opacity: 0
                visible: control.animationId === 1

                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                    GradientStop { position: 1.0; color: "transparent" }
                }

                SequentialAnimation {
                    id: sweepAnim
                    PropertyAction { target: sweepRect; property: "opacity"; value: 1.0 }
                    NumberAnimation {
                        target: sweepRect; property: "x"
                        from: -sweepRect.width * 1.5
                        to: bgContainer.width + sweepRect.width
                        duration: 650; easing.type: Easing.InOutSine
                    }
                    PropertyAction { target: sweepRect; property: "opacity"; value: 0 }
                }
            }
        }
    }

    // =================== CAPTURA DE EFECTOS (NO SOBREESCRIBE EL BOTÓN) ===================
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: true // Permite que el botón detecte el click

        onPressed: function(mouse) {
            // Calcular centro del ripple en base a donde se hizo el click
            ripple.x = mouse.x - ripple.width / 2
            ripple.y = mouse.y - ripple.height / 2
            rippleAnim.restart()

            // Rechazamos el evento final en el mouse area para que el componente
            // padre "Button" asuma el press y ejecute su "onClicked" de forma nativa.
            mouse.accepted = false
        }
    }

    // =================== ANIMACIÓN DE PULSO (animationId == 2) ===================
    SequentialAnimation {
        id: pulseAnim
        loops: Animation.Infinite
        running: control.hovered && control.animationId === 2 && !control.pressed
        onStopped: control.pulseScale = 1.0

        NumberAnimation {
            target: control; property: "pulseScale"
            from: 1.0; to: 1.04
            duration: 700; easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: control; property: "pulseScale"
            from: 1.04; to: 1.0
            duration: 700; easing.type: Easing.InOutSine
        }
    }

    // =================== CONTROLADORES DE EVENTOS ===================
    onHoveredChanged: {
        if (hovered && animationId === 1) {
            sweepAnim.restart()
        }
    }
}