#pragma once
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QCryptographicHash>
namespace SessionProof {
inline QJsonObject read(const QString &path) {
 QFile f(path); if(!f.open(QIODevice::ReadOnly))return {};
 return QJsonDocument::fromJson(f.readAll()).object();
}
inline QString hash(const QString &path) {
 QFile f(path); if(!f.open(QIODevice::ReadOnly))return {};
 QCryptographicHash h(QCryptographicHash::Sha256);
 if(!h.addData(&f))return {};
 return QString::fromLatin1(h.result().toHex());
}
inline QString restored(const QString &folder) {
 const auto version=read(folder+"/session.json").value("version").toString();
 const auto prepared=hash(folder+"/prepared.json"), marker=hash(folder+"/write-started");
 if(version.isEmpty() || prepared.isEmpty() || marker.isEmpty())return "uncertain";
 const bool verified=QFile::exists(folder+"/verified.json");
 const auto proof=read(folder+(verified?"/verified.json":"/unchanged.json"));
 if(proof.value("version").toString()!=version || proof.value("prepared_sha256").toString()!=prepared || proof.value("marker_sha256").toString()!=marker)return "uncertain";
 return verified?"done":"not-applied";
}
}
