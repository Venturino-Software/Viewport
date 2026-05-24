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

signals:
    void appClosed();
    void commandOutput(const QString &text);
    void aptProgress(int percent, const QString &lastLine);
    void aptFinished(bool success);
    void logUpdated(QString message); // <--- DEBE estar aquí
    void isFirstRunChanged();

private:
    QProcess *m_currentProcess;
};


#endif // BACKEND_H