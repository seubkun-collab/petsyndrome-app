// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'packaging.dart';

class PackagingHistoryAdapter extends TypeAdapter<PackagingHistory> {
  @override
  final int typeId = 5;

  @override
  PackagingHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PackagingHistory(
      changedAt: fields[0] as DateTime,
      containerPrice: fields[1] as double,
      packagingCost: fields[2] as double,
      note: fields[3] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, PackagingHistory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.changedAt)
      ..writeByte(1)
      ..write(obj.containerPrice)
      ..writeByte(2)
      ..write(obj.packagingCost)
      ..writeByte(3)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackagingHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PackagingAdapter extends TypeAdapter<Packaging> {
  @override
  final int typeId = 2;

  @override
  Packaging read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Packaging(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      containerPrice: fields[3] as double,
      packagingCost: fields[4] as double,
      volumeCC: fields[5] as int?,
      isActive: fields[6] as bool? ?? true,
      sortOrder: fields[7] as int? ?? 0,
      updatedAt: fields[8] as DateTime?,
      history: (fields[9] as List?)?.cast<PackagingHistory>() ?? [],
    );
  }

  @override
  void write(BinaryWriter writer, Packaging obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.containerPrice)
      ..writeByte(4)
      ..write(obj.packagingCost)
      ..writeByte(5)
      ..write(obj.volumeCC)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.sortOrder)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.history);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackagingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
