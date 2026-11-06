import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatTimestampWithRelative', () {
    test('combines relative and absolute UTC time', () {
      // appClock is pinned to 2026-04-10T10:00:00Z by flutter_test_config.
      expect(
        formatTimestampWithRelative('2026-04-10T08:40:00Z'),
        '1 hour ago · 2026-04-10 08:40 UTC',
      );
    });

    test('returns raw input when unparseable', () {
      expect(formatTimestampWithRelative('not-a-date'), 'not-a-date');
    });

    test('shows only absolute time for future timestamps', () {
      expect(
        formatTimestampWithRelative('2027-01-02T03:04:00Z'),
        '2027-01-02 03:04 UTC',
      );
    });
  });
}
