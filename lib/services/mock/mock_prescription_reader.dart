import 'dart:typed_data';

import '../../core/models/models.dart';
import '../../core/services/prescription_reader.dart';

class MockPrescriptionReader implements PrescriptionReader {
  int demoIndex;

  MockPrescriptionReader({this.demoIndex = 0});

  @override
  Future<Prescription> read(Uint8List jpeg) async {
    return Prescription(
      id: 'rx_mock_1',
      createdAt: DateTime.now(),
      synthetic: true,
      lines: const [],
    );
  }
}
