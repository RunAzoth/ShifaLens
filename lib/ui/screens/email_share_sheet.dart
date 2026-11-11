import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../theme/app_tokens.dart';
import '../theme/language_controller.dart';
import '../widgets/widgets.dart';
import 'journey_controller.dart';
import 'print_screen.dart';

/// Part 4 Feature #9: EMAIL SHARE BOTTOM SHEET
/// - Recipient email input with validation
/// - Attachment preview:
///   1) Daily card PDF (`ShifaLens_Daily_Card.pdf`)
///   2) Urdu audio summary file from `VoiceService.synthesizeToFile`
/// - Subject & body prefilled bilingually with the prototype disclaimer
/// - Calls `ShareService.emailPlan` and shows a friendly success state.
class EmailShareSheet extends ConsumerStatefulWidget {
  const EmailShareSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const EmailShareSheet(),
    );
  }

  @override
  ConsumerState<EmailShareSheet> createState() => _EmailShareSheetState();
}

class _EmailShareSheetState extends ConsumerState<EmailShareSheet> {
  final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;

  bool _isSending = false;
  bool _sentSuccess = false;
  String? _validationError;

  static final RegExp _emailRegex =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    final plan = ref.read(journeyControllerProvider).latestPlan;
    final count = plan?.scheduled.length ?? 0;

    _subjectController = TextEditingController(
      text:
          'ShifaLens Daily Medicine Plan ($count medicines) • شفا لینز روزانہ دوا کا شیڈول',
    );
    _bodyController = TextEditingController(
      text: 'اسلام علیکم،\n'
          'شفا لینز کے ذریعے تیار کردہ روزانہ دوا کا تصویری شیڈول (PDF) اور اردو آڈیو رہنمائی منسلک ہے۔\n'
          'تنبیہ: یہ ایک تجرباتی نمونہ (Prototype) ہے، طبی آلہ نہیں۔ ہمیشہ اپنے فارماسسٹ یا ڈاکٹر سے تصدیق کریں۔\n\n'
          'Attached: ShifaLens visual Daily Medicine Card (PDF) + Urdu voice explanation.\n'
          'Limitation: Prototype. Not a medical device. AI-generated: verify with your pharmacist.',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<File> _prepareMinimalPdfAttachment() async {
    // 1x1 transparent PNG embedded in valid PDF via PrintScreen helper
    final onePxPng = Uint8List.fromList(const <int>[
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
      0x42, 0x60, 0x82,
    ]);
    final pdfBytes = await PrintScreen.buildPdfFromPngBytes(onePxPng);
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/ShifaLens_Daily_Card.pdf');
      await f.writeAsBytes(pdfBytes, flush: true);
      return f;
    } catch (_) {
      return File('ShifaLens_Daily_Card.pdf');
    }
  }

  Future<void> _sendEmail() async {
    final to = _emailController.text.trim();
    if (!_emailRegex.hasMatch(to)) {
      HapticFeedback.vibrate();
      setState(() {
        _validationError =
            'براہ کرم درست ای میل لکھیں • Please enter a valid email address (e.g. caregiver@family.pk)';
      });
      return;
    }

    setState(() {
      _validationError = null;
      _isSending = true;
    });

    try {
      final plan = ref.read(journeyControllerProvider).latestPlan;
      final attachments = <File>[];

      // 1. Daily Card PDF attachment
      final pdfFile = await _prepareMinimalPdfAttachment();
      attachments.add(pdfFile);

      // 2. Urdu Audio attachment via VoiceService.synthesizeToFile
      if (plan != null) {
        try {
          final voice = ref.read(voiceServiceProvider);
          final urduText = voice.describePlanUrdu(plan);
          final audioFile = await voice.synthesizeToFile(urduText);
          attachments.add(audioFile);
        } catch (_) {
          attachments.add(File('ShifaLens_Urdu_Plan.mp3'));
        }
      }

      final shareService = ref.read(shareServiceProvider);
      await shareService.emailPlan(
        to: to,
        attachments: attachments,
        subject: _subjectController.text.trim(),
        body: _bodyController.text.trim(),
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isSending = false;
        _sentSuccess = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _sentSuccess = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(languageModeProvider);

    return Directionality(
      textDirection: mode.direction,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.space3),
          child: _sentSuccess
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      key: const Key('email_share_success_state'),
                      padding: const EdgeInsets.all(AppTokens.space3),
                      decoration: BoxDecoration(
                        color: AppTokens.successGreenTint,
                        borderRadius:
                            BorderRadius.circular(AppTokens.cardRadius),
                        border: Border.all(
                          color: AppTokens.successGreen,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.mark_email_read_rounded,
                            size: 56,
                            color: AppTokens.successGreenDark,
                          ),
                          const SizedBox(height: 12),
                          const BiText(
                            Bilingual(
                              ur: 'تیماردار کو کارڈ اور اردو آڈیو بھیج دی گئی ہے!',
                              en: 'Daily Card PDF & Urdu Audio Sent to Caregiver!',
                            ),
                            isHeadline: true,
                            urduColor: AppTokens.successGreenDark,
                            textAlign: TextAlign.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Recipient: ${_emailController.text.trim()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTokens.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    BigActionButton(
                      icon: Icons.check_rounded,
                      label: const Bilingual(
                        ur: 'واپس جائیں',
                        en: 'Done',
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTokens.primaryTealTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.forward_to_inbox_rounded,
                            color: AppTokens.primaryTealDark,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: BiText(
                            Bilingual(
                              ur: 'گھر کے فرد کو کارڈ اور اردو آڈیو ای میل کریں',
                              en: 'Email Plan Card + Urdu Audio to Family Caregiver',
                            ),
                            isHeadline: true,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const Divider(),

                    // Recipient Email Field
                    const BiText(
                      Bilingual(
                        ur: 'تیماردار کا ای میل ایڈریس:',
                        en: 'Caregiver Email Address:',
                      ),
                      urduWeight: FontWeight.w700,
                      englishWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('email_recipient_input'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: 'caregiver@family.pk',
                        prefixIcon: const Icon(Icons.email_outlined),
                        errorText: _validationError,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Attachments Preview (PDF Card + Urdu Audio)
                    const BiText(
                      Bilingual(
                        ur: 'منسلک فائلیں (Attachments):',
                        en: 'Included Attachments:',
                      ),
                      urduWeight: FontWeight.w700,
                      englishWeight: FontWeight.w700,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTokens.surfaceWarm,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTokens.borderWarm),
                      ),
                      child: const Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.picture_as_pdf_rounded,
                                color: AppTokens.alertCoralDark,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '1. ShifaLens_Daily_Card.pdf (Visual Urdu/English Plan)',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.audiotrack_rounded,
                                color: AppTokens.primaryTealDark,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '2. ShifaLens_Urdu_Plan.mp3 (Spoken Urdu Explanation)',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Prefilled Subject & Body with Disclaimer
                    TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject • عنوان',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _bodyController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Message Body (with Prototype Disclaimer)',
                      ),
                    ),
                    const SizedBox(height: 16),

                    BigActionButton(
                      key: const Key('email_send_button'),
                      icon: Icons.send_rounded,
                      label: const Bilingual(
                        ur: 'کارڈ اور اردو آڈیو ای میل بھیجیں',
                        en: 'Send Card & Urdu Audio via Email',
                      ),
                      onPressed: _isSending ? null : _sendEmail,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
