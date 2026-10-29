import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/utils/formatters.dart';

void main() {
  group('diary date formatting', () {
    test('labels today and yesterday by calendar day', () {
      final now = DateTime(2026, 10, 29, 18, 30);

      expect(formatDiaryDay(DateTime(2026, 10, 29, 8), now: now), 'Hari ini');
      expect(
        formatDiaryDay(DateTime(2026, 10, 28, 23, 59), now: now),
        'Kemarin',
      );
    });

    test('formats older days with Indonesian month abbreviations', () {
      expect(
        formatDiaryDay(DateTime(2026, 10, 27), now: DateTime(2026, 10, 29)),
        '27 Okt 2026',
      );
      expect(
        formatDiaryDay(DateTime(2025, 1, 3), now: DateTime(2026, 10, 29)),
        '3 Jan 2025',
      );
    });

    test('formats local clock time with a dot separator', () {
      expect(formatClockTime(DateTime(2026, 10, 29, 8, 5)), '08.05');
      expect(formatClockTime(DateTime(2026, 10, 29, 19, 30)), '19.30');
    });
  });
}
