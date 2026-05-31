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
#include <QMutex>
#include <QJsonDocument>
#include <QJsonObject>

#include <alsa/asoundlib.h>

class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isFirstRun READ isFirstRun NOTIFY isFirstRunChanged)
public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend();
    /*
     *
     *  lib-vpt
     *
     */
    bool isFirstRun() {
        return !QFile::exists("/vpt/flags/.atp_setup_done");
    }
    Q_INVOKABLE QVariantList loadDesktopApps();
    /*
     *
     *  lib-jt-eds (management of cage ""ENVIROVEMENT DESKTOP SERVER"")
     *
     */
    Q_INVOKABLE void openApp(const QString &execCommand);
    /*
     *
     *  lib-atp-cmdwrap
     *
     */
    Q_INVOKABLE void runCommandWithOutput(const QString &command);
    /*
     *
     *  lib-tj-hyper + lib-pc-mobility
     *
     *  HYPER: The wrapper of the kit (The Joints) that makes
     *  viewport&atp sooo well integrated with the app
     *
     *  MOBILITY: The library of functions thinked about
     *  devices diferences and making some well...
     *  adaptations.
     *
     *  lib-...-HYPER+MOBILITY are fusioned on this script
     *  for a more deep management of the system.
     *
     */

    /*
     *  lib-tj-hyper + lib-pc-mobility (sound)
     */
    Q_INVOKABLE int getVolume();
    Q_INVOKABLE void setVolume(int vol);
    Q_INVOKABLE void playTestSound();
    /*
     *  lib-tj-hyper + lib-pc-mobility (brigthness)
     */
    Q_INVOKABLE int getBrightness();
    Q_INVOKABLE void setBrightness(int val);
    /*
     *  lib-tj-hyper + lib-pc-mobility (wifi)
     */
    Q_INVOKABLE QVariantList scanWifi(const QString &iface);
    Q_INVOKABLE QVariantList getWifiInterfaces();
    Q_INVOKABLE bool connectWifi(const QString &iface, const QString &ssid, const QString &password);
    /*
     *
     *  lib-vpt-hyper (LEGACY)
     *
     */
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
    /*
     *
     *  deprecated
     *
     */
    Q_INVOKABLE void resetSetup() {
        QFile file("/vpt/flags.atp_setup_done");
        if (file.exists()) {
            file.remove(); // Borramos el archivo testigo de Debian
            emit isFirstRunChanged(); // Le avisamos a QML que isFirstRun cambió
        }
    }
    /*
     *
     *  lib-tj-hyper + lib-pc-mobility (files management)
     *
     */
    Q_INVOKABLE QString readFile(const QString& path);
    Q_INVOKABLE void writeFile(const QString& path, const QString& content);
    /*
     *
     *  lib-atp-pkitwcmd
     *
     */
    Q_INVOKABLE void runCommandWithSudo(const QString &command, const QString &password, QJSValue callback = QJSValue());
    Q_INVOKABLE void runCommand(const QString &cmd) {
        // Ejecuta el comando en un hilo separado de forma asíncrona
        // para que la interfaz QML no se congele mientras cambia la resolución
        QProcess::startDetached("/bin/sh", QStringList() << "-c" << cmd);
    }
    Q_INVOKABLE void runPkexec(const QString &command);
    /*
     *
     *  lib-vptatp
     *
     */
    Q_INVOKABLE void checkForUpdates(); // combina apt update + análisis
    /*
     *
     *  lib-tj-hyper + lib-pc-mobility (sound + display management) (added on unstable-v1.62)
     *  (procmanagment in dev)
     *
     */
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
    Q_INVOKABLE QStringList getAvailableRefreshRates(const QString &outputName);
    Q_INVOKABLE QString getCurrentRefreshRate(const QString &outputName);
    Q_INVOKABLE QStringList getAvailableResolutions(const QString &outputName);
    Q_INVOKABLE QString getCurrentResolution(const QString &outputName);
    Q_INVOKABLE void terminateCurrentApp();
    /*
     * lib-tj-hyper (speed test)
     */
    Q_INVOKABLE void startSpeedTest();

signals:
    /*
     *
     *  lib-tj-hyper + lib-pc-mobility (signals)
     *
     */
    void appClosed();
    void commandOutput(const QString &text);
    void aptProgress(int percent, const QString &lastLine);
    void aptFinished(bool success);
    void logUpdated(QString message);
    void isFirstRunChanged();
    void updatesAvailable(int count, const QString &packages);
    void speedTestFinished(double downloadMbps, double uploadMbps, double pingMs);
    void speedTestError(const QString &message);

private:
    QProcess *m_currentProcess;
    /*
     *
     *  lib-tj-hyper + lib-pc-mobility (audio legacy)
     *  deprecated......... well, soon removing
     *
     */
    void initAudio();
    void cleanupAudio();

    snd_pcm_t *m_alsaHandle;
    QMutex m_alsaMutex;
    bool m_audioInitialized;
};


#endif // BACKEND_H