import 'package:hive/hive.dart';

part 'packaging.g.dart';

@HiveType(typeId: 7)
class PackagingHistory extends HiveObject {
  @HiveField(0)
  DateTime changedAt;

  @HiveField(1)
  double containerPrice;

  @HiveField(2)
  double packagingCost;

  @HiveField(3)
  String note;

  PackagingHistory({
    required this.changedAt,
    required this.containerPrice,
    required this.packagingCost,
    required this.note,
  });
}

@HiveType(typeId: 2)
class Packaging extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String category; // 'container', 'vinyl', 'sample', 'manual'

  @HiveField(3)
  double containerPrice;

  @HiveField(4)
  double packagingCost;

  @HiveField(5)
  int? volumeCC;

  @HiveField(6)
  bool isActive;

  @HiveField(7)
  int sortOrder;

  @HiveField(8)
  DateTime updatedAt;

  @HiveField(9)
  List<PackagingHistory> history;

  Packaging({
    required this.id,
    required this.name,
    required this.category,
    required this.containerPrice,
    required this.packagingCost,
    this.volumeCC,
    this.isActive = true,
    this.sortOrder = 0,
    DateTime? updatedAt,
    List<PackagingHistory>? history,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        history = history ?? [];

  String get categoryName {
    switch (category) {
      case 'container': return '통포장';
      case 'vinyl': return '비닐포장';
      case 'sample': return '샘플포장';
      case 'manual': return '수작업';
      default: return category;
    }
  }
}
