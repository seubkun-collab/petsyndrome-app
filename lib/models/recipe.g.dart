// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

class RecipeItemAdapter extends TypeAdapter<RecipeItem> {
  @override
  final int typeId = 3;

  @override
  RecipeItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeItem(
      ingredientId: fields[0] as String,
      ingredientName: fields[1] as String,
      ratio: fields[2] as double,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.ingredientId)
      ..writeByte(1)
      ..write(obj.ingredientName)
      ..writeByte(2)
      ..write(obj.ratio);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 4;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      id: fields[0] as String,
      name: fields[1] as String,
      items: (fields[2] as List).cast<RecipeItem>(),
      packagingId: fields[3] as String,
      packagingWeight: fields[4] as double,
      packagingType: fields[5] as String,
      calculatedPrice: fields[6] as double,
      customerNote: fields[7] as String? ?? '',
      createdAt: fields[8] as DateTime,
      workerName: fields[9] as String? ?? '',
      weightCategory: fields[10] as String? ?? 'under100',
      bulkMoqKg: fields[11] as double? ?? 10.0,
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.packagingId)
      ..writeByte(4)
      ..write(obj.packagingWeight)
      ..writeByte(5)
      ..write(obj.packagingType)
      ..writeByte(6)
      ..write(obj.calculatedPrice)
      ..writeByte(7)
      ..write(obj.customerNote)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.workerName)
      ..writeByte(10)
      ..write(obj.weightCategory)
      ..writeByte(11)
      ..write(obj.bulkMoqKg);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
