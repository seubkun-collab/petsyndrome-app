import 'package:hive/hive.dart';

part 'recipe.g.dart';

@HiveType(typeId: 3)
class RecipeItem extends HiveObject {
  @HiveField(0)
  String ingredientId;

  @HiveField(1)
  String ingredientName;

  @HiveField(2)
  double ratio;

  RecipeItem({
    required this.ingredientId,
    required this.ingredientName,
    required this.ratio,
  });
}

@HiveType(typeId: 4)
class Recipe extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<RecipeItem> items;

  @HiveField(3)
  String packagingId;

  @HiveField(4)
  double packagingWeight; // g (벌크는 kg*1000)

  @HiveField(5)
  String packagingType; // 'vinyl', 'container', 'sample'

  @HiveField(6)
  double calculatedPrice;

  @HiveField(7)
  String customerNote;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  String workerName; // 작업자명

  @HiveField(10)
  String weightCategory; // 'under100', 'over100', 'bulk'

  @HiveField(11)
  double bulkMoqKg; // 벌크 MOQ (kg) - 기본 10kg

  Recipe({
    required this.id,
    required this.name,
    required this.items,
    required this.packagingId,
    required this.packagingWeight,
    required this.packagingType,
    required this.calculatedPrice,
    this.customerNote = '',
    this.workerName = '',
    this.weightCategory = 'under100',
    this.bulkMoqKg = 10.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isSingleIngredient => items.length == 1;
  double get totalRatio => items.fold(0, (sum, item) => sum + item.ratio);
}
