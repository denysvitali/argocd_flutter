enum HealthEventKind {
  degraded,
  recovered,
  drifted,
  synced,
  failed,
  operationFailed,
}

class HealthEvent {
  const HealthEvent({
    required this.applicationName,
    required this.kind,
    required this.previousValue,
    required this.currentValue,
    required this.detectedAt,
  });

  final String applicationName;
  final HealthEventKind kind;
  final String previousValue;
  final String currentValue;
  final DateTime detectedAt;

  String get summary {
    return switch (kind) {
      HealthEventKind.degraded =>
        '$applicationName is now Degraded (was $previousValue)',
      HealthEventKind.recovered =>
        '$applicationName recovered to Healthy',
      HealthEventKind.drifted =>
        '$applicationName drifted OutOfSync',
      HealthEventKind.synced =>
        '$applicationName is now Synced',
      HealthEventKind.failed =>
        '$applicationName operation failed',
      HealthEventKind.operationFailed =>
        '$applicationName sync operation failed',
    };
  }

  bool get isNegative =>
      kind == HealthEventKind.degraded ||
      kind == HealthEventKind.drifted ||
      kind == HealthEventKind.failed ||
      kind == HealthEventKind.operationFailed;
}
