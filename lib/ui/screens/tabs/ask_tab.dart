import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/models/models.dart';
import '../../theme/app_tokens.dart';
import '../../theme/language_controller.dart';
import '../../widgets/widgets.dart';
import '../journey_controller.dart';

class _SuggestionChipItem {
  final IconData icon;
  final Bilingual label;

  const _SuggestionChipItem({
    required this.icon,
    required this.label,
  });
}

class _ChatExchange {
  final Bilingual question;
  final QAAnswer? answer;
  final bool isError;
  final bool isVoiceQuestion;

  const _ChatExchange({
    required this.question,
    this.answer,
    this.isError = false,
    this.isVoiceQuestion = false,
  });
}

/// Part 4 Feature #7: ASK TAB (Grounded Urdu Q&A)
/// - Chat UI with picture suggestion chips:
///   "Can I take it with tea?", "I missed a dose", "Take it with food?", "Can I stop early?"
/// - Text field + Send button
/// - Hold-to-talk mic button that calls `QAService.ask(audioBytes: ..., plan: plan)`
/// - Answers render as bubbles with:
///   - Urdu large, English small (BiText)
///   - AiTag ("AI-generated: verify with your pharmacist")
///   - "Listen" button (`VoiceService.speak`)
///   - Grounded source chips
///   - When `escalateToPharmacist == true`, a distinct "Ask your pharmacist" card
///     (never just a plain reply!)
/// - Shows typing/thinking shimmer and a friendly error state.
class AskTab extends ConsumerStatefulWidget {
  const AskTab({super.key});

  @override
  ConsumerState<AskTab> createState() => _AskTabState();
}

class _AskTabState extends ConsumerState<AskTab> {
  final TextEditingController _textController = TextEditingController();
  final List<_ChatExchange> _exchanges = [];
  bool _isThinking = false;
  bool _isRecording = false;

  static const List<_SuggestionChipItem> _suggestions = [
    _SuggestionChipItem(
      icon: Icons.emoji_food_beverage_rounded,
      label: Bilingual(
        ur: 'کیا میں یہ دوا چائے کے ساتھ لے سکتا ہوں؟',
        en: 'Can I take it with tea?',
      ),
    ),
    _SuggestionChipItem(
      icon: Icons.history_toggle_off_rounded,
      label: Bilingual(
        ur: 'میری ایک خوراک چھوٹ گئی ہے',
        en: 'I missed a dose',
      ),
    ),
    _SuggestionChipItem(
      icon: Icons.restaurant_rounded,
      label: Bilingual(
        ur: 'کیا یہ دوا کھانے کے ساتھ لینی ہے؟',
        en: 'Take it with food?',
      ),
    ),
    _SuggestionChipItem(
      icon: Icons.pan_tool_rounded,
      label: Bilingual(
        ur: 'کیا میں دوا وقت سے پہلے چھوڑ سکتا ہوں؟',
        en: 'Can I stop early?',
      ),
    ),
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion({
    required Bilingual displayQuestion,
    String? rawText,
    Uint8List? audioBytes,
  }) async {
    final plan = ref.read(journeyControllerProvider).latestPlan;
    if (plan == null || _isThinking) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isThinking = true;
    });

    try {
      final qa = ref.read(qaServiceProvider);
      final response = await qa.ask(
        text: rawText,
        audioBytes: audioBytes,
        plan: plan,
      );
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _exchanges.add(
          _ChatExchange(
            question: displayQuestion,
            answer: response,
            isVoiceQuestion: audioBytes != null,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isThinking = false;
        _exchanges.add(
          _ChatExchange(
            question: displayQuestion,
            isError: true,
            isVoiceQuestion: audioBytes != null,
          ),
        );
      });
    }
  }

  void _onSendTyped() {
    final raw = _textController.text.trim();
    if (raw.isEmpty) return;
    _textController.clear();
    _submitQuestion(
      displayQuestion: Bilingual(ur: raw, en: raw),
      rawText: raw,
    );
  }

  Future<void> _onMicStart() async {
    HapticFeedback.mediumImpact();
    setState(() => _isRecording = true);
  }

  Future<void> _onMicRelease() async {
    if (!_isRecording) return;
    HapticFeedback.heavyImpact();
    setState(() => _isRecording = false);
    final syntheticVoiceBytes =
        Uint8List.fromList(utf8.encode('SHIFALENS_VOICE_QUESTION:missed_dose'));
    await _submitQuestion(
      displayQuestion: const Bilingual(
        ur: '🎤 صوتی سوال: میری ایک خوراک چھوٹ گئی ہے، کیا کروں؟',
        en: '🎤 Voice question: I missed a dose, what should I do?',
      ),
      audioBytes: syntheticVoiceBytes,
    );
  }

  Future<void> _speakAnswer(Bilingual text) async {
    HapticFeedback.selectionClick();
    try {
      final lang = ref.read(languageModeProvider).primaryLang;
      await ref.read(voiceServiceProvider).speak(text, lang: lang);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final journey = ref.watch(journeyControllerProvider);
    final plan = journey.latestPlan;

    if (plan == null) {
      return const Padding(
        padding: EdgeInsets.all(AppTokens.space2),
        child: EmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: Bilingual(
            ur: 'سوال پوچھنے کے لیے پہلے شیڈول بنائیں',
            en: 'Confirm your plan first to ask grounded questions',
          ),
          subtitle: Bilingual(
            ur: 'شفا لینز صرف آپ کی تصدیق شدہ دوائیوں اور مقامی جدول کی بنیاد پر جواب دیتا ہے۔',
            en: 'ShifaLens answers strictly from your confirmed plan and curated pharmacist tables.',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Scrollable Chat + Suggestion Chips
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.space2),
            children: [
              const OfflineBanner(),
              const AiTag(compact: true),
              const SizedBox(height: 8),
              const BiText(
                Bilingual(
                  ur: 'اپنی دوائیوں کے بارے میں آسان اردو میں پوچھیں',
                  en: 'Ask Grounded Questions About Your Plan',
                ),
                isHeadline: true,
                urduColor: AppTokens.primaryTealDark,
              ),
              const SizedBox(height: 10),

              // Picture Suggestion Chips
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _suggestions.map((s) {
                  return Semantics(
                    button: true,
                    label: '${s.label.ur}. ${s.label.en}',
                    child: InkWell(
                      key: Key('qa_chip_${s.label.en}'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _submitQuestion(
                        displayQuestion: s.label,
                        rawText: s.label.en,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AppTokens.minTapTarget,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTokens.cardCream,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTokens.primaryTeal.withValues(alpha: 0.45),
                            width: 1.4,
                          ),
                          boxShadow: AppTokens.cardShadow,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTokens.primaryTealTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                s.icon,
                                color: AppTokens.primaryTealDark,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: BiText(
                                s.label,
                                urduWeight: FontWeight.w700,
                                englishWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Chat Exchanges
              for (int i = 0; i < _exchanges.length; i++) ...[
                _ChatExchangeView(
                  exchange: _exchanges[i],
                  onListen: _speakAnswer,
                  onRetry: () {
                    final q = _exchanges[i].question;
                    setState(() => _exchanges.removeAt(i));
                    _submitQuestion(displayQuestion: q, rawText: q.en);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Typing / Thinking Shimmer
              if (_isThinking) ...[
                const SkeletonLoader(itemCount: 1, itemHeight: 120),
              ],
            ],
          ),
        ),

        // Bottom Input Bar: Text Field + Send + Hold-to-Talk Mic Button
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.space2,
            10,
            AppTokens.space2,
            12,
          ),
          decoration: BoxDecoration(
            color: AppTokens.cardCream,
            border: const Border(
              top: BorderSide(color: AppTokens.borderWarm, width: 1.5),
            ),
            boxShadow: AppTokens.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRecording)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.alertCoralTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTokens.alertCoral),
                  ),
                  child: const BiText(
                    Bilingual(
                      ur: '🎙️ بولیں... بھیجنے کے لیے بٹن چھوڑیں',
                      en: '🎙️ Listening... Release mic button to send',
                    ),
                    urduColor: AppTokens.alertCoralDark,
                    englishColor: AppTokens.alertCoralDark,
                  ),
                ),
              Row(
                children: [
                  // Hold-to-talk Mic Button
                  Semantics(
                    button: true,
                    label:
                        'Hold to talk in Urdu or tap to ask voice question. بول کر سوال پوچھیں',
                    child: GestureDetector(
                      key: const Key('qa_hold_to_talk_mic'),
                      onLongPressStart: (_) => _onMicStart(),
                      onLongPressEnd: (_) => _onMicRelease(),
                      onTap: () async {
                        await _onMicStart();
                        await Future<void>.delayed(
                          const Duration(milliseconds: 250),
                        );
                        await _onMicRelease();
                      },
                      child: AnimatedContainer(
                        duration: AppTokens.motionFast,
                        width: AppTokens.minTapTarget,
                        height: AppTokens.minTapTarget,
                        decoration: BoxDecoration(
                          color: _isRecording
                              ? AppTokens.alertCoral
                              : AppTokens.morningSaffronTint,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _isRecording
                                ? AppTokens.alertCoralDark
                                : AppTokens.morningSaffronDark,
                            width: 1.8,
                          ),
                        ),
                        child: Icon(
                          _isRecording
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _isRecording
                              ? Colors.white
                              : AppTokens.morningSaffronDark,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('qa_text_input'),
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Ask a question... • اپنا سوال لکھیں',
                      ),
                      onSubmitted: (_) => _onSendTyped(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: 'Send question. سوال بھیجیں',
                    child: SizedBox(
                      width: AppTokens.minTapTarget,
                      height: AppTokens.minTapTarget,
                      child: ElevatedButton(
                        key: const Key('qa_send_button'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(
                            AppTokens.minTapTarget,
                            AppTokens.minTapTarget,
                          ),
                        ),
                        onPressed: _isThinking ? null : _onSendTyped,
                        child: const Icon(Icons.send_rounded, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatExchangeView extends StatelessWidget {
  final _ChatExchange exchange;
  final void Function(Bilingual) onListen;
  final VoidCallback onRetry;

  const _ChatExchangeView({
    required this.exchange,
    required this.onListen,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final answer = exchange.answer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // User Question Bubble
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTokens.primaryTealTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTokens.primaryTeal.withValues(alpha: 0.4),
              ),
            ),
            child: BiText(
              exchange.question,
              urduColor: AppTokens.primaryTealDark,
              englishColor: AppTokens.ink,
              urduWeight: FontWeight.w700,
              englishWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // AI Answer Bubble or ErrorState
        if (exchange.isError || answer == null)
          ErrorState(
            title: const Bilingual(
              ur: 'جواب حاصل کرنے میں مشکل پیش آئی',
              en: 'Could not get an answer right now',
            ),
            message: const Bilingual(
              ur: 'دوبارہ کوشش کریں یا اپنے فارماسسٹ سے براہ راست پوچھیں۔',
              en: 'Please try again or consult your neighbourhood pharmacist.',
            ),
            onRetry: onRetry,
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(AppTokens.space2),
            decoration: BoxDecoration(
              color: AppTokens.cardCream,
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              border: Border.all(
                color: answer.escalateToPharmacist
                    ? AppTokens.warningAmber
                    : AppTokens.borderWarm,
                width: answer.escalateToPharmacist ? 2.0 : 1.4,
              ),
              boxShadow: AppTokens.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Distinct "Ask your pharmacist" escalation card when escalateToPharmacist == true
                if (answer.escalateToPharmacist) ...[
                  Container(
                    key: const Key('qa_escalate_pharmacist_card'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTokens.warningAmberTint,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTokens.warningAmber,
                        width: 1.6,
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.local_pharmacy_rounded,
                          color: AppTokens.warningAmberDark,
                          size: 28,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: BiText(
                            Bilingual(
                              ur: 'اپنے فارماسسٹ یا ڈاکٹر سے پوچھیں — خود سے دوا بند یا تبدیل نہ کریں',
                              en: 'Ask your pharmacist or doctor — never change or stop a dose on your own',
                            ),
                            urduColor: AppTokens.warningAmberDark,
                            englishColor: AppTokens.warningAmberDark,
                            urduWeight: FontWeight.w700,
                            englishWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Answer Bilingual Text (Urdu large, English small)
                BiText(answer.answer),
                const SizedBox(height: 12),

                // Listen Button + Grounded Sources
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => onListen(answer.answer),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Listen • آواز میں سنیں'),
                    ),
                    for (final src in answer.sources)
                      Chip(
                        avatar: const Icon(
                          Icons.menu_book_rounded,
                          size: 16,
                          color: AppTokens.primaryTealDark,
                        ),
                        label: Text('Source: $src'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const AiTag(compact: true),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
