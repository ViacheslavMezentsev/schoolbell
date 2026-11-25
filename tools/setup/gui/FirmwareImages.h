#pragma once
#include <QFile>
#include <QDir>
#include <QSaveFile>
#include <QCryptographicHash>
namespace FirmwareImages {
inline QByteArray read(const QString &profile) {
 const QByteArray expected=profile=="openwrt"?"e621da95d07d25102b1016a28400122f5c92bce9830d5cc061323e306b6204fa":profile=="factory"?"2b0d85b1c7f5e6c65930e117ada0afe60a29a35882ecac65610191876b6b0665":"";
 if(expected.isEmpty())return {};
 QFile f(":/firmware/"+profile+".bin");if(!f.open(QIODevice::ReadOnly))return {};
 auto b=f.readAll();if(b.size()!=0x7c0000 || QCryptographicHash::hash(b,QCryptographicHash::Sha256).toHex()!=expected)return {};
 return b;
}
inline bool available(){static const bool ok=!read("openwrt").isEmpty() && !read("factory").isEmpty();return ok;}
inline bool exportImage(const QString &profile,const QString &directory) {
 auto b=read(profile);if(b.isEmpty() || !QDir(directory).exists())return false;
 QSaveFile f(QDir(directory).filePath(profile+".bin"));
 return f.open(QIODevice::WriteOnly) && f.write(b)==b.size() && f.commit();
}
}
