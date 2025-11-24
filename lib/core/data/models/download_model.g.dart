// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadModelAdapter extends TypeAdapter<DownloadModel> {
  @override
  final int typeId = 10;

  @override
  DownloadModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadModel(
      id: fields[0] as String,
      mediaId: fields[1] as String,
      mediaTitle: fields[2] as String,
      episodeId: fields[3] as String?,
      chapterId: fields[4] as String?,
      episodeNumber: fields[5] as int?,
      chapterNumber: fields[6] as double?,
      url: fields[7] as String,
      localPath: fields[8] as String,
      statusIndex: fields[9] as int,
      progress: fields[10] as double,
      totalBytes: fields[11] as int,
      downloadedBytes: fields[12] as int,
      createdAt: fields[13] as DateTime,
      completedAt: fields[14] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.mediaId)
      ..writeByte(2)
      ..write(obj.mediaTitle)
      ..writeByte(3)
      ..write(obj.episodeId)
      ..writeByte(4)
      ..write(obj.chapterId)
      ..writeByte(5)
      ..write(obj.episodeNumber)
      ..writeByte(6)
      ..write(obj.chapterNumber)
      ..writeByte(7)
      ..write(obj.url)
      ..writeByte(8)
      ..write(obj.localPath)
      ..writeByte(9)
      ..write(obj.statusIndex)
      ..writeByte(10)
      ..write(obj.progress)
      ..writeByte(11)
      ..write(obj.totalBytes)
      ..writeByte(12)
      ..write(obj.downloadedBytes)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.completedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
