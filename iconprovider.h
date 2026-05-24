/*
 * Viewport - Sistema de entorno gráfico minimalista
 * Copyright (C) 2026 VNT
 *
 * Este programa es software libre: puedes redistribuirlo y/o modificarlo
 * bajo los términos de la Licencia Pública General de GNU según es publicada
 * por la Free Software Foundation, ya sea la versión 3 de la Licencia,
 * o (a tu elección) cualquier versión posterior.
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