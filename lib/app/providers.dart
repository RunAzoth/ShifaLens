import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/models.dart';
import '../core/services/services.dart';
import '../services/mock/mock_services.dart';
import '../services/real/real_services.dart';
import 'config.dart';

class AppConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() => const AppConfig();

  void setConfig(AppConfig config) {
    state = config;
  }

  void update(AppConfig Function(AppConfig current) updater) {
    state = updater(state);
  }
}

final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfig>(
  AppConfigNotifier.new,
);

class LangNotifier extends Notifier<Lang> {
  @override
  Lang build() => Lang.ur;

  void setLang(Lang lang) => state = lang;
  void toggle() => state = state == Lang.ur ? Lang.en : Lang.ur;
}

final langProvider = NotifierProvider<LangNotifier, Lang>(LangNotifier.new);

class DemoRxIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index.clamp(0, 2);
}

final activeDemoRxIndexProvider = NotifierProvider<DemoRxIndexNotifier, int>(
  DemoRxIndexNotifier.new,
);

class CurrentPrescriptionNotifier extends Notifier<Prescription?> {
  @override
  Prescription? build() => null;

  void setPrescription(Prescription? rx) => state = rx;
}

final currentPrescriptionProvider =
    NotifierProvider<CurrentPrescriptionNotifier, Prescription?>(
      CurrentPrescriptionNotifier.new,
    );

class CurrentPlanNotifier extends Notifier<DailyPlan?> {
  @override
  DailyPlan? build() => null;

  void setPlan(DailyPlan? plan) => state = plan;
}

final currentPlanProvider = NotifierProvider<CurrentPlanNotifier, DailyPlan?>(
  CurrentPlanNotifier.new,
);

class MealTimesNotifier extends Notifier<MealTimes> {
  @override
  MealTimes build() => MealTimes.defaults();

  void setMealTimes(MealTimes times) => state = times;
}

final mealTimesProvider = NotifierProvider<MealTimesNotifier, MealTimes>(
  MealTimesNotifier.new,
);

/// Service factory hooks so Real implementations can be customized or overridden cleanly.
typedef ServiceBuilder<T> = T Function(Ref ref);

ServiceBuilder<PrescriptionReader>? realPrescriptionReaderBuilder;
ServiceBuilder<StripMatcher>? realStripMatcherBuilder;
ServiceBuilder<KnowledgeService>? realKnowledgeServiceBuilder;
ServiceBuilder<ScheduleEngine>? realScheduleEngineBuilder;
ServiceBuilder<VoiceService>? realVoiceServiceBuilder;
ServiceBuilder<QAService>? realQAServiceBuilder;
ServiceBuilder<PlanRepository>? realPlanRepositoryBuilder;
ServiceBuilder<ReminderService>? realReminderServiceBuilder;
ServiceBuilder<ShareService>? realShareServiceBuilder;

final geminiClientProvider = Provider<GeminiClient>((ref) {
  return GeminiClient();
});

final knowledgeServiceProvider = Provider<KnowledgeService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.mockKnowledge) {
    if (realKnowledgeServiceBuilder != null) {
      return realKnowledgeServiceBuilder!(ref);
    }
    return RealKnowledgeService();
  }
  return MockKnowledgeService();
});

final prescriptionReaderProvider = Provider<PrescriptionReader>((ref) {
  final cfg = ref.watch(appConfigProvider);
  final demoIdx = ref.watch(activeDemoRxIndexProvider);
  if (!cfg.mockReader) {
    if (realPrescriptionReaderBuilder != null) {
      return realPrescriptionReaderBuilder!(ref);
    }
    return RealPrescriptionReader(
      client: ref.watch(geminiClientProvider),
      knowledge: ref.watch(knowledgeServiceProvider),
      fallbackDemoIndex: demoIdx,
    );
  }
  return MockPrescriptionReader(demoIndex: demoIdx);
});

final stripMatcherProvider = Provider<StripMatcher>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.mockStrips) {
    if (realStripMatcherBuilder != null) {
      return realStripMatcherBuilder!(ref);
    }
    return RealStripMatcher(
      client: ref.watch(geminiClientProvider),
      knowledge: ref.watch(knowledgeServiceProvider),
    );
  }
  return MockStripMatcher();
});

final scheduleEngineProvider = Provider<ScheduleEngine>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.mockKnowledge) {
    if (realScheduleEngineBuilder != null) {
      return realScheduleEngineBuilder!(ref);
    }
    return RealScheduleEngine(knowledge: ref.watch(knowledgeServiceProvider));
  }
  return MockScheduleEngine(knowledge: ref.watch(knowledgeServiceProvider));
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.mockVoice) {
    if (realVoiceServiceBuilder != null) {
      return realVoiceServiceBuilder!(ref);
    }
    return RealVoiceService();
  }
  return MockVoiceService();
});

final qaServiceProvider = Provider<QAService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.mockQA) {
    if (realQAServiceBuilder != null) {
      return realQAServiceBuilder!(ref);
    }
    return RealQAService(client: ref.watch(geminiClientProvider));
  }
  return MockQAService();
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.mockRepo) {
    if (realPlanRepositoryBuilder != null) {
      return realPlanRepositoryBuilder!(ref);
    }
    return RealPlanRepository();
  }
  return MockPlanRepository();
});

final reminderServiceProvider = Provider<ReminderService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.mockReminders) {
    if (realReminderServiceBuilder != null) {
      return realReminderServiceBuilder!(ref);
    }
    return RealReminderService();
  }
  return MockReminderService();
});

final shareServiceProvider = Provider<ShareService>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.mockShare) {
    if (realShareServiceBuilder != null) {
      return realShareServiceBuilder!(ref);
    }
    return RealShareService();
  }
  return MockShareService();
});
