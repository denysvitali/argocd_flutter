import 'dart:convert';

import 'package:argocd_flutter/core/utils/json_parsing.dart';

enum ContainerRunState { running, waiting, terminated, unknown }

/// One container of a pod, merged from `spec` and `status`.
class PodContainer {
  const PodContainer({
    required this.name,
    required this.image,
    required this.isInit,
    required this.ready,
    required this.restartCount,
    required this.state,
    required this.reason,
    required this.message,
    required this.exitCode,
    required this.startedAt,
  });

  final String name;
  final String image;
  final bool isInit;
  final bool ready;
  final int restartCount;
  final ContainerRunState state;

  /// e.g. CrashLoopBackOff, Completed, OOMKilled. Empty when running.
  final String reason;
  final String message;
  final int? exitCode;
  final String startedAt;

  /// Init containers that exited 0 are finished, not failed.
  bool get completedOk =>
      state == ContainerRunState.terminated && (exitCode ?? 0) == 0;
}

/// The bits of a live Pod manifest the pod screen needs.
class PodDetails {
  const PodDetails({
    required this.phase,
    required this.nodeName,
    required this.podIp,
    required this.startTime,
    required this.containers,
  });

  /// Parses whatever `fetchResourceManifest` returned: a bare Pod object, an
  /// envelope with `manifest`/`liveState`, or either of those JSON-encoded as
  /// a string.
  factory PodDetails.fromManifestPayload(String payload) {
    return PodDetails.fromJson(_unwrapPod(_decode(payload)));
  }

  factory PodDetails.fromJson(Map<String, dynamic> pod) {
    final spec = parseMap(pod['spec']);
    final status = parseMap(pod['status']);

    Map<String, Map<String, dynamic>> statusesByName(String key) {
      return <String, Map<String, dynamic>>{
        for (final dynamic item in parseList(status[key]))
          parseString(parseMap(item)['name']): parseMap(item),
      };
    }

    List<PodContainer> containers(String specKey, String statusKey, bool init) {
      final statuses = statusesByName(statusKey);
      return <PodContainer>[
        for (final dynamic item in parseList(spec[specKey]))
          _container(parseMap(item), statuses, isInit: init),
      ];
    }

    return PodDetails(
      phase: parseString(status['phase'], fallback: 'Unknown'),
      nodeName: parseString(spec['nodeName']),
      podIp: parseString(status['podIP']),
      startTime: parseString(status['startTime']),
      containers: <PodContainer>[
        ...containers('initContainers', 'initContainerStatuses', true),
        ...containers('containers', 'containerStatuses', false),
      ],
    );
  }

  final String phase;
  final String nodeName;
  final String podIp;
  final String startTime;
  final List<PodContainer> containers;

  List<PodContainer> get initContainers =>
      containers.where((c) => c.isInit).toList(growable: false);
  List<PodContainer> get appContainers =>
      containers.where((c) => !c.isInit).toList(growable: false);

  int get restartCount => containers.fold<int>(
    0,
    (int sum, PodContainer c) => sum + c.restartCount,
  );
}

PodContainer _container(
  Map<String, dynamic> spec,
  Map<String, Map<String, dynamic>> statuses, {
  required bool isInit,
}) {
  final name = parseString(spec['name']);
  final status = statuses[name] ?? const <String, dynamic>{};
  final stateMap = parseMap(status['state']);
  var state = ContainerRunState.unknown;
  var detail = const <String, dynamic>{};
  if (stateMap['running'] is Map) {
    state = ContainerRunState.running;
    detail = parseMap(stateMap['running']);
  } else if (stateMap['waiting'] is Map) {
    state = ContainerRunState.waiting;
    detail = parseMap(stateMap['waiting']);
  } else if (stateMap['terminated'] is Map) {
    state = ContainerRunState.terminated;
    detail = parseMap(stateMap['terminated']);
  }
  final exit = detail['exitCode'];
  final restarts = status['restartCount'];

  return PodContainer(
    name: name,
    image: parseString(spec['image']),
    isInit: isInit,
    ready: status['ready'] == true,
    restartCount: restarts is num ? restarts.toInt() : 0,
    state: state,
    reason: parseString(detail['reason']),
    message: parseString(detail['message']),
    exitCode: exit is num ? exit.toInt() : null,
    startedAt: parseString(detail['startedAt']),
  );
}

dynamic _decode(dynamic value) {
  if (value is String) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }
  return value;
}

Map<String, dynamic> _unwrapPod(dynamic decoded) {
  var current = decoded;
  for (var depth = 0; depth < 4; depth++) {
    final map = parseMap(current);
    if (map['kind'] == 'Pod' || map.containsKey('spec')) {
      return map;
    }
    final next = map['liveState'] ?? map['manifest'];
    if (next == null) {
      return map;
    }
    current = _decode(next);
  }
  return parseMap(current);
}

/// ArgoCD returns this as log *content* (not an HTTP error) when a
/// multi-container pod is queried without a container. Returns the
/// container names it lists, or null when [logs] is not that message.
List<String>? containersFromLogError(String logs) {
  final match = RegExp(
    r'a container name must be specified for pod \S+?,? choose one of: \[([^\]]*)\]',
  ).firstMatch(logs.trim());
  if (match == null) {
    return null;
  }
  return match
      .group(1)!
      .split(RegExp(r'\s+'))
      .where((String name) => name.isNotEmpty)
      .toList(growable: false);
}
