import 'package:argocd_flutter/core/utils/diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeDiffLines (Myers diff)', () {
    test('identical inputs produce only unchanged lines', () {
      final lines = computeDiffLines(
        <String>['a', 'b', 'c'],
        <String>['a', 'b', 'c'],
      );
      expect(lines.length, 3);
      expect(lines.every((l) => l.kind == DiffLineKind.unchanged), isTrue);
    });

    test('empty inputs produce empty diff', () {
      final lines = computeDiffLines(<String>[], <String>[]);
      expect(lines, isEmpty);
    });

    test('all lines added', () {
      final lines = computeDiffLines(<String>[], <String>['x', 'y']);
      expect(lines.length, 2);
      expect(lines.every((l) => l.kind == DiffLineKind.added), isTrue);
      expect(lines[0].text, 'x');
      expect(lines[1].text, 'y');
    });

    test('all lines removed', () {
      final lines = computeDiffLines(<String>['x', 'y'], <String>[]);
      expect(lines.length, 2);
      expect(lines.every((l) => l.kind == DiffLineKind.removed), isTrue);
    });

    test('insertion in the middle is detected correctly', () {
      final lines = computeDiffLines(
        <String>['a', 'c'],
        <String>['a', 'b', 'c'],
      );
      // Should be: unchanged 'a', added 'b', unchanged 'c'
      expect(lines.length, 3);
      expect(lines[0].kind, DiffLineKind.unchanged);
      expect(lines[0].text, 'a');
      expect(lines[1].kind, DiffLineKind.added);
      expect(lines[1].text, 'b');
      expect(lines[2].kind, DiffLineKind.unchanged);
      expect(lines[2].text, 'c');
    });

    test('deletion in the middle is detected correctly', () {
      final lines = computeDiffLines(
        <String>['a', 'b', 'c'],
        <String>['a', 'c'],
      );
      // Should be: unchanged 'a', removed 'b', unchanged 'c'
      expect(lines.length, 3);
      expect(lines[0].kind, DiffLineKind.unchanged);
      expect(lines[1].kind, DiffLineKind.removed);
      expect(lines[1].text, 'b');
      expect(lines[2].kind, DiffLineKind.unchanged);
    });

    test('modification shows as remove + add', () {
      final lines = computeDiffLines(
        <String>['a', 'old', 'c'],
        <String>['a', 'new', 'c'],
      );
      expect(lines.length, 4);
      expect(lines[0].kind, DiffLineKind.unchanged);
      expect(lines[1].kind, DiffLineKind.removed);
      expect(lines[1].text, 'old');
      expect(lines[2].kind, DiffLineKind.added);
      expect(lines[2].text, 'new');
      expect(lines[3].kind, DiffLineKind.unchanged);
    });

    test('block insertion does not misalign subsequent lines', () {
      final old = <String>['header', 'footer'];
      final updated = <String>['header', 'line1', 'line2', 'line3', 'footer'];
      final lines = computeDiffLines(old, updated);

      // 'header' unchanged, 3 added lines, 'footer' unchanged
      final unchanged =
          lines.where((l) => l.kind == DiffLineKind.unchanged).toList();
      final added =
          lines.where((l) => l.kind == DiffLineKind.added).toList();

      expect(unchanged.length, 2);
      expect(unchanged[0].text, 'header');
      expect(unchanged[1].text, 'footer');
      expect(added.length, 3);
    });
  });

  group('computeDiff (with context collapsing)', () {
    test('collapses long unchanged regions', () {
      final old = <String>[
        for (var i = 0; i < 20; i++) 'line $i',
      ];
      final updated = List<String>.of(old)..[10] = 'CHANGED';
      final sections = computeDiff(old, updated, contextLines: 3);

      // Should have: collapsed, hunk, collapsed
      expect(sections.length, 3);
      expect(sections[0].isCollapsed, isTrue);
      expect(sections[1].isCollapsed, isFalse);
      expect(sections[2].isCollapsed, isTrue);

      // The hunk should contain context + change
      final hunk = sections[1].lines;
      final changed =
          hunk.where((l) => l.kind != DiffLineKind.unchanged).toList();
      expect(changed.length, 2); // removed 'line 10' + added 'CHANGED'
    });

    test('merges nearby hunks', () {
      final old = <String>[
        for (var i = 0; i < 20; i++) 'line $i',
      ];
      // Changes at index 5 and 8 — close enough to merge with context=3
      final updated = List<String>.of(old)
        ..[5] = 'CHANGED_A'
        ..[8] = 'CHANGED_B';
      final sections = computeDiff(old, updated, contextLines: 3);

      // Should be: collapsed, one merged hunk, collapsed
      expect(sections.length, 3);
      expect(sections[0].isCollapsed, isTrue);
      expect(sections[1].isCollapsed, isFalse);
      expect(sections[2].isCollapsed, isTrue);
    });

    test('no changes produces single collapsed section', () {
      final lines = <String>['a', 'b', 'c'];
      final sections = computeDiff(lines, lines);
      expect(sections.length, 1);
      expect(sections[0].isCollapsed, isTrue);
      expect(sections[0].collapsedCount, 3);
    });

    test('all different produces single hunk with no collapsed sections', () {
      final sections = computeDiff(
        <String>['a', 'b'],
        <String>['x', 'y'],
        contextLines: 3,
      );
      // Everything changed, so one hunk, no collapsed
      expect(sections.every((s) => !s.isCollapsed), isTrue);
    });
  });
}
