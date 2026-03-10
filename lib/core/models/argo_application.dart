class ArgoApplication {
  const ArgoApplication({
    required this.name,
    required this.project,
    required this.namespace,
    required this.cluster,
    required this.repoUrl,
    required this.path,
    required this.targetRevision,
    required this.syncStatus,
    required this.healthStatus,
    required this.operationPhase,
    required this.lastSyncedAt,
    required this.resources,
    required this.history,
  });

  factory ArgoApplication.fromJson(Map<String, dynamic> json) {
    final metadata = _map(json['metadata']);
    final spec = _map(json['spec']);
    final destination = _map(spec['destination']);
    final source = _sourceMap(spec);
    final status = _map(json['status']);
    final sync = _map(status['sync']);
    final health = _map(status['health']);
    final operationState = _map(status['operationState']);

    return ArgoApplication(
      name: _string(metadata['name'], fallback: 'Unknown'),
      project: _string(spec['project'], fallback: 'default'),
      namespace: _string(destination['namespace'], fallback: 'default'),
      cluster: _string(
        destination['server'],
        fallback: _string(destination['name'], fallback: 'in-cluster'),
      ),
      repoUrl: _string(source['repoURL'], fallback: 'Unknown'),
      path: _string(source['path'], fallback: '/'),
      targetRevision: _string(source['targetRevision'], fallback: 'HEAD'),
      syncStatus: _string(sync['status'], fallback: 'Unknown'),
      healthStatus: _string(health['status'], fallback: 'Unknown'),
      operationPhase: _string(
        operationState['phase'],
        fallback: status['operationState'] == null ? 'Idle' : 'Unknown',
      ),
      lastSyncedAt: _string(sync['reconciledAt']),
      resources: _list(status['resources'])
          .map((dynamic item) => ArgoResource.fromJson(_map(item)))
          .toList(growable: false),
      history: _list(status['history'])
          .map((dynamic item) => ArgoHistoryEntry.fromJson(_map(item)))
          .toList(growable: false),
    );
  }

  final String name;
  final String project;
  final String namespace;
  final String cluster;
  final String repoUrl;
  final String path;
  final String targetRevision;
  final String syncStatus;
  final String healthStatus;
  final String operationPhase;
  final String? lastSyncedAt;
  final List<ArgoResource> resources;
  final List<ArgoHistoryEntry> history;

  bool get isOutOfSync => syncStatus.toLowerCase() != 'synced';
  bool get isHealthy => healthStatus.toLowerCase() == 'healthy';
}

class ArgoResource {
  const ArgoResource({
    required this.kind,
    required this.name,
    required this.namespace,
    required this.group,
    required this.version,
    required this.status,
    required this.health,
  });

  factory ArgoResource.fromJson(Map<String, dynamic> json) {
    return ArgoResource(
      kind: _string(json['kind'], fallback: 'Resource'),
      name: _string(json['name'], fallback: 'Unknown'),
      namespace: _string(json['namespace'], fallback: '-'),
      group: _string(json['group'], fallback: ''),
      version: _string(json['version'], fallback: ''),
      status: _string(json['status'], fallback: 'Unknown'),
      health: _string(json['health'], fallback: 'Unknown'),
    );
  }

  final String kind;
  final String name;
  final String namespace;
  final String group;
  final String version;
  final String status;
  final String health;
}

class ArgoHistoryEntry {
  const ArgoHistoryEntry({
    required this.id,
    required this.revision,
    required this.deployedAt,
  });

  factory ArgoHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ArgoHistoryEntry(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      revision: _string(json['revision'], fallback: '-'),
      deployedAt: _string(json['deployedAt'], fallback: '-'),
    );
  }

  final int id;
  final String revision;
  final String deployedAt;
}

Map<String, dynamic> _sourceMap(Map<String, dynamic> spec) {
  final source = _map(spec['source']);
  if (source.isNotEmpty) {
    return source;
  }

  final sources = _list(spec['sources']);
  if (sources.isNotEmpty) {
    return _map(sources.first);
  }

  return const <String, dynamic>{};
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic val) => MapEntry(key.toString(), val),
    );
  }
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  if (value is List) {
    return List<dynamic>.from(value);
  }
  return const <dynamic>[];
}

String _string(dynamic value, {String? fallback}) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  if (value != null) {
    final stringValue = value.toString();
    if (stringValue.trim().isNotEmpty) {
      return stringValue;
    }
  }
  return fallback ?? '';
}
