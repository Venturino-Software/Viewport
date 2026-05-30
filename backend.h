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
#include <QtConcurrent/QtConcurrent>
#include <alsa/asoundlib.h>

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
        QProcess::startDetached("/usr/bin/pkexec /bin/bash", QStringList() << scriptPath);
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

    Q_INVOKABLE void runCommand(const QString &cmd) {
        // Ejecuta el comando en un hilo separado de forma asíncrona
        // para que la interfaz QML no se congele mientras cambia la resolución
        QProcess::startDetached("/bin/sh", QStringList() << "-c" << cmd);
    }

    Q_INVOKABLE void runPkexec(const QString &command);
    Q_INVOKABLE void checkForUpdates(); // combina apt update + análisis
    Q_INVOKABLE void playSound(const QString &fileName)
    {
        // Capturamos la ruta completa y delegamos a un hilo secundario
        QString fullPath = "/vpt/bin/src/" + fileName;
        QThreadPool::globalInstance()->start([this, fullPath]() {
            // --- Aquí va toda la lógica de reproducción (bloqueante) ---
            QFile file(fullPath);
            if (!file.open(QIODevice::ReadOnly)) {
                qDebug() << "[ALSA] No se pudo abrir el archivo:" << fullPath;
                return;
            }

            QByteArray rawData = file.readAll();
            file.close();

            if (rawData.size() < 44) {
                qDebug() << "[ALSA] Archivo demasiado pequeño para WAV";
                return;
            }

            // Validar cabecera RIFF y WAVE
            if (rawData.mid(0, 4) != "RIFF" || rawData.mid(8, 4) != "WAVE") {
                qDebug() << "[ALSA] No es un WAV válido (cabecera incorrecta)";
                return;
            }

            // Buscar el chunk 'data'
            int dataOffset = -1;
            quint32 dataSize = 0;
            int pos = 12;
            while (pos + 8 <= rawData.size()) {
                QByteArray chunkId = rawData.mid(pos, 4);
                quint32 chunkSize = *reinterpret_cast<const quint32*>(rawData.constData() + pos + 4);
                if (chunkId == "data") {
                    dataOffset = pos + 8;
                    dataSize = chunkSize;
                    break;
                }
                pos += 8 + chunkSize;
            }

            if (dataOffset == -1 || dataOffset + dataSize > rawData.size()) {
                qDebug() << "[ALSA] No se encontró el chunk 'data'";
                return;
            }

            QByteArray pcmData = rawData.mid(dataOffset, dataSize);
            const int bytesPerFrame = 4; // estéreo 16-bit
            if (pcmData.size() % bytesPerFrame != 0) {
                qDebug() << "[ALSA] Datos PCM no múltiplo de" << bytesPerFrame << "bytes";
                return;
            }

            snd_pcm_t *handle = nullptr;
            int err;

            err = snd_pcm_open(&handle, "default", SND_PCM_STREAM_PLAYBACK, 0);
            if (err < 0) {
                qDebug() << "[ALSA] Error al abrir dispositivo:" << snd_strerror(err);
                return;
            }

            err = snd_pcm_set_params(handle,
                                     SND_PCM_FORMAT_S16_LE,
                                     SND_PCM_ACCESS_RW_INTERLEAVED,
                                     2,      // canales
                                     48000,  // frecuencia
                                     1,      // resample software permitido
                                     50000); // latencia 50ms
            if (err < 0) {
                qDebug() << "[ALSA] Error al configurar parámetros:" << snd_strerror(err);
                snd_pcm_close(handle);
                return;
            }

            // ... (después de snd_pcm_set_params)

            err = snd_pcm_prepare(handle); // <--- ESTO ES VITAL
            if (err < 0) {
                qDebug() << "[ALSA] Error al preparar el dispositivo:" << snd_strerror(err);
                snd_pcm_close(handle);
                return;
            }

            // Ahora sí, escribimos
            snd_pcm_sframes_t frames = snd_pcm_writei(handle, pcmData.constData(), pcmData.size() / bytesPerFrame);
            if (frames < 0) {
                qDebug() << "[ALSA] Error escribiendo datos:" << snd_strerror(frames);
            } else if (frames != static_cast<snd_pcm_sframes_t>(pcmData.size() / bytesPerFrame)) {
                qDebug() << "[ALSA] Solo se escribieron" << frames << "frames de" << (pcmData.size() / bytesPerFrame);
            }

            snd_pcm_drain(handle);
            snd_pcm_close(handle);
            qDebug() << "[ALSA] Reproducción finalizada:" << fullPath;
        });
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