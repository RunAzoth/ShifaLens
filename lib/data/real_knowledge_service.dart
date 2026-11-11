import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../core/models/models.dart';
import '../core/services/knowledge_service.dart';
import '../services/mock/mock_knowledge_service.dart';

class RealKnowledgeService implements KnowledgeService {
  final FirebaseFirestore? _firestoreOverride;
  bool _loaded = false;

  final List<BrandEntry> _brands = [];
  final List<FoodCard> _foodCards = [];
  final Map<String, SideEffectInfo> _sideEffects = {};
  PlateGuide? _plateGuideCache;

  RealKnowledgeService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore {
    _seedFallbackSync();
  }

  void _seedFallbackSync() {
    if (_brands.isNotEmpty) return;
    final mock = MockKnowledgeService();
    // Ensure synchronous baseline before async load() completes
    _brands.addAll(_builtinBrands.map(BrandEntry.fromJson));
    _foodCards.addAll(_builtinFoodCards.map(FoodCard.fromJson));
    for (final s in _builtinSideEffects) {
      final info = SideEffectInfo.fromJson(s);
      _sideEffects[info.generic.toLowerCase()] = info;
    }
    // Keep reference to mock unused warning free
    mock.resolveBrand('Panadol');
  }

  @override
  Future<void> load() async {
    if (_loaded) return;

    // 1. Load bundled JSON assets first (offline-safe guarantee)
    await _loadFromBundledAssets();

    // 2. Attempt Firestore sync with short timeout (falls back silently if offline)
    await _tryLoadFromFirestore();

    _loaded = true;
  }

  Future<void> _loadFromBundledAssets() async {
    try {
      final brandsRaw = await rootBundle.loadString(
        'assets/data/brands_generics.json',
      );
      final brandsJson = jsonDecode(brandsRaw) as List<dynamic>;
      _brands
        ..clear()
        ..addAll(
          brandsJson.map(
            (e) => BrandEntry.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    } catch (_) {}

    try {
      final foodRaw = await rootBundle.loadString('assets/data/food_med.json');
      final foodJson = jsonDecode(foodRaw) as List<dynamic>;
      _foodCards
        ..clear()
        ..addAll(
          foodJson.map(
            (e) => FoodCard.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
    } catch (_) {}

    try {
      final seRaw = await rootBundle.loadString(
        'assets/data/side_effects.json',
      );
      final seJson = jsonDecode(seRaw) as List<dynamic>;
      _sideEffects.clear();
      for (final item in seJson) {
        final info = SideEffectInfo.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        _sideEffects[info.generic.toLowerCase()] = info;
      }
    } catch (_) {}

    try {
      final pgRaw = await rootBundle.loadString('assets/data/plate_guide.json');
      final pgMap = jsonDecode(pgRaw) as Map<String, dynamic>;
      _plateGuideCache = _parsePlateGuideDoc(pgMap);
    } catch (_) {}
  }

  Future<void> _tryLoadFromFirestore() async {
    if (_firestoreOverride == null && Firebase.apps.isEmpty) return;
    try {
      final db = _firestoreOverride ?? FirebaseFirestore.instance;

      final brandsSnap = await db
          .collection('brands_generics')
          .get()
          .timeout(const Duration(seconds: 4));
      if (brandsSnap.docs.isNotEmpty) {
        _brands
          ..clear()
          ..addAll(brandsSnap.docs.map((d) => BrandEntry.fromJson(d.data())));
      }

      final foodSnap = await db
          .collection('food_med')
          .get()
          .timeout(const Duration(seconds: 4));
      if (foodSnap.docs.isNotEmpty) {
        _foodCards
          ..clear()
          ..addAll(foodSnap.docs.map((d) => FoodCard.fromJson(d.data())));
      }

      final seSnap = await db
          .collection('side_effects')
          .get()
          .timeout(const Duration(seconds: 4));
      if (seSnap.docs.isNotEmpty) {
        _sideEffects.clear();
        for (final doc in seSnap.docs) {
          final info = SideEffectInfo.fromJson(doc.data());
          _sideEffects[info.generic.toLowerCase()] = info;
        }
      }

      final plateDoc = await db
          .collection('plate_guide')
          .doc('main')
          .get()
          .timeout(const Duration(seconds: 4));
      if (plateDoc.exists && plateDoc.data() != null) {
        _plateGuideCache = _parsePlateGuideDoc(plateDoc.data()!);
      }
    } catch (_) {
      // Offline or unconfigured: bundled JSON remains active
    }
  }

  PlateGuide _parsePlateGuideDoc(Map<String, dynamic> map) {
    final title = map['title'] != null
        ? Bilingual.fromJson(Map<String, dynamic>.from(map['title'] as Map))
        : const Bilingual(
            ur: 'متوازن پاکستانی کھانے کی پلیٹ (روٹی، دال، سبزی اور سلاد)',
            en: 'Balanced Pakistani Plate Guide (Roti, Daal, Sabzi & Salad)',
          );
    final tips = (map['tips'] as List<dynamic>? ?? const [])
        .map((e) => Bilingual.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    Uint8List imageBytes;
    final b64 = map['imageBase64'] as String? ?? map['imageBytes'] as String?;
    if (b64 != null && b64.length > 200) {
      try {
        imageBytes = base64Decode(b64);
      } catch (_) {
        imageBytes = buildFlatPlateIllustrationPng();
      }
    } else {
      imageBytes = buildFlatPlateIllustrationPng();
    }

    return PlateGuide(
      title: title,
      imageBytes: imageBytes,
      tips: tips,
    );
  }

  /// Normalizes a raw brand/line string:
  /// lowercase, strips Tab./Cap./Syp./Inj., strengths (500mg), frequencies (1+0+1), durations (x5d), and punctuation.
  static String normalizeBrand(String raw) {
    var s = raw.toLowerCase().trim();
    if (s.contains('???')) return '';

    // Remove dosage form prefixes
    s = s.replaceAll(
      RegExp(
        r'\b(tab|tabs|tablet|tablets|cap|caps|capsule|capsules|syp|syrup|inj|injection|susp|suspension|drp|drops|sachet)\.?\b',
      ),
      ' ',
    );

    // Remove strengths like 625mg, 500 mg, 20mcg, 5ml
    s = s.replaceAll(
      RegExp(r'\b\d+(\.\d+)?\s*(mg|mcg|g|ml|iu|%)\b'),
      ' ',
    );

    // Remove frequency patterns like 1+0+1, 1-1-1, bd, tds, od, hs, sos
    s = s.replaceAll(
      RegExp(r'\b[0-9]\s*[+-]\s*[0-9]\s*[+-]\s*[0-9]\b'),
      ' ',
    );
    s = s.replaceAll(
      RegExp(r'\b(od|qd|bd|bid|tds|tid|qid|hs|sos|prn|q8h|q12h)\b'),
      ' ',
    );

    // Remove duration patterns like x5d, x 14 days
    s = s.replaceAll(
      RegExp(r'\bx?\s*\d+\s*(d|day|days|wk|weeks)\b'),
      ' ',
    );

    // Remove common timing words
    s = s.replaceAll(
      RegExp(
        r'\b(before|after|with|meals|meal|breakfast|lunch|dinner|bedtime|empty|stomach|morning|night)\b',
      ),
      ' ',
    );

    // Strip punctuation except spaces and hyphens inside drug names
    s = s.replaceAll(RegExp(r'[^\w\s+-]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Computes standard Levenshtein edit distance between two strings.
  static int levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        curr[j + 1] = math.min(
          math.min(curr[j] + 1, prev[j + 1] + 1),
          prev[j] + cost,
        );
      }
      for (var j = 0; j <= b.length; j++) {
        prev[j] = curr[j];
      }
    }
    return prev[b.length];
  }

  @override
  ({String? generic, bool ambiguous}) resolveBrand(String raw) {
    if (raw.contains('?')) {
      return (generic: null, ambiguous: true);
    }
    final norm = normalizeBrand(raw);
    if (norm.isEmpty) {
      return (generic: null, ambiguous: true);
    }

    final firstToken = norm.split(' ').first;

    // 1. Exact match on full normalized string or first token (brand, generic, or alias)
    for (final entry in _brands) {
      final brandLower = entry.brand.toLowerCase();
      final genericLower = entry.generic.toLowerCase();

      if (norm == brandLower ||
          norm == genericLower ||
          entry.aliases.contains(norm)) {
        return (generic: entry.generic, ambiguous: entry.ambiguous);
      }
    }

    for (final entry in _brands) {
      final brandLower = entry.brand.toLowerCase();
      if (firstToken.length >= 4 &&
          (firstToken == brandLower || entry.aliases.contains(firstToken))) {
        return (generic: entry.generic, ambiguous: entry.ambiguous);
      }
    }

    // 2. Fuzzy match: Levenshtein <= 2 on names >= 5 chars -> marks ambiguous = true
    final candidatesToCheck = <String>{norm, firstToken}
        .where((s) => s.length >= 5)
        .toList();

    BrandEntry? bestFuzzyEntry;
    int bestDistance = 99;

    for (final candidate in candidatesToCheck) {
      for (final entry in _brands) {
        final targets = <String>{
          entry.brand.toLowerCase(),
          entry.generic.toLowerCase(),
          ...entry.aliases,
        }.where((t) => t.length >= 5);

        for (final target in targets) {
          if ((candidate.length - target.length).abs() > 2) continue;
          final dist = levenshteinDistance(candidate, target);
          if (dist <= 2 && dist < bestDistance) {
            bestDistance = dist;
            bestFuzzyEntry = entry;
          }
        }
      }
    }

    if (bestFuzzyEntry != null) {
      return (generic: bestFuzzyEntry.generic, ambiguous: true);
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
      final resolvedGen = (line.genericName ??
              resolveBrand(line.brandName ?? line.rawText).generic)
          ?.trim()
          .toLowerCase();
      if (resolvedGen == null || resolvedGen.isEmpty) continue;

      byGeneric.putIfAbsent(resolvedGen, () => []).add(line);

      final cls = drugClassForGeneric(resolvedGen);
      if (cls != null && cls.isNotEmpty) {
        byClass.putIfAbsent(cls, () => []).add(line);
      }
    }

    final alertedGenericMedIds = <String>{};

    // 1. Same generic across lines = strong alert (sameGeneric: true)
    byGeneric.forEach((generic, meds) {
      if (meds.length > 1) {
        final names = meds
            .map((m) => m.brandName ?? m.genericName ?? m.rawText)
            .join(' + ');
        final ids = meds.map((m) => m.id).toList();
        alertedGenericMedIds.addAll(ids);
        alerts.add(
          DuplicateAlert(
            id: 'dup_generic_${generic.replaceAll(RegExp(r'\s+'), '_')}',
            sameGeneric: true,
            label: generic,
            medicineIds: ids,
            message: Bilingual(
              ur: 'شدید انتباہ: $names میں ایک ہی دوا ($generic) شامل ہے۔ دونوں ایک ساتھ لینے سے پہلے اپنے فارماسسٹ یا ڈاکٹر سے تصدیق کریں۔',
              en: 'Strong Alert: $names contain the same active medicine ($generic). Verify with your pharmacist or doctor before taking both.',
            ),
          ),
        );
      }
    });

    // 2. Same drugClass across lines = soft alert ("ask your pharmacist if these can be taken together")
    byClass.forEach((drugClass, meds) {
      final distinctGenerics = meds
          .map(
            (m) => (m.genericName ??
                    resolveBrand(m.brandName ?? m.rawText).generic ??
                    '')
                .toLowerCase(),
          )
          .toSet();
      if (meds.length > 1 && distinctGenerics.length > 1) {
        final names = meds
            .map((m) => m.brandName ?? m.genericName ?? m.rawText)
            .join(' + ');
        alerts.add(
          DuplicateAlert(
            id: 'dup_class_$drugClass',
            sameGeneric: false,
            label: drugClass,
            medicineIds: meds.map((m) => m.id).toList(),
            message: Bilingual(
              ur: 'احتیاط: $names ایک ہی قسم ($drugClass) کی دوائیں ہیں — اپنے فارماسسٹ سے پوچھیں کہ کیا یہ دوائیں ایک ساتھ لی جا سکتی ہیں۔',
              en: 'Caution: $names belong to the same medicine class ($drugClass) — ask your pharmacist if these can be taken together.',
            ),
          ),
        );
      }
    });

    return alerts;
  }

  @override
  Future<PlateGuide> plateGuide() async {
    if (_plateGuideCache != null) return _plateGuideCache!;
    await load();
    if (_plateGuideCache != null) return _plateGuideCache!;

    _plateGuideCache = PlateGuide(
      title: const Bilingual(
        ur: 'متوازن پاکستانی کھانے کی پلیٹ (روٹی، دال، سبزی اور سلاد)',
        en: 'Balanced Pakistani Plate Guide (Roti, Daal, Sabzi & Salad)',
      ),
      imageBytes: buildFlatPlateIllustrationPng(),
      tips: const [
        Bilingual(
          ur: 'شوگر کی دواؤں کے ساتھ کھانے کے اوقات باقاعدہ رکھیں اور روٹی یا چاول کو دن بھر کے کھانوں میں متوازن تقسیم کریں۔',
          en: 'With diabetes medicines, keep meal times steady and spread carbohydrates (roti or rice) evenly across your meals.',
        ),
        Bilingual(
          ur: 'آدھی پلیٹ تازہ کچی سلاد اور کم تیل میں پکی موسمی سبزیوں کے لیے رکھیں۔',
          en: 'Fill half the plate with fresh salad and lightly cooked seasonal sabzi.',
        ),
        Bilingual(
          ur: 'پلیٹ کا ایک چوتھائی حصہ دال، چنے، لوبیا، انڈے، مچھلی یا مرغی کے لیے رکھیں۔',
          en: 'Keep one quarter of the plate for daal, chickpeas, beans, egg, fish, or lean chicken.',
        ),
        Bilingual(
          ur: 'باقی چوتھائی حصے میں چکی کے آٹے کی روٹی یا سادہ چاول شامل کریں۔',
          en: 'Reserve the remaining quarter of the plate for whole-wheat roti or plain rice.',
        ),
      ],
    );
    return _plateGuideCache!;
  }

  /// Generates a clean flat illustration of a divided Pakistani plate
  /// (1/2 Sabzi & Salad in green, 1/4 Daal in warm amber, 1/4 Roti in wheat tan)
  /// compressed as a PNG well under 300KB.
  static Uint8List buildFlatPlateIllustrationPng() {
    final canvas = img.Image(width: 280, height: 280);
    // Soft cream background
    img.fill(canvas, color: img.ColorRgb8(248, 246, 240));

    // Outer plate rim (teal)
    img.fillCircle(
      canvas,
      x: 140,
      y: 140,
      radius: 124,
      color: img.ColorRgb8(13, 115, 119),
    );
    // Inner ceramic plate
    img.fillCircle(
      canvas,
      x: 140,
      y: 140,
      radius: 112,
      color: img.ColorRgb8(255, 255, 255),
    );

    // Left half: Sabzi & Salad (fresh green bowl/quadrant)
    img.fillCircle(
      canvas,
      x: 92,
      y: 140,
      radius: 52,
      color: img.ColorRgb8(76, 175, 80),
    );
    // Top-right quarter: Daal / Chana bowl (warm golden lentil color)
    img.fillCircle(
      canvas,
      x: 182,
      y: 98,
      radius: 38,
      color: img.ColorRgb8(230, 161, 45),
    );
    // Bottom-right quarter: Whole-wheat Chakki Roti (warm wheat brown)
    img.fillCircle(
      canvas,
      x: 182,
      y: 182,
      radius: 40,
      color: img.ColorRgb8(210, 170, 115),
    );

    // Divider lines across the plate
    img.drawLine(
      canvas,
      x1: 140,
      y1: 28,
      x2: 140,
      y2: 252,
      color: img.ColorRgb8(13, 115, 119),
      thickness: 3,
    );
    img.drawLine(
      canvas,
      x1: 140,
      y1: 140,
      x2: 252,
      y2: 140,
      color: img.ColorRgb8(13, 115, 119),
      thickness: 3,
    );

    return Uint8List.fromList(img.encodePng(canvas, level: 6));
  }
}

const List<Map<String, dynamic>> _builtinBrands = [
  {
    'brand': 'Augmentin',
    'aliases': ['augmentin', 'augmentin duo', 'co-amoxiclav', 'amoxiclav', 'calamox'],
    'generic': 'amoxicillin + clavulanic acid',
    'drugClass': 'penicillin_antibiotic',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Amoxil',
    'aliases': ['amoxil', 'amoxicillin', 'amoxycillin'],
    'generic': 'amoxicillin',
    'drugClass': 'penicillin_antibiotic',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Panadol',
    'aliases': ['panadol', 'panadol advance', 'paracetamol', 'acetaminophen'],
    'generic': 'paracetamol',
    'drugClass': 'analgesic_antipyretic',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Calpol',
    'aliases': ['calpol', 'calpol 500', 'febrol', 'disprol'],
    'generic': 'paracetamol',
    'drugClass': 'analgesic_antipyretic',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Brufen',
    'aliases': ['brufen', 'ibuprofen', 'advil'],
    'generic': 'ibuprofen',
    'drugClass': 'nsaid',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Ponstan',
    'aliases': ['ponstan', 'ponstan forte', 'mefenamic acid'],
    'generic': 'mefenamic acid',
    'drugClass': 'nsaid',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Voren',
    'aliases': ['voren', 'dicloran', 'voltral', 'diclofenac'],
    'generic': 'diclofenac',
    'drugClass': 'nsaid',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Synflex',
    'aliases': ['synflex', 'naproxen', 'apranax'],
    'generic': 'naproxen',
    'drugClass': 'nsaid',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Risek',
    'aliases': ['risek', 'omega', 'losec', 'omeprazole'],
    'generic': 'omeprazole',
    'drugClass': 'ppi',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Nexum',
    'aliases': ['nexum', 'nexium', 'esomeprazole'],
    'generic': 'esomeprazole',
    'drugClass': 'ppi',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Glucophage',
    'aliases': ['glucophage', 'neodipar', 'metformin'],
    'generic': 'metformin',
    'drugClass': 'biguanide',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Amaryl',
    'aliases': ['amaryl', 'getryl', 'glimepiride'],
    'generic': 'glimepiride',
    'drugClass': 'sulfonylurea',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Norvasc',
    'aliases': ['norvasc', 'sofvasc', 'amlocard', 'amlodipine'],
    'generic': 'amlodipine',
    'drugClass': 'calcium_channel_blocker',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Concor',
    'aliases': ['concor', 'bisoprolol'],
    'generic': 'bisoprolol',
    'drugClass': 'beta_blocker',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Cozaar',
    'aliases': ['cozaar', 'eziday', 'losartan'],
    'generic': 'losartan',
    'drugClass': 'arb',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Lipitor',
    'aliases': ['lipitor', 'atorva', 'atorvastatin', 'descol'],
    'generic': 'atorvastatin',
    'drugClass': 'statin',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Rovista',
    'aliases': ['rovista', 'crestor', 'rosuvastatin'],
    'generic': 'rosuvastatin',
    'drugClass': 'statin',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Cipro',
    'aliases': ['cipro', 'ciproxin', 'novidat', 'ciprofloxacin'],
    'generic': 'ciprofloxacin',
    'drugClass': 'fluoroquinolone',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Leflox',
    'aliases': ['leflox', 'cravit', 'levofloxacin'],
    'generic': 'levofloxacin',
    'drugClass': 'fluoroquinolone',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Flagyl',
    'aliases': ['flagyl', 'metronidazole'],
    'generic': 'metronidazole',
    'drugClass': 'nitroimidazole_antibiotic',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Azomax',
    'aliases': ['azomax', 'zithromax', 'azithromycin', 'azee'],
    'generic': 'azithromycin',
    'drugClass': 'macrolide_antibiotic',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Vibramycin',
    'aliases': ['vibramycin', 'doxycycline'],
    'generic': 'doxycycline',
    'drugClass': 'tetracycline_antibiotic',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Ferrous sulfate',
    'aliases': ['ferrous sulfate', 'ferrous sulphate', 'fefol', 'iberet'],
    'generic': 'ferrous sulfate',
    'drugClass': 'iron_supplement',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Thyronorm',
    'aliases': ['thyronorm', 'eltroxin', 'levothyroxine'],
    'generic': 'levothyroxine',
    'drugClass': 'thyroid_hormone',
    'ambiguous': false,
    'reviewed': false,
  },
  {
    'brand': 'Marevan',
    'aliases': ['marevan', 'warfarin', 'coumadin'],
    'generic': 'warfarin',
    'drugClass': 'anticoagulant',
    'ambiguous': false,
    'reviewed': false,
  },
];

const List<Map<String, dynamic>> _builtinFoodCards = [
  {
    'id': 'food_cipro_1',
    'generic': 'ciprofloxacin',
    'type': 'separateFrom',
    'iconKey': 'no_dairy_iron',
    'title': {
      'ur': 'دودھ، دہی، کیلشیم، تیزابیت کی دوا اور آئرن سے 2 گھنٹے وقفہ رکھیں',
      'en': 'Separate by 2 hours from dairy, calcium, antacids, and iron',
    },
    'body': {
      'ur': 'دودھ، دہی، لسی، کیلشیم، اینٹاسڈ یا آئرن کی گولی اس دوا کے اثر کو کم کر دیتی ہے۔ سادہ پانی زیادہ پئیں۔',
      'en': 'Milk, yogurt, lassi, calcium, antacids, or iron tablets block absorption of this antibiotic. Take with plain water.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_doxy_1',
    'generic': 'doxycycline',
    'type': 'separateFrom',
    'iconKey': 'no_dairy_iron',
    'title': {
      'ur': 'دودھ، کیلشیم اور آئرن سے 2 گھنٹے الگ رکھیں اور بیٹھ کر پانی پئیں',
      'en': 'Separate by 2 hours from dairy/iron and take sitting upright',
    },
    'body': {
      'ur': 'دودھ اور آئرن کی گولی سے وقفہ رکھیں۔ گولی کھانے کے بعد کم از کم 30 منٹ تک سیدھے بیٹھیں۔',
      'en': 'Keep apart from milk, antacids, and iron. Stay upright for 30 minutes after swallowing with water.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_iron_1',
    'generic': 'ferrous sulfate',
    'type': 'separateFrom',
    'iconKey': 'no_tea_dairy',
    'title': {
      'ur': 'تیز چائے، کافی، دودھ اور اینٹی بائیوٹک سے 2 گھنٹے الگ رکھیں',
      'en': 'Keep 2 hours apart from strong chai, coffee, milk, and antibiotics',
    },
    'body': {
      'ur': 'چائے، کافی یا دودھ جسم میں آئرن کو جذب ہونے سے روکتے ہیں۔ اگر خالی پیٹ متلی ہو تو کھانے کے بعد لے سکتے ہیں۔',
      'en': 'Strong tea (chai), coffee, and milk reduce iron absorption. If it upsets an empty stomach, take after food away from tea/milk.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_ibuprofen_1',
    'generic': 'ibuprofen',
    'type': 'takeWithFood',
    'iconKey': 'meal_plate',
    'title': {
      'ur': 'معدے کی حفاظت کے لیے کھانے کے ساتھ یا بعد میں لیں',
      'en': 'Take with or right after food to protect your stomach',
    },
    'body': {
      'ur': 'خالی پیٹ درد کی یہ دوا لینے سے معدے میں جلن یا تیزابیت ہو سکتی ہے۔',
      'en': 'Taking NSAID pain relievers on an empty stomach can irritate the stomach lining.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_metformin_1',
    'generic': 'metformin',
    'type': 'takeWithFood',
    'iconKey': 'meal_plate',
    'title': {
      'ur': 'کھانے کے دوران یا کھانے کے فوراً بعد لیں',
      'en': 'Take with or right after meals',
    },
    'body': {
      'ur': 'کھانے کے ساتھ لینے سے پیٹ میں مروڑ، متلی اور بدہضمی کم ہوتی ہے۔',
      'en': 'Taking metformin with meals reduces nausea, stomach cramps, and diarrhea.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_metronidazole_1',
    'generic': 'metronidazole',
    'type': 'avoid',
    'iconKey': 'avoid_alcohol',
    'title': {
      'ur': 'کھانے کے بعد لیں اور الکحل والی اشیاء سے مکمل پرہیز کریں',
      'en': 'Take with food and strictly avoid alcohol',
    },
    'body': {
      'ur': 'یہ دوا کھانے کے بعد پانی کے ساتھ لیں اور الکحل والی مصنوعات سے پرہیز کریں۔',
      'en': 'Take with or after food and strictly avoid alcohol during treatment.',
    },
    'reviewed': false,
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
      'ur': 'کیپسول کو ثابت نگلیں، چبائیں یا کھولیں نہیں۔',
      'en': 'Swallow the capsule whole with water 30 minutes before breakfast.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_atorvastatin_1',
    'generic': 'atorvastatin',
    'type': 'avoid',
    'iconKey': 'no_grapefruit',
    'title': {
      'ur': 'چکوترے (Grapefruit) کے رس سے پرہیز کریں',
      'en': 'Avoid grapefruit and grapefruit juice',
    },
    'body': {
      'ur': 'چکوترا خون میں اس دوا کی مقدار بڑھا سکتا ہے۔ عام طور پر رات کو لی جاتی ہے۔',
      'en': 'Grapefruit juice can raise medicine levels in your blood. Usually taken at bedtime.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_levothyroxine_1',
    'generic': 'levothyroxine',
    'type': 'emptyStomach',
    'iconKey': 'empty_stomach',
    'title': {
      'ur': 'صبح ناشتے یا چائے سے 30 تا 60 منٹ پہلے خالی پیٹ لیں',
      'en': 'Take on an empty stomach 30–60 minutes before breakfast or tea',
    },
    'body': {
      'ur': 'سادہ پانی کے ساتھ صبح خالی پیٹ لیں۔ آئرن یا کیلشیم سے 4 گھنٹے وقفہ رکھیں۔',
      'en': 'Take first thing in the morning with plain water before breakfast or chai.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_warfarin_1',
    'generic': 'warfarin',
    'type': 'keepSteady',
    'iconKey': 'leafy_greens',
    'title': {
      'ur': 'پالک، ساگ اور ہری سبزیوں کی مقدار روزانہ یکساں رکھیں',
      'en': 'Keep leafy green vegetables (palak, saag) steady from day to day',
    },
    'body': {
      'ur': 'ہری سبزیوں کو اچانک بہت زیادہ بڑھانے یا بند کرنے سے دوا کے اثر میں فرق آ سکتا ہے۔',
      'en': 'Keep intake of green leafy vegetables consistent from day to day.',
    },
    'reviewed': false,
  },
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
      'ur': 'یہ اینٹی بائیوٹک کھانے کے ساتھ لینے سے پیٹ خراب یا متلی کم ہوتی ہے۔',
      'en': 'Taking this antibiotic with food helps reduce stomach upset or nausea.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_amlodipine_1',
    'generic': 'amlodipine',
    'type': 'keepSteady',
    'iconKey': 'clock_steady',
    'title': {
      'ur': 'روزانہ ایک مقررہ وقت پر لیں اور چکوترے سے بچیں',
      'en': 'Take at the same time every day; avoid large amounts of grapefruit',
    },
    'body': {
      'ur': 'کھانے کے ساتھ یا بغیر لیا جا سکتا ہے مگر وقت روزانہ ایک جیسا رکھیں۔',
      'en': 'Can be taken with or without food at the same time daily.',
    },
    'reviewed': false,
  },
  {
    'id': 'food_paracetamol_1',
    'generic': 'paracetamol',
    'type': 'keepSteady',
    'iconKey': 'water_glass',
    'title': {
      'ur': 'پانی کے پورے گلاس کے ساتھ لیں؛ پیراسیٹامول والی دوسری دوا ساتھ نہ لیں',
      'en': 'Take with water; do not combine with other paracetamol products',
    },
    'body': {
      'ur': 'کھانے کے ساتھ یا بغیر لی جا سکتی ہے۔ دوسری پیراسیٹامول دوا ساتھ نہ لیں۔',
      'en': 'Can be taken with or without food. Avoid duplicate paracetamol.',
    },
    'reviewed': false,
  },
];

const List<Map<String, dynamic>> _builtinSideEffects = [
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
    ],
    'reviewed': false,
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
    ],
    'reviewed': false,
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
    'reviewed': false,
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
        'en': 'Fast or shallow breathing, extreme weakness, or dizziness.',
      },
    ],
    'reviewed': false,
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
    'reviewed': false,
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
    'reviewed': false,
  },
  {
    'generic': 'ferrous sulfate',
    'common': {
      'ur': 'پاخانے کا رنگ گہرا یا کالا ہونا (یہ عام اور بے ضرر ہے)، قبض یا ہلکی متلی۔',
      'en': 'Dark or black stools (harmless and expected), mild constipation, or mild nausea.',
    },
    'callDoctorIf': [
      {
        'ur': 'پیٹ میں شدید مروڑ، قے میں خون، یا نگلتے وقت سینے میں جلن۔',
        'en': 'Severe stomach cramps, vomiting blood, or chest pain when swallowing.',
      },
    ],
    'reviewed': false,
  },
];
