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

class Backend : public QObject
{
    Q_OBJECT
public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend();

    Q_INVOKABLE QVariantList loadDesktopApps();
    Q_INVOKABLE void openApp(const QString &execCommand);

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

signals:
    void appClosed();
    void commandOutput(const QString &text);
    void aptProgress(int percent, const QString &lastLine);
    void aptFinished(bool success);

private:
    QProcess *m_currentProcess;
};

#endif // BACKEND_H