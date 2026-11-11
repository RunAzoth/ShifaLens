import 'dart:convert';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/services/prescription_reader.dart';

class MockPrescriptionReader implements PrescriptionReader {
  int demoIndex;
  final Duration delay;

  MockPrescriptionReader({
    this.demoIndex = 0,
    this.delay = const Duration(milliseconds: 850),
  });

  static const List<String> _assetPaths = [
    'assets/demo/cached/rx1_infection.json',
    'assets/demo/cached/rx2_chronic.json',
    'assets/demo/cached/rx3_duplicate.json',
  ];

  @override
  Future<Prescription> read(Uint8List jpeg) async {
    await Future<void>.delayed(delay);

    int idx = demoIndex.clamp(0, 2);
    if (jpeg.length >= 3) {
      final header = String.fromCharCodes(jpeg.sublist(0, 3));
      if (header == 'RX1') idx = 0;
      if (header == 'RX2') idx = 1;
      if (header == 'RX3') idx = 2;
    }

    return loadCachedPrescription(idx);
  }

  static Future<Prescription> loadCachedPrescription(int index) async {
    final safeIdx = index.clamp(0, 2);
    try {
      final raw = await rootBundle.loadString(_assetPaths[safeIdx]);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Prescription.fromJson(map);
    } catch (_) {
      return Prescription.fromJson(_fallbackPrescriptions[safeIdx]);
    }
  }

  static final List<Map<String, dynamic>> _fallbackPrescriptions = [
    {
      'id': 'rx_demo_1',
      'createdAt': '2026-11-11T08:00:00.000Z',
      'synthetic': true,
      'lines': [
        {
          'id': 'rx1_line_1',
          'rawText': 'Tab. Augmentin 625 mg 1+0+1 x 5 days',
          'brandName': 'Augmentin',
          'genericName': 'amoxicillin + clavulanic acid',
          'strength': '625 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+0+1',
          'timingNote': 'after meals',
          'durationDays': 5,
          'fieldConfidence': {
            'name': 0.96,
            'strength': 0.95,
            'frequency': 0.97,
            'duration': 0.94,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 0,
        },
        {
          'id': 'rx1_line_2',
          'rawText': 'Tab. Panadol 500 mg 1+1+1 x 3 days',
          'brandName': 'Panadol',
          'genericName': 'paracetamol',
          'strength': '500 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+1+1',
          'timingNote': 'after meals',
          'durationDays': 3,
          'fieldConfidence': {
            'name': 0.98,
            'strength': 0.96,
            'frequency': 0.97,
            'duration': 0.95,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 1,
        },
        {
          'id': 'rx1_line_3',
          'rawText': 'Cap. Risek 20 mg 1+0+0 before breakfast x 14 days',
          'brandName': 'Risek',
          'genericName': 'omeprazole',
          'strength': '20 mg',
          'form': 'Capsule',
          'frequencyRaw': '1+0+0',
          'timingNote': 'before breakfast',
          'durationDays': 14,
          'fieldConfidence': {
            'name': 0.94,
            'strength': 0.93,
            'frequency': 0.96,
            'duration': 0.92,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 2,
        },
        {
          'id': 'rx1_line_4',
          'rawText': 'Tab. ????? 1+0+1',
          'brandName': null,
          'genericName': null,
          'strength': null,
          'form': 'Tablet',
          'frequencyRaw': '1+0+1',
          'timingNote': null,
          'durationDays': null,
          'fieldConfidence': {
            'name': 0.18,
            'strength': 0.12,
            'frequency': 0.85,
            'duration': 0.10,
          },
          'needsPharmacist': true,
          'confirmed': false,
          'isManual': false,
          'identityIndex': 3,
        },
      ],
    },
    {
      'id': 'rx_demo_2',
      'createdAt': '2026-11-11T08:05:00.000Z',
      'synthetic': true,
      'lines': [
        {
          'id': 'rx2_line_1',
          'rawText': 'Tab. Glucophage 500 mg 1+0+1 with meals x 30 days',
          'brandName': 'Glucophage',
          'genericName': 'metformin',
          'strength': '500 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+0+1',
          'timingNote': 'with meals',
          'durationDays': 30,
          'fieldConfidence': {
            'name': 0.96,
            'strength': 0.95,
            'frequency': 0.97,
            'duration': 0.95,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 0,
        },
        {
          'id': 'rx2_line_2',
          'rawText': 'Tab. Norvasc 5 mg 1+0+0 x 30 days',
          'brandName': 'Norvasc',
          'genericName': 'amlodipine',
          'strength': '5 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+0+0',
          'timingNote': 'morning',
          'durationDays': 30,
          'fieldConfidence': {
            'name': 0.95,
            'strength': 0.94,
            'frequency': 0.96,
            'duration': 0.95,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 1,
        },
        {
          'id': 'rx2_line_3',
          'rawText': 'Tab. Lipitor 20 mg at bedtime x 30 days',
          'brandName': 'Lipitor',
          'genericName': 'atorvastatin',
          'strength': '20 mg',
          'form': 'Tablet',
          'frequencyRaw': 'HS',
          'timingNote': 'at bedtime',
          'durationDays': 30,
          'fieldConfidence': {
            'name': 0.94,
            'strength': 0.93,
            'frequency': 0.92,
            'duration': 0.95,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 2,
        },
      ],
    },
    {
      'id': 'rx_demo_3',
      'createdAt': '2026-11-11T08:10:00.000Z',
      'synthetic': true,
      'lines': [
        {
          'id': 'rx3_line_1',
          'rawText': 'Tab. Cipro 500 mg 1+0+1 x 7 days',
          'brandName': 'Cipro',
          'genericName': 'ciprofloxacin',
          'strength': '500 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+0+1',
          'timingNote': 'separate from dairy and iron',
          'durationDays': 7,
          'fieldConfidence': {
            'name': 0.95,
            'strength': 0.95,
            'frequency': 0.96,
            'duration': 0.93,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 0,
        },
        {
          'id': 'rx3_line_2',
          'rawText': 'Tab. Ferrous sulfate 200 mg 1+0+0 x 30 days',
          'brandName': 'Ferrous sulfate',
          'genericName': 'ferrous sulfate',
          'strength': '200 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+0+0',
          'timingNote': 'empty stomach or after lunch',
          'durationDays': 30,
          'fieldConfidence': {
            'name': 0.92,
            'strength': 0.93,
            'frequency': 0.95,
            'duration': 0.94,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 1,
        },
        {
          'id': 'rx3_line_3',
          'rawText': 'Tab. Panadol 500 mg 1+1+1',
          'brandName': 'Panadol',
          'genericName': 'paracetamol',
          'strength': '500 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+1+1',
          'timingNote': 'after meals',
          'durationDays': 5,
          'fieldConfidence': {
            'name': 0.97,
            'strength': 0.96,
            'frequency': 0.96,
            'duration': 0.85,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 2,
        },
        {
          'id': 'rx3_line_4',
          'rawText': 'Tab. Calpol 500 mg 1+1+1',
          'brandName': 'Calpol',
          'genericName': 'paracetamol',
          'strength': '500 mg',
          'form': 'Tablet',
          'frequencyRaw': '1+1+1',
          'timingNote': 'after meals',
          'durationDays': 5,
          'fieldConfidence': {
            'name': 0.94,
            'strength': 0.95,
            'frequency': 0.96,
            'duration': 0.85,
          },
          'needsPharmacist': false,
          'confirmed': true,
          'isManual': false,
          'identityIndex': 3,
        },
      ],
    },
  ];
}
