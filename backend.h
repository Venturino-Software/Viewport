/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VNT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
 */

#ifndef BACKEND_H
#define BACKEND_H

#include <QObject>
#include <QProcess>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QVariantList>
#include <QVariantMap>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QLocale>
#include <QSettings>
#include <QFileInfo>
#include <qjsvalue.h>

class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isFirstRun READ isFirstRun NOTIFY isFirstRunChanged)
public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend();
    bool isFirstRun() {
        return !QFile::exists("/vpt/flags/.atp_setup_done");
    }
    Q_INVOKABLE QVariantList loadDesktopApps();
    Q_INVOKABLE void openApp(const QString &execCommand);
    Q_INVOKABLE void runNS(const QString &args);


    // Nuevos métodos para popups
    Q_INVOKABLE void runCommandWithOutput(const QString &command);
    Q_INVOKABLE int getVolume();
    Q_INVOKABLE void setVolume(int vol);
    Q_INVOKABLE void playTestSound();
    Q_INVOKABLE int getBrightness();
    Q_INVOKABLE void setBrightness(int val);
    Q_INVOKABLE QVariantList scanWifi();
    Q_INVOKABLE void connectWifi(const QString &ssid, const QString &password);
    Q_INVOKABLE void aptInstall(const QString &package, const QString &sudoPassword);


    Q_INVOKABLE void runGenericScript(const QString &scriptPath) {
        // Ejecuta independiente sin congelar la interfaz
        QProcess::startDetached("/bin/bash", QStringList() << scriptPath);
    }

    Q_INVOKABLE void markSetupAsDone() {
        QFile file("/vpt/flags/.atp_setup_done");
        if (file.open(QIODevice::WriteOnly)) {
            file.write("ATP_OS_INITIALIZED");
            file.close();
            emit isFirstRunChanged();
        }
    }

    Q_INVOKABLE void resetSetup() {
        QFile file("/vpt/flags.atp_setup_done");
        if (file.exists()) {
            file.remove(); // Borramos el archivo testigo de Debian
            emit isFirstRunChanged(); // Le avisamos a QML que isFirstRun cambió
        }
    }

    Q_INVOKABLE QString readFile(const QString& path);
    Q_INVOKABLE void writeFile(const QString& path, const QString& content);

    Q_INVOKABLE void runCommandWithSudo(const QString &command, const QString &password, QJSValue callback = QJSValue());

    Q_INVOKABLE void runPkexec(const QString &command);
    Q_INVOKABLE void checkForUpdates(); // combina apt update + análisis

    Q_INVOKABLE void playSound(const QString &source) {
        QString res = "/vpt/bin/src/" + source;
        QProcess::startDetached("aplay", {res});
    }

signals:
    void appClosed();
    void commandOutput(const QString &text);
    void aptProgress(int percent, const QString &lastLine);
    void aptFinished(bool success);
    void logUpdated(QString message); // <--- DEBE estar aquí
    void isFirstRunChanged();
    void updatesAvailable(int count, const QString &packages);

private:
    QProcess *m_currentProcess;
};


#endif // BACKEND_H