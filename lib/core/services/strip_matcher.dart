import 'dart:typed_data';

import '../models/models.dart';

abstract class StripMatcher {
  Future<List<StripMatch>> match(
    List<Uint8List> strips,
    List<MedicineLine> meds,
  );
}
