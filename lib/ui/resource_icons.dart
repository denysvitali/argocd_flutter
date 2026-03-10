import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

IconData iconForResourceKind(String kind) {
  return switch (kind.toLowerCase()) {
    'pod' => Icons.widgets,
    'deployment' => Icons.rocket_launch,
    'replicaset' => Icons.copy_all,
    'service' => Icons.language,
    'configmap' => Icons.settings,
    'secret' => Icons.lock,
    'ingress' => Icons.alt_route,
    'statefulset' => Icons.storage,
    'daemonset' => Icons.device_hub,
    'job' => Icons.work,
    'cronjob' => Icons.schedule,
    'persistentvolumeclaim' || 'persistentvolume' => Icons.inventory_2,
    'namespace' => Icons.folder,
    'serviceaccount' => Icons.person,
    'role' || 'clusterrole' => Icons.admin_panel_settings,
    'rolebinding' || 'clusterrolebinding' => Icons.link,
    'horizontalpodautoscaler' => Icons.speed,
    'networkpolicy' => Icons.security,
    'endpoints' => Icons.hub,
    _ => Icons.dns,
  };
}

Color colorForResourceKind(String kind) {
  return switch (kind.toLowerCase()) {
    'pod' => AppColors.teal,
    'deployment' => AppColors.cobalt,
    'replicaset' => AppColors.cobalt,
    'service' => AppColors.amber,
    'configmap' => AppColors.grey,
    'secret' => AppColors.coral,
    'ingress' => AppColors.amber,
    'statefulset' => AppColors.cobalt,
    'daemonset' => AppColors.cobalt,
    'job' || 'cronjob' => AppColors.amber,
    'persistentvolumeclaim' || 'persistentvolume' => AppColors.teal,
    'namespace' => AppColors.grey,
    'serviceaccount' => AppColors.grey,
    'role' || 'clusterrole' => AppColors.coral,
    'rolebinding' || 'clusterrolebinding' => AppColors.coral,
    _ => AppColors.grey,
  };
}
