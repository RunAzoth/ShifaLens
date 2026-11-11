import 'dart:typed_data';

import '../../core/models/models.dart';
import '../../core/services/knowledge_service.dart';

class MockKnowledgeService implements KnowledgeService {
  @override
  Future<void> load() async {}

  @override
  ({String? generic, bool ambiguous}) resolveBrand(String raw) {
    return (generic: null, ambiguous: false);
  }

  @override
  List<FoodCard> foodCardsFor(String generic) => const [];

  @override
  SideEffectInfo? sideEffectsFor(String generic) => null;

  @override
  List<DuplicateAlert> findDuplicates(List<MedicineLine> lines) => const [];

  @override
  Future<PlateGuide> plateGuide() async {
    return PlateGuide(
      title: const Bilingual(
        ur: 'متوازن غذا کی پلیٹ',
        en: 'Balanced Plate Guide',
      ),
      imageBytes: Uint8List(0),
      tips: const [],
    );
  }
}
