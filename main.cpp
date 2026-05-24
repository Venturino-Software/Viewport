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
#include "backend.h"
#include "iconprovider.h"  // o donde lo pongas
#include <QIcon> // Asegúrate de incluir esto

int main(int argc, char *argv[])
{
    qputenv("QT_QPA_PLATFORM", "wayland");
    qputenv("QT_WAYLAND_FORCE_DPI", "physical");
    qputenv("QT_SCALE_FACTOR", "1");

    QGuiApplication app(argc, argv);

    // 1. Definimos las rutas donde sabemos que existen tus iconos
    QStringList iconPaths;
    iconPaths << "/usr/share/icons" << "/usr/share/pixmaps" << "/snap/gtk-common-themes/current/share/icons";

    // 2. Le decimos a Qt que añada estas rutas a su búsqueda
    QIcon::setThemeSearchPaths(iconPaths);

    QIcon::setThemeName("Yaru");
    QIcon::setFallbackThemeName("hicolor");

    QQmlApplicationEngine engine;

    Backend appBackend;

    engine.addImageProvider("icon", new IconProvider);
    engine.rootContext()->setContextProperty("AppBackend", &appBackend);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.load(QUrl::fromLocalFile("Main.qml"));

    return QGuiApplication::exec();
}