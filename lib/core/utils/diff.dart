/// Myers diff algorithm with unified output and context collapsing.
///
/// Produces minimal edit scripts (like `git diff`) so that insertions and
/// deletions are properly grouped rather than compared positionally.

/// The kind of change a diff line represents.
enum DiffLineKind { unchanged, added, removed }

/// A single line in a unified diff.
class DiffLine {
  const DiffLine({required this.prefix, required this.text, required this.kind});

  final String prefix;
  final String text;
  final DiffLineKind kind;
}

/// A section of a diff — either a hunk of changes with surrounding context,
/// or a collapsed region of unchanged lines.
class DiffSection {
  const DiffSection.hunk(this.lines)
      : collapsedCount = 0,
        isCollapsed = false;

  const DiffSection.collapsed(this.collapsedCount)
      : lines = const <DiffLine>[],
        isCollapsed = true;

  final List<DiffLine> lines;
  final int collapsedCount;
  final bool isCollapsed;
}

/// Computes a unified diff between [oldLines] and [newLines] using the
/// Myers diff algorithm, then groups the result into sections with
/// [contextLines] of surrounding unchanged context (default 3).
///
/// Unchanged regions longer than `2 * contextLines` between hunks are
/// collapsed into [DiffSection.collapsed] entries.
List<DiffSection> computeDiff(
  List<String> oldLines,
  List<String> newLines, {
  int contextLines = 3,
}) {
  final rawDiff = _myersDiff(oldLines, newLines);
  if (rawDiff.isEmpty) {
    return const <DiffSection>[];
  }
  return _collapseIntoSections(rawDiff, contextLines: contextLines);
}

/// Flat list of diff lines (no collapsing). Useful for the manifest viewer
/// which handles its own display logic.
List<DiffLine> computeDiffLines(
  List<String> oldLines,
  List<String> newLines,
) {
  return _myersDiff(oldLines, newLines);
}

// ---------------------------------------------------------------------------
// Myers diff implementation
// ---------------------------------------------------------------------------

List<DiffLine> _myersDiff(List<String> oldLines, List<String> newLines) {
  final n = oldLines.length;
  final m = newLines.length;
  final max = n + m;

  if (max == 0) {
    return const <DiffLine>[];
  }

  // v[k] = furthest reaching x on diagonal k.
  // Offset by max so that negative indices work: v[k + max].
  final v = List<int>.filled(2 * max + 1, 0);
  final trace = <List<int>>[];

  // Forward pass — find shortest edit script length D.
  var found = false;
  for (var d = 0; d <= max && !found; d++) {
    for (var k = -d; k <= d; k += 2) {
      final idx = k + max;
      int x;
      if (k == -d || (k != d && v[idx - 1] < v[idx + 1])) {
        x = v[idx + 1]; // move down (insert from diagonal k+1)
      } else {
        x = v[idx - 1] + 1; // move right (delete from diagonal k-1)
      }
      var y = x - k;

      // Follow diagonal (unchanged lines).
      while (x < n && y < m && oldLines[x] == newLines[y]) {
        x++;
        y++;
      }
      v[idx] = x;
      if (x >= n && y >= m) {
        found = true;
      }
    }
    // Snapshot v AFTER processing step d.
    trace.add(List<int>.of(v));
    if (found) break;
  }

  // Backtrack through the trace to recover the edit script.
  // trace[d] holds v after step d completed. D = trace.length - 1.
  final edits = <DiffLine>[];
  var x = n;
  var y = m;

  for (var d = trace.length - 1; d > 0; d--) {
    final prev = trace[d - 1]; // v after step d-1
    final k = x - y;
    final idx = k + max;

    // Determine which diagonal we came from at step d-1.
    int prevK;
    if (k == -d || (k != d && prev[idx - 1] < prev[idx + 1])) {
      prevK = k + 1; // came from insert (diagonal k+1 -> k via down move)
    } else {
      prevK = k - 1; // came from delete (diagonal k-1 -> k via right move)
    }

    final prevEndX = prev[prevK + max];
    final prevEndY = prevEndX - prevK;

    // Diagonal (unchanged) portion — walk backward from (x, y).
    while (x > prevEndX + (prevK < k ? 1 : 0) &&
        y > prevEndY + (prevK > k ? 1 : 0)) {
      x--;
      y--;
      edits.add(DiffLine(
        prefix: ' ',
        text: oldLines[x],
        kind: DiffLineKind.unchanged,
      ));
    }

    // The edit itself.
    if (prevK > k) {
      // Insert (moved down from k+1 to k).
      y--;
      edits.add(DiffLine(
        prefix: '+',
        text: newLines[y],
        kind: DiffLineKind.added,
      ));
    } else {
      // Delete (moved right from k-1 to k).
      x--;
      edits.add(DiffLine(
        prefix: '-',
        text: oldLines[x],
        kind: DiffLineKind.removed,
      ));
    }
  }

  // Any remaining diagonal at the start (step d=0 has no edit, only diagonal).
  while (x > 0 && y > 0) {
    x--;
    y--;
    edits.add(DiffLine(
      prefix: ' ',
      text: oldLines[x],
      kind: DiffLineKind.unchanged,
    ));
  }

  return edits.reversed.toList();
}

// ---------------------------------------------------------------------------
// Context collapsing
// ---------------------------------------------------------------------------

List<DiffSection> _collapseIntoSections(
  List<DiffLine> lines, {
  required int contextLines,
}) {
  // Find indices of all changed lines.
  final changedIndices = <int>[
    for (var i = 0; i < lines.length; i++)
      if (lines[i].kind != DiffLineKind.unchanged) i,
  ];

  if (changedIndices.isEmpty) {
    // Everything is unchanged — collapse it all.
    return <DiffSection>[DiffSection.collapsed(lines.length)];
  }

  // Build ranges of lines to show (changed lines + context).
  final ranges = <(int, int)>[];
  for (final ci in changedIndices) {
    final start = (ci - contextLines).clamp(0, lines.length);
    final end = (ci + contextLines + 1).clamp(0, lines.length);
    if (ranges.isNotEmpty && ranges.last.$2 >= start) {
      // Merge overlapping ranges.
      ranges[ranges.length - 1] = (ranges.last.$1, end);
    } else {
      ranges.add((start, end));
    }
  }

  final sections = <DiffSection>[];
  var cursor = 0;

  for (final (start, end) in ranges) {
    if (start > cursor) {
      sections.add(DiffSection.collapsed(start - cursor));
    }
    sections.add(DiffSection.hunk(lines.sublist(start, end)));
    cursor = end;
  }

  if (cursor < lines.length) {
    sections.add(DiffSection.collapsed(lines.length - cursor));
  }

  return sections;
}
