import 'package:argocd_flutter/core/models/argo_application.dart';
import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/last_updated_text.dart';
import 'package:flutter/material.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({
    super.key,
    required this.controller,
    required this.onOpenApplication,
  });

  final AppController controller;
  final ValueChanged<String> onOpenApplication;

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final allApplications = widget.controller.applications;
    final unhealthyCount = allApplications
        .where((application) => !application.isHealthy)
        .length;
    final outOfSyncCount = allApplications
        .where((application) => application.isOutOfSync)
        .length;
    final applications = widget.controller.applications
        .where((application) {
          if (normalizedQuery.isEmpty) {
            return true;
          }

          return application.name.toLowerCase().contains(normalizedQuery) ||
              application.project.toLowerCase().contains(normalizedQuery) ||
              application.namespace.toLowerCase().contains(normalizedQuery);
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: widget.controller.busy
                ? null
                : () => widget.controller.refreshApplications(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => widget.controller.refreshApplications(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            LastUpdatedText(timestamp: widget.controller.lastRefreshedAt),
            _OverviewStrip(
              controller: widget.controller,
              totalApplications: allApplications.length,
              unhealthyCount: unhealthyCount,
              outOfSyncCount: outOfSyncCount,
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Filter applications',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
            const SizedBox(height: 20),
            if (widget.controller.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  widget.controller.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (widget.controller.loadingApplications &&
                !widget.controller.hasLoadedApplications)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (applications.isEmpty)
              _EmptyState(
                filtered: normalizedQuery.isNotEmpty,
                hasApps: widget.controller.applications.isNotEmpty,
              )
            else
              ...applications.map(
                (application) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ApplicationCard(
                    application: application,
                    onTap: () => widget.onOpenApplication(application.name),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({
    required this.controller,
    required this.totalApplications,
    required this.unhealthyCount,
    required this.outOfSyncCount,
  });

  final AppController controller;
  final int totalApplications;
  final int unhealthyCount;
  final int outOfSyncCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = controller.session;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF0E1726),
            Color(0xFF183153),
            Color(0xFF1F6FEB),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Control plane overview',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            session == null
                ? 'Connect to ArgoCD to inspect application health.'
                : 'Signed in as ${session.username} on ${session.serverUrl}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFD8E5FF),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _MetricChip(label: 'Applications', value: '$totalApplications'),
              _MetricChip(label: 'Out of sync', value: '$outOfSyncCount'),
              _MetricChip(label: 'Degraded', value: '$unhealthyCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFD8E5FF)),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});

  final ArgoApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    application.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(
                  label: application.syncStatus,
                  color: application.isOutOfSync
                      ? const Color(0xFFFF6B57)
                      : const Color(0xFF1F6FEB),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: application.healthStatus,
                  color: application.isHealthy
                      ? const Color(0xFF14B8A6)
                      : const Color(0xFFFFC857),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${application.project} • ${application.namespace}',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              application.repoUrl,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _FactBadge(icon: Icons.route_outlined, label: application.path),
                _FactBadge(
                  icon: Icons.commit_outlined,
                  label: application.targetRevision,
                ),
                _FactBadge(icon: Icons.public, label: application.cluster),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.24 : 0.12,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FactBadge extends StatelessWidget {
  const _FactBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.hasApps});

  final bool filtered;
  final bool hasApps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = filtered
        ? 'No applications match this filter'
        : hasApps
        ? 'No applications visible'
        : 'No applications loaded';
    final subtitle = filtered
        ? 'Clear or change the filter to see more applications.'
        : hasApps
        ? 'Your RBAC scope or current project access may be limiting the '
              'visible applications.'
        : 'Connect to ArgoCD, then pull to refresh once your RBAC scope has '
              'visible applications.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(subtitle),
        ],
      ),
    );
  }
}
