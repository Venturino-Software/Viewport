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
#include <QPalette>
#include "backend.h"
#include "iconprovider.h"

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_STYLE", "Fusion");
    qputenv("QT_QPA_PLATFORM", "wayland");
    qputenv("QT_WAYLAND_FORCE_DPI", "physical");
    qputenv("QT_SCALE_FACTOR", "1.65");
    qputenv("QT_WAYLAND_FORCE_DPI", "physical");
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);

    QGuiApplication app(argc, argv);

    // 1. Rutas de iconos
    QStringList iconPaths;
    iconPaths << "/usr/share/icons"
              << "/usr/share/pixmaps"
              << "/snap/gtk-common-themes/current/share/icons";
    QIcon::setThemeSearchPaths(iconPaths);
    QIcon::setThemeName("Adwaita");
    QIcon::setFallbackThemeName("hicolor");
    Backend appBackend;
    QString testWav = "/vpt/pop.wav";
    QString videoPath = "/vpt/bin/media/helloworld.mp4";
    if (!QFile::exists(videoPath)) {
        qWarning() << videoPath << "no existe!";
        // Crear directorio si no existe
        QDir().mkpath("/vpt/bin/media");
    }
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("AppBackend", &appBackend);
    engine.addImageProvider("icon", new IconProvider);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(QUrl::fromLocalFile("Main.qml"));

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Error: No se pudo cargar Main.qml";
        return -1;
    }

    return app.exec();
}