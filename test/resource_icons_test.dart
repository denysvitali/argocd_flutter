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
    group('workload kinds return cobalt', () {
      test('Deployment returns cobalt', () {
        expect(colorForResourceKind('Deployment'), AppColors.cobalt);
      });

      test('StatefulSet returns cobalt', () {
        expect(colorForResourceKind('StatefulSet'), AppColors.cobalt);
      });

      test('DaemonSet returns cobalt', () {
        expect(colorForResourceKind('DaemonSet'), AppColors.cobalt);
      });

      test('ReplicaSet returns cobalt', () {
        expect(colorForResourceKind('ReplicaSet'), AppColors.cobalt);
      });
    });

    group('pod kind returns teal', () {
      test('Pod returns teal', () {
        expect(colorForResourceKind('Pod'), AppColors.teal);
      });
    });

    group('networking kinds return amber', () {
      test('Service returns amber', () {
        expect(colorForResourceKind('Service'), AppColors.amber);
      });

      test('Ingress returns amber', () {
        expect(colorForResourceKind('Ingress'), AppColors.amber);
      });

      test('Endpoints returns amber', () {
        expect(colorForResourceKind('Endpoints'), AppColors.amber);
      });

      test('EndpointSlice returns amber', () {
        expect(colorForResourceKind('EndpointSlice'), AppColors.amber);
      });
    });

    group('config kinds return coral', () {
      test('ConfigMap returns coral', () {
        expect(colorForResourceKind('ConfigMap'), AppColors.coral);
      });

      test('Secret returns coral', () {
        expect(colorForResourceKind('Secret'), AppColors.coral);
      });
    });

    group('job kinds return grey', () {
      test('Job returns grey', () {
        expect(colorForResourceKind('Job'), AppColors.grey);
      });

      test('CronJob returns grey', () {
        expect(colorForResourceKind('CronJob'), AppColors.grey);
      });
    });

    group('storage kinds return greyLight', () {
      test('PersistentVolumeClaim returns greyLight', () {
        expect(colorForResourceKind('PersistentVolumeClaim'), AppColors.greyLight);
      });

      test('PersistentVolume returns greyLight', () {
        expect(colorForResourceKind('PersistentVolume'), AppColors.greyLight);
      });

      test('StorageClass returns greyLight', () {
        expect(colorForResourceKind('StorageClass'), AppColors.greyLight);
      });
    });

    group('RBAC kinds return amber', () {
      test('ServiceAccount returns amber', () {
        expect(colorForResourceKind('ServiceAccount'), AppColors.amber);
      });

      test('Role returns amber', () {
        expect(colorForResourceKind('Role'), AppColors.amber);
      });

      test('ClusterRole returns amber', () {
        expect(colorForResourceKind('ClusterRole'), AppColors.amber);
      });

      test('RoleBinding returns amber', () {
        expect(colorForResourceKind('RoleBinding'), AppColors.amber);
      });

      test('ClusterRoleBinding returns amber', () {
        expect(colorForResourceKind('ClusterRoleBinding'), AppColors.amber);
      });
    });

    group('cluster kinds return cobalt', () {
      test('Namespace returns cobalt', () {
        expect(colorForResourceKind('Namespace'), AppColors.cobalt);
      });

      test('Node returns cobalt', () {
        expect(colorForResourceKind('Node'), AppColors.cobalt);
      });
    });

    group('certificate kinds return teal', () {
      test('Certificate returns teal', () {
        expect(colorForResourceKind('Certificate'), AppColors.teal);
      });

      test('Issuer returns teal', () {
        expect(colorForResourceKind('Issuer'), AppColors.teal);
      });

      test('ClusterIssuer returns teal', () {
        expect(colorForResourceKind('ClusterIssuer'), AppColors.teal);
      });
    });

    group('event kind returns greyLight', () {
      test('Event returns greyLight', () {
        expect(colorForResourceKind('Event'), AppColors.greyLight);
      });
    });

    group('unknown kinds return grey default', () {
      test('unknown kind returns grey', () {
        expect(colorForResourceKind('SomeUnknownResource'), AppColors.grey);
      });

      test('empty string returns grey', () {
        expect(colorForResourceKind(''), AppColors.grey);
      });

      test('Application (ArgoCD kind) returns grey default', () {
        // Application has an icon but no specific color mapping — falls to default
        expect(colorForResourceKind('Application'), AppColors.grey);
      });
    });

    group('case sensitivity', () {
      test('lowercase deployment returns cobalt', () {
        expect(colorForResourceKind('deployment'), AppColors.cobalt);
      });

      test('uppercase POD returns teal', () {
        expect(colorForResourceKind('POD'), AppColors.teal);
      });

      test('mixed-case sErViCe returns amber', () {
        expect(colorForResourceKind('sErViCe'), AppColors.amber);
      });
    });
  });
}
