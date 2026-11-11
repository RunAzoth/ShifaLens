import 'dart:typed_data';

import '../../core/models/models.dart';
import '../../core/services/strip_matcher.dart';

class MockStripMatcher implements StripMatcher {
  @override
  Future<List<StripMatch>> match(
    List<Uint8List> strips,
    List<MedicineLine> meds,
  ) async {
    return const [];
  }
}
