import '../../core/models/models.dart';
import '../../core/services/schedule_engine.dart';

class MockScheduleEngine implements ScheduleEngine {
  @override
  DailyPlan build(
    Prescription rx, {
    bool ramadan = false,
    bool ramadanApproved = false,
  }) {
    final scheduled = rx.lines
        .where((l) => l.confirmed && !l.needsPharmacist)
        .toList();
    final unscheduled = rx.lines
        .where((l) => !l.confirmed || l.needsPharmacist)
        .toList();
    return DailyPlan(
      id: 'plan_${rx.id}',
      prescriptionId: rx.id,
      scheduled: scheduled,
      unscheduled: unscheduled,
      doses: const [],
      duplicates: const [],
      foodCardsByMedicineId: const {},
      sideEffectsByMedicineId: const {},
      ramadan: ramadan,
      ramadanDoctorApproved: ramadanApproved,
    );
  }
}
