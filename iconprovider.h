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