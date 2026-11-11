import '../models/models.dart';

abstract class PlanRepository {
  Future<void> savePlan(DailyPlan p);
  Future<DailyPlan?> loadLatest();
  Future<void> saveTick(TickEntry t);
  Stream<List<TickEntry>> tickLog({int lastDays = 7});
}
