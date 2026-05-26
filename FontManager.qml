import QtQuick 2.15
import Qt.labs.platform 1.1

QtObject {
    id: fontManager

    // === PROPIEDADES DE FUENTES ACTUALES ===
    property string titleFontFamily: "Changa One"
    property string bodyFontFamily: "Nunito"
    property string monoFontFamily: "Azaret Mono"  // Por si querés mono

    // === RUTA DE CONFIGURACIÓN (con fallback) ===
    property string configPath: {
        try {
            return StandardPaths.writableLocation(StandardPaths.AppConfigLocation) + "/font.cfg"
        } catch(e) {
            // Fallback si StandardPaths falla
            return Qt.application.dirPath + "/.fontcfg"
        }
    }

    // === ESTADO DE CARGA ===
    property bool fontsReady: false
    property bool configLoaded: false

    // === CARGAR FUENTES ===
    FontLoader {
        id: changaOneLoader
        source: "fonts/changaone.ttf"  // Mejor en subcarpeta
        onStatusChanged: checkAllFontsReady()
    }

    FontLoader {
        id: nunitoLoader
        source: "fonts/nunito.ttf"
        onStatusChanged: checkAllFontsReady()
    }

    FontLoader {
        id: interLoader
        source: "fonts/inter.ttf"
        onStatusChanged: checkAllFontsReady()
    }

    // Fuentes mono opcionales
    FontLoader {
        id: azaretmono
        source: "fonts/azaretmono.ttf"
        onStatusChanged: checkAllFontsReady()
    }

    // === VERIFICAR CUANDO TODAS LAS FUENTES ESTÁN LISTAS ===
    function checkAllFontsReady() {
        if (changaOneLoader.status === FontLoader.Ready &&
            nunitoLoader.status === FontLoader.Ready &&
            interLoader.status === FontLoader.Ready) {

            fontsReady = true
            if (!configLoaded) {
                loadConfig()
                configLoaded = true
            }
        }
    }

    // === MAPA DE FUENTES DISPONIBLES ===
    property var availableFonts: ({
        "changaone": {
            name: "Changa One",
            loader: changaOneLoader,
            category: "title",
            displayName: "Changa One (Títulos)"
        },
        "nunito": {
            name: "Nunito",
            loader: nunitoLoader,
            category: "body",
            displayName: "Nunito Regular"
        },
        "inter": {
            name: "Inter",
            loader: interLoader,
            category: "body",
            displayName: "Inter Regular"
        },
        "jetbrains": {
            name: "Azaret Mono",
            loader: azaretmono,
            category: "mono",
            displayName: "Azaret Mono Regular"
        }
    })

    // === CARGAR CONFIGURACIÓN ===
    function loadConfig() {
        try {
            var content = AppBackend.readFile(configPath)

            if (content && content !== "") {
                parseConfigContent(content)
            } else {
                console.log("[FontManager] No se encontró configuración, creando default...")
                createDefaultConfig()
            }
        } catch(e) {
            console.warn("[FontManager] Error al leer configuración:", e)
            createDefaultConfig()
        }
    }

    // === PARSEAR CONTENIDO DE CONFIGURACIÓN ===
    function parseConfigContent(content) {
        var lines = content.split("\n")
        var foundTitle = false
        var foundBody = false

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            // Ignorar comentarios y líneas vacías
            if (line === "" || line.startsWith("#")) continue

            if (line.startsWith("titleFont=")) {
                var titleKey = line.substring(10).trim()
                var mappedTitle = mapFontKey(titleKey)
                if (mappedTitle && availableFonts[titleKey]) {
                    titleFontFamily = mappedTitle
                    foundTitle = true
                    console.log("[FontManager] Título configurado:", mappedTitle)
                }
            } else if (line.startsWith("bodyFont=")) {
                var bodyKey = line.substring(8).trim()
                var mappedBody = mapFontKey(bodyKey)
                if (mappedBody && availableFonts[bodyKey]) {
                    bodyFontFamily = mappedBody
                    foundBody = true
                    console.log("[FontManager] Cuerpo configurado:", mappedBody)
                }
            }
        }

        // Si faltaba alguna, usar defaults
        if (!foundTitle) titleFontFamily = "Changa One"
        if (!foundBody) bodyFontFamily = "Nunito"

        console.log("[FontManager] Configuración cargada:", titleFontFamily, bodyFontFamily)
    }

    // === MAPEAR KEY A NOMBRE DE FUENTE ===
    function mapFontKey(key) {
        if (!key) return null

        var cleanKey = key.toLowerCase().trim()
        var font = availableFonts[cleanKey]

        if (font && font.loader && font.loader.status === FontLoader.Ready) {
            return font.name
        }

        console.warn("[FontManager] Fuente no disponible:", key)
        return null
    }

    // === CREAR CONFIGURACIÓN POR DEFECTO ===
    function createDefaultConfig() {
        var defaultConfig = [
            "# VPT Font Configuration",
            "# Generado automáticamente",
            "",
            "titleFont=changaone",
            "bodyFont=nunito",
            ""
        ].join("\n")

        try {
            AppBackend.writeFile(configPath, defaultConfig)
            console.log("[FontManager] Configuración default creada en:", configPath)
        } catch(e) {
            console.error("[FontManager] Error al crear configuración:", e)
        }

        // Establecer defaults
        titleFontFamily = "Changa One"
        bodyFontFamily = "Nunito"
    }

    // === GUARDAR CONFIGURACIÓN ===
    function saveConfig() {
        var config = [
            "# VPT Font Configuration",
            "# Última modificación: " + new Date().toISOString(),
            "",
            "titleFont=" + getFontKey(titleFontFamily),
            "bodyFont=" + getFontKey(bodyFontFamily),
            ""
        ].join("\n")

        try {
            AppBackend.writeFile(configPath, config)
            console.log("[FontManager] Configuración guardada")
            return true
        } catch(e) {
            console.error("[FontManager] Error al guardar:", e)
            return false
        }
    }

    // === OBTENER KEY DESDE NOMBRE DE FUENTE ===
    function getFontKey(fontName) {
        for (var key in availableFonts) {
            if (availableFonts[key].name === fontName) {
                return key
            }
        }
        return "nunito" // fallback
    }

    // === CAMBIAR FUENTE EN TIEMPO REAL ===
    function setTitleFont(fontKey) {
        var mapped = mapFontKey(fontKey)
        if (mapped) {
            titleFontFamily = mapped
            saveConfig()
            return true
        }
        return false
    }

    function setBodyFont(fontKey) {
        var mapped = mapFontKey(fontKey)
        if (mapped) {
            bodyFontFamily = mapped
            saveConfig()
            return true
        }
        return false
    }

    // === OBTENER LISTA DE FUENTES PARA UI ===
    function getAvailableTitleFonts() {
        var fonts = []
        for (var key in availableFonts) {
            if (availableFonts[key].category === "title" ||
                availableFonts[key].category === "body") {
                fonts.push({
                    key: key,
                    name: availableFonts[key].name,
                    displayName: availableFonts[key].displayName
                })
            }
        }
        return fonts
    }

    function getAvailableBodyFonts() {
        var fonts = []
        for (var key in availableFonts) {
            if (availableFonts[key].category === "body") {
                fonts.push({
                    key: key,
                    name: availableFonts[key].name,
                    displayName: availableFonts[key].displayName
                })
            }
        }
        return fonts
    }

    // === RESETEAR A VALORES POR DEFECTO ===
    function resetToDefaults() {
        titleFontFamily = "Changa One"
        bodyFontFamily = "Nunito"
        saveConfig()
        console.log("[FontManager] Reseteado a defaults")
    }

    // === INICIALIZACIÓN (reemplaza tu Component.onCompleted) ===
    Component.onCompleted: {
        console.log("[FontManager] Inicializando...")
        // checkAllFontsReady se llamará automáticamente cuando las fuentes carguen
    }
}