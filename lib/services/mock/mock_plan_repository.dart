import 'dart:async';

import '../../core/models/models.dart';
import '../../core/services/plan_repository.dart';

class MockPlanRepository implements PlanRepository {
  DailyPlan? _latest;
  final List<TickEntry> _ticks = [];
  final StreamController<List<TickEntry>> _tickController =
      StreamController<List<TickEntry>>.broadcast();

  @override
  Future<void> savePlan(DailyPlan p) async {
    _latest = p;
  }

  @override
  Future<DailyPlan?> loadLatest() async => _latest;

  @override
  Future<void> saveTick(TickEntry t) async {
    _ticks.removeWhere((e) => e.doseKey == t.doseKey && e.date == t.date);
    _ticks.add(t);
    _tickController.add(List.unmodifiable(_ticks));
  }

  @override
  Stream<List<TickEntry>> tickLog({int lastDays = 7}) async* {
    yield List.unmodifiable(_ticks);
    yield* _tickController.stream;
  }
}
