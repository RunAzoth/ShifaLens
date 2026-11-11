import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../app/config.dart';
import '../app/providers.dart';
import '../core/models/models.dart';
import '../firebase_options.dart';
import '../ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (DefaultFirebaseOptions.isConfigured) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await FirebaseAuth.instance.signInAnonymously();
    } else {
      await Firebase.initializeApp();
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (_) {
    // Runs safely even when Firebase is not yet configured on the host machine
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith(_RealByDefaultConfigNotifier.new),
      ],
      child: const ShifaLensAiLabApp(),
    ),
  );
}

class _RealByDefaultConfigNotifier extends AppConfigNotifier {
  @override
  AppConfig build() => const AppConfig(
        mockReader: false,
        mockStrips: false,
        mockQA: false,
        mockVoice: false,
      );
}

class ShifaLensAiLabApp extends StatelessWidget {
  const ShifaLensAiLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShifaLens AI Lab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AiLabScreen(),
    );
  }
}

class AiLabScreen extends ConsumerStatefulWidget {
  const AiLabScreen({super.key});

  @override
  ConsumerState<AiLabScreen> createState() => _AiLabScreenState();
}

class _AiLabScreenState extends ConsumerState<AiLabScreen> {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final TextEditingController _qaController = TextEditingController(
    text: 'Augmentin کھانے کے ساتھ لینی ہے یا خالی پیٹ؟',
  );

  bool _busy = false;
  bool _isRecording = false;
  String _statusLog = 'Ready. Flip Mock/Real flags above or run any service test.';
  Uint8List? _selectedImageBytes;
  List<StripMatch> _stripMatches = const [];
  QAAnswer? _qaAnswer;
  String? _synthesizedFilePath;
  bool _ramadan = false;
  bool _ramadanApproved = false;

  @override
  void dispose() {
    _qaController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Uint8List _createSyntheticTestJpeg(String label) {
    final canvas = img.Image(width: 800, height: 400);
    img.fill(canvas, color: img.ColorRgb8(252, 250, 245));
    img.drawString(
      canvas,
      label,
      font: img.arial24,
      x: 28,
      y: 40,
      color: img.ColorRgb8(20, 20, 20),
    );
    return Uint8List.fromList(img.encodeJpg(canvas, quality: 85));
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _statusLog = 'Loaded photo (${bytes.length} bytes).';
      });
    } catch (e) {
      setState(() => _statusLog = 'Image picker error: $e');
    }
  }

  Future<void> _runPrescriptionReader() async {
    setState(() {
      _busy = true;
      _statusLog = 'Running PrescriptionReader ($kGeminiModel)...';
    });
    try {
      final demoIdx = ref.read(activeDemoRxIndexProvider);
      final bytes = _selectedImageBytes ??
          _createSyntheticTestJpeg(
            demoIdx == 0
                ? 'RX1: Tab Augmentin 625mg 1+0+1 x5d\nTab Panadol 500mg 1+1+1 x3d\nCap Risek 20mg 1+0+0 before breakfast x14d\nTab. ????? 1+0+1'
                : demoIdx == 1
                    ? 'RX2: Tab Glucophage 500mg 1+0+1 with meals x30d\nTab Norvasc 5mg 1+0+0 x30d\nTab Lipitor 20mg HS x30d'
                    : 'RX3: Tab Cipro 500mg 1+0+1 x7d\nTab Ferrous sulfate 200mg 1+0+0 x30d\nTab Panadol 500mg 1+1+1\nTab Calpol 500mg 1+1+1',
          );

      final reader = ref.read(prescriptionReaderProvider);
      final rx = await reader.read(bytes);
      ref.read(currentPrescriptionProvider.notifier).setPrescription(rx);

      final engine = ref.read(scheduleEngineProvider);
      final plan = engine.build(
        rx,
        ramadan: _ramadan,
        ramadanApproved: _ramadanApproved,
      );
      ref.read(currentPlanProvider.notifier).setPlan(plan);

      setState(() {
        _statusLog =
            'Read Rx ${rx.id}: ${plan.scheduled.length} scheduled, '
            '${plan.unscheduled.length} unscheduled (needs pharmacist), '
            '${plan.duplicates.length} duplicate alert(s).';
      });
    } catch (e) {
      setState(() => _statusLog = 'PrescriptionReader error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runStripMatcher() async {
    final rx = ref.read(currentPrescriptionProvider);
    final meds = rx?.lines ?? const <MedicineLine>[];
    setState(() {
      _busy = true;
      _statusLog = 'Running StripMatcher on 3 strip photos...';
    });
    try {
      final strips = <Uint8List>[
        _selectedImageBytes ??
            _createSyntheticTestJpeg('Augmentin 625mg Co-amoxiclav GSK'),
        _createSyntheticTestJpeg('Risek 40mg Omeprazole Capsules Getz'),
        _createSyntheticTestJpeg('Brufen 400mg Ibuprofen Tablets Abbott'),
      ];
      final matcher = ref.read(stripMatcherProvider);
      final matches = await matcher.match(strips, meds);
      setState(() {
        _stripMatches = matches;
        _statusLog = 'StripMatcher returned ${matches.length} result(s).';
      });
    } catch (e) {
      setState(() => _statusLog = 'StripMatcher error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runTextQA() async {
    var plan = ref.read(currentPlanProvider);
    if (plan == null) {
      await _runPrescriptionReader();
      plan = ref.read(currentPlanProvider);
    }
    if (plan == null) return;

    setState(() {
      _busy = true;
      _statusLog = 'Running grounded QAService...';
    });
    try {
      final qa = ref.read(qaServiceProvider);
      final answer = await qa.ask(text: _qaController.text, plan: plan);
      setState(() {
        _qaAnswer = answer;
        _statusLog =
            'Q&A complete (grounded=${answer.grounded}, escalate=${answer.escalateToPharmacist}).';
      });
    } catch (e) {
      setState(() => _statusLog = 'QAService error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _toggleAudioRecordingAndAsk() async {
    var plan = ref.read(currentPlanProvider);
    if (plan == null) {
      await _runPrescriptionReader();
      plan = ref.read(currentPlanProvider);
    }
    if (plan == null) return;

    try {
      if (!_isRecording) {
        final hasPerm = await _recorder.hasPermission();
        if (!hasPerm) {
          setState(() => _statusLog = 'Microphone permission not granted.');
          return;
        }
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/ailab_question.wav';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: path,
        );
        setState(() {
          _isRecording = true;
          _statusLog = 'Recording voice question in Urdu/English... Tap again to stop & send.';
        });
      } else {
        final path = await _recorder.stop();
        setState(() {
          _isRecording = false;
          _busy = true;
          _statusLog = 'Sending recorded voice question to QAService...';
        });
        if (path != null && await File(path).exists()) {
          final bytes = await File(path).readAsBytes();
          final qa = ref.read(qaServiceProvider);
          final answer = await qa.ask(audioBytes: bytes, plan: plan);
          setState(() {
            _qaAnswer = answer;
            _statusLog = 'Voice Q&A complete.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _statusLog = 'Audio recording error: $e';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _runVoiceService({required bool synthesizeFile}) async {
    var plan = ref.read(currentPlanProvider);
    if (plan == null) {
      await _runPrescriptionReader();
      plan = ref.read(currentPlanProvider);
    }
    if (plan == null) return;

    final voice = ref.read(voiceServiceProvider);
    final scriptUr = voice.describePlanUrdu(plan);
    setState(() {
      _busy = true;
      _statusLog = synthesizeFile
          ? 'Synthesizing Urdu plan audio to file...'
          : 'Speaking Urdu plan aloud...';
    });

    try {
      if (synthesizeFile) {
        final file = await voice.synthesizeToFile(scriptUr);
        final len = await file.length();
        setState(() {
          _synthesizedFilePath = '${file.path} ($len bytes)';
          _statusLog = 'Synthesized audio file ready for email attachment.';
        });
      } else {
        await voice.speak(
          Bilingual(ur: scriptUr, en: 'Daily medication schedule in Urdu.'),
          lang: Lang.ur,
        );
        setState(() => _statusLog = 'VoiceService.speak completed.');
      }
    } catch (e) {
      setState(() => _statusLog = 'VoiceService error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(appConfigProvider);
    final demoIdx = ref.watch(activeDemoRxIndexProvider);
    final rx = ref.watch(currentPrescriptionProvider);
    final plan = ref.watch(currentPlanProvider);
    final voice = ref.watch(voiceServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShifaLens AI Lab (Person A)'),
        actions: [
          TextButton.icon(
            onPressed: () {
              final allMock = cfg.mockReader &&
                  cfg.mockStrips &&
                  cfg.mockQA &&
                  cfg.mockVoice;
              ref.read(appConfigProvider.notifier).setConfig(
                    allMock
                        ? const AppConfig.allReal()
                        : const AppConfig.allMock(),
                  );
            },
            icon: const Icon(Icons.swap_horiz),
            label: Text(
              cfg.mockReader ? 'Switch All REAL' : 'Switch All MOCK',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '⚠️ AI-generated: verify with your pharmacist / اے آئی سے تیار کردہ: اپنے فارماسسٹ سے تصدیق کریں\n'
              'Prototype. Not a medical device. / پروٹوٹائپ۔ یہ طبی آلہ نہیں ہے۔',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text('mockReader: ${cfg.mockReader}'),
                selected: !cfg.mockReader,
                onSelected: (_) => ref
                    .read(appConfigProvider.notifier)
                    .update((c) => c.copyWith(mockReader: !c.mockReader)),
              ),
              FilterChip(
                label: Text('mockStrips: ${cfg.mockStrips}'),
                selected: !cfg.mockStrips,
                onSelected: (_) => ref
                    .read(appConfigProvider.notifier)
                    .update((c) => c.copyWith(mockStrips: !c.mockStrips)),
              ),
              FilterChip(
                label: Text('mockQA: ${cfg.mockQA}'),
                selected: !cfg.mockQA,
                onSelected: (_) => ref
                    .read(appConfigProvider.notifier)
                    .update((c) => c.copyWith(mockQA: !c.mockQA)),
              ),
              FilterChip(
                label: Text('mockVoice: ${cfg.mockVoice}'),
                selected: !cfg.mockVoice,
                onSelected: (_) => ref
                    .read(appConfigProvider.notifier)
                    .update((c) => c.copyWith(mockVoice: !c.mockVoice)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Demo Rx: '),
              const SizedBox(width: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Rx1 (Infection)')),
                  ButtonSegment(value: 1, label: Text('Rx2 (Chronic)')),
                  ButtonSegment(value: 2, label: Text('Rx3 (Duplicate)')),
                ],
                selected: {demoIdx},
                onSelectionChanged: (set) {
                  ref
                      .read(activeDemoRxIndexProvider.notifier)
                      .setIndex(set.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera Photo'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery Photo'),
              ),
              FilterChip(
                label: const Text('Ramadan Mode (Doctor Approved)'),
                selected: _ramadan && _ramadanApproved,
                onSelected: (v) {
                  setState(() {
                    _ramadan = v;
                    _ramadanApproved = v;
                  });
                },
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _runPrescriptionReader,
                icon: const Icon(Icons.document_scanner),
                label: const Text('1. Read Prescription & Build Plan'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _runStripMatcher,
                icon: const Icon(Icons.medication),
                label: const Text('2. Match 3 Medicine Strips'),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    _busy ? null : () => _runVoiceService(synthesizeFile: false),
                icon: const Icon(Icons.volume_up),
                label: const Text('3. Speak Urdu Plan'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _busy ? null : () => _runVoiceService(synthesizeFile: true),
                icon: const Icon(Icons.audio_file),
                label: const Text('4. Synthesize Audio File'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Status: $_statusLog',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          if (rx != null && plan != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DailyPlan (${plan.id}) — Scheduled (${plan.scheduled.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    for (final m in plan.scheduled)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          child: Text('${m.identityIndex}'),
                        ),
                        title: Text(
                          '${m.brandName ?? m.rawText} (${m.strength ?? "-"}) → ${m.genericName}',
                        ),
                        subtitle: Text(
                          'Freq: ${m.frequencyRaw} | Confidence: ${m.fieldConfidence}',
                        ),
                      ),
                    if (plan.unscheduled.isNotEmpty) ...[
                      const Divider(),
                      Text(
                        'Not Scheduled — Ask Your Pharmacist (${plan.unscheduled.length})',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      for (final u in plan.unscheduled)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(u.rawText),
                          subtitle: Text(
                            'needsPharmacist=${u.needsPharmacist} | conf=${u.fieldConfidence}',
                          ),
                        ),
                    ],
                    if (plan.duplicates.isNotEmpty) ...[
                      const Divider(),
                      for (final dup in plan.duplicates)
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.report_problem,
                            color: Colors.deepOrange,
                          ),
                          title: Text(dup.message.ur),
                          subtitle: Text(dup.message.en),
                        ),
                    ],
                    const Divider(),
                    Text(
                      'Deterministic Urdu Voice Script:',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      voice.describePlanUrdu(plan),
                      textDirection: TextDirection.rtl,
                    ),
                    if (_synthesizedFilePath != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Audio File: $_synthesizedFilePath',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_stripMatches.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'StripMatcher Results (${_stripMatches.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final s in _stripMatches)
                      ListTile(
                        dense: true,
                        title: Text(
                          'Strip #${s.imageIndex}: ${s.readText ?? "(unreadable)"}',
                        ),
                        subtitle: Text(
                          'Issue: ${s.issue.name} | Matched: ${s.matchedMedicineId ?? "none"} | Conf: ${s.confidence.toStringAsFixed(2)}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grounded Q&A (Text or Voice)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qaController,
                    decoration: const InputDecoration(
                      labelText: 'Ask in Urdu or English',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy ? null : _runTextQA,
                        icon: const Icon(Icons.question_answer),
                        label: const Text('Ask Grounded Q&A'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _toggleAudioRecordingAndAsk,
                        icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                        label: Text(
                          _isRecording ? 'Stop & Send Voice' : 'Record Voice Q&A',
                        ),
                      ),
                      ActionChip(
                        label: const Text('Test Dose Escalation'),
                        onPressed: () {
                          _qaController.text =
                              'Can I stop taking Augmentin after 2 days or skip a dose?';
                          _runTextQA();
                        },
                      ),
                      ActionChip(
                        label: const Text('Test Red-Flag Symptom'),
                        onPressed: () {
                          _qaController.text =
                              'مجھے سینے میں درد اور سانس لینے میں دشواری ہو رہی ہے';
                          _runTextQA();
                        },
                      ),
                    ],
                  ),
                  if (_qaAnswer != null) ...[
                    const Divider(height: 20),
                    Text(
                      _qaAnswer!.answer.ur,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_qaAnswer!.answer.en),
                    const SizedBox(height: 6),
                    Text(
                      'grounded: ${_qaAnswer!.grounded} | escalateToPharmacist: ${_qaAnswer!.escalateToPharmacist} | sources: ${_qaAnswer!.sources}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
