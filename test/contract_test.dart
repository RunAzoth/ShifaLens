import 'package:flutter_test/flutter_test.dart';
import 'package:nuskha_saathi/app/config.dart';
import 'package:nuskha_saathi/core/models/models.dart';

void main() {
  test('Contract v1 models serialize and deserialize cleanly', () {
    const config = AppConfig();
    expect(config.mockReader, isTrue);
    expect(config.mockStrips, isTrue);
    expect(config.mockQA, isTrue);
    expect(config.mockVoice, isTrue);
    expect(config.mockKnowledge, isTrue);
    expect(config.mockRepo, isTrue);
    expect(config.mockReminders, isTrue);
    expect(config.mockShare, isTrue);

    const bi = Bilingual(ur: 'صبح', en: 'Morning');
    expect(Bilingual.fromJson(bi.toJson()), equals(bi));
  });
}
