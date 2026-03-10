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
    final health = _map(json['health']);
    final parentRefs = _list(json['parentRefs']);

    return ArgoResourceNode(
      group: _string(json['group']),
      version: _string(json['version']),
      kind: _string(json['kind'], fallback: 'Resource'),
      namespace: _string(json['namespace'], fallback: '-'),
      name: _string(json['name'], fallback: 'Unknown'),
      uid: _string(json['uid']),
      parentUids: parentRefs
          .map((dynamic item) => _string(_map(item)['uid']))
          .where((String uid) => uid.isNotEmpty)
          .toList(growable: false),
      healthStatus: _string(health['status'], fallback: 'Unknown'),
      healthMessage: _string(health['message']),
      createdAt: _string(json['createdAt']),
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
