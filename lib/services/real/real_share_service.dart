import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/share_service.dart';

class RealShareService implements ShareService {
  @override
  Future<void> emailPlan({
    required String to,
    required List<File> attachments,
    required String subject,
    required String body,
  }) async {
    final existingPaths = <String>[];
    for (final file in attachments) {
      try {
        if (await file.exists()) {
          existingPaths.add(file.path);
        }
      } catch (_) {}
    }

    // 1. Primary path: flutter_email_sender with PDF + audio attachments
    try {
      final email = Email(
        body: body,
        subject: subject,
        recipients: to.trim().isNotEmpty ? [to.trim()] : const [],
        attachmentPaths: existingPaths,
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
      return;
    } catch (_) {
      // 2. Fallback to share_plus if no email client is installed or on platform error
      try {
        final shareText =
            '${to.trim().isNotEmpty ? "To: ${to.trim()}\n" : ""}$subject\n\n$body';
        if (existingPaths.isNotEmpty) {
          final xFiles = existingPaths.map(XFile.new).toList();
          await SharePlus.instance.share(
            ShareParams(
              files: xFiles,
              subject: subject,
              text: shareText,
            ),
          );
        } else {
          await SharePlus.instance.share(
            ShareParams(
              subject: subject,
              text: shareText,
            ),
          );
        }
      } catch (_) {}
    }
  }
}
