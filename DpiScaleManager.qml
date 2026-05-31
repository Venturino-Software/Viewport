/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VNT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
 *
 * Powered by Debian 13 (trixie)
 * VPT
 * \- The Joints Library
 * \- The Viewport Library
 * \- The ATP Utils Library
 *
 * Thanks for all for contributing this proyect.
 * [last milestone=100 commits]
 *
 * Developed by:
 * a little bit of AI
 * - gemini 3.1 pro (20% design)
 * - deepseek R1 (debug)
 * soooo much human
 * - Soyzian (Soy Zeus Ian Ruffo)
 * -- (Soy-Z-Ian):
 * 100% participation:
 * - lib-vpt-components
 * - lib-atp-loader
 * - sources - background design
 * - git - repo
 * - UX/UI main leader
 * 70% participation:
 * - all rest of viewport
 * 0% participation:
 * - none
 *
 * All people is welcome to contribute to viewport, following the next link:
 *
 *       /---------------  Viewport Repository  -------------------\
 *              https://github.com/Venturino-Software/Viewport
 *       \---------------------------------------------------------/
 *          -   Composition
 *              QML 66.6%   [##############      ] .qml
 *              C++ 29.1%   [#######             ] .h .cpp
 *              CMake 3.6%  [##                  ] <cmake>
 *              Shell 0.7%  [#                   ] .sh .zsh
 *        /------------------  Venturino Site  --------------------\
 *                  https://github.com/Venturino-Software
 *       \---------------------------------------------------------/
 *          -   Composition
 *              Top Language: QML [X]
 *
 */


import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: dpiManager
    property real scaleFactor: 1.0
    property bool ready: false

    readonly property real dpScale: scaleFactor

    // Ruta del archivo de configuración
    readonly property string configPath: {
        var home = (typeof AppBackend !== "undefined" && AppBackend.getHomeDir) ?
                   AppBackend.getHomeDir() : Qt.environmentVariables("HOME")[0]
        return home + "/.config/viewport/dpicfg"
    }

    function saveConfig() {
        if (typeof AppBackend !== "undefined" && AppBackend.writeFile) {
            AppBackend.writeFile(configPath, scaleFactor.toString())
        } else {
            console.warn("No se pudo guardar dpicfg")
        }
    }

    function loadConfig() {
        if (typeof AppBackend !== "undefined" && AppBackend.fileExists &&
            AppBackend.fileExists(configPath)) {
            var content = AppBackend.readFile(configPath)
            if (content !== "") {
                var loaded = parseFloat(content)
                if (!isNaN(loaded) && loaded >= 0.5 && loaded <= 2.0)
                    scaleFactor = loaded
            }
        }
        ready = true
    }

    function changeScale(delta) {
        var newScale = scaleFactor + delta
        if (newScale < 0.5) newScale = 0.5
        if (newScale > 2.0) newScale = 2.0
        if (newScale !== scaleFactor) {
            scaleFactor = newScale
            saveConfig()
        }
    }

    Component.onCompleted: loadConfig()
}