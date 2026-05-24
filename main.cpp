/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VNT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
 */

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QDir>
#include "backend.h"
#include "iconprovider.h"

int main(int argc, char *argv[])
{
    qputenv("QT_QPA_PLATFORM", "wayland");
    qputenv("QT_WAYLAND_FORCE_DPI", "physical");
    qputenv("QT_SCALE_FACTOR", "1");

    QGuiApplication app(argc, argv);

    // 1. Rutas de iconos
    QStringList iconPaths;
    iconPaths << "/usr/share/icons"
              << "/usr/share/pixmaps"
              << "/snap/gtk-common-themes/current/share/icons";
    QIcon::setThemeSearchPaths(iconPaths);
    QIcon::setThemeName("Yaru");
    QIcon::setFallbackThemeName("hicolor");

    // 2. ✅ CREAR Backend ANTES de exponerlo
    Backend appBackend;

    // 3. ✅ Verificar paths necesarios
    QDir vptDir("/vpt");
    if (!vptDir.exists()) {
        qWarning() << "/vpt no existe, creando...";
        QDir().mkpath("/vpt/etc/sounds");
        QDir().mkpath("/vpt/share/media");
        QDir().mkpath("/vpt/adm/bin");
    }

    // 4. ✅ Verificar archivos requeridos
    QString testWav = "/vpt/etc/sounds/test.wav";
    if (!QFile::exists(testWav)) {
        qWarning() << testWav << "no existe, creando dummy...";
        QFile file(testWav);
        if (file.open(QIODevice::WriteOnly)) {
            file.close();
        }
    }

    QString videoPath = "/vpt/share/media/helloworld.mp4";
    if (!QFile::exists(videoPath)) {
        qWarning() << videoPath << "no existe!";
        // Crear directorio si no existe
        QDir().mkpath("/vpt/share/media");
    }

    // 5. ✅ Exponer Backend AL CONTEXTO QML
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("AppBackend", &appBackend);

    // 6. ✅ Agregar ImageProvider
    engine.addImageProvider("icon", new IconProvider);

    // 7. ✅ Conexión de errores
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    // 8. ✅ Cargar QML
    engine.load(QUrl::fromLocalFile("Main.qml"));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Error: No se pudo cargar Main.qml";
        return -1;
    }

    return app.exec();
}