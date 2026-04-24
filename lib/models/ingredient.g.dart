// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient.dart';

class IngredientHistoryAdapter extends TypeAdapter<IngredientHistory> {
  @override
  final int typeId = 5;

  @override
  IngredientHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IngredientHistory(
      changedAt: fields[0] as DateTime,
      unitPrice: fields[1] as double,
      moisture: fields[2] as double,
      note: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, IngredientHistory obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.changedAt)
      ..writeByte(1)
      ..write(obj.unitPrice)
      ..writeByte(2)
      ..write(obj.moisture)
      ..writeByte(3)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class IngredientAdapter extends TypeAdapter<Ingredient> {
  @override
  final int typeId = 0;

  @override
  Ingredient read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ingredient(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      unitPrice: fields[3] as double,
      moisture: fields[4] as double,
      crudeProtein: fields[5] as double?,
      crudeFat: fields[6] as double?,
      crudeAsh: fields[7] as double?,
      crudeFiber: fields[8] as double?,
      phosphorus: fields[9] as double?,
      calcium: fields[10] as double?,
      isActive: fields[11] as bool,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime? ?? DateTime.now(),
      bulkWeightKg: fields[14] as double? ?? 10.0,
      history: (fields[15] as List?)?.cast<IngredientHistory>() ?? [],
      ref300ccWeightG: fields[16] as double? ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, Ingredient obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.unitPrice)
      ..writeByte(4)
      ..write(obj.moisture)
      ..writeByte(5)
      ..write(obj.crudeProtein)
      ..writeByte(6)
      ..write(obj.crudeFat)
      ..writeByte(7)
      ..write(obj.crudeAsh)
      ..writeByte(8)
      ..write(obj.crudeFiber)
      ..writeByte(9)
      ..write(obj.phosphorus)
      ..writeByte(10)
      ..write(obj.calcium)
      ..writeByte(11)
      ..write(obj.isActive)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.bulkWeightKg)
      ..writeByte(15)
      ..write(obj.history)
      ..writeByte(16)
      ..write(obj.ref300ccWeightG);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
