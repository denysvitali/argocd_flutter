import 'package:argocd_flutter/core/utils/json_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMap', () {
    test('returns map when given Map<String, dynamic>', () {
      final map = <String, dynamic>{'key': 'value'};
      expect(parseMap(map), same(map));
    });

    test('converts Map<dynamic, dynamic> to Map<String, dynamic>', () {
      final map = <dynamic, dynamic>{'key': 'value'};
      final result = parseMap(map);
      expect(result['key'], 'value');
    });

    test('returns empty map for null', () {
      expect(parseMap(null), isEmpty);
    });

    test('returns empty map for non-map value', () {
      expect(parseMap('not a map'), isEmpty);
      expect(parseMap(42), isEmpty);
    });
  });

  group('parseList', () {
    test('returns list when given List<dynamic>', () {
      final list = <dynamic>[1, 2, 3];
      expect(parseList(list), same(list));
    });

    test('converts List<int> to List<dynamic>', () {
      final list = <int>[1, 2, 3];
      final result = parseList(list);
      expect(result, [1, 2, 3]);
    });

    test('returns empty list for null', () {
      expect(parseList(null), isEmpty);
    });

    test('returns empty list for non-list value', () {
      expect(parseList('not a list'), isEmpty);
    });
  });

  group('parseString', () {
    test('returns string when given non-empty string', () {
      expect(parseString('hello'), 'hello');
    });

    test('returns fallback for null', () {
      expect(parseString(null, fallback: 'default'), 'default');
    });

    test('returns empty string when null without fallback', () {
      expect(parseString(null), '');
    });

    test('returns fallback for empty string', () {
      expect(parseString('', fallback: 'default'), 'default');
    });

    test('returns fallback for whitespace-only string', () {
      expect(parseString('   ', fallback: 'default'), 'default');
    });

    test('converts non-string value to string', () {
      expect(parseString(42), '42');
    });
  });
}
