import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/models.dart';
import '../../core/strings_disclosure.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';

class _DisclosureSection {
  final IconData icon;
  final Bilingual title;
  final Bilingual body;
  final Color accent;
  final Color tint;

  const _DisclosureSection({
    required this.icon,
    required this.title,
    required this.body,
    this.accent = AppTokens.primaryTealDark,
    this.tint = AppTokens.primaryTealTint,
  });
}

/// Part 4 Feature #10: ABOUT AND RESPONSIBLE AI
/// Covers all required disclosures:
/// - Which AI models do what (Gemini Flash via Firebase AI Logic perceives handwriting,
///   matches strips, answers grounded Q&A, speaks)
/// - What deterministic rules and code decide (food rules, duplicates, schedules,
///   and side-effect text come strictly from local curated tables and plain code)
/// - Privacy (synthetic data only, prescription/strip photos processed in memory and
///   never stored to Firestore/Storage, anonymous auth)
/// - Table review status (Pending pharmacist review badge when reviewed=false)
/// - Limitations ("Prototype. Not a medical device.", handwriting errors possible)
/// - AI-generated assets disclosure & "Ask your doctor or pharmacist" contact guidance
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const List<_DisclosureSection> _sections = [
    _DisclosureSection(
      icon: Icons.auto_awesome_rounded,
      title: Bilingual(
        ur: '۱۔ مصنوعی ذہانت (AI) کیا کرتی ہے؟ (Gemini Flash)',
        en: '1. Which AI models do what (Gemini Flash via Firebase AI Logic)',
      ),
      body: Bilingual(
        ur: 'جیمنائی فلیش (Gemini Flash) صرف نسخے کی لکھائی پڑھتی ہے، دوا کے پتے (Strips) پہچانتی ہے، اور تصدیق شدہ جدول کے اندر رہتے ہوئے اردو میں سوالات کا جواب دیتی ہے۔ نسخے کے اندر لکھی عبارت کو صرف غیر مصدقہ ڈیٹا سمجھا جاتا ہے، ہدایات نہیں۔',
        en: 'Gemini Flash is used strictly for perception and grounded conversation: reading prescription handwriting, matching physical blister strips, and answering Urdu Q&A grounded in local tables. Text inside photos is treated strictly as untrusted data, never instructions.',
      ),
    ),
    _DisclosureSection(
      icon: Icons.rule_folder_rounded,
      title: Bilingual(
        ur: '۲۔ تصدیق شدہ اصول اور کوڈ کیا فیصلہ کرتے ہیں؟',
        en: '2. What verified rules and plain code decide',
      ),
      body: Bilingual(
        ur: 'کھانے اور پرہیز کے کارڈز، ڈبل دوا (Duplicate) کی وارننگ، روزانہ کا شیڈول، اور مضر اثرات صرف مقامی جدول (Curated Tables) اور سادہ کوڈ سے آتے ہیں۔ مصنوعی ذہانت خود سے کوئی خوراک، پرہیز یا دوا بند کرنے کا مشورہ نہیں بناتی۔',
        en: 'Meal schedules, duplicate ingredient alerts, food-medicine rules, and side-effect warnings come 100% from deterministic code and local curated tables. The AI model never invents dosing, interactions, or diet advice.',
      ),
    ),
    _DisclosureSection(
      icon: Icons.lock_outline_rounded,
      title: Bilingual(
        ur: '۳۔ رازداری اور ڈیٹا کی حفاظت (Privacy)',
        en: '3. Privacy & Synthetic Data Protection',
      ),
      body: Bilingual(
        ur: 'یہ پروٹوٹائپ صرف فرضی ڈیٹا (Synthetic Data) کے لیے ہے۔ نسخے اور دوا کے پتوں کی تصاویر صرف فون کی میموری (RAM) میں پڑھی جاتی ہیں اور کبھی بھی کلاؤڈ اسٹوریج یا ڈیٹا بیس میں محفوظ نہیں کی جاتیں۔',
        en: 'Designed for synthetic demo data only. Prescription and strip photos are processed strictly in volatile memory and are never uploaded to Cloud Firestore or Cloud Storage. Anonymous authentication only.',
      ),
    ),
    _DisclosureSection(
      icon: Icons.fact_check_rounded,
      accent: AppTokens.warningAmberDark,
      tint: AppTokens.warningAmberTint,
      title: Bilingual(
        ur: '۴۔ معلوماتی جدول کا درجہ (Pending Pharmacist Review)',
        en: '4. Curated Table Review Status',
      ),
      body: Bilingual(
        ur: 'ہر معلوماتی کارڈ کے ساتھ reviewed فلیگ موجود ہے۔ جب تک فارماسسٹ اس کی حتمی تصدیق نہ کرے، اسکرین پر "فارماسسٹ کا جائزہ باقی ہے" کا نشان واضح طور پر دکھایا جاتا ہے۔ ہم کسی کلینیکل تصدیق کا دعویٰ نہیں کرتے۔',
        en: 'Every curated record carries a `reviewed` boolean flag. While false, the UI explicitly displays "Pending pharmacist review". We make no claim of clinical validation.',
      ),
    ),
    _DisclosureSection(
      icon: Icons.warning_amber_rounded,
      accent: AppTokens.alertCoralDark,
      tint: AppTokens.alertCoralTint,
      title: Bilingual(
        ur: '۵۔ حدود اور احتیاط (Prototype — Not a Medical Device)',
        en: '5. Limitations & AI Asset Disclosure',
      ),
      body: Bilingual(
        ur: 'یہ ایک تعلیمی ہیکاتھون پروٹوٹائپ ہے، طبی آلہ (Medical Device) نہیں۔ ہاتھ کی لکھائی پڑھنے میں غلطی ممکن ہے۔ پلیٹ گائیڈ اور ڈیمو تصاویر مصنوعی ذہانت کی مدد سے تیار کردہ تعلیمی مثالیں ہیں۔',
        en: 'Prototype. Not a medical device. Handwriting OCR errors are possible, and nothing unconfirmed is ever scheduled. Demo prescriptions and plate illustrations are synthetic educational assets.',
      ),
    ),
    _DisclosureSection(
      icon: Icons.local_pharmacy_rounded,
      title: Bilingual(
        ur: '۶۔ ہمیشہ اپنے ڈاکٹر یا فارماسسٹ سے رجوع کریں',
        en: '6. Ask Your Doctor or Pharmacist',
      ),
      body: Bilingual(
        ur: 'کوئی بھی دوا شروع کرنے، تبدیل کرنے یا چھوڑنے سے پہلے اپنے مستند ڈاکٹر یا قریبی فارماسسٹ سے مشورہ ضرور کریں۔',
        en: 'Always verify your medicine schedule, strengths, and timing with a qualified pharmacist or physician before taking any medication.',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(languageModeProvider);

    return Directionality(
      textDirection: mode.direction,
      child: Scaffold(
        backgroundColor: AppTokens.surfaceCream,
        appBar: AppBar(
          title: const Text('About & Responsible AI • ذمہ دارانہ AI'),
          actions: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: LanguageToggle(compact: true),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppTokens.space2),
            children: [
              const OfflineBanner(),
              SafetyBanner.prototype(),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: AiTag(compact: true)),
                ],
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: ReviewBadge(reviewed: false),
              ),
              const SizedBox(height: 16),

              // Official ShifaLensDisclosureStrings sections from lib/core/strings_disclosure.dart
              for (final disclosure in ShifaLensDisclosureStrings.allSections) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(AppTokens.space2),
                  decoration: BoxDecoration(
                    color: AppTokens.primaryTealSurface,
                    borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                    border: Border.all(
                      color: AppTokens.primaryTeal.withValues(alpha: 0.4),
                      width: 1.4,
                    ),
                  ),
                  child: BiText(disclosure),
                ),
              ],

              for (final sec in _sections) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(AppTokens.space2),
                  decoration: BoxDecoration(
                    color: AppTokens.cardCream,
                    borderRadius: BorderRadius.circular(AppTokens.cardRadius),
                    border: Border.all(color: AppTokens.borderWarm, width: 1.4),
                    boxShadow: AppTokens.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: sec.tint,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              sec.icon,
                              color: sec.accent,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BiText(
                              sec.title,
                              isHeadline: true,
                              urduColor: sec.accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      BiText(sec.body),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
