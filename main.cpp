#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext> // Necesario para setContextProperty
#include "backend.h"

int main(int argc, char *argv[])
{
    // Como estás usando cage-wayland, es una buena práctica asegurar
    // que Qt priorice el plugin nativo de Wayland en lugar de XCB/XWayland.
    qputenv("QT_QPA_PLATFORM", "wayland");

    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    // Instanciamos tu clase puente C++
    Backend appBackend;

    // Registramos la instancia en QML bajo el nombre "AppBackend"
    engine.rootContext()->setContextProperty("AppBackend", &appBackend);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("vpt01", "Main");

    return QGuiApplication::exec();
}