import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/resource_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // iconForResourceKind
  // ---------------------------------------------------------------------------

  group('iconForResourceKind', () {
    group('workload kinds', () {
      test('Deployment returns rocket_launch_outlined', () {
        expect(iconForResourceKind('Deployment'), Icons.rocket_launch_outlined);
      });

      test('ReplicaSet returns view_module_outlined', () {
        expect(iconForResourceKind('ReplicaSet'), Icons.view_module_outlined);
      });

      test('StatefulSet returns view_column_outlined', () {
        expect(iconForResourceKind('StatefulSet'), Icons.view_column_outlined);
      });

      test('DaemonSet returns developer_board_outlined', () {
        expect(
          iconForResourceKind('DaemonSet'),
          Icons.developer_board_outlined,
        );
      });

      test('Job returns work_outline', () {
        expect(iconForResourceKind('Job'), Icons.work_outline);
      });

      test('CronJob returns schedule_outlined', () {
        expect(iconForResourceKind('CronJob'), Icons.schedule_outlined);
      });

      test('Pod returns memory_outlined', () {
        expect(iconForResourceKind('Pod'), Icons.memory_outlined);
      });
    });

    group('networking kinds', () {
      test('Service returns hub_outlined', () {
        expect(iconForResourceKind('Service'), Icons.hub_outlined);
      });

      test('Ingress returns language_outlined', () {
        expect(iconForResourceKind('Ingress'), Icons.language_outlined);
      });

      test('NetworkPolicy returns shield_outlined', () {
        expect(iconForResourceKind('NetworkPolicy'), Icons.shield_outlined);
      });

      test('Endpoints returns electrical_services_outlined', () {
        expect(
          iconForResourceKind('Endpoints'),
          Icons.electrical_services_outlined,
        );
      });

      test('EndpointSlice returns electrical_services_outlined', () {
        expect(
          iconForResourceKind('EndpointSlice'),
          Icons.electrical_services_outlined,
        );
      });
    });

    group('config and storage kinds', () {
      test('ConfigMap returns tune_outlined', () {
        expect(iconForResourceKind('ConfigMap'), Icons.tune_outlined);
      });

      test('Secret returns vpn_key_outlined', () {
        expect(iconForResourceKind('Secret'), Icons.vpn_key_outlined);
      });

      test('PersistentVolumeClaim returns storage_outlined', () {
        expect(
          iconForResourceKind('PersistentVolumeClaim'),
          Icons.storage_outlined,
        );
      });

      test('PersistentVolume returns storage_outlined', () {
        expect(
          iconForResourceKind('PersistentVolume'),
          Icons.storage_outlined,
        );
      });

      test('StorageClass returns inventory_2_outlined', () {
        expect(iconForResourceKind('StorageClass'), Icons.inventory_2_outlined);
      });
    });

    group('RBAC kinds', () {
      test('ServiceAccount returns badge_outlined', () {
        expect(iconForResourceKind('ServiceAccount'), Icons.badge_outlined);
      });

      test('Role returns admin_panel_settings_outlined', () {
        expect(
          iconForResourceKind('Role'),
          Icons.admin_panel_settings_outlined,
        );
      });

      test('ClusterRole returns admin_panel_settings_outlined', () {
        expect(
          iconForResourceKind('ClusterRole'),
          Icons.admin_panel_settings_outlined,
        );
      });

      test('RoleBinding returns link_outlined', () {
        expect(iconForResourceKind('RoleBinding'), Icons.link_outlined);
      });

      test('ClusterRoleBinding returns link_outlined', () {
        expect(iconForResourceKind('ClusterRoleBinding'), Icons.link_outlined);
      });
    });

    group('cluster kinds', () {
      test('Namespace returns folder_outlined', () {
        expect(iconForResourceKind('Namespace'), Icons.folder_outlined);
      });

      test('Node returns dns_outlined', () {
        expect(iconForResourceKind('Node'), Icons.dns_outlined);
      });
    });

    group('autoscaling and policy kinds', () {
      test('HorizontalPodAutoscaler returns auto_graph_outlined', () {
        expect(
          iconForResourceKind('HorizontalPodAutoscaler'),
          Icons.auto_graph_outlined,
        );
      });

      test('VerticalPodAutoscaler returns trending_up_outlined', () {
        expect(
          iconForResourceKind('VerticalPodAutoscaler'),
          Icons.trending_up_outlined,
        );
      });

      test('PodDisruptionBudget returns health_and_safety_outlined', () {
        expect(
          iconForResourceKind('PodDisruptionBudget'),
          Icons.health_and_safety_outlined,
        );
      });

      test('LimitRange returns data_usage_outlined', () {
        expect(iconForResourceKind('LimitRange'), Icons.data_usage_outlined);
      });

      test('ResourceQuota returns data_usage_outlined', () {
        expect(iconForResourceKind('ResourceQuota'), Icons.data_usage_outlined);
      });
    });

    group('certificate and webhook kinds', () {
      test('Certificate returns verified_outlined', () {
        expect(iconForResourceKind('Certificate'), Icons.verified_outlined);
      });

      test('Issuer returns verified_outlined', () {
        expect(iconForResourceKind('Issuer'), Icons.verified_outlined);
      });

      test('ClusterIssuer returns verified_outlined', () {
        expect(iconForResourceKind('ClusterIssuer'), Icons.verified_outlined);
      });

      test('CustomResourceDefinition returns extension_outlined', () {
        expect(
          iconForResourceKind('CustomResourceDefinition'),
          Icons.extension_outlined,
        );
      });

      test('MutatingWebhookConfiguration returns webhook_outlined', () {
        expect(
          iconForResourceKind('MutatingWebhookConfiguration'),
          Icons.webhook_outlined,
        );
      });

      test('ValidatingWebhookConfiguration returns webhook_outlined', () {
        expect(
          iconForResourceKind('ValidatingWebhookConfiguration'),
          Icons.webhook_outlined,
        );
      });
    });

    group('ArgoCD application kind', () {
      test('Application returns apps icon', () {
        expect(iconForResourceKind('Application'), Icons.apps);
      });
    });

    group('event kind', () {
      test('Event returns event_note_outlined', () {
        expect(iconForResourceKind('Event'), Icons.event_note_outlined);
      });
    });

    group('unknown kinds', () {
      test('unknown kind returns widgets_outlined default', () {
        expect(
          iconForResourceKind('SomeUnknownResource'),
          Icons.widgets_outlined,
        );
      });

      test('empty string returns widgets_outlined default', () {
        expect(iconForResourceKind(''), Icons.widgets_outlined);
      });
    });

    group('case sensitivity', () {
      test('lowercase deployment matches', () {
        expect(iconForResourceKind('deployment'), Icons.rocket_launch_outlined);
      });

      test('uppercase DEPLOYMENT matches', () {
        expect(iconForResourceKind('DEPLOYMENT'), Icons.rocket_launch_outlined);
      });

      test('mixed-case dEpLoYmEnT matches', () {
        expect(iconForResourceKind('dEpLoYmEnT'), Icons.rocket_launch_outlined);
      });

      test('lowercase pod matches', () {
        expect(iconForResourceKind('pod'), Icons.memory_outlined);
      });

      test('lowercase service matches', () {
        expect(iconForResourceKind('service'), Icons.hub_outlined);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // colorForResourceKind
  // ---------------------------------------------------------------------------

  group('colorForResourceKind', () {
    group('workload kinds return teal', () {
      test('Deployment returns teal', () {
        expect(colorForResourceKind('Deployment'), AppColors.teal);
      });

      test('StatefulSet returns teal', () {
        expect(colorForResourceKind('StatefulSet'), AppColors.teal);
      });

      test('DaemonSet returns teal', () {
        expect(colorForResourceKind('DaemonSet'), AppColors.teal);
      });

      test('ReplicaSet returns teal', () {
        expect(colorForResourceKind('ReplicaSet'), AppColors.teal);
      });
    });

    group('pod kind returns healthy', () {
      test('Pod returns healthy', () {
        expect(colorForResourceKind('Pod'), AppColors.healthy);
      });
    });

    group('networking kinds return outOfSync', () {
      test('Service returns outOfSync', () {
        expect(colorForResourceKind('Service'), AppColors.outOfSync);
      });

      test('Ingress returns outOfSync', () {
        expect(colorForResourceKind('Ingress'), AppColors.outOfSync);
      });

      test('Endpoints returns outOfSync', () {
        expect(colorForResourceKind('Endpoints'), AppColors.outOfSync);
      });

      test('EndpointSlice returns outOfSync', () {
        expect(colorForResourceKind('EndpointSlice'), AppColors.outOfSync);
      });
    });

    group('config kinds return degraded', () {
      test('ConfigMap returns degraded', () {
        expect(colorForResourceKind('ConfigMap'), AppColors.degraded);
      });

      test('Secret returns degraded', () {
        expect(colorForResourceKind('Secret'), AppColors.degraded);
      });
    });

    group('job kinds return gray6', () {
      test('Job returns gray6', () {
        expect(colorForResourceKind('Job'), AppColors.gray6);
      });

      test('CronJob returns gray6', () {
        expect(colorForResourceKind('CronJob'), AppColors.gray6);
      });
    });

    group('storage kinds return gray5', () {
      test('PersistentVolumeClaim returns gray5', () {
        expect(colorForResourceKind('PersistentVolumeClaim'), AppColors.gray5);
      });

      test('PersistentVolume returns gray5', () {
        expect(colorForResourceKind('PersistentVolume'), AppColors.gray5);
      });

      test('StorageClass returns gray5', () {
        expect(colorForResourceKind('StorageClass'), AppColors.gray5);
      });
    });

    group('RBAC kinds return suspended', () {
      test('ServiceAccount returns suspended', () {
        expect(colorForResourceKind('ServiceAccount'), AppColors.suspended);
      });

      test('Role returns suspended', () {
        expect(colorForResourceKind('Role'), AppColors.suspended);
      });

      test('ClusterRole returns suspended', () {
        expect(colorForResourceKind('ClusterRole'), AppColors.suspended);
      });

      test('RoleBinding returns suspended', () {
        expect(colorForResourceKind('RoleBinding'), AppColors.suspended);
      });

      test('ClusterRoleBinding returns suspended', () {
        expect(colorForResourceKind('ClusterRoleBinding'), AppColors.suspended);
      });
    });

    group('cluster kinds return tealDark', () {
      test('Namespace returns tealDark', () {
        expect(colorForResourceKind('Namespace'), AppColors.tealDark);
      });

      test('Node returns tealDark', () {
        expect(colorForResourceKind('Node'), AppColors.tealDark);
      });
    });

    group('certificate kinds return healthy', () {
      test('Certificate returns healthy', () {
        expect(colorForResourceKind('Certificate'), AppColors.healthy);
      });

      test('Issuer returns healthy', () {
        expect(colorForResourceKind('Issuer'), AppColors.healthy);
      });

      test('ClusterIssuer returns healthy', () {
        expect(colorForResourceKind('ClusterIssuer'), AppColors.healthy);
      });
    });

    group('event kind returns gray5', () {
      test('Event returns gray5', () {
        expect(colorForResourceKind('Event'), AppColors.gray5);
      });
    });

    group('unknown kinds return gray6 default', () {
      test('unknown kind returns gray6', () {
        expect(colorForResourceKind('SomeUnknownResource'), AppColors.gray6);
      });

      test('empty string returns gray6', () {
        expect(colorForResourceKind(''), AppColors.gray6);
      });

      test('Application (ArgoCD kind) returns gray6 default', () {
        // Application has an icon but no specific color mapping — falls to default
        expect(colorForResourceKind('Application'), AppColors.gray6);
      });
    });

    group('case sensitivity', () {
      test('lowercase deployment returns teal', () {
        expect(colorForResourceKind('deployment'), AppColors.teal);
      });

      test('uppercase POD returns healthy', () {
        expect(colorForResourceKind('POD'), AppColors.healthy);
      });

      test('mixed-case sErViCe returns outOfSync', () {
        expect(colorForResourceKind('sErViCe'), AppColors.outOfSync);
      });
    });
  });
}
