import 'package:argocd_flutter/core/utils/json_parsing.dart';

class ArgoProject {
  const ArgoProject({
    required this.name,
    required this.description,
    required this.sourceRepos,
    required this.destinations,
    required this.clusterResourceWhitelist,
  });

  factory ArgoProject.fromJson(Map<String, dynamic> json) {
    final metadata = parseMap(json['metadata']);
    final spec = parseMap(json['spec']);

    return ArgoProject(
      name: parseString(metadata['name'], fallback: 'Unknown'),
      description: parseString(spec['description'], fallback: 'No description'),
      sourceRepos: parseList(spec['sourceRepos'])
          .map((dynamic item) => parseString(item))
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      destinations: parseList(spec['destinations'])
          .map((dynamic item) => ArgoProjectDestination.fromJson(parseMap(item)))
          .toList(growable: false),
      clusterResourceWhitelist: parseList(spec['clusterResourceWhitelist'])
          .map(
            (dynamic item) => ArgoProjectClusterResource.fromJson(parseMap(item)),
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
      server: parseString(json['server'], fallback: '*'),
      namespace: parseString(json['namespace'], fallback: '*'),
      name: parseString(json['name'], fallback: ''),
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
      group: parseString(json['group'], fallback: '*'),
      kind: parseString(json['kind'], fallback: '*'),
    );
  }

  final String group;
  final String kind;
}
