#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext> // Necesario para setContextProperty
#include "backend.h"

int main(int argc, char *argv[])
{
    // Como estás usando cage-wayland, es una buena práctica asegurar
    // que Qt priorice el plugin nativo de Wayland en lugar de XCB/XWayland.
    qputenv("QT_QPA_PLATFORM", "wayland");
    qputenv("QT_WAYLAND_FORCE_DPI", "physical"); // Usa DPI físico del monitor
    qputenv("QT_SCALE_FACTOR", "1"); // Para que Qt no sobrescriba nuestro dpScale

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