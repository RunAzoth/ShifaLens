import 'dart:typed_data';

import '../models/models.dart';

abstract class PrescriptionReader {
  Future<Prescription> read(Uint8List jpeg);
}
