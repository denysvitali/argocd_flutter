class ArgoProject {
  const ArgoProject({
    required this.name,
    required this.description,
    required this.sourceRepos,
    required this.destinations,
    required this.clusterResourceWhitelist,
  });

  factory ArgoProject.fromJson(Map<String, dynamic> json) {
    final metadata = _map(json['metadata']);
    final spec = _map(json['spec']);

    return ArgoProject(
      name: _string(metadata['name'], fallback: 'Unknown'),
      description: _string(spec['description'], fallback: 'No description'),
      sourceRepos: _list(spec['sourceRepos'])
          .map((dynamic item) => _string(item))
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      destinations: _list(spec['destinations'])
          .map((dynamic item) => ArgoProjectDestination.fromJson(_map(item)))
          .toList(growable: false),
      clusterResourceWhitelist: _list(spec['clusterResourceWhitelist'])
          .map(
            (dynamic item) => ArgoProjectClusterResource.fromJson(_map(item)),
          )
          .toList(growable: false),
    );
  }

  final String name;
  final String description;
  final List<String> sourceRepos;
  final List<ArgoProjectDestination> destinations;
  final List<ArgoProjectClusterResource> clusterResourceWhitelist;
}

class ArgoProjectDestination {
  const ArgoProjectDestination({
    required this.server,
    required this.namespace,
    required this.name,
  });

  factory ArgoProjectDestination.fromJson(Map<String, dynamic> json) {
    return ArgoProjectDestination(
      server: _string(json['server'], fallback: '*'),
      namespace: _string(json['namespace'], fallback: '*'),
      name: _string(json['name'], fallback: ''),
    );
  }

  final String server;
  final String namespace;
  final String name;
}

class ArgoProjectClusterResource {
  const ArgoProjectClusterResource({required this.group, required this.kind});

  factory ArgoProjectClusterResource.fromJson(Map<String, dynamic> json) {
    return ArgoProjectClusterResource(
      group: _string(json['group'], fallback: '*'),
      kind: _string(json['kind'], fallback: '*'),
    );
  }

  final String group;
  final String kind;
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
