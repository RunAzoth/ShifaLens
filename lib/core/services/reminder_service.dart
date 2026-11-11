import '../models/models.dart';

abstract class ReminderService {
  Future<bool> requestPermissions();
  Future<void> scheduleForPlan(DailyPlan p, MealTimes t);
  Future<void> cancelAll();
  Future<String?> registerFcmToken();
}
