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