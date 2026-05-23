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
    // Inicializamos el puntero en nullptr
    explicit Backend(QObject *parent = nullptr) : QObject(parent), m_currentProcess(nullptr) {}

    // Destructor: Si el launcher se cierra de emergencia, cerramos la app que esté abierta
    ~Backend() {
        if (m_currentProcess && m_currentProcess->state() != QProcess::NotRunning) {
            m_currentProcess->terminate();
            m_currentProcess->waitForFinished(1000);
        }
    }

    // Tu código de escaneo de apps (intacto)
    Q_INVOKABLE QVariantList loadDesktopApps() {
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

                            // LIMPIEZA EXTRA: Quita cualquier texto descriptivo entre paréntesis
                            // Ej: "ImageMagick (color depth=q16)" -> "ImageMagick"
                            name.replace(QRegularExpression("\\s*\\([^)]*\\)"), "");
                            name = name.trimmed();
                        }
                        else if (line.startsWith("Icon=")) icon = line.mid(5);
                        else if (line.startsWith("Categories=")) category = line.mid(11);
                        else if (line.startsWith("NoDisplay=true")) noDisplay = true;
                        else if (line.startsWith("Terminal=true")) isTerminal = true;
                        else if (line.startsWith("Exec=")) {
                            exec = line.mid(5);
                            exec.replace(QRegularExpression("%[uUfF]"), "");
                            exec = exec.trimmed();
                        }
                    }

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

    // NUEVA FUNCIÓN: Lanzamiento de apps monitorizado
    Q_INVOKABLE void openApp(const QString &execCommand) {
        // 1. Evitar lanzar múltiples apps si ya hay una corriendo
        if (m_currentProcess && m_currentProcess->state() != QProcess::NotRunning) {
            qWarning() << "[C++] Ya hay una app corriendo. Esperando a que el usuario la cierre.";
            return;
        }

        // Limpiar un proceso anterior que ya haya terminado pero siga en memoria
        if (m_currentProcess) {
            m_currentProcess->deleteLater();
            m_currentProcess = nullptr;
        }

        // 2. Crear el nuevo proceso
        m_currentProcess = new QProcess(this);

        // 3. Parsear el comando correctamente ("kitty -e htop" -> "kitty", ["-e", "htop"])
        QStringList arguments = QProcess::splitCommand(execCommand);
        if (arguments.isEmpty()) {
            emit appClosed(); // Descongela la UI si el comando era inválido
            return;
        }

        QString program = arguments.takeFirst();

        // 4. Conectar la señal de ÉXITO (La app se cerró normalmente)
        connect(m_currentProcess, &QProcess::finished, this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
            qDebug() << "[C++] App cerrada de forma natural. Código:" << exitCode;
            emit appClosed();

            m_currentProcess->deleteLater();
            m_currentProcess = nullptr;
        });

        // 5. Conectar la señal de ERROR (La app no existe, crasheó al abrir, etc.)
        connect(m_currentProcess, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
            qWarning() << "[C++] Error grave al ejecutar la app:" << error;
            emit appClosed(); // Descongela la UI para no dejar la pantalla de carga para siempre

            m_currentProcess->deleteLater();
            m_currentProcess = nullptr;
        });

        // 6. ¡Lanzar!
        qDebug() << "[C++] Ejecutando proceso maestro:" << program << arguments;
        m_currentProcess->start(program, arguments);
    }

signals:
    // Esta señal viaja hasta QML
    void appClosed();

private:
    QProcess *m_currentProcess;
};

#endif // BACKEND_H