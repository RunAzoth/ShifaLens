import '../models/models.dart';

abstract class KnowledgeService {
  Future<void> load();
  ({String? generic, bool ambiguous}) resolveBrand(String raw);
  List<FoodCard> foodCardsFor(String generic);
  SideEffectInfo? sideEffectsFor(String generic);
  List<DuplicateAlert> findDuplicates(List<MedicineLine> lines);
  Future<PlateGuide> plateGuide();
}
