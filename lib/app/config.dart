import 'package:flutter/foundation.dart';

const String kGeminiModel = String.fromEnvironment(
  'GEMINI_MODEL',
  defaultValue: 'gemini-2.5-flash',
);

const bool kDemoMode = bool.fromEnvironment(
  'DEMO_MODE',
  defaultValue: true,
);

@immutable
class AppConfig {
  final bool mockReader;
  final bool mockStrips;
  final bool mockQA;
  final bool mockVoice;
  final bool mockKnowledge;
  final bool mockRepo;
  final bool mockReminders;
  final bool mockShare;

  const AppConfig({
    this.mockReader = true,
    this.mockStrips = true,
    this.mockQA = true,
    this.mockVoice = true,
    this.mockKnowledge = true,
    this.mockRepo = true,
    this.mockReminders = true,
    this.mockShare = true,
  });

  const AppConfig.allMock()
      : mockReader = true,
        mockStrips = true,
        mockQA = true,
        mockVoice = true,
        mockKnowledge = true,
        mockRepo = true,
        mockReminders = true,
        mockShare = true;

  const AppConfig.allReal()
      : mockReader = false,
        mockStrips = false,
        mockQA = false,
        mockVoice = false,
        mockKnowledge = false,
        mockRepo = false,
        mockReminders = false,
        mockShare = false;

  AppConfig copyWith({
    bool? mockReader,
    bool? mockStrips,
    bool? mockQA,
    bool? mockVoice,
    bool? mockKnowledge,
    bool? mockRepo,
    bool? mockReminders,
    bool? mockShare,
  }) {
    return AppConfig(
      mockReader: mockReader ?? this.mockReader,
      mockStrips: mockStrips ?? this.mockStrips,
      mockQA: mockQA ?? this.mockQA,
      mockVoice: mockVoice ?? this.mockVoice,
      mockKnowledge: mockKnowledge ?? this.mockKnowledge,
      mockRepo: mockRepo ?? this.mockRepo,
      mockReminders: mockReminders ?? this.mockReminders,
      mockShare: mockShare ?? this.mockShare,
    );
  }
}
