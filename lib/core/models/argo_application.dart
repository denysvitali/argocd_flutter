import 'package:argocd_flutter/core/utils/json_parsing.dart';

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
    required this.operationMessage,
    required this.lastSyncedAt,
    required this.resources,
    required this.history,
  });

  factory ArgoApplication.fromJson(Map<String, dynamic> json) {
    final metadata = parseMap(json['metadata']);
    final spec = parseMap(json['spec']);
    final destination = parseMap(spec['destination']);
    final source = _sourceMap(spec);
    final status = parseMap(json['status']);
    final sync = parseMap(status['sync']);
    final health = parseMap(status['health']);
    final operationState = parseMap(status['operationState']);

    return ArgoApplication(
      name: parseString(metadata['name'], fallback: 'Unknown'),
      project: parseString(spec['project'], fallback: 'default'),
      namespace: parseString(destination['namespace'], fallback: 'default'),
      cluster: parseString(
        destination['server'],
        fallback: parseString(destination['name'], fallback: 'in-cluster'),
      ),
      repoUrl: parseString(source['repoURL'], fallback: 'Unknown'),
      path: parseString(source['path'], fallback: '/'),
      targetRevision: parseString(source['targetRevision'], fallback: 'HEAD'),
      syncStatus: parseString(sync['status'], fallback: 'Unknown'),
      healthStatus: parseString(health['status'], fallback: 'Unknown'),
      operationPhase: parseString(
        operationState['phase'],
        fallback: status['operationState'] == null ? 'Idle' : 'Unknown',
      ),
      operationMessage: parseString(operationState['message']),
      lastSyncedAt: parseString(sync['reconciledAt']),
      resources: parseList(status['resources'])
          .map((dynamic item) => ArgoResource.fromJson(parseMap(item)))
          .toList(growable: false),
      history: parseList(status['history'])
          .map((dynamic item) => ArgoHistoryEntry.fromJson(parseMap(item)))
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
  final String? operationMessage;
  final String? lastSyncedAt;
  final List<ArgoResource> resources;
  final List<ArgoHistoryEntry> history;

  bool get isOutOfSync => syncStatus.toLowerCase() != 'synced';
  bool get isHealthy => healthStatus.toLowerCase() == 'healthy';
  bool get hasOperationError =>
      operationPhase.toLowerCase() == 'failed' &&
      operationMessage != null &&
      operationMessage!.isNotEmpty;
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
    required this.healthMessage,
  });

  factory ArgoResource.fromJson(Map<String, dynamic> json) {
    final healthObj = parseMap(json['health']);
    return ArgoResource(
      kind: parseString(json['kind'], fallback: 'Resource'),
      name: parseString(json['name'], fallback: 'Unknown'),
      namespace: parseString(json['namespace'], fallback: '-'),
      group: parseString(json['group'], fallback: ''),
      version: parseString(json['version'], fallback: ''),
      status: parseString(json['status'], fallback: 'Unknown'),
      health: parseString(healthObj['status'], fallback: 'Unknown'),
      healthMessage: parseString(healthObj['message']),
    );
  }

  final String kind;
  final String name;
  final String namespace;
  final String group;
  final String version;
  final String status;
  final String health;
  final String healthMessage;
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
      revision: parseString(json['revision'], fallback: '-'),
      deployedAt: parseString(json['deployedAt'], fallback: '-'),
    );
  }

  final int id;
  final String revision;
  final String deployedAt;
}

Map<String, dynamic> _sourceMap(Map<String, dynamic> spec) {
  final source = parseMap(spec['source']);
  if (source.isNotEmpty) {
    return source;
  }

  final sources = parseList(spec['sources']);
  if (sources.isNotEmpty) {
    return parseMap(sources.first);
  }

  return const <String, dynamic>{};
}
