/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VNT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
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
QVariantList Backend::loadDesktopApps() {
    QVariantList apps;
    QStringList paths = {
        "/usr/share/applications",
        QDir::homePath() + "/.local/share/applications"
    };

    for (const QString &path : paths) {
        QDir dir(path);
        if (!dir.exists()) continue;
        QStringList files = dir.entryList(QStringList() << "*.desktop", QDir::Files);
        for (const QString &file : files) {
            QFile f(dir.absoluteFilePath(file));
            if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream in(&f);
                QString name, icon, exec, category;
                bool noDisplay = false;
                bool isTerminal = false;
                bool inDesktopEntry = false;

                while (!in.atEnd()) {
                    QString line = in.readLine().trimmed();
                    if (line == "[Desktop Entry]") { inDesktopEntry = true; continue; }
                    if (line.startsWith("[")) { inDesktopEntry = false; continue; }
                    if (!inDesktopEntry) continue;

                    if (line.startsWith("Name=")) {
                        name = line.mid(5);
                        name.replace(QRegularExpression("\\s*\\([^)]*\\)"), "");
                        name = name.trimmed();
                    } else if (line.startsWith("Icon=")) icon = line.mid(5);
                    // Después de obtener 'icon'
                    else if (line.startsWith("Icon=")) {
                        icon = line.mid(5);
                        // Normalizar icono
                        if (icon.startsWith('/')) {
                            if (!QFile::exists(icon)) {
                                QFileInfo fi(icon);
                                icon = fi.completeBaseName();
                                qDebug() << "[C++] Icono como ruta no encontrado, usando nombre de tema:" << icon;
                            }
                        }
                    }
                    else if (line.startsWith("Categories=")) category = line.mid(11);
                    else if (line.startsWith("NoDisplay=true")) noDisplay = true;
                    else if (line.startsWith("Terminal=true")) isTerminal = true;
                    else if (line.startsWith("Exec=")) {
                        exec = line.mid(5);
                        exec.replace(QRegularExpression("%[uUfF]"), "");
                        exec = exec.trimmed();
                    }
                }
                f.close();

                if (!noDisplay && !name.isEmpty() && !exec.isEmpty()) {
                    if (isTerminal) {
                        exec = "kitty -e " + exec;
                    }
                    QVariantMap appMap;
                    appMap["name"] = name;
                    appMap["icon"] = icon;
                    appMap["exec"] = exec;
                    appMap["category"] = category.split(";").first();
                    apps.append(appMap);
                }
            }
        }
    }

    if (apps.isEmpty()) {
        qDebug() << "[C++] No se encontraron .desktops. Cargando apps por defecto.";
        QVariantMap term; term["name"] = "Terminal"; term["icon"] = "utilities-terminal"; term["exec"] = "kitty"; term["category"] = "System";
        QVariantMap web; web["name"] = "Navegador"; web["icon"] = "browser"; web["exec"] = "firefox"; web["category"] = "Network";
        apps.append(term);
        apps.append(web);
    }
    return apps;
}
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

int Backend::getVolume() {
    QStringList controls = {"Master", "PCM", "Headphone", "Speaker"};
    for (const QString &ctrl : controls) {
        QProcess p;
        p.start("amixer", {"sget", ctrl});
        p.waitForFinished(1000);
        QString out = p.readAllStandardOutput();
        QRegularExpression re("\\[(\\d+)%\\]");
        auto match = re.match(out);
        if (match.hasMatch()) {
            return match.captured(1).toInt();
        }
    }
    qWarning("No se pudo obtener el volumen");
    return 50;
}

void Backend::setVolume(int vol) {
    QProcess::startDetached("amixer", {"sset", "Master", QString::number(vol) + "%"});
}

void Backend::playTestSound() {
    QProcess::startDetached("aplay", {"/src/test.wav"});
}


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


QVariantList Backend::scanWifi() {
    QVariantList list;
    QProcess p;
    p.start("nmcli", {"device", "wifi", "rescan"});
    p.waitForFinished(2000);
    // luego el listado
    p.start("pkexec", {"/usr/bin/nmcli", "-t", "-f", "SSID,SECURITY", "device", "wifi", "list"});
    p.waitForFinished(5000);
    if (p.exitCode() != 0) {
        qWarning() << "nmcli error:" << p.readAllStandardError();
        return list;
    }
    QString out = p.readAllStandardOutput();
    QStringList lines = out.split('\n', Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        QStringList parts = line.split(':');
        if (parts.size() >= 2) {
            QVariantMap net;
            net["ssid"] = parts[0];
            net["encrypted"] = (parts[1] != "" && parts[1] != "--");
            list.append(net);
        }
    }
    return list;
}

void Backend::runNS(const QString &args) {
    QProcess *process = new QProcess();

    // Conectamos señales para ver qué pasa
    // viewport, conexion total
    connect(process, &QProcess::readyReadStandardOutput, [=]() {
        // Aquí podrías emitir una señal a QML para mostrar el log
        emit logUpdated(process->readAllStandardOutput());
    });

    // ¡Ojo aquí! Para el sudo, necesitas manejar la entrada de contraseña
    // o configurar un archivo sudoers para que este script no pida pass
    // Como entiende Soyzian esta funcion:
    // proceso: empezar: pica kulo exec, quality lista de strings, ruta de binario/configuracion de internet
    process->start("/usr/bin/pkexec", QStringList() << "/vpt/adm/bin/netconfig.sh" << args);
}

void Backend::connectWifi(const QString &ssid, const QString &password) {
    QStringList args;
    args << "device" << "wifi" << "connect" << ssid;
    if (!password.isEmpty()) args << "password" << password;
    QProcess::startDetached("/usr/bin/pkexec", QStringList() << "/usr/bin/nmcli" << args);
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

