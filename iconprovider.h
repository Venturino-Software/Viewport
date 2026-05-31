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

// IconProvider.h
#ifndef ICONPROVIDER_H
#define ICONPROVIDER_H

#include <QQuickImageProvider>
#include <QIcon>

class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override {
        QIcon icon = QIcon::fromTheme(id);
        QSize targetSize = requestedSize.isValid() ? requestedSize : QSize(64, 64);
        QPixmap pixmap = icon.pixmap(targetSize);
        if (size) *size = pixmap.size();
        return pixmap;
    }
};

#endif // ICONPROVIDER_H