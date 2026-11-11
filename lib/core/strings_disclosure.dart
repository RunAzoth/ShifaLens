import 'models/bilingual.dart';

/// Bilingual constants for the ShifaLens About, Safety, AI Disclosure,
/// SDG Alignment, and Limitations screens (Rule 4, Rule 5, Part 2 Task 7).
class ShifaLensDisclosureStrings {
  const ShifaLensDisclosureStrings._();

  static const Bilingual appTitle = Bilingual(
    ur: 'شفا لینز (ShifaLens)',
    en: 'ShifaLens',
  );

  static const Bilingual tagline = Bilingual(
    ur: 'ہر مریض کے لیے فارماسسٹ کی وضاحت، اردو میں، تصویروں کے ساتھ۔',
    en: 'A pharmacist\'s explanation for every patient, in Urdu, with pictures.',
  );

  static const Bilingual prototypeBanner = Bilingual(
    ur: 'پروٹوٹائپ۔ یہ طبی آلہ نہیں ہے۔ / Prototype. Not a medical device.',
    en: 'Prototype. Not a medical device.',
  );

  static const Bilingual aiVerifyTag = Bilingual(
    ur: 'اے آئی سے تیار کردہ: اپنے فارماسسٹ سے تصدیق کریں',
    en: 'AI-generated: verify with your pharmacist',
  );

  static const Bilingual pendingPharmacistReviewTag = Bilingual(
    ur: 'فارماسسٹ کی تصدیق زیرِ التواء',
    en: 'Pending pharmacist review',
  );

  static const Bilingual ramadanSuggestedDisclaimer = Bilingual(
    ur: 'تجویز کردہ ترتیب — روزے میں دوا کے اوقات اپنے ڈاکٹر سے تصدیق کریں۔',
    en: 'Suggested layout — confirm Ramadan dosing times with your doctor.',
  );

  static const Bilingual problemStatement = Bilingual(
    ur: 'پاکستان میں لاکھوں کم خواندہ مریض اور ان کے اہلِ خانہ ہاتھ سے لکھے یا انگریزی نسخوں، دواؤں کے پراسرار ناموں، کھانے کے ساتھ احتیاطوں اور ہم شکل گولیوں کے باعث الجھن کا شکار ہوتے ہیں، جس سے خوراک کی غلطی یا ڈبل دوا لینے کا خطرہ بڑھ جاتا ہے۔',
    en: 'Millions of low-literacy patients and family caregivers in Pakistan struggle with handwritten or English prescriptions, unfamiliar brand names, food-medicine timing rules, and look-alike blister strips—leading to missed doses, duplicate active ingredients, or unsafe administration.',
  );

  static const Bilingual targetUsers = Bilingual(
    ur: 'پاکستان میں کم خواندہ مریض، بزرگ افراد اور خاندان کے دیکھ بھال کرنے والے (Caregivers) جنہیں اردو آواز، تصویری علامتوں اور سادہ شیڈول کی ضرورت ہے۔',
    en: 'Low-literacy patients, older adults, and family caregivers in Pakistan who benefit from Urdu-first visual schedules, spoken explanations, and English subtitles for clinical/caregiver verification.',
  );

  static const Bilingual sdgAlignment = Bilingual(
    ur: 'ایس ڈی جی 3 (اچھی صحت اور تندرستی — بنیادی): دواؤں کے محفوظ استعمال اور فارماسسٹ کی ہدایات کو عام فہم بنا کر ادویات کے نقصان کو کم کرنا۔ ایس ڈی جی 10 (عدم مساوات میں کمی — معاون): کم خواندہ اور اردو بولنے والے مریضوں کو یکساں طبی معلومات فراہم کرنا۔',
    en: 'SDG 3 (Good Health and Well-Being — Primary): Reduces preventable medication errors through clear schedules, duplicate-generic alerts, and food-interaction guidance. SDG 10 (Reduced Inequalities — Supporting): Bridges health-literacy and language barriers with Urdu voice, visual meal icons, and colour/shape pill badges.',
  );

  static const Bilingual corePrinciple = Bilingual(
    ur: 'بنیادی اصول: اے آئی صرف دیکھتا اور بات کرتا ہے؛ تصدیق شدہ اصول فیصلہ کرتے ہیں۔ جیمنائی (Gemini) صرف نسخہ پڑھتا ہے، پتے ملاتا ہے اور تصدیق شدہ معلومات سے سوال کا جواب دیتا ہے، جبکہ خوراک کا شیڈول، ڈبل دوا کی وارننگ اور کھانے کی احتیاطیں صرف مقامی تصدیق شدہ ڈیٹا اور کوڈ سے طے ہوتی ہیں۔',
    en: 'Core Principle: AI perceives and converses; verified rules decide. Gemini only reads prescriptions, matches physical strips, and answers grounded Q&A, while schedules, duplicate alerts, food rules, and side-effect cards come strictly from local curated tables and deterministic Dart code.',
  );

  static const Bilingual aiUseDisclosure = Bilingual(
    ur: 'اے آئی کا استعمال اور وضاحت:\n'
        '• ماڈل: Google Gemini Flash (gemini-2.5-flash بذریعہ Firebase AI Logic) نسخے کی تحریر پڑھنے، دوا کے پتے ملانے اور محدود سیاق و سباق (Context) سے اردو/انگریزی سوالات کے جوابات کے لیے۔\n'
        '• متوازن پلیٹ کی تصویر: روٹی، دال، سبزی اور سلاد کی سادہ تصویری مثال اے آئی/کوڈ کی مدد سے تیار کی گئی ہے (کوئی کیلوری یا ڈائٹ پلان نہیں)۔\n'
        '• کوڈنگ معاونت: ہیکاتھون پروٹوٹائپ اور ابتدائی JSON جدول کی تیاری میں اے آئی کوڈنگ اسسٹنٹس استعمال کیے گئے ہیں، جن پر ہر ریکارڈ میں "reviewed: false" درج ہے۔',
    en: 'AI Use & Disclosure:\n'
        '• Runtime Model: Google Gemini Flash (gemini-2.5-flash via Firebase AI Logic) for prescription OCR, blister-strip matching, and context-grounded bilingual Q&A.\n'
        '• Plate Guide Illustration: Flat visual illustration of a balanced Pakistani plate (roti, daal, sabzi, salad) generated programmatically/with AI assistance (qualitative only; no calorie targets).\n'
        '• Development Assistance: AI coding assistants were used to accelerate hackathon scaffolding and draft initial JSON knowledge records (all marked reviewed: false until pharmacist sign-off).',
  );

  static const Bilingual limitations = Bilingual(
    ur: 'حدود اور انتباہ:\n'
        '1. یہ صرف ایک ہیکاتھون پروٹوٹائپ ہے، کوئی طبی آلہ (Medical Device) نہیں۔\n'
        '2. پرائیویسی: صرف فرضی (Synthetic) ڈیٹا استعمال کیا گیا ہے۔ نسخے کی تصاویر صرف میموری میں پڑھی جاتی ہیں اور کبھی سرور پر محفوظ نہیں ہوتیں۔\n'
        '3. ادویات اور غذا کے جدول ابھی فارماسسٹ کی حتمی تصدیق کے منتظر ہیں (Pending pharmacist review)۔\n'
        '4. ہاتھ سے لکھے نسخوں میں غلطی ممکن ہے؛ غیر واضح سطریں کبھی شیڈول نہیں کی جاتیں۔\n'
        '5. اردو ٹی ٹی ایس (TTS) آواز کا معیار مختلف فونز پر مختلف ہو سکتا ہے۔\n'
        '6. دوا کے اوقات کی یاد دہانی فون پر مقامی (Local) ہے جبکہ ایف سی ایم (FCM) پش نوٹیفکیشن ڈیمو کے لیے ہے۔',
    en: 'Limitations & Safety Disclaimers:\n'
        '1. Hackathon prototype only — NOT a certified medical device or clinical decision system.\n'
        '2. Synthetic data & privacy: Tested exclusively on synthetic prescriptions. Photos are processed in memory and never uploaded to Firestore or Cloud Storage.\n'
        '3. Knowledge tables pending pharmacist review: All drafted drug-food and side-effect records carry reviewed: false until verified by a licensed pharmacist.\n'
        '4. Handwriting OCR errors are possible: Any line with <0.75 confidence or ambiguous brand is held in "Not scheduled — ask your pharmacist".\n'
        '5. Urdu TTS quality is unverified across all Android OEM voice packs and English brand transliterations.\n'
        '6. Dose-time alarms run locally on-device via flutter_local_notifications; FCM push is registered for caregiver/console demo notifications.',
  );

  static const List<Bilingual> allSections = [
    problemStatement,
    targetUsers,
    sdgAlignment,
    corePrinciple,
    aiUseDisclosure,
    limitations,
  ];
}
