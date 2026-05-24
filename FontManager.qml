import QtQuick 2.15
import Qt.labs.platform 1.1   // Para FileDialog (opcional) y StandardPaths
// Nota: Usamos Qt.labs.platform para leer/escribir archivos fácilmente.
// Si no quieres esa dependencia, puedes implementar con XMLHttpRequest.

QtObject {
    id: fontManager
    property string titleFontFamily: "Changa One"
    property string bodyFontFamily: "Nunito"

    property string configPath: Qt.application.dirPath + "/.fontcfg"

    FontLoader { id: changaOneLoader; source: "changaone.ttf" }
    FontLoader { id: nunitoLoader;    source: "nunito.ttf" }
    FontLoader { id: interLoader;     source: "inter.ttf" }

    function loadConfig() {
        var content = AppBackend.readFile(configPath);
        if (content !== "") {
            var lines = content.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i].trim();
                if (line.startsWith("titleFont="))
                    titleFontFamily = mapFontName(line.substring(10));
                else if (line.startsWith("bodyFont="))
                    bodyFontFamily = mapFontName(line.substring(8));
            }
        } else {
            createDefaultConfig();
        }
    }

    function mapFontName(shortName) {
        if (shortName === "changaone") return "Changa One";
        if (shortName === "nunito") return "Nunito";
        if (shortName === "inter") return "Inter";
        return "Nunito";
    }

    function createDefaultConfig() {
        AppBackend.writeFile(configPath, "titleFont=changaone\nbodyFont=nunito");
        titleFontFamily = "Changa One";
        bodyFontFamily = "Nunito";
    }

    Component.onCompleted: {
        var waitForFonts = function() {
            if (changaOneLoader.status === FontLoader.Ready &&
                nunitoLoader.status === FontLoader.Ready &&
                interLoader.status === FontLoader.Ready) {
                loadConfig();
            } else {
                Qt.callLater(waitForFonts, 50);
            }
        };
        waitForFonts();
    }
}