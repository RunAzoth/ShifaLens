import '../models/models.dart';

abstract class ScheduleEngine {
  DailyPlan build(
    Prescription rx, {
    bool ramadan = false,
    bool ramadanApproved = false,
  });
}
