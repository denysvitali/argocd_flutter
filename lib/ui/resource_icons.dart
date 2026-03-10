import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

IconData iconForResourceKind(String kind) {
  return switch (kind.toLowerCase()) {
    'application' => Icons.apps,
    'deployment' => Icons.rocket_launch,
    'replicaset' => Icons.view_module,
    'statefulset' => Icons.view_column,
    'daemonset' => Icons.developer_board,
    'job' => Icons.work_outline,
    'cronjob' => Icons.schedule,
    'pod' => Icons.memory,
    'service' => Icons.dns,
    'ingress' => Icons.public,
    'configmap' => Icons.description,
    'secret' => Icons.lock,
    'persistentvolumeclaim' || 'persistentvolume' => Icons.storage,
    'serviceaccount' => Icons.account_circle,
    'role' || 'clusterrole' => Icons.admin_panel_settings,
    'rolebinding' || 'clusterrolebinding' => Icons.link,
    'namespace' => Icons.folder,
    'node' => Icons.computer,
    'horizontalpodautoscaler' => Icons.auto_graph,
    'networkpolicy' => Icons.security,
    'endpoints' || 'endpointslice' => Icons.lan,
    'certificate' => Icons.verified_user,
    _ => Icons.widgets,
  };
}

Color colorForResourceKind(String kind) {
  return switch (kind.toLowerCase()) {
    'application' => AppColors.cobalt,
    'deployment' || 'statefulset' || 'daemonset' => AppColors.cobalt,
    'replicaset' => AppColors.cobalt,
    'pod' => AppColors.teal,
    'service' || 'ingress' || 'endpoints' || 'endpointslice' => AppColors.coral,
    'configmap' || 'secret' => AppColors.amber,
    'job' || 'cronjob' => AppColors.grey,
    'persistentvolumeclaim' || 'persistentvolume' => AppColors.coral,
    'serviceaccount' || 'role' || 'clusterrole' ||
    'rolebinding' || 'clusterrolebinding' => AppColors.grey,
    'namespace' => AppColors.cobalt,
    'node' => AppColors.teal,
    'horizontalpodautoscaler' => AppColors.amber,
    'networkpolicy' || 'certificate' => AppColors.grey,
    _ => AppColors.greyLight,
  };
}
