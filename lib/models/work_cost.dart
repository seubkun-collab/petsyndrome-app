import 'package:hive/hive.dart';

part 'work_cost.g.dart';

@HiveType(typeId: 6)
class WorkCostHistory extends HiveObject {
  @HiveField(0)
  DateTime changedAt;

  @HiveField(1)
  double dryingCost;

  @HiveField(2)
  double mixingCost;

  @HiveField(3)
  double cuttingCost;

  @HiveField(4)
  double cuttingLossRate;

  @HiveField(5)
  double marginRate;

  @HiveField(6)
  String note;

  @HiveField(7)
  String changedBy; // 수정한 작업자 이름

  WorkCostHistory({
    required this.changedAt,
    required this.dryingCost,
    required this.mixingCost,
    required this.cuttingCost,
    required this.cuttingLossRate,
    required this.marginRate,
    this.note = '',
    this.changedBy = '관리자',
  });
}

@HiveType(typeId: 1)
class WorkCost extends HiveObject {
  @HiveField(0)
  String id;

  // 동결 작업비
  @HiveField(1)
  double dryingCost; // 건조비 (원/kg)

  @HiveField(2)
  double mixingCost; // 배합작업비 (원/kg)

  @HiveField(3)
  double cuttingCost; // 절단비 (원/kg)

  @HiveField(4)
  double cuttingLossRate; // 절단로스율 (0~1)

  @HiveField(5)
  double marginRate; // 마진율 (0~1)

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  List<WorkCostHistory> history;

  @HiveField(8)
  String changedBy; // 마지막 수정자

  WorkCost({
    required this.id,
    required this.dryingCost,
    required this.mixingCost,
    required this.cuttingCost,
    required this.cuttingLossRate,
    required this.marginRate,
    DateTime? updatedAt,
    List<WorkCostHistory>? history,
    this.changedBy = '관리자',
  })  : updatedAt = updatedAt ?? DateTime.now(),
        history = history ?? [];
}
