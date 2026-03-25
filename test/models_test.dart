import 'package:flutter_test/flutter_test.dart';

import 'package:argocd_flutter/core/models/app_session.dart';
import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/models/argo_project.dart';
import 'package:argocd_flutter/core/models/argo_resource_node.dart';

void main() {
  group('ArgoApplication.fromJson', () {
    test('parses complete JSON correctly', () {
      final json = <String, dynamic>{
        'metadata': {
          'name': 'guestbook',
          'namespace': 'argocd',
          'uid': 'abc-123',
        },
        'spec': {
          'project': 'my-project',
          'source': {
            'repoURL': 'https://github.com/argoproj/argocd-example-apps.git',
            'path': 'guestbook',
            'targetRevision': 'main',
          },
          'destination': {
            'server': 'https://kubernetes.default.svc',
            'namespace': 'guestbook-ns',
          },
        },
        'status': {
          'sync': {
            'status': 'Synced',
            'reconciledAt': '2026-03-10T12:00:00Z',
          },
          'health': {'status': 'Healthy'},
          'operationState': {'phase': 'Succeeded'},
          'resources': [
            {
              'kind': 'Deployment',
              'name': 'guestbook-ui',
              'namespace': 'guestbook-ns',
              'group': 'apps',
              'version': 'v1',
              'status': 'Synced',
              'health': {'status': 'Healthy'},
            },
            {
              'kind': 'Service',
              'name': 'guestbook-svc',
              'namespace': 'guestbook-ns',
              'group': '',
              'version': 'v1',
              'status': 'Synced',
              'health': {'status': 'Healthy'},
            },
          ],
          'history': [
            {
              'id': '1',
              'revision': 'abc1234',
              'deployedAt': '2026-03-09T10:00:00Z',
            },
            {
              'id': '2',
              'revision': 'def5678',
              'deployedAt': '2026-03-10T12:00:00Z',
            },
          ],
        },
      };

      final app = ArgoApplication.fromJson(json);

      expect(app.name, 'guestbook');
      expect(app.project, 'my-project');
      expect(app.namespace, 'guestbook-ns');
      expect(app.cluster, 'https://kubernetes.default.svc');
      expect(
        app.repoUrl,
        'https://github.com/argoproj/argocd-example-apps.git',
      );
      expect(app.path, 'guestbook');
      expect(app.targetRevision, 'main');
      expect(app.syncStatus, 'Synced');
      expect(app.healthStatus, 'Healthy');
      expect(app.operationPhase, 'Succeeded');
      expect(app.lastSyncedAt, '2026-03-10T12:00:00Z');
      expect(app.resources, hasLength(2));
      expect(app.resources[0].kind, 'Deployment');
      expect(app.resources[1].kind, 'Service');
      expect(app.history, hasLength(2));
      expect(app.history[0].id, 1);
      expect(app.history[1].revision, 'def5678');
    });

    test('handles missing optional fields gracefully', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{},
        'spec': <String, dynamic>{},
        'status': <String, dynamic>{},
      };

      final app = ArgoApplication.fromJson(json);

      expect(app.name, 'Unknown');
      expect(app.project, 'default');
      expect(app.namespace, 'default');
      expect(app.cluster, 'in-cluster');
      expect(app.repoUrl, 'Unknown');
      expect(app.path, '/');
      expect(app.targetRevision, 'HEAD');
      expect(app.syncStatus, 'Unknown');
      expect(app.healthStatus, 'Unknown');
      expect(app.operationPhase, 'Idle');
      expect(app.lastSyncedAt, isEmpty);
      expect(app.resources, isEmpty);
      expect(app.history, isEmpty);
    });

    test('handles completely empty JSON', () {
      final app = ArgoApplication.fromJson(<String, dynamic>{});

      expect(app.name, 'Unknown');
      expect(app.project, 'default');
      expect(app.resources, isEmpty);
      expect(app.history, isEmpty);
    });

    test('uses sources array when source is absent', () {
      final json = <String, dynamic>{
        'metadata': {'name': 'multi-source-app'},
        'spec': {
          'project': 'default',
          'sources': [
            {
              'repoURL': 'https://github.com/org/repo-a.git',
              'path': 'manifests',
              'targetRevision': 'v1.0.0',
            },
            {
              'repoURL': 'https://github.com/org/repo-b.git',
              'path': 'charts',
              'targetRevision': 'v2.0.0',
            },
          ],
          'destination': {
            'server': 'https://kubernetes.default.svc',
            'namespace': 'production',
          },
        },
        'status': {
          'sync': {'status': 'Synced'},
          'health': {'status': 'Healthy'},
        },
      };

      final app = ArgoApplication.fromJson(json);

      expect(app.repoUrl, 'https://github.com/org/repo-a.git');
      expect(app.path, 'manifests');
      expect(app.targetRevision, 'v1.0.0');
    });
  });

  group('ArgoApplication computed getters', () {
    ArgoApplication makeApp({
      required String syncStatus,
      required String healthStatus,
    }) {
      return ArgoApplication(
        name: 'test-app',
        project: 'default',
        namespace: 'default',
        cluster: 'in-cluster',
        repoUrl: 'https://example.com/repo.git',
        path: '.',
        targetRevision: 'HEAD',
        syncStatus: syncStatus,
        healthStatus: healthStatus,
        operationPhase: 'Succeeded',
        operationMessage: null,
        lastSyncedAt: null,
        resources: const <ArgoResource>[],
        history: const <ArgoHistoryEntry>[],
      );
    }

    test('isOutOfSync returns false when Synced', () {
      final app = makeApp(syncStatus: 'Synced', healthStatus: 'Healthy');
      expect(app.isOutOfSync, isFalse);
    });

    test('isOutOfSync returns true when OutOfSync', () {
      final app = makeApp(syncStatus: 'OutOfSync', healthStatus: 'Healthy');
      expect(app.isOutOfSync, isTrue);
    });

    test('isOutOfSync is case-insensitive', () {
      final app = makeApp(syncStatus: 'synced', healthStatus: 'Healthy');
      expect(app.isOutOfSync, isFalse);
    });

    test('isHealthy returns true when Healthy', () {
      final app = makeApp(syncStatus: 'Synced', healthStatus: 'Healthy');
      expect(app.isHealthy, isTrue);
    });

    test('isHealthy returns false when Degraded', () {
      final app = makeApp(syncStatus: 'Synced', healthStatus: 'Degraded');
      expect(app.isHealthy, isFalse);
    });

    test('isHealthy is case-insensitive', () {
      final app = makeApp(syncStatus: 'Synced', healthStatus: 'healthy');
      expect(app.isHealthy, isTrue);
    });
  });

  group('ArgoProject.fromJson', () {
    test('parses complete JSON correctly', () {
      final json = <String, dynamic>{
        'metadata': {'name': 'my-project'},
        'spec': {
          'description': 'Production services project',
          'sourceRepos': [
            'https://github.com/org/repo-a.git',
            'https://github.com/org/repo-b.git',
          ],
          'destinations': [
            {
              'server': 'https://kubernetes.default.svc',
              'namespace': 'production',
              'name': 'in-cluster',
            },
            {
              'server': 'https://remote-cluster.example.com',
              'namespace': 'staging',
              'name': 'remote',
            },
          ],
          'clusterResourceWhitelist': [
            {'group': '*', 'kind': 'Namespace'},
            {'group': 'rbac.authorization.k8s.io', 'kind': 'ClusterRole'},
          ],
        },
      };

      final project = ArgoProject.fromJson(json);

      expect(project.name, 'my-project');
      expect(project.description, 'Production services project');
      expect(project.sourceRepos, hasLength(2));
      expect(project.sourceRepos[0], 'https://github.com/org/repo-a.git');
      expect(project.sourceRepos[1], 'https://github.com/org/repo-b.git');
      expect(project.destinations, hasLength(2));
      expect(project.destinations[0].server,
          'https://kubernetes.default.svc');
      expect(project.destinations[0].namespace, 'production');
      expect(project.destinations[0].name, 'in-cluster');
      expect(project.destinations[1].name, 'remote');
      expect(project.clusterResourceWhitelist, hasLength(2));
      expect(project.clusterResourceWhitelist[0].group, '*');
      expect(project.clusterResourceWhitelist[0].kind, 'Namespace');
      expect(project.clusterResourceWhitelist[1].group,
          'rbac.authorization.k8s.io');
    });

    test('handles empty lists', () {
      final json = <String, dynamic>{
        'metadata': {'name': 'empty-project'},
        'spec': {
          'description': 'An empty project',
          'sourceRepos': <String>[],
          'destinations': <Map<String, dynamic>>[],
          'clusterResourceWhitelist': <Map<String, dynamic>>[],
        },
      };

      final project = ArgoProject.fromJson(json);

      expect(project.name, 'empty-project');
      expect(project.sourceRepos, isEmpty);
      expect(project.destinations, isEmpty);
      expect(project.clusterResourceWhitelist, isEmpty);
    });

    test('handles missing lists', () {
      final json = <String, dynamic>{
        'metadata': {'name': 'minimal-project'},
        'spec': <String, dynamic>{},
      };

      final project = ArgoProject.fromJson(json);

      expect(project.name, 'minimal-project');
      expect(project.description, 'No description');
      expect(project.sourceRepos, isEmpty);
      expect(project.destinations, isEmpty);
      expect(project.clusterResourceWhitelist, isEmpty);
    });

    test('handles completely empty JSON', () {
      final project = ArgoProject.fromJson(<String, dynamic>{});

      expect(project.name, 'Unknown');
      expect(project.description, 'No description');
      expect(project.sourceRepos, isEmpty);
      expect(project.destinations, isEmpty);
      expect(project.clusterResourceWhitelist, isEmpty);
    });
  });

  group('ArgoResourceNode.fromJson', () {
    test('parses complete JSON correctly', () {
      final json = <String, dynamic>{
        'group': 'apps',
        'version': 'v1',
        'kind': 'Deployment',
        'namespace': 'guestbook-ns',
        'name': 'guestbook-ui',
        'uid': 'uid-deploy-001',
        'parentRefs': [
          {'uid': 'uid-app-root-001'},
        ],
        'health': {
          'status': 'Healthy',
          'message': 'Deployment is available',
        },
        'createdAt': '2026-03-10T08:30:00Z',
      };

      final node = ArgoResourceNode.fromJson(json);

      expect(node.group, 'apps');
      expect(node.version, 'v1');
      expect(node.kind, 'Deployment');
      expect(node.namespace, 'guestbook-ns');
      expect(node.name, 'guestbook-ui');
      expect(node.uid, 'uid-deploy-001');
      expect(node.parentUids, ['uid-app-root-001']);
      expect(node.healthStatus, 'Healthy');
      expect(node.healthMessage, 'Deployment is available');
      expect(node.createdAt, '2026-03-10T08:30:00Z');
    });

    test('handles missing optional fields', () {
      final json = <String, dynamic>{
        'kind': 'ConfigMap',
        'name': 'app-config',
      };

      final node = ArgoResourceNode.fromJson(json);

      expect(node.group, isEmpty);
      expect(node.version, isEmpty);
      expect(node.kind, 'ConfigMap');
      expect(node.namespace, '-');
      expect(node.name, 'app-config');
      expect(node.uid, isEmpty);
      expect(node.parentUids, isEmpty);
      expect(node.healthStatus, 'Unknown');
      expect(node.healthMessage, isEmpty);
      expect(node.createdAt, isEmpty);
    });

    test('filters out empty parent UIDs', () {
      final json = <String, dynamic>{
        'kind': 'Pod',
        'name': 'test-pod',
        'parentRefs': [
          {'uid': 'uid-rs-001'},
          <String, dynamic>{},
          {'uid': ''},
          {'uid': 'uid-rs-002'},
        ],
      };

      final node = ArgoResourceNode.fromJson(json);

      expect(node.parentUids, ['uid-rs-001', 'uid-rs-002']);
    });
  });

  group('ArgoResourceNode computed getters', () {
    test('isRoot returns true when parentUids is empty', () {
      final node = ArgoResourceNode(
        group: '',
        version: 'v1',
        kind: 'Application',
        namespace: 'argocd',
        name: 'my-app',
        uid: 'uid-001',
        parentUids: const <String>[],
        healthStatus: 'Healthy',
        healthMessage: '',
        createdAt: '2026-03-10T08:30:00Z',
      );

      expect(node.isRoot, isTrue);
    });

    test('isRoot returns false when parentUids is non-empty', () {
      final node = ArgoResourceNode(
        group: 'apps',
        version: 'v1',
        kind: 'ReplicaSet',
        namespace: 'default',
        name: 'rs-001',
        uid: 'uid-002',
        parentUids: const ['uid-001'],
        healthStatus: 'Healthy',
        healthMessage: '',
        createdAt: '2026-03-10T08:30:00Z',
      );

      expect(node.isRoot, isFalse);
    });

    test('displayKind includes group when present', () {
      final node = ArgoResourceNode(
        group: 'apps',
        version: 'v1',
        kind: 'Deployment',
        namespace: 'default',
        name: 'deploy-001',
        uid: 'uid-003',
        parentUids: const <String>[],
        healthStatus: 'Healthy',
        healthMessage: '',
        createdAt: '',
      );

      expect(node.displayKind, 'Deployment.apps');
    });

    test('displayKind returns kind only when group is empty', () {
      final node = ArgoResourceNode(
        group: '',
        version: 'v1',
        kind: 'Service',
        namespace: 'default',
        name: 'svc-001',
        uid: 'uid-004',
        parentUids: const <String>[],
        healthStatus: 'Healthy',
        healthMessage: '',
        createdAt: '',
      );

      expect(node.displayKind, 'Service');
    });
  });

  group('ArgoApplication.fromJson edge cases', () {
    test('handles null values in metadata', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': null, 'namespace': null},
        'spec': <String, dynamic>{},
        'status': <String, dynamic>{},
      };

      final app = ArgoApplication.fromJson(json);

      expect(app.name, 'Unknown');
    });

    test('handles numeric values where strings are expected', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 12345},
        'spec': <String, dynamic>{
          'project': 42,
          'source': <String, dynamic>{
            'repoURL': 99,
            'path': 0,
          },
          'destination': <String, dynamic>{
            'server': 100,
            'namespace': 200,
          },
        },
        'status': <String, dynamic>{},
      };

      final app = ArgoApplication.fromJson(json);

      expect(app.name, '12345');
      expect(app.project, '42');
      expect(app.repoUrl, '99');
    });

    test('handles malformed resources list', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'test'},
        'spec': <String, dynamic>{},
        'status': <String, dynamic>{
          'resources': <dynamic>[
            <String, dynamic>{},
            <String, dynamic>{'kind': 'Service', 'name': 'svc'},
          ],
        },
      };

      final app = ArgoApplication.fromJson(json);

      expect(app.resources, hasLength(2));
      expect(app.resources[0].kind, 'Resource');
      expect(app.resources[0].name, 'Unknown');
      expect(app.resources[1].kind, 'Service');
      expect(app.resources[1].name, 'svc');
    });

    test('handles malformed history entries', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'test'},
        'spec': <String, dynamic>{},
        'status': <String, dynamic>{
          'history': <dynamic>[
            <String, dynamic>{},
            <String, dynamic>{
              'id': 'not-a-number',
              'revision': 'abc123',
              'deployedAt': '2026-03-10T10:00:00Z',
            },
          ],
        },
      };

      final app = ArgoApplication.fromJson(json);

      expect(app.history, hasLength(2));
      expect(app.history[0].id, 0);
      expect(app.history[0].revision, '-');
      expect(app.history[1].id, 0); // 'not-a-number' cannot parse to int
      expect(app.history[1].revision, 'abc123');
    });

    test('handles operationState present but phase missing', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'test'},
        'spec': <String, dynamic>{},
        'status': <String, dynamic>{
          'operationState': <String, dynamic>{},
        },
      };

      final app = ArgoApplication.fromJson(json);

      // operationState is present but phase is absent, so fallback is 'Unknown'
      expect(app.operationPhase, 'Unknown');
    });

    test('empty strings fall back to defaults', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': ''},
        'spec': <String, dynamic>{
          'project': '',
          'source': <String, dynamic>{
            'repoURL': '   ',
            'path': '',
            'targetRevision': '',
          },
          'destination': <String, dynamic>{
            'server': '',
            'namespace': '',
          },
        },
        'status': <String, dynamic>{
          'sync': <String, dynamic>{'status': ''},
          'health': <String, dynamic>{'status': ''},
        },
      };

      final app = ArgoApplication.fromJson(json);

      expect(app.name, 'Unknown');
      expect(app.project, 'default');
      expect(app.repoUrl, 'Unknown');
      expect(app.path, '/');
      expect(app.targetRevision, 'HEAD');
      expect(app.syncStatus, 'Unknown');
      expect(app.healthStatus, 'Unknown');
    });
  });

  group('ArgoResourceNode.fromJson edge cases', () {
    test('parses multiple parent UIDs', () {
      final json = <String, dynamic>{
        'kind': 'Pod',
        'name': 'test-pod',
        'parentRefs': <dynamic>[
          <String, dynamic>{'uid': 'parent-1'},
          <String, dynamic>{'uid': 'parent-2'},
          <String, dynamic>{'uid': 'parent-3'},
        ],
      };

      final node = ArgoResourceNode.fromJson(json);

      expect(node.parentUids, hasLength(3));
      expect(node.parentUids, <String>['parent-1', 'parent-2', 'parent-3']);
    });

    test('handles health with Degraded status and message', () {
      final json = <String, dynamic>{
        'kind': 'Deployment',
        'name': 'broken-deploy',
        'health': <String, dynamic>{
          'status': 'Degraded',
          'message': 'Deployment has 0 available replicas',
        },
      };

      final node = ArgoResourceNode.fromJson(json);

      expect(node.healthStatus, 'Degraded');
      expect(node.healthMessage, 'Deployment has 0 available replicas');
    });

    test('handles health with Progressing status', () {
      final json = <String, dynamic>{
        'kind': 'Deployment',
        'name': 'rolling-deploy',
        'health': <String, dynamic>{
          'status': 'Progressing',
          'message': 'Waiting for rollout',
        },
      };

      final node = ArgoResourceNode.fromJson(json);

      expect(node.healthStatus, 'Progressing');
    });

    test('handles completely empty JSON', () {
      final node = ArgoResourceNode.fromJson(<String, dynamic>{});

      expect(node.kind, 'Resource');
      expect(node.name, 'Unknown');
      expect(node.namespace, '-');
      expect(node.uid, isEmpty);
      expect(node.parentUids, isEmpty);
      expect(node.healthStatus, 'Unknown');
    });
  });

  group('ArgoProject.fromJson edge cases', () {
    test('parses wildcard source repos', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'wildcard-project'},
        'spec': <String, dynamic>{
          'description': 'Allows all repos',
          'sourceRepos': <dynamic>['*'],
          'destinations': <dynamic>[],
        },
      };

      final project = ArgoProject.fromJson(json);

      expect(project.sourceRepos, <String>['*']);
    });

    test('filters out empty source repos', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'filter-test'},
        'spec': <String, dynamic>{
          'sourceRepos': <dynamic>[
            'https://github.com/org/repo.git',
            '',
            '   ',
            'https://github.com/org/other.git',
          ],
        },
      };

      final project = ArgoProject.fromJson(json);

      expect(project.sourceRepos, hasLength(2));
      expect(project.sourceRepos[0], 'https://github.com/org/repo.git');
      expect(project.sourceRepos[1], 'https://github.com/org/other.git');
    });

    test('parses destinations with wildcard namespace', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'wildcard-ns'},
        'spec': <String, dynamic>{
          'destinations': <dynamic>[
            <String, dynamic>{
              'server': 'https://kubernetes.default.svc',
              'namespace': '*',
            },
          ],
        },
      };

      final project = ArgoProject.fromJson(json);

      expect(project.destinations, hasLength(1));
      expect(project.destinations[0].namespace, '*');
      expect(project.destinations[0].name, isEmpty);
    });

    test('parses empty destinations list', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'no-dest'},
        'spec': <String, dynamic>{
          'destinations': <dynamic>[],
        },
      };

      final project = ArgoProject.fromJson(json);

      expect(project.destinations, isEmpty);
    });

    test('parses destinations with missing fields', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'missing-dest-fields'},
        'spec': <String, dynamic>{
          'destinations': <dynamic>[
            <String, dynamic>{},
          ],
        },
      };

      final project = ArgoProject.fromJson(json);

      expect(project.destinations, hasLength(1));
      expect(project.destinations[0].server, '*');
      expect(project.destinations[0].namespace, '*');
      expect(project.destinations[0].name, isEmpty);
    });

    test('parses cluster resource whitelist with wildcard', () {
      final json = <String, dynamic>{
        'metadata': <String, dynamic>{'name': 'crw-test'},
        'spec': <String, dynamic>{
          'clusterResourceWhitelist': <dynamic>[
            <String, dynamic>{'group': '*', 'kind': '*'},
          ],
        },
      };

      final project = ArgoProject.fromJson(json);

      expect(project.clusterResourceWhitelist, hasLength(1));
      expect(project.clusterResourceWhitelist[0].group, '*');
      expect(project.clusterResourceWhitelist[0].kind, '*');
    });
  });

  group('ArgoResource.fromJson edge cases', () {
    test('handles completely empty JSON', () {
      final resource = ArgoResource.fromJson(<String, dynamic>{});

      expect(resource.kind, 'Resource');
      expect(resource.name, 'Unknown');
      expect(resource.namespace, '-');
      expect(resource.group, isEmpty);
      expect(resource.version, isEmpty);
      expect(resource.status, 'Unknown');
      expect(resource.health, 'Unknown');
    });

    test('parses all fields correctly', () {
      final json = <String, dynamic>{
        'kind': 'Deployment',
        'name': 'web',
        'namespace': 'production',
        'group': 'apps',
        'version': 'v1',
        'status': 'Synced',
        'health': {'status': 'Healthy', 'message': 'Deployment is available'},
      };

      final resource = ArgoResource.fromJson(json);

      expect(resource.kind, 'Deployment');
      expect(resource.name, 'web');
      expect(resource.namespace, 'production');
      expect(resource.group, 'apps');
      expect(resource.version, 'v1');
      expect(resource.status, 'Synced');
      expect(resource.health, 'Healthy');
      expect(resource.healthMessage, 'Deployment is available');
    });
  });

  group('ArgoHistoryEntry.fromJson edge cases', () {
    test('handles completely empty JSON', () {
      final entry = ArgoHistoryEntry.fromJson(<String, dynamic>{});

      expect(entry.id, 0);
      expect(entry.revision, '-');
      expect(entry.deployedAt, '-');
    });

    test('parses numeric id from string', () {
      final json = <String, dynamic>{
        'id': '42',
        'revision': 'abc',
        'deployedAt': '2026-01-01',
      };

      final entry = ArgoHistoryEntry.fromJson(json);

      expect(entry.id, 42);
    });

    test('parses numeric id from integer', () {
      final json = <String, dynamic>{
        'id': 7,
        'revision': 'def',
        'deployedAt': '2026-02-02',
      };

      final entry = ArgoHistoryEntry.fromJson(json);

      expect(entry.id, 7);
    });
  });

  group('AppSession.copyWith', () {
    test('returns new instance with updated serverUrl', () {
      const session = AppSession(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        token: 'token-abc-123',
      );

      final updated = session.copyWith(serverUrl: 'https://argocd-v2.example.com');

      expect(updated.serverUrl, 'https://argocd-v2.example.com');
      expect(updated.username, 'admin');
      expect(updated.token, 'token-abc-123');
    });

    test('returns new instance with updated username', () {
      const session = AppSession(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        token: 'token-abc-123',
      );

      final updated = session.copyWith(username: 'operator');

      expect(updated.serverUrl, 'https://argocd.example.com');
      expect(updated.username, 'operator');
      expect(updated.token, 'token-abc-123');
    });

    test('returns new instance with updated token', () {
      const session = AppSession(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        token: 'token-abc-123',
      );

      final updated = session.copyWith(token: 'token-xyz-789');

      expect(updated.serverUrl, 'https://argocd.example.com');
      expect(updated.username, 'admin');
      expect(updated.token, 'token-xyz-789');
    });

    test('returns identical copy when no arguments provided', () {
      const session = AppSession(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        token: 'token-abc-123',
      );

      final copy = session.copyWith();

      expect(copy.serverUrl, session.serverUrl);
      expect(copy.username, session.username);
      expect(copy.token, session.token);
    });

    test('returns new instance with all fields updated', () {
      const session = AppSession(
        serverUrl: 'https://argocd.example.com',
        username: 'admin',
        token: 'token-abc-123',
      );

      final updated = session.copyWith(
        serverUrl: 'https://new-server.example.com',
        username: 'new-user',
        token: 'new-token',
      );

      expect(updated.serverUrl, 'https://new-server.example.com');
      expect(updated.username, 'new-user');
      expect(updated.token, 'new-token');
    });
  });
}
