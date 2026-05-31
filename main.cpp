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