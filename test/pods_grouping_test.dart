import 'package:argocd_flutter/core/models/argo_resource_node.dart';
import 'package:argocd_flutter/features/applications/pods_screen.dart';
import 'package:flutter_test/flutter_test.dart';

ArgoResourceNode _node(
  String kind,
  String name, {
  List<String> parents = const [],
}) => ArgoResourceNode(
  group: '',
  version: 'v1',
  kind: kind,
  namespace: 'ns',
  name: name,
  uid: '$kind/$name',
  parentUids: parents,
  healthStatus: 'Healthy',
  healthMessage: '',
  createdAt: '',
);

void main() {
  test('groups pods by ReplicaSet and Deployment', () {
    final groups = groupPodsByWorkload(<ArgoResourceNode>[
      _node('Deployment', 'web'),
      _node('ReplicaSet', 'web-1', parents: ['Deployment/web']),
      _node('ReplicaSet', 'web-2', parents: ['Deployment/web']),
      _node('Pod', 'web-1-a', parents: ['ReplicaSet/web-1']),
      _node('Pod', 'web-2-a', parents: ['ReplicaSet/web-2']),
      _node('Pod', 'web-2-b', parents: ['ReplicaSet/web-2']),
      _node('Pod', 'lonely'),
    ]);
    expect(groups.length, 2);
    expect(groups[0].workload?.name, 'web');
    expect(groups[0].podCount, 3);
    expect(groups[0].groups.map((g) => g.owner?.name), ['web-1', 'web-2']);
    expect(groups[1].workload, isNull);
  });
}
