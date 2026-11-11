import '../../core/models/models.dart';
import '../../core/services/reminder_service.dart';

class MockReminderService implements ReminderService {
  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleForPlan(DailyPlan p, MealTimes t) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<String?> registerFcmToken() async => 'mock-fcm-token';
}
