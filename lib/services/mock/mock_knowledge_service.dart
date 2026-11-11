import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../../core/models/models.dart';
import '../../core/services/knowledge_service.dart';

class BrandEntry {
  final String brand;
  final List<String> aliases;
  final String generic;
  final String drugClass;
  final bool ambiguous;
  final bool reviewed;

  const BrandEntry({
    required this.brand,
    required this.aliases,
    required this.generic,
    required this.drugClass,
    required this.ambiguous,
    required this.reviewed,
  });

  factory BrandEntry.fromJson(Map<String, dynamic> json) {
    return BrandEntry(
      brand: (json['brand'] as String?) ?? '',
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().toLowerCase())
          .toList(),
      generic: (json['generic'] as String?) ?? '',
      drugClass: (json['drugClass'] as String?) ?? '',
      ambiguous: (json['ambiguous'] as bool?) ?? false,
      reviewed: (json['reviewed'] as bool?) ?? false,
    );
  }
}

class MockKnowledgeService implements KnowledgeService {
  bool _loaded = false;
  final List<BrandEntry> _brands = [];
  final List<FoodCard> _foodCards = [];
  final Map<String, SideEffectInfo> _sideEffects = {};

  MockKnowledgeService() {
    _loadFallbackSync();
  }

  void _loadFallbackSync() {
    if (_brands.isNotEmpty) return;
    final data = _defaultKnowledgeMap;
    _parseMap(data);
  }

  void _parseMap(Map<String, dynamic> data) {
    _brands.clear();
    _foodCards.clear();
    _sideEffects.clear();

    for (final b in (data['brands'] as List<dynamic>? ?? const [])) {
      _brands.add(BrandEntry.fromJson(Map<String, dynamic>.from(b as Map)));
    }
    for (final f in (data['foodCards'] as List<dynamic>? ?? const [])) {
      _foodCards.add(FoodCard.fromJson(Map<String, dynamic>.from(f as Map)));
    }
    for (final s in (data['sideEffects'] as List<dynamic>? ?? const [])) {
      final info = SideEffectInfo.fromJson(Map<String, dynamic>.from(s as Map));
      _sideEffects[info.generic.toLowerCase()] = info;
    }
  }

  @override
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/knowledge_db.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _parseMap(decoded);
      _loaded = true;
    } catch (_) {
      _loadFallbackSync();
      _loaded = true;
    }
  }

  @override
  ({String? generic, bool ambiguous}) resolveBrand(String raw) {
    final cleaned = raw.trim().toLowerCase();
    if (cleaned.isEmpty || cleaned.contains('???')) {
      return (generic: null, ambiguous: true);
    }

    for (final entry in _brands) {
      if (entry.brand.toLowerCase() == cleaned ||
          entry.generic.toLowerCase() == cleaned ||
          entry.aliases.any((a) => cleaned.contains(a) || a.contains(cleaned))) {
        return (generic: entry.generic, ambiguous: entry.ambiguous);
      }
    }
    return (generic: null, ambiguous: true);
  }

  String? drugClassForGeneric(String generic) {
    final g = generic.trim().toLowerCase();
    for (final entry in _brands) {
      if (entry.generic.toLowerCase() == g) {
        return entry.drugClass;
      }
    }
    return null;
  }

  @override
  List<FoodCard> foodCardsFor(String generic) {
    final g = generic.trim().toLowerCase();
    return _foodCards
        .where((card) => card.generic.toLowerCase() == g)
        .toList();
  }

  @override
  SideEffectInfo? sideEffectsFor(String generic) {
    final g = generic.trim().toLowerCase();
    return _sideEffects[g];
  }

  @override
  List<DuplicateAlert> findDuplicates(List<MedicineLine> lines) {
    final alerts = <DuplicateAlert>[];
    final byGeneric = <String, List<MedicineLine>>{};
    final byClass = <String, List<MedicineLine>>{};

    for (final line in lines) {
      final gen = (line.genericName ??
              resolveBrand(line.brandName ?? line.rawText).generic)
          ?.toLowerCase();
      if (gen == null || gen.isEmpty) continue;
      byGeneric.putIfAbsent(gen, () => []).add(line);

      final cls = drugClassForGeneric(gen);
      if (cls != null && cls.isNotEmpty) {
        byClass.putIfAbsent(cls, () => []).add(line);
      }
    }

    final alertedGenericIds = <String>{};

    byGeneric.forEach((generic, meds) {
      if (meds.length > 1) {
        final names = meds
            .map((m) => m.brandName ?? m.genericName ?? m.rawText)
            .join(' + ');
        final ids = meds.map((m) => m.id).toList();
        alertedGenericIds.addAll(ids);
        alerts.add(
          DuplicateAlert(
            id: 'dup_gen_${generic.replaceAll(' ', '_')}',
            sameGeneric: true,
            label: generic,
            medicineIds: ids,
            message: Bilingual(
              ur: 'توجہ: $names میں ایک ہی دوا ($generic) شامل ہے۔ دونوں ایک ساتھ لینے سے پہلے اپنے فارماسسٹ یا ڈاکٹر سے تصدیق کریں۔',
              en: 'Warning: $names contain the same active medicine ($generic). Verify with your pharmacist or doctor before taking both.',
            ),
          ),
        );
      }
    });

    byClass.forEach((drugClass, meds) {
      final remaining =
          meds.where((m) => !alertedGenericIds.contains(m.id)).toList();
      if (remaining.length > 1) {
        final names = remaining
            .map((m) => m.brandName ?? m.genericName ?? m.rawText)
            .join(' + ');
        alerts.add(
          DuplicateAlert(
            id: 'dup_cls_$drugClass',
            sameGeneric: false,
            label: drugClass,
            medicineIds: remaining.map((m) => m.id).toList(),
            message: Bilingual(
              ur: 'احتیاط: $names ایک ہی قسم ($drugClass) کی دوائیں ہیں۔ فارماسسٹ سے مشورہ کریں۔',
              en: 'Caution: $names belong to the same medicine class ($drugClass). Please check with your pharmacist.',
            ),
          ),
        );
      }
    });

    return alerts;
  }

  @override
  Future<PlateGuide> plateGuide() async {
    final canvas = img.Image(width: 240, height: 240);
    img.fill(canvas, color: img.ColorRgb8(240, 249, 248));
    img.fillCircle(
      canvas,
      x: 120,
      y: 120,
      radius: 100,
      color: img.ColorRgb8(13, 115, 119),
    );
    img.fillCircle(
      canvas,
      x: 120,
      y: 120,
      radius: 92,
      color: img.ColorRgb8(255, 255, 255),
    );
    final pngBytes = Uint8List.fromList(img.encodePng(canvas));

    return PlateGuide(
      title: const Bilingual(
        ur: 'صحت مند کھانے کی سادہ پلیٹ (پاکستانی خوراک)',
        en: 'Simple Balanced Plate Guide (Pakistani Meals)',
      ),
      imageBytes: pngBytes,
      tips: const [
        Bilingual(
          ur: 'آدھی پلیٹ تازہ سلاد اور کم تیل میں پکی سبزیوں (جیسے پالک، توری، بھنڈی) سے بھریں۔',
          en: 'Fill half your plate with fresh salad and lightly cooked vegetables (like spinach, gourd, okra).',
        ),
        Bilingual(
          ur: 'چوتھائی پلیٹ دال، چنے، مچھلی، انڈے یا مرغی کے لیے رکھیں۔',
          en: 'Keep one quarter of the plate for daal, chickpeas, fish, eggs, or lean chicken.',
        ),
        Bilingual(
          ur: 'چوتھائی پلیٹ چکی کے آٹے کی روٹی یا سادہ ابلے چاول کے لیے رکھیں اور سادہ پانی زیادہ پئیں۔',
          en: 'Use one quarter for whole-wheat roti or plain rice, and drink plenty of plain water with your medicines.',
        ),
      ],
    );
  }
}

const Map<String, dynamic> _defaultKnowledgeMap = {
  'brands': [
    {
      'brand': 'Augmentin',
      'aliases': ['augmentin', 'co-amoxiclav', 'amoxiclav', 'calamox'],
      'generic': 'amoxicillin + clavulanic acid',
      'drugClass': 'penicillin_antibiotic',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Panadol',
      'aliases': ['panadol', 'paracetamol', 'acetaminophen', 'disprol'],
      'generic': 'paracetamol',
      'drugClass': 'analgesic_antipyretic',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Calpol',
      'aliases': ['calpol', 'febrol'],
      'generic': 'paracetamol',
      'drugClass': 'analgesic_antipyretic',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Risek',
      'aliases': ['risek', 'omega', 'losec', 'omeprazole'],
      'generic': 'omeprazole',
      'drugClass': 'ppi',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Glucophage',
      'aliases': ['glucophage', 'neodipar', 'metformin'],
      'generic': 'metformin',
      'drugClass': 'biguanide',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Norvasc',
      'aliases': ['norvasc', 'sofvasc', 'amlocard', 'amlodipine'],
      'generic': 'amlodipine',
      'drugClass': 'calcium_channel_blocker',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Lipitor',
      'aliases': ['lipitor', 'atorva', 'atorvastatin'],
      'generic': 'atorvastatin',
      'drugClass': 'statin',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Cipro',
      'aliases': ['cipro', 'ciproxin', 'novidat', 'ciprofloxacin'],
      'generic': 'ciprofloxacin',
      'drugClass': 'fluoroquinolone',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Ferrous sulfate',
      'aliases': ['ferrous sulfate', 'ferrous sulphate', 'fefol', 'iberet'],
      'generic': 'ferrous sulfate',
      'drugClass': 'iron_supplement',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Brufen',
      'aliases': ['brufen', 'ibuprofen'],
      'generic': 'ibuprofen',
      'drugClass': 'nsaid',
      'ambiguous': false,
      'reviewed': true,
    },
    {
      'brand': 'Ponstan',
      'aliases': ['ponstan', 'mefenamic acid'],
      'generic': 'mefenamic acid',
      'drugClass': 'nsaid',
      'ambiguous': false,
      'reviewed': false,
    },
  ],
  'foodCards': [
    {
      'id': 'food_amox_clav_1',
      'generic': 'amoxicillin + clavulanic acid',
      'type': 'takeWithFood',
      'iconKey': 'meal_plate',
      'title': {
        'ur': 'کھانے کے آغاز میں یا کھانے کے ساتھ لیں',
        'en': 'Take at the start of a meal',
      },
      'body': {
        'ur': 'یہ اینٹی بائیوٹک کھانے کے ساتھ لینے سے پیٹ خراب یا متلی کم ہوتی ہے۔ پورا کورس مکمل کریں۔',
        'en': 'Taking this antibiotic with food helps reduce stomach upset or nausea. Complete the full prescribed course.',
      },
      'reviewed': true,
    },
    {
      'id': 'food_paracetamol_1',
      'generic': 'paracetamol',
      'type': 'keepSteady',
      'iconKey': 'water_glass',
      'title': {
        'ur': 'پانی کے پورے گلاس کے ساتھ لیں',
        'en': 'Take with a full glass of water',
      },
      'body': {
        'ur': 'یہ دوا کھانے کے ساتھ یا بغیر کھانے کے لی جا سکتی ہے۔ پیراسیٹامول والی دوسری دوا ساتھ نہ لیں۔',
        'en': 'Can be taken with or without food. Do not combine with other medicines containing paracetamol.',
      },
      'reviewed': true,
    },
    {
      'id': 'food_omeprazole_1',
      'generic': 'omeprazole',
      'type': 'emptyStomach',
      'iconKey': 'empty_stomach',
      'title': {
        'ur': 'ناشتے سے 30 منٹ پہلے خالی پیٹ لیں',
        'en': 'Take 30 minutes before breakfast on an empty stomach',
      },
      'body': {
        'ur': 'کیپسول کو ثابت نگلیں، چبائیں یا کھولیں نہیں۔ کھانے سے پہلے لینے سے تیزابیت پر بہتر اثر ہوتا ہے۔',
        'en': 'Swallow the capsule whole with water; do not crush or chew. Taking it before your meal makes it work properly.',
      },
      'reviewed': true,
    },
    {
      'id': 'food_metformin_1',
      'generic': 'metformin',
      'type': 'takeWithFood',
      'iconKey': 'meal_plate',
      'title': {
        'ur': 'کھانے کے دوران یا کھانے کے فوراً بعد لیں',
        'en': 'Take with meals',
      },
      'body': {
        'ur': 'کھانے کے ساتھ لینے سے پیٹ میں مروڑ، متلی اور بدہضمی کم ہوتی ہے۔ اپنے کھانے کے اوقات باقاعدہ رکھیں۔',
        'en': 'Taking metformin with food minimizes stomach upset and diarrhea. Keep meal timings consistent.',
      },
      'reviewed': true,
    },
    {
      'id': 'food_amlodipine_1',
      'generic': 'amlodipine',
      'type': 'keepSteady',
      'iconKey': 'clock_steady',
      'title': {
        'ur': 'روزانہ ایک مقررہ وقت پر لیں',
        'en': 'Take at the same time every day',
      },
      'body': {
        'ur': 'کھانے کے ساتھ یا بغیر لیا جا سکتا ہے۔ چکوترے (Grapefruit) کے رس سے پرہیز کریں۔',
        'en': 'May be taken with or without food. Avoid large amounts of grapefruit or grapefruit juice.',
      },
      'reviewed': true,
    },
    {
      'id': 'food_atorvastatin_1',
      'generic': 'atorvastatin',
      'type': 'avoid',
      'iconKey': 'no_grapefruit',
      'title': {
        'ur': 'چکوترے (Grapefruit) سے پرہیز کریں',
        'en': 'Avoid grapefruit juice',
      },
      'body': {
        'ur': 'چکوترا خون میں اس دوا کی مقدار بڑھا سکتا ہے۔ عام طور پر رات کو سونے سے پہلے لی جاتی ہے۔',
        'en': 'Grapefruit juice can increase medicine levels in your blood. Usually taken in the evening or at bedtime.',
      },
      'reviewed': false,
    },
    {
      'id': 'food_cipro_1',
      'generic': 'ciprofloxacin',
      'type': 'separateFrom',
      'iconKey': 'no_dairy_iron',
      'title': {
        'ur': 'دودھ، دہی اور آئرن کی گولی سے 2 گھنٹے کا وقفہ رکھیں',
        'en': 'Separate by 2 hours from milk, yogurt, calcium, and iron',
      },
      'body': {
        'ur': 'دودھ، دہی، لسی یا آئرن کی گولی اس دوا کے اثر کو کم کر دیتی ہے۔ دوا کے ساتھ سادہ پانی زیادہ پئیں۔',
        'en': 'Milk, yogurt, lassi, calcium, or iron tablets stop this antibiotic from absorbing properly. Drink plenty of plain water.',
      },
      'reviewed': true,
    },
    {
      'id': 'food_iron_1',
      'generic': 'ferrous sulfate',
      'type': 'separateFrom',
      'iconKey': 'no_tea_dairy',
      'title': {
        'ur': 'چائے، دودھ اور اینٹی بائیوٹک سے 2 گھنٹے الگ رکھیں',
        'en': 'Keep 2 hours apart from tea, milk, and ciprofloxacin',
      },
      'body': {
        'ur': 'چائے یا دودھ آئرن کو جذب ہونے سے روکتے ہیں۔ اگر خالی پیٹ متلی ہو تو کھانے کے بعد لے سکتے ہیں۔',
        'en': 'Tea, coffee, and milk reduce iron absorption. If it upsets an empty stomach, take after food (away from dairy/tea).',
      },
      'reviewed': true,
    },
  ],
  'sideEffects': [
    {
      'generic': 'amoxicillin + clavulanic acid',
      'common': {
        'ur': 'ہلکی متلی، نرم پاخانہ یا پیٹ میں ہلکی بے چینی۔',
        'en': 'Mild nausea, loose stools, or mild stomach discomfort.',
      },
      'callDoctorIf': [
        {
          'ur': 'جسم پر شدید خارش، سرخ دانے، یا چہرے/ہونٹوں پر سوجن ہو۔',
          'en': 'Severe skin rash, hives, or swelling of the face, lips, or tongue.',
        },
        {
          'ur': 'سانس لینے میں دشواری ہو یا شدید دست بند نہ ہوں۔',
          'en': 'Difficulty breathing or severe watery diarrhea that does not stop.',
        },
      ],
      'reviewed': true,
    },
    {
      'generic': 'paracetamol',
      'common': {
        'ur': 'معمول کی خوراک میں سائیڈ ایفیکٹس بہت کم ہوتے ہیں۔',
        'en': 'Side effects are rare when taken at the recommended dose.',
      },
      'callDoctorIf': [
        {
          'ur': 'جلد پر دانے، خارش، یا آنکھوں اور جلد کا رنگ پیلا پڑنا۔',
          'en': 'Skin rash, itching, or yellowing of the eyes or skin.',
        },
        {
          'ur': 'اگر غلطی سے تجویز کردہ مقدار سے زیادہ گولیاں کھا لی جائیں۔',
          'en': 'If more than the prescribed number of tablets are taken.',
        },
      ],
      'reviewed': true,
    },
    {
      'generic': 'omeprazole',
      'common': {
        'ur': 'ہلکا سر درد، پیٹ میں گیس یا ہلکی متلی۔',
        'en': 'Mild headache, stomach gas, or mild nausea.',
      },
      'callDoctorIf': [
        {
          'ur': 'نگلنے میں تکلیف، سیاہ پاخانہ، یا مسلسل پیٹ درد۔',
          'en': 'Difficulty swallowing, black stools, or persistent abdominal pain.',
        },
      ],
      'reviewed': true,
    },
    {
      'generic': 'metformin',
      'common': {
        'ur': 'شروع کے دنوں میں متلی، پیٹ میں گیس یا منہ کا ذائقہ بدلنا۔',
        'en': 'Mild nausea, stomach gas, or metallic taste during the first few days.',
      },
      'callDoctorIf': [
        {
          'ur': 'تیز سانس پھولنا، شدید کمزوری، چکر آنا یا غیر معمولی ٹھنڈ لگنا۔',
          'en': 'Fast or shallow breathing, extreme weakness, dizziness, or feeling unusually cold.',
        },
      ],
      'reviewed': true,
    },
    {
      'generic': 'amlodipine',
      'common': {
        'ur': 'ٹخنوں یا پاؤں پر ہلکی سوجن، سر درد یا ہلکی تھکن۔',
        'en': 'Mild swelling of ankles or feet, headache, or mild tiredness.',
      },
      'callDoctorIf': [
        {
          'ur': 'سینے میں درد، دل کی دھڑکن بہت تیز ہونا یا بے ہوشی جیسی کیفیت۔',
          'en': 'Chest pain, very fast heartbeat, or feeling faint.',
        },
      ],
      'reviewed': true,
    },
    {
      'generic': 'atorvastatin',
      'common': {
        'ur': 'ہلکا پٹھوں کا کھنچاؤ، جوڑوں میں ہلکا درد یا بدہضمی۔',
        'en': 'Mild muscle ache, mild joint discomfort, or indigestion.',
      },
      'callDoctorIf': [
        {
          'ur': 'پٹھوں میں شدید غیر معمولی درد، کمزوری، یا پیشاب کا رنگ گہرا بھورا ہونا۔',
          'en': 'Severe unexplained muscle pain, weakness, or dark brown urine.',
        },
      ],
      'reviewed': false,
    },
    {
      'generic': 'ciprofloxacin',
      'common': {
        'ur': 'متلی، ہلکا سر درد یا پیٹ میں ہلکی بے چینی۔',
        'en': 'Mild nausea, slight headache, or mild stomach upset.',
      },
      'callDoctorIf': [
        {
          'ur': 'ایڑی یا جوڑوں کے پٹھوں (Tendon) میں اچانک درد یا سوجن۔',
          'en': 'Sudden pain, swelling, or tenderness in the heel or joints (tendon pain).',
        },
      ],
      'reviewed': true,
    },
    {
      'generic': 'ferrous sulfate',
      'common': {
        'ur': 'پاخانے کا رنگ گہرا یا کالا ہونا (یہ عام اور بے ضرر ہے)، قبض یا ہلکی متلی۔',
        'en': 'Dark or black stools (harmless and expected), mild constipation, or mild nausea.',
      },
      'callDoctorIf': [
        {
          'ur': 'پیٹ میں شدید مروڑ، قے میں خون، یا سینے میں جلن۔',
          'en': 'Severe stomach cramps, vomiting blood, or severe chest pain when swallowing.',
        },
      ],
      'reviewed': true,
    },
  ],
};
