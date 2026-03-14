import 'package:argocd_flutter/core/utils/json_parsing.dart';

class ArgoResourceNode {
  const ArgoResourceNode({
    required this.group,
    required this.version,
    required this.kind,
    required this.namespace,
    required this.name,
    required this.uid,
    required this.parentUids,
    required this.healthStatus,
    required this.healthMessage,
    required this.createdAt,
  });

  factory ArgoResourceNode.fromJson(Map<String, dynamic> json) {
    final health = parseMap(json['health']);
    final parentRefs = parseList(json['parentRefs']);

    return ArgoResourceNode(
      group: parseString(json['group']),
      version: parseString(json['version']),
      kind: parseString(json['kind'], fallback: 'Resource'),
      namespace: parseString(json['namespace'], fallback: '-'),
      name: parseString(json['name'], fallback: 'Unknown'),
      uid: parseString(json['uid']),
      parentUids: parentRefs
          .map((dynamic item) => parseString(parseMap(item)['uid']))
          .where((String uid) => uid.isNotEmpty)
          .toList(growable: false),
      healthStatus: parseString(health['status'], fallback: 'Unknown'),
      healthMessage: parseString(health['message']),
      createdAt: parseString(json['createdAt']),
    );
  }

  final String group;
  final String version;
  final String kind;
  final String namespace;
  final String name;
  final String uid;
  final List<String> parentUids;
  final String healthStatus;
  final String healthMessage;
  final String createdAt;

  bool get isRoot => parentUids.isEmpty;
  String get displayKind => group.isNotEmpty ? '$kind.$group' : kind;
}
