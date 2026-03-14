/// Defensive JSON parsing helpers used across all model factories.

/// Safely extracts a `Map<String, dynamic>` from [value].
///
/// Returns the map directly if already `Map<String, dynamic>`, converts
/// `Map<dynamic, dynamic>` keys to strings, or returns an empty map for
/// null/non-map values.
Map<String, dynamic> parseMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) =>
          MapEntry<String, dynamic>(key.toString(), val),
    );
  }
  return <String, dynamic>{};
}

/// Safely extracts a `List<dynamic>` from [value].
///
/// Returns the list directly if already `List<dynamic>`, converts other
/// list types, or returns an empty list for null/non-list values.
List<dynamic> parseList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  if (value is List) {
    return value.toList();
  }
  return <dynamic>[];
}

/// Safely extracts a string from [value].
///
/// Returns the string if non-empty (after trimming). Returns [fallback]
/// when the value is null, empty, or whitespace-only. Converts non-string
/// values via `toString()`.
String parseString(dynamic value, {String? fallback}) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  if (value != null) {
    final converted = value.toString();
    if (converted.trim().isNotEmpty) {
      return converted;
    }
  }
  return fallback ?? '';
}
