import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

IconData iconForResourceKind(String kind) {
  return switch (kind.toLowerCase()) {
    'application' => Icons.apps,
    'deployment' => Icons.rocket_launch_outlined,
    'replicaset' => Icons.view_module_outlined,
    'statefulset' => Icons.view_column_outlined,
    'daemonset' => Icons.developer_board_outlined,
    'job' => Icons.work_outline,
    'cronjob' => Icons.schedule_outlined,
    'pod' => Icons.memory_outlined,
    'service' => Icons.hub_outlined,
    'ingress' => Icons.language_outlined,
    'networkpolicy' => Icons.shield_outlined,
    'configmap' => Icons.tune_outlined,
    'secret' => Icons.vpn_key_outlined,
    'persistentvolumeclaim' || 'persistentvolume' => Icons.storage_outlined,
    'storageclass' => Icons.inventory_2_outlined,
    'serviceaccount' => Icons.badge_outlined,
    'role' || 'clusterrole' => Icons.admin_panel_settings_outlined,
    'rolebinding' || 'clusterrolebinding' => Icons.link_outlined,
    'namespace' => Icons.folder_outlined,
    'node' => Icons.dns_outlined,
    'horizontalpodautoscaler' => Icons.auto_graph_outlined,
    'verticalpodautoscaler' => Icons.trending_up_outlined,
    'poddisruptionbudget' => Icons.health_and_safety_outlined,
    'limitrange' || 'resourcequota' => Icons.data_usage_outlined,
    'endpoints' || 'endpointslice' => Icons.electrical_services_outlined,
    'certificate' || 'issuer' || 'clusterissuer' => Icons.verified_outlined,
    'customresourcedefinition' => Icons.extension_outlined,
    'mutatingwebhookconfiguration' ||
    'validatingwebhookconfiguration' => Icons.webhook_outlined,
    'event' => Icons.event_note_outlined,
    _ => Icons.widgets_outlined,
  };
}

Color colorForResourceKind(String kind) {
  return switch (kind.toLowerCase()) {
    'deployment' || 'statefulset' || 'daemonset' => AppColors.cobalt,
    'replicaset' => AppColors.cobalt,
    'pod' => AppColors.teal,
    'service' || 'ingress' || 'endpoints' || 'endpointslice' => AppColors.amber,
    'configmap' || 'secret' => AppColors.coral,
    'job' || 'cronjob' => AppColors.grey,
    'persistentvolumeclaim' ||
    'persistentvolume' ||
    'storageclass' => AppColors.greyLight,
    'serviceaccount' ||
    'role' ||
    'clusterrole' ||
    'rolebinding' ||
    'clusterrolebinding' => AppColors.amber,
    'namespace' || 'node' => AppColors.cobalt,
    'certificate' || 'issuer' || 'clusterissuer' => AppColors.teal,
    'event' => AppColors.greyLight,
    _ => AppColors.grey,
  };
}
