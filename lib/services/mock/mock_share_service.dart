import 'dart:io';

import '../../core/services/share_service.dart';

class MockShareService implements ShareService {
  @override
  Future<void> emailPlan({
    required String to,
    required List<File> attachments,
    required String subject,
    required String body,
  }) async {}
}
