import 'package:hive/hive.dart';

part 'ingredient.g.dart';

// 변동 이력 항목
@HiveType(typeId: 5)
class IngredientHistory extends HiveObject {
  @HiveField(0)
  DateTime changedAt;

  @HiveField(1)
  double unitPrice;

  @HiveField(2)
  double moisture;

  @HiveField(3)
  String note; // 변경 메모

  IngredientHistory({
    required this.changedAt,
    required this.unitPrice,
    required this.moisture,
    this.note = '',
  });
}

@HiveType(typeId: 0)
class Ingredient extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String type; // 'raw' = 원재료, 'sub' = 부재료

  @HiveField(3)
  double unitPrice; // 단가 (원/kg)

  @HiveField(4)
  double moisture; // 수분율 (0~1)

  @HiveField(5)
  double? crudeProtein;

  @HiveField(6)
  double? crudeFat;

  @HiveField(7)
  double? crudeAsh;

  @HiveField(8)
  double? crudeFiber;

  @HiveField(9)
  double? phosphorus;

  @HiveField(10)
  double? calcium;

  @HiveField(11)
  bool isActive;

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
  DateTime updatedAt;

  @HiveField(14)
  double bulkWeightKg; // 벌크 포장 중량 (kg), 기본 10kg

  @HiveField(15)
  List<IngredientHistory> history; // 단가/수분율 변동 이력

  @HiveField(16)
  double ref300ccWeightG; // 300cc 기준 담기는 중량 (g), 기본 0 (미설정)

  Ingredient({
    required this.id,
    required this.name,
    required this.type,
    required this.unitPrice,
    required this.moisture,
    this.crudeProtein,
    this.crudeFat,
    this.crudeAsh,
    this.crudeFiber,
    this.phosphorus,
    this.calcium,
    this.isActive = true,
    this.bulkWeightKg = 10.0,
    this.ref300ccWeightG = 0.0,
    List<IngredientHistory>? history,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        history = history ?? [];

  String get typeName => type == 'raw' ? '원재료' : '부재료';
}
