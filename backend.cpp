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

#include "backend.h"
#include <qjsvalue.h>

Backend::Backend(QObject *parent) : QObject(parent), m_currentProcess(nullptr) {}

Backend::~Backend() {
    if (m_currentProcess && m_currentProcess->state() != QProcess::NotRunning) {
        m_currentProcess->terminate();
        m_currentProcess->waitForFinished(1000);
    }
}

/*
 *  lib-tj-hyper + lib-pc-mobility (display)
 */
QStringList Backend::getAvailableRefreshRates(const QString &outputName) {
    QStringList rates;
    if (outputName.isEmpty()) return rates;

    QProcess proc;
    proc.start("wlr-randr");
    if (!proc.waitForFinished()) return rates;

    QString output = QString::fromLocal8Bit(proc.readAllStandardOutput());
    QStringList lines = output.split("\n");

    bool targetOutputFound = false;
    // Expresión regular para capturar los Hz (acepta decimales enteros)
    QRegularExpression hzRegex("(\\d+(?:\\.\\d+)?)\\s+Hz");

    for (const QString &line : lines) {
        // Detectamos si empieza la sección de la pantalla que nos interesa
        if (line.startsWith(outputName)) {
            targetOutputFound = true;
            continue;
        }
        // Si empieza otra sección de pantalla, dejamos de leer
        if (targetOutputFound && !line.startsWith(" ") && !line.isEmpty()) {
            break;
        }

        if (targetOutputFound) {
            QRegularExpressionMatch match = hzRegex.match(line);
            if (match.hasMatch()) {
                float hzFloat = match.captured(1).toFloat();
                // Redondeamos para quitar los molestos .001000 de Wayland
                QString hzStr = QString::number(qRound(hzFloat));
                if (!rates.contains(hzStr)) {
                    rates.append(hzStr);
                }
            }
        }
    }
    return rates;
}
QStringList Backend::getAvailableResolutions(const QString &outputName) {
    QStringList resList;
    if (outputName.isEmpty()) return resList;

    QProcess proc;
    proc.start("wlr-randr");
    if (!proc.waitForFinished()) return resList;

    QString output = QString::fromLocal8Bit(proc.readAllStandardOutput());
    QStringList lines = output.split("\n");

    bool targetOutputFound = false;
    // Captura formatos tipo "1920x1080"
    QRegularExpression resRegex("(\\d+x\\d+)\\s+px");

    for (const QString &line : lines) {
        if (line.startsWith(outputName)) {
            targetOutputFound = true;
            continue;
        }
        if (targetOutputFound && !line.startsWith(" ") && !line.isEmpty()) break;

        if (targetOutputFound) {
            QRegularExpressionMatch match = resRegex.match(line);
            if (match.hasMatch()) {
                QString resStr = match.captured(1);
                if (!resList.contains(resStr)) resList.append(resStr);
            }
        }
    }
    return resList;
}

QString Backend::getCurrentResolution(const QString &outputName) {
    if (outputName.isEmpty()) return "1920x1080"; // Fallback seguro

    QProcess proc;
    proc.start("wlr-randr");
    if (!proc.waitForFinished()) return "1920x1080";

    QString output = QString::fromLocal8Bit(proc.readAllStandardOutput());
    QStringList lines = output.split("\n");

    bool targetOutputFound = false;
    QRegularExpression resRegex("(\\d+x\\d+)\\s+px");

    for (const QString &line : lines) {
        if (line.startsWith(outputName)) {
            targetOutputFound = true;
            continue;
        }
        if (targetOutputFound && !line.startsWith(" ") && !line.isEmpty()) {
            break; // Pasamos a otra pantalla, salimos
        }

        // Si es nuestra pantalla y es la resolución activa actual
        if (targetOutputFound && line.contains("current")) {
            QRegularExpressionMatch match = resRegex.match(line);
            if (match.hasMatch()) {
                return match.captured(1); // Devuelve "1920x1080"
            }
        }
    }
    return "1920x1080";
}
QString Backend::getCurrentRefreshRate(const QString &outputName) {
    if (outputName.isEmpty()) return "60"; // Valor seguro por defecto

    QProcess proc;
    proc.start("wlr-randr");
    if (!proc.waitForFinished()) return "60";

    QString output = QString::fromLocal8Bit(proc.readAllStandardOutput());
    QStringList lines = output.split("\n");

    bool targetOutputFound = false;
    QRegularExpression hzRegex("(\\d+(?:\\.\\d+)?)\\s+Hz.*current");

    for (const QString &line : lines) {
        if (line.startsWith(outputName)) {
            targetOutputFound = true;
            continue;
        }
        if (targetOutputFound && !line.startsWith(" ") && !line.isEmpty()) {
            break;
        }

        if (targetOutputFound && line.contains("current")) {
            QRegularExpressionMatch match = hzRegex.match(line);
            if (match.hasMatch()) {
                float hzFloat = match.captured(1).toFloat();
                return QString::number(qRound(hzFloat));
            }
        }
    }
    return "60";
}

/*
 *  lib-tj-hyper + lib-pc-mobility (wifi)
 */
QVariantList Backend::getWifiInterfaces() {
    QVariantList interfaces;
    QProcess p;
    // Pedimos a nmcli que liste los dispositivos y su tipo
    p.start("nmcli", {"-t", "-f", "DEVICE,TYPE", "device"});
    p.waitForFinished(2000);

    QString out = p.readAllStandardOutput();
    QStringList lines = out.split('\n', Qt::SkipEmptyParts);

    for (const QString &line : lines) {
        QStringList parts = line.split(':');
        // Si el dispositivo es de tipo "wifi", lo agregamos
        if (parts.size() >= 2 && parts[1] == "wifi") {
            interfaces.append(parts[0]);
        }
    }
    return interfaces;
}

QVariantList Backend::scanWifi(const QString &iface) {
    QVariantList list;
    if (iface.isEmpty()) return list;

    QProcess p;
    // 1. Forzamos un escaneo fresco en la antena seleccionada
    p.start("nmcli", {"device", "wifi", "rescan", "ifname", iface});
    p.waitForFinished(3000);

    // 2. Listamos los resultados
    p.start("nmcli", {"-t", "-f", "SSID,SECURITY", "device", "wifi", "list", "ifname", iface});
    p.waitForFinished(5000);

    if (p.exitCode() != 0) {
        qWarning() << "[Wi-Fi] nmcli error:" << p.readAllStandardError();
        return list;
    }

    QString out = p.readAllStandardOutput();
    QStringList lines = out.split('\n', Qt::SkipEmptyParts);
    QSet<QString> seenSSIDs; // Para no mostrar duplicados

    for (const QString &line : lines) {
        int firstColon = line.indexOf(':');
        if (firstColon != -1) {
            // Reemplazamos los ":" escapados en caso de que el SSID los contenga
            QString ssid = line.left(firstColon).replace("\\:", ":");
            QString security = line.mid(firstColon + 1);

            // Ignoramos redes vacías (ocultas) o ya procesadas
            if (ssid.isEmpty() || ssid == "--" || seenSSIDs.contains(ssid)) continue;

            QVariantMap net;
            net["ssid"] = ssid;
            net["encrypted"] = (security != "" && security != "--");
            net["security_type"] = security;
            list.append(net);
            seenSSIDs.insert(ssid);
        }
    }
    return list;
}
bool Backend::connectWifi(const QString &iface, const QString &ssid, const QString &password)
{
    // 1. Borramos cualquier perfil previo con ese SSID (sin esperar resultado)
    QProcess::execute("/usr/bin/pkexec",
                      QStringList() << "/usr/bin/nmcli" << "connection" << "delete" << ssid);

    // 2. Construir los argumentos de conexión
    QStringList args;
    args << "device" << "wifi" << "connect" << ssid
         << "ifname" << iface;
    if (!password.isEmpty()) {
        args << "password" << password;
    }

    // 3. Ejecutar de forma síncrona (bloquea el hilo principal unos segundos)
    QProcess p;
    p.start("/usr/bin/pkexec", QStringList() << "/usr/bin/nmcli" << args);
    p.waitForFinished(10000);  // 10 segundos máximo

    QString output = p.readAllStandardOutput();
    QString errOutput = p.readAllStandardError();
    int exitCode = p.exitCode();

    // 4. Determinar éxito
    //    nmcli exitoso devuelve 0 e imprime "successfully activated"
    // 4. Determinar éxito
    //    nmcli devuelve 0 si se conectó correctamente.
    //    Podemos ignorar la salida textual y confiar en el exit code.
    bool success = (exitCode == 0);

    // Opcional: puedes verificar que no haya mensajes de error en stderr
    if (success && !errOutput.isEmpty()) {
        // Si hay algo en stderr, quizá no sea éxito real (poco probable si exitCode=0)
        if (errOutput.contains("Error", Qt::CaseInsensitive) ||
            errOutput.contains("failure", Qt::CaseInsensitive)) {
            success = false;
        }
    }

    // Línea de depuración (bórrala cuando todo funcione)
    qDebug() << "[WiFi] connect exitCode:" << exitCode
             << "success:" << success
             << "\nstdout:" << output
             << "\nstderr:" << errOutput;

    return success;
}
/*
 *  lib-tj-hyper + lib-pc-mobility (file managment)
 */
QString Backend::readFile(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "[Backend] No se pudo abrir el archivo:" << path;
        return QString();
    }
    QTextStream stream(&file);
    return stream.readAll();
}

void Backend::writeFile(const QString& path, const QString& content) {
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "[Backend] No se pudo escribir el archivo:" << path;
        return;
    }
    QTextStream stream(&file);
    stream << content;
    file.close();
}

/*
 *
 *  lib-vpt
 *
 */
QVariantList Backend::loadDesktopApps() {
    QVariantList apps;
    QStringList paths = {
        "/usr/share/applications",
        QDir::homePath() + "/.local/share/applications"
    };

    // Obtener el idioma del sistema para la localización de los nombres
    const QString systemLocale = QLocale::system().name();      // ej. "es_MX"
    const QString shortLocale = systemLocale.split('_').first(); // ej. "es"

    for (const QString &dirPath : paths) {
        QDir dir(dirPath);
        if (!dir.exists()) continue;

        const QStringList files = dir.entryList(QStringList() << "*.desktop", QDir::Files);
        for (const QString &fileName : files) {
            const QString filePath = dir.absoluteFilePath(fileName);
            QSettings desktop(filePath, QSettings::IniFormat);
            desktop.beginGroup("Desktop Entry");

            // Verificar si la entrada está oculta
            if (desktop.value("NoDisplay", false).toBool() ||
                desktop.value("Hidden", false).toBool()) {
                desktop.endGroup();
                continue;
            }

            // Obtener nombre localizado: prioridad exacta, luego corta, luego genérico
            QString name;
            if (desktop.contains("Name[" + systemLocale + "]")) {
                name = desktop.value("Name[" + systemLocale + "]").toString();
            } else if (desktop.contains("Name[" + shortLocale + "]")) {
                name = desktop.value("Name[" + shortLocale + "]").toString();
            } else {
                name = desktop.value("Name").toString();
            }
            // Limpiar sufijos entre paréntesis (ej. "Firefox (Navegador)" -> "Firefox")
            name.replace(QRegularExpression("\\s*\\([^)]*\\)"), "");
            name = name.trimmed();
            if (name.isEmpty()) {
                desktop.endGroup();
                continue;
            }

            // Obtener y normalizar el icono
            QString icon = desktop.value("Icon").toString();
            if (!icon.isEmpty() && icon.startsWith('/')) {
                // Es una ruta absoluta; si no existe, usar solo el nombre base
                if (!QFile::exists(icon)) {
                    QFileInfo fi(icon);
                    icon = fi.completeBaseName();  // p.ej. "libreoffice-draw"
                    qDebug() << "[C++] Icono como ruta no encontrado, usando nombre de tema:" << icon;
                }
            }

            // Obtener ejecutable y limpiar marcadores de campo
            QString exec = desktop.value("Exec").toString();
            if (exec.isEmpty()) {
                desktop.endGroup();
                continue;
            }
            exec.replace(QRegularExpression("%[uUfFdDnNikcvm]"), "");
            exec = exec.trimmed();

            // Si es terminal, envolvemos con kitty
            if (desktop.value("Terminal", false).toBool()) {
                exec = "kitty -e " + exec;
            }

            // Categoría (solo la primera)
            QString category = desktop.value("Categories").toString();
            category = category.split(';').first();

            QVariantMap appMap;
            appMap["name"] = name;
            appMap["icon"] = icon;
            appMap["exec"] = exec;
            appMap["category"] = category;
            apps.append(appMap);

            desktop.endGroup();
        }
    }

    // Si no se encontró ninguna aplicación, cargar unas por defecto
    if (apps.isEmpty()) {
        qDebug() << "[C++] No se encontraron .desktops. Cargando apps por defecto.";
        QVariantMap term;
        term["name"] = "Terminal";
        term["icon"] = "utilities-terminal";
        term["exec"] = "kitty";
        term["category"] = "System";
        apps.append(term);

        QVariantMap web;
        web["name"] = "Navegador";
        web["icon"] = "browser";
        web["exec"] = "firefox";
        web["category"] = "Network";
        apps.append(web);
    }

    return apps;
}
/*
 *
 *  lib-jt-eds (management of cage ""ENVIROVEMENT DESKTOP SERVER"")
 *
 */
void Backend::openApp(const QString &execCommand) {
    if (m_currentProcess && m_currentProcess->state() != QProcess::NotRunning) {
        qWarning() << "[C++] Ya hay una app corriendo.";
        return;
    }
    if (m_currentProcess) {
        m_currentProcess->deleteLater();
        m_currentProcess = nullptr;
    }

    m_currentProcess = new QProcess(this);
    QStringList args = QProcess::splitCommand(execCommand);
    if (args.isEmpty()) {
        emit appClosed();
        return;
    }
    QString program = args.takeFirst();

    connect(m_currentProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus) {
                qDebug() << "[C++] App cerrada con código:" << exitCode;
                emit appClosed();
                m_currentProcess->deleteLater();
                m_currentProcess = nullptr;
            });
    connect(m_currentProcess, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        qWarning() << "[C++] Error al ejecutar app:" << err;
        emit appClosed();
        m_currentProcess->deleteLater();
        m_currentProcess = nullptr;
    });

    qDebug() << "[C++] Ejecutando:" << program << args;
    m_currentProcess->start(program, args);
}
void Backend::terminateCurrentApp() {
    if (m_currentProcess && m_currentProcess->state() != QProcess::NotRunning) {
        qDebug() << "[C++] Enviando SIGTERM a la app activa...";
        m_currentProcess->terminate();
    } else {
        qWarning() << "[C++] Intento de cerrar app, pero no hay ninguna ejecución activa.";
    }
}
/*
 *
 *  lib-atp-cmdwrap
 *
 */
void Backend::runCommandWithOutput(const QString &command) {
    QProcess *proc = new QProcess(this);
    proc->setProcessChannelMode(QProcess::MergedChannels);

    connect(proc, &QProcess::readyRead, this, [proc, this]() {
        QString text = QString::fromUtf8(proc->readAll());
        if (!text.isEmpty()) emit commandOutput(text);
    });

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [proc, this](int exitCode) {
                if (exitCode != 0)
                    emit commandOutput(QString("\n[Proceso terminado con código %1]").arg(exitCode));
                proc->deleteLater();
            });

    connect(proc, &QProcess::errorOccurred, this, [proc, this](QProcess::ProcessError err) {
        QString msg = "[Error al ejecutar el comando: ";
        switch (err) {
        case QProcess::FailedToStart: msg += "No se pudo iniciar]"; break;
        case QProcess::Crashed: msg += "El proceso crasheó]"; break;
        default: msg += "Error desconocido]"; break;
        }
        emit commandOutput(msg + "\n");
        proc->deleteLater();
    });

    proc->start("/bin/bash", QStringList() << "-c" << command);
}
/*
     *  lib-tj-hyper + lib-pc-mobility (sound)
     */
int Backend::getVolume() {
    QProcess p;
    // "@DEFAULT_AUDIO_SINK@" apunta automáticamente a la salida activa (auriculares o parlantes)
    p.start("wpctl", {"get-volume", "@DEFAULT_AUDIO_SINK@"});
    p.waitForFinished(500);

    QString out = p.readAllStandardOutput().trimmed();
    // wpctl devuelve algo como: "Volume: 0.65" o "Volume: 0.65 [MUTED]"

    QRegularExpression re("Volume:\\s+([0-9.]+)");
    auto match = re.match(out);
    if (match.hasMatch()) {
        float volFloat = match.captured(1).toFloat();
        return static_cast<int>(volFloat * 100); // Lo pasamos a rango 0-100
    }

    qWarning() << "[Orbit] No se pudo obtener el volumen de PipeWire, usando fallback 50. Output:" << out;
    return 50;
}

void Backend::setVolume(int vol) {
    // wpctl escala de 0.0 a 1.0 (ejemplo: 65% es 0.65)
    float volFloat = vol / 100.0f;

    // Forzamos un límite para no reventar los parlantes (opcional)
    if (volFloat > 1.0f) volFloat = 1.0f;
    if (volFloat < 0.0f) volFloat = 0.0f;

    QProcess::startDetached("wpctl", {"set-volume", "@DEFAULT_AUDIO_SINK@", QString::number(volFloat, 'f', 2)});
}

void Backend::playTestSound() {
    QProcess::startDetached("aplay", {"/src/test.wav"});
}

/*
     *  lib-tj-hyper + lib-pc-mobility (brigthness)
     */
int Backend::getBrightness() {
    QProcess p;
    p.start("brightnessctl", {"-m", "g"});
    p.waitForFinished(1000);
    QString out = p.readAllStandardOutput().trimmed();
    QRegularExpression re("(\\d+)\\.?\\d*%");
    auto match = re.match(out);
    if (match.hasMatch()) {
        return match.captured(1).toInt();
    }
    qWarning("No se pudo obtener el brillo");
    return 50;
}

void Backend::setBrightness(int val) {
    QProcess::startDetached("/usr/bin/pkexec", QStringList() << "brightnessctl" << "s" << QString::number(val) + "%");
}
/*
     *
     *  lib-atp-pkitwcmd
     *
     */
void Backend::runCommandWithSudo(const QString &command, const QString &password, QJSValue callback) {
    QProcess *proc = new QProcess(this);
    proc->start("/usr/bin/pkexec", QStringList() << "-S" << "-p" << "" << "sh" << "-c" << command);
    proc->write(password.toUtf8() + "\n");
    proc->closeWriteChannel();

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [proc, callback, this](int exitCode) {
                bool success = (exitCode == 0);
                if (callback.isCallable()) {
                    callback.call(QJSValueList{success});
                }
                proc->deleteLater();
            });

    connect(proc, &QProcess::errorOccurred, this, [proc, callback](QProcess::ProcessError) {
        if (callback.isCallable()) {
            callback.call(QJSValueList{false});
        }
        proc->deleteLater();
    });
}
void Backend::runPkexec(const QString &command) {
    QProcess *proc = new QProcess(this);
    proc->start("/usr/bin/pkexec", QStringList() << "sh" << "-c" << command);
    connect(proc, &QProcess::readyReadStandardOutput, this, [proc, this]() {
        QString out = QString::fromUtf8(proc->readAllStandardOutput());
        if (!out.isEmpty()) emit commandOutput(out);
    });
    connect(proc, &QProcess::readyReadStandardError, this, [proc, this]() {
        QString err = QString::fromUtf8(proc->readAllStandardError());
        if (!err.isEmpty()) emit commandOutput("[ERROR] " + err);
    });
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [proc, this](int exitCode) {
                if (exitCode != 0) emit commandOutput(QString("\nComando terminado con código %1").arg(exitCode));
                proc->deleteLater();
            });
    connect(proc, &QProcess::errorOccurred, this, [proc, this](QProcess::ProcessError err) {
        emit commandOutput(QString("[pkexec error] %1").arg(err));
        proc->deleteLater();
    });
}
/*
     *
     *  lib-vptatp
     *
     */
void Backend::checkForUpdates() {
    // 1. Ejecutar apt update con permisos (pedirá autenticación gráfica)
    QProcess *updateProc = new QProcess(this);
    updateProc->start("/usr/bin/pkexec", QStringList() << "apt" << "update");

    // Cuando termine apt update (bien o mal), procedemos al listado
    connect(updateProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, updateProc](int exitCode) {
                if (exitCode != 0) {
                    // Si falla el update, emitimos 0 actualizaciones y un mensaje de error
                    emit updatesAvailable(0, "Error al actualizar la lista de paquetes");
                    updateProc->deleteLater();
                    return;
                }

                // 2. Ahora obtener la lista de paquetes actualizables (sin pkexec)
                QProcess *listProc = new QProcess(this);
                QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
                env.insert("LC_ALL", "C");   // forzar inglés para "upgradable from"
                listProc->setProcessEnvironment(env);
                listProc->start("apt", QStringList() << "list" << "--upgradable");

                connect(listProc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                        this, [this, listProc](int) {
                            QString data = QString::fromUtf8(listProc->readAllStandardOutput());
                            int count = 0;
                            QStringList packages;
                            QStringList lines = data.split('\n');
                            for (const QString &line : lines) {
                                if (line.contains("upgradable from")) {
                                    count++;
                                    QString pkg = line.split('/').first().trimmed();
                                    packages << pkg;
                                }
                            }
                            // Siempre emitimos la señal, incluso si count es 0
                            emit updatesAvailable(count, packages.join(", "));
                            listProc->deleteLater();
                        });
                // Manejar error del listado
                connect(listProc, &QProcess::errorOccurred, this, [this, listProc]() {
                    emit updatesAvailable(0, "Error al listar paquetes");
                    listProc->deleteLater();
                });

                updateProc->deleteLater();
            });

    // Si apt update no puede iniciar, emitimos error
    connect(updateProc, &QProcess::errorOccurred, this, [this, updateProc]() {
        emit updatesAvailable(0, "Error al ejecutar apt update");
        updateProc->deleteLater();
    });
}
/*
     *
     *  lib-vpt-hyper (LEGACY)
     *
     */
void Backend::aptInstall(const QString &package, const QString &sudoPassword) {
    QProcess *proc = new QProcess(this);
    QString cmd = QString("apt install -y %1").arg(package);
    proc->start("sudo", {"-S", "bash", "-c", cmd});
    proc->write(sudoPassword.toUtf8() + '\n');
    proc->closeWriteChannel();

    connect(proc, &QProcess::readyReadStandardOutput, this, [proc, this]() {
        QString data = proc->readAllStandardOutput();
        if (data.isEmpty()) return;
        static QRegularExpression re("(\\d+)%");
        auto match = re.match(data);
        if (match.hasMatch()) {
            emit aptProgress(match.captured(1).toInt(), data.trimmed());
        } else {
            emit aptProgress(-1, data.trimmed());
        }
    });
    connect(proc, &QProcess::readyReadStandardError, this, [proc, this]() {
        QString data = proc->readAllStandardError();
        if (!data.isEmpty()) emit aptProgress(-1, data.trimmed());
    });
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode) {
                emit aptFinished(exitCode == 0);
            });
    connect(proc, &QProcess::errorOccurred, this, [this]() {
        emit aptFinished(false);
    });
    connect(proc, &QProcess::finished, proc, &QProcess::deleteLater);

    // Ejemplo conceptual en tu C++

}


void Backend::startSpeedTest()
{
    // Verificar si speedtest-cli está instalado
    QProcess check;
    check.start("which", {"speedtest-cli"});
    check.waitForFinished(2000);
    if (check.exitCode() != 0) {
        emit speedTestError("speedtest-cli no encontrado. Instálalo con:\n"
                            "sudo apt install speedtest-cli");
        return;
    }

    // Ejecutar speedtest-cli con salida JSON
    QProcess *proc = new QProcess(this);
    proc->start("speedtest-cli", {"--json"});

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc](int exitCode, QProcess::ExitStatus) {
                proc->deleteLater();

                if (exitCode != 0) {
                    QString err = proc->readAllStandardError();
                    emit speedTestError("Error al ejecutar speedtest-cli:\n" + err);
                    return;
                }

                QByteArray output = proc->readAllStandardOutput();
                QJsonParseError jsonError;
                QJsonDocument doc = QJsonDocument::fromJson(output, &jsonError);

                if (jsonError.error != QJsonParseError::NoError || !doc.isObject()) {
                    emit speedTestError("Error al leer el resultado JSON.");
                    return;
                }

                QJsonObject obj = doc.object();

                // Extraer datos (los nombres exactos dependen de la versión)
                // Para speedtest-cli oficial (Ookla) los campos son:
                double downloadBps = obj["download"].toDouble();   // en bits/s
                double uploadBps   = obj["upload"].toDouble();     // en bits/s
                double pingMs      = obj["ping"].toDouble();       // en ms

                // Convertir a Mbps (1 Mbps = 1,000,000 bps)
                double downloadMbps = downloadBps / 1e6;
                double uploadMbps   = uploadBps / 1e6;

                emit speedTestFinished(downloadMbps, uploadMbps, pingMs);
            });
}

