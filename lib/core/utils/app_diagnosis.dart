import 'package:argocd_flutter/core/models/argo_application.dart';

/// How bad an [AppIssue] is. Declaration order is display order.
enum IssueSeverity { error, warning, progressing }

/// One reason an application isn't healthy and synced.
class AppIssue {
  const AppIssue({
    required this.severity,
    required this.title,
    required this.status,
    this.detail,
    this.resource,
  });

  final IssueSeverity severity;

  /// Resource name, or a short label such as "Sync failed".
  final String title;

  /// Short state label shown next to the status dot ("Degraded", "Error").
  final String status;

  /// Why, in ArgoCD's words, when it said anything.
  final String? detail;

  /// The resource at fault, when the issue is about one.
  final ArgoResource? resource;
}

const Map<String, IssueSeverity> _resourceHealthSeverity =
    <String, IssueSeverity>{
      'degraded': IssueSeverity.error,
      'missing': IssueSeverity.warning,
      'progressing': IssueSeverity.progressing,
    };

/// Explains why [application] is not Healthy/Synced, most severe first.
///
/// [knownApplications] (the fleet list the controller already holds) is used
/// to explain child `Application` resources of an app-of-apps: ArgoCD gives
/// those no health message of their own, so the child's own top issue is
/// shown instead.
List<AppIssue> diagnoseApplication(
  ArgoApplication application, {
  List<ArgoApplication> knownApplications = const <ArgoApplication>[],
}) {
  final issues = <AppIssue>[];

  final healthMessage = application.healthMessage;
  if (!application.isHealthy && healthMessage != null) {
    issues.add(
      AppIssue(
        severity: IssueSeverity.error,
        title: 'Application health',
        status: application.healthStatus,
        detail: healthMessage,
      ),
    );
  }

  if (application.hasOperationError) {
    issues.add(
      AppIssue(
        severity: IssueSeverity.error,
        title: 'Last sync failed',
        status: application.operationPhase,
        detail: application.operationMessage,
      ),
    );
  }

  for (final condition in application.conditions) {
    if (!condition.isError && !condition.isWarning) {
      continue;
    }
    issues.add(
      AppIssue(
        severity: condition.isError
            ? IssueSeverity.error
            : IssueSeverity.warning,
        title: humanizeConditionType(condition.type),
        status: condition.isError ? 'Error' : 'Warning',
        detail: condition.message.isEmpty ? null : condition.message,
      ),
    );
  }

  final resourceIssues = <AppIssue>[];
  final outOfSync = application.isOutOfSync;
  for (final resource in application.resources) {
    final severity = resource.hasHealth
        ? _resourceHealthSeverity[resource.health.toLowerCase()]
        : null;
    final resourceOutOfSync =
        outOfSync && resource.status.toLowerCase() == 'outofsync';
    if (severity == null && !resourceOutOfSync) {
      continue;
    }
    resourceIssues.add(
      AppIssue(
        severity: severity ?? IssueSeverity.warning,
        title: resource.name,
        status: severity == null ? 'OutOfSync' : resource.health,
        detail: _resourceDetail(resource, knownApplications),
        resource: resource,
      ),
    );
  }
  resourceIssues.sort((a, b) {
    final bySeverity = a.severity.index.compareTo(b.severity.index);
    if (bySeverity != 0) {
      return bySeverity;
    }
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });

  return <AppIssue>[...issues, ...resourceIssues];
}

/// The single most useful line explaining what's wrong with [application],
/// or null when nothing is.
String? summarizeApplicationProblem(ArgoApplication application) {
  final issues = diagnoseApplication(application);
  if (issues.isEmpty) {
    return null;
  }
  final top = issues.first;
  final resource = top.resource;
  final String headline;
  if (resource == null) {
    headline = top.detail == null ? top.title : '${top.title}: ${top.detail}';
  } else {
    final who = '${resource.kind} ${resource.name}';
    headline = top.detail == null
        ? '$who is ${top.status}'
        : '$who: ${top.detail}';
  }

  final sameKind = issues
      .where((i) => i.resource != null && i.status == top.status)
      .length;
  if (resource != null && sameKind > 1) {
    return '$headline (+${sameKind - 1} more ${top.status.toLowerCase()})';
  }
  return headline;
}

/// "ComparisonError" → "Comparison error",
/// "OrphanedResourceWarning" → "Orphaned resource warning".
String humanizeConditionType(String type) {
  final words = type
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ')
      .split(' ');
  if (words.isEmpty) {
    return type;
  }
  return <String>[
    words.first,
    ...words.skip(1).map((w) => w.toLowerCase()),
  ].join(' ');
}

String? _resourceDetail(
  ArgoResource resource,
  List<ArgoApplication> knownApplications,
) {
  if (resource.healthMessage.isNotEmpty) {
    return resource.healthMessage;
  }
  if (resource.isApplication) {
    for (final child in knownApplications) {
      if (child.name == resource.name) {
        return summarizeApplicationProblem(child);
      }
    }
  }
  if (resource.status.toLowerCase() == 'outofsync') {
    return 'Live state differs from Git';
  }
  return null;
}
