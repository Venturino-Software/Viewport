import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: rootPill

    // --- PROPIEDADES PÚBLICAS ---
    property color bgColor: "#1a1c2b"
    property color accentColor: "#7f99ff"
    property real dpScale: typeof globalDpScale !== "undefined" ? globalDpScale : 1.0

    property StyledPopup sudoWarningPopup: null
    property StyledPopup terminalPopup: null
    property var searchOverlayRef: null


    // Posicionamiento ideal (Abajo en el centro)
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: 60 * dpScale

    width: Math.min(600 * dpScale, parent.width * 0.9)
    height: 56 * dpScale
    signal pillOpened()

    Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        // LÓGICA UNIFICADA de visibilidad
        onVisibleChanged: {
            if (visible) {
                // Cerrar el buscador si está abierto
                if (searchOverlayRef && searchOverlayRef.state === "VISIBLE") {
                    searchOverlayRef.state = "HIDDEN"
                }
                opacity = 1
                y = 0
                commandInput.forceActiveFocus()
            } else {
                opacity = 0
                y = 30 * dpScale
            }
        }
    function tryExecute() {
        if (commandInput.text.trim() === "") return;

        let prefix = prefixCombo.currentText;
        let command = commandInput.text.trim();
        let fullCommand = prefix.toLowerCase() + " " + command;

        if (prefix === "Sudo") {
            sudoWarningPopup.pendingCommand = "/usr/bin/pkexec /usr/bin/" + command;
            AppBackend.playSound("critical.wav")
            sudoWarningPopup.open();
        } else if (prefix === "Apt") {
            AppBackend.playSound("detail.wav")
            runInTerminal("/usr/bin/pkexec /usr/bin/" + fullCommand)
        } else if (prefix === "$") {
            AppBackend.playSound("subt-ui.wav")
            runInTerminal(command);
        } else {
            runInTerminal("/usr/bin/" + fullCommand);
        }
    }

    function runInTerminal(cmd) {
        terminalPopup.command = cmd;
        terminalPopup.open();
        commandInput.text = ""; // Limpiar tras enviar
    }


    // --- FONDO DE LA PILL ---
    Rectangle {
        id: pillBackground
        anchors.fill: parent
        color: rootPill.bgColor
        radius: height / 2 // Esto la hace una verdadera "Pill"
        border.color: Qt.darker(rootPill.bgColor, 1.2)
        border.width: 1 * dpScale

        RowLayout {
            anchors.fill: parent
            anchors.margins: 6 * dpScale
            spacing: 8 * dpScale

            // 1. DROPDOWN (Comandos Base)
            ComboBox {
                id: prefixCombo
                model: ["$", "Apt", "Sudo", "Sh"]
                Layout.preferredWidth: 110 * dpScale
                Layout.fillHeight: true

                background: Rectangle {
                    color: "transparent"
                    radius: height / 2
                }

                contentItem: Text {
                    text: prefixCombo.displayText
                    color: rootPill.accentColor
                    font.bold: true
                    font.pixelSize: 14 * dpScale
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                // Personalización para que se abra HACIA ARRIBA y con bordes redondeados
                popup: Popup {
                    clip: true
                    y: -height - (10 * dpScale) // Abre hacia arriba, con un margen de 10
                    width: prefixCombo.width
                    implicitHeight: contentItem.implicitHeight
                    padding: 4 * dpScale

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: prefixCombo.popup.visible ? prefixCombo.delegateModel : null
                        currentIndex: prefixCombo.highlightedIndex
                        ScrollIndicator.vertical: ScrollIndicator { }
                    }

                    background: Rectangle {
                        color: rootPill.bgColor
                        radius: 16 * dpScale // Pill style dropdown
                        border.color: rootPill.accentColor
                        border.width: 1 * dpScale
                    }
                }

                delegate: ItemDelegate {
                    width: prefixCombo.width
                    height: 40 * dpScale
                    contentItem: Text {
                        text: modelData
                        color: highlighted ? rootPill.accentColor : "#ffffff"
                        font.bold: highlighted
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        color: highlighted ? Qt.darker(rootPill.accentColor, 3.0) : "transparent"
                        radius: 12 * dpScale
                    }
                }
            }

            // Separador Visual
            Rectangle {
                Layout.preferredWidth: 2 * dpScale
                Layout.fillHeight: true
                Layout.topMargin: 10 * dpScale
                Layout.bottomMargin: 10 * dpScale
                color: "#33354a"
                radius: 1
            }

            // 2. TEXT FIELD (Entrada del comando)
            TextField {
                id: commandInput
                Layout.fillWidth: true
                Layout.fillHeight: true
                placeholderText: "Escribe tu comando aquí..."
                placeholderTextColor: "#666980"
                color: "#ffffff"
                font.pixelSize: 15 * dpScale
                wrapMode: TextInput.NoWrap

                background: Item {} // Fondo transparente para que se vea la pill

                Keys.onReturnPressed: rootPill.tryExecute()
                Keys.onEnterPressed: rootPill.tryExecute()
                // Detección automática de prefijos
                property bool _updatingText: false

                onTextChanged: {
                    if (_updatingText) return

                    let t = text
                    let lower = t.toLowerCase()

                    // Define las reglas: palabra clave, índice en el ComboBox, solo al inicio o en cualquier parte
                    let rules = [
                        { keyword: "sudo", index: 2, startOnly: false },  // Sudo en cualquier posición
                        { keyword: "apt",  index: 1, startOnly: true  },
                        { keyword: "sh",   index: 3, startOnly: true  }
                    ]

                    for (let r of rules) {
                        let match = null
                        if (r.startOnly) {
                            // Solo al principio (ignorando espacios iniciales)
                            match = t.match(new RegExp(`^\\s*${r.keyword}(?=\\s|$)`, "i"))
                        } else {
                            // En cualquier lugar como palabra completa
                            match = t.match(new RegExp(`\\b${r.keyword}(?=\\s|$)`, "i"))
                        }

                        if (match) {
                            if (prefixCombo.currentIndex !== r.index) {
                                _updatingText = true
                                prefixCombo.currentIndex = r.index
                                // Elimina la palabra clave y los espacios que la rodean
                                let newText = t.slice(0, match.index) + t.slice(match.index + match[0].length)
                                // Limpia espacios múltiples que puedan quedar
                                commandInput.text = newText.trim().replace(/\s+/g, " ")
                                _updatingText = false
                            }
                            break  // solo aplica una regla por cambio
                        }
                    }
                }
            }

            // 3. BOTÓN DE ENVIAR
            Button {
                id: sendBtn
                Layout.preferredWidth: height
                Layout.fillHeight: true

                background: Rectangle {
                    color: sendBtn.pressed ? Qt.darker(rootPill.accentColor, 1.2) : rootPill.accentColor
                    radius: height / 2 // Botón circular dentro de la pill
                }

                contentItem: Text {
                    text: "➤" // Puedes cambiarlo por un icono FontAwesome
                    color: rootPill.bgColor
                    font.pixelSize: 18 * dpScale
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: rootPill.tryExecute()
            }
        }
    }
}