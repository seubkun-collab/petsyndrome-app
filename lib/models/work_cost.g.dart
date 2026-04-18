// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_cost.dart';

class WorkCostHistoryAdapter extends TypeAdapter<WorkCostHistory> {
  @override
  final int typeId = 6;

  @override
  WorkCostHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkCostHistory(
      changedAt: fields[0] as DateTime,
      dryingCost: fields[1] as double,
      mixingCost: fields[2] as double,
      cuttingCost: fields[3] as double,
      cuttingLossRate: fields[4] as double,
      marginRate: fields[5] as double,
      note: fields[6] as String? ?? '',
      changedBy: fields[7] as String? ?? '관리자',
    );
  }

  @override
  void write(BinaryWriter writer, WorkCostHistory obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.changedAt)
      ..writeByte(1)
      ..write(obj.dryingCost)
      ..writeByte(2)
      ..write(obj.mixingCost)
      ..writeByte(3)
      ..write(obj.cuttingCost)
      ..writeByte(4)
      ..write(obj.cuttingLossRate)
      ..writeByte(5)
      ..write(obj.marginRate)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.changedBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkCostHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkCostAdapter extends TypeAdapter<WorkCost> {
  @override
  final int typeId = 1;

  @override
  WorkCost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkCost(
      id: fields[0] as String,
      dryingCost: fields[1] as double,
      mixingCost: fields[2] as double,
      cuttingCost: fields[3] as double,
      cuttingLossRate: fields[4] as double,
      marginRate: fields[5] as double,
      updatedAt: fields[6] as DateTime?,
      history: (fields[7] as List?)?.cast<WorkCostHistory>() ?? [],
      changedBy: fields[8] as String? ?? '관리자',
    );
  }

  @override
  void write(BinaryWriter writer, WorkCost obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dryingCost)
      ..writeByte(2)
      ..write(obj.mixingCost)
      ..writeByte(3)
      ..write(obj.cuttingCost)
      ..writeByte(4)
      ..write(obj.cuttingLossRate)
      ..writeByte(5)
      ..write(obj.marginRate)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.history)
      ..writeByte(8)
      ..write(obj.changedBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkCostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
