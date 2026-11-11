import 'dart:io';

abstract class ShareService {
  Future<void> emailPlan({
    required String to,
    required List<File> attachments,
    required String subject,
    required String body,
  });
}
