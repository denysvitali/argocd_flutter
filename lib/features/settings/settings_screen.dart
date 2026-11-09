import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/health_monitor.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/shared_widgets.dart';
import 'package:flutter/material.dart';

/// iOS Settings palette for [IconWell] glyph backgrounds.
abstract final class _WellColors {
  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color indigo = Color(0xFF5856D6);
  static const Color orange = Color(0xFFFF9500);
  static const Color red = Color(0xFFFF3B30);
  static const Color pink = Color(0xFFFF2D55);
  static const Color teal = Color(0xFF30B0C7);
  static const Color gray = Color(0xFF8E8E93);
}

const double _sectionGap = 28;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    required this.themeController,
  });

  final AppController controller;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final monitor = controller.healthMonitor;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        controller,
        themeController,
        ?monitor,
      ]),
      builder: (BuildContext context, Widget? child) {
        final session = controller.session;
        final certificateStatus = controller.certificateStatus;
        final busy = controller.busy;
        final serverUrl = session?.serverUrl ?? controller.lastServerUrl;
        final savedServerDiffers =
            session != null &&
            controller.lastServerUrl.isNotEmpty &&
            controller.lastServerUrl != session.serverUrl;
        final username = session?.username.isNotEmpty == true
            ? session!.username
            : (controller.lastUsername.isNotEmpty
                  ? controller.lastUsername
                  : 'Signed out');

        return Scaffold(
          body: ListView(
            padding: kPagePadding,
            children: <Widget>[
              AppPageHeader(
                title: 'Settings',
                subtitle: session == null
                    ? 'Preferences and connection state'
                    : 'Connected as ${session.username}',
              ),
              const SizedBox(height: 20),
              _AccountCard(
                username: username,
                serverUrl: serverUrl,
                signedIn: session != null,
              ),
              const SizedBox(height: _sectionGap),
              GroupedList(
                header: 'Appearance',
                children: <Widget>[
                  for (final option in _themeOptions)
                    _CheckmarkRow(
                      label: option.label,
                      selected: themeController.themeMode == option.mode,
                      onTap: () => themeController.setThemeMode(option.mode),
                    ),
                ],
              ),
              if (monitor != null) ...<Widget>[
                const SizedBox(height: _sectionGap),
                _HealthMonitorSection(monitor: monitor),
              ],
              const SizedBox(height: _sectionGap),
              GroupedList(
                header: 'Connection',
                dividerIndent: 60,
                children: <Widget>[
                  GroupedRow(
                    leading: const IconWell(
                      icon: Icons.dns_rounded,
                      color: _WellColors.blue,
                    ),
                    title: 'Server',
                    trailing: _RowValue(_hostOf(serverUrl)),
                    onTap: busy ? null : () => _showServerDialog(context),
                    showChevron: true,
                  ),
                  if (savedServerDiffers)
                    GroupedRow(
                      leading: const IconWell(
                        icon: Icons.bookmark_rounded,
                        color: _WellColors.orange,
                      ),
                      title: 'Saved next server',
                      trailing: _RowValue(_hostOf(controller.lastServerUrl)),
                    ),
                  GroupedRow(
                    leading: const IconWell(
                      icon: Icons.lock_rounded,
                      color: _WellColors.green,
                    ),
                    title: 'Session',
                    trailing: _SessionState(connected: session != null),
                  ),
                  GroupedRow(
                    leading: const IconWell(
                      icon: Icons.wifi_tethering_rounded,
                      color: _WellColors.teal,
                    ),
                    title: 'Test connection',
                    onTap: busy ? null : () => _testConnection(context),
                    showChevron: false,
                  ),
                  GroupedRow(
                    leading: const IconWell(
                      icon: Icons.refresh_rounded,
                      color: _WellColors.indigo,
                    ),
                    title: 'Refresh applications',
                    onTap: busy ? null : () => controller.refreshApplications(),
                    showChevron: false,
                  ),
                  GroupedRow(
                    leading: const IconWell(
                      icon: Icons.folder_rounded,
                      color: _WellColors.gray,
                    ),
                    title: 'Refresh projects',
                    onTap: busy ? null : () => controller.refreshProjects(),
                    showChevron: false,
                  ),
                ],
              ),
              const SizedBox(height: _sectionGap),
              GroupedList(
                header: 'Certificates',
                footer:
                    certificateStatus?.message ??
                    'Loading certificate support...',
                dividerIndent: 60,
                children: <Widget>[
                  GroupedRow(
                    leading: const IconWell(
                      icon: Icons.verified_user_rounded,
                      color: _WellColors.green,
                    ),
                    title: 'User certificates',
                    trailing: _RowValue(
                      certificateStatus?.supported == true
                          ? 'Enabled'
                          : 'Unavailable',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _sectionGap),
              GroupedList(
                header: 'About',
                children: const <Widget>[
                  GroupedRow(
                    title: 'Application',
                    trailing: _RowValue('ArgoCD Flutter'),
                  ),
                  GroupedRow(title: 'Version', trailing: _RowValue('v1.0.0+1')),
                  GroupedRow(
                    title: 'Framework',
                    trailing: _RowValue('Flutter 3.38+'),
                  ),
                  GroupedRow(
                    title: 'Source',
                    trailing: _RowValue('github.com/argocd-flutter'),
                  ),
                ],
              ),
              const SizedBox(height: _sectionGap),
              GroupedList(
                children: <Widget>[
                  _CenteredActionRow(
                    label: 'Sign out',
                    onTap: busy ? null : () => _confirmSignOut(context),
                  ),
                ],
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out'),
          content: const Text(
            'Are you sure you want to sign out? You will need to '
            'enter your credentials again to reconnect.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await controller.signOut();
  }

  Future<void> _showServerDialog(BuildContext context) async {
    final textController = TextEditingController(
      text: controller.session?.serverUrl ?? controller.lastServerUrl,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update server URL'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'https://argocd.example.com',
            ),
            keyboardType: TextInputType.url,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      return;
    }

    await controller.updateServerUrl(textController.text);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          controller.session == null
              ? 'Server URL updated.'
              : 'Saved for the next sign-in. Your current session stays connected.',
        ),
      ),
    );
  }

  Future<void> _testConnection(BuildContext context) async {
    try {
      await controller.testConnection();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connection verified.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
  }

  String _errorText(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }
}

String _hostOf(String url) {
  if (url.isEmpty) {
    return 'Not set';
  }
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return url;
  }
  return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
}

String _initialsOf(String name) {
  final parts = name
      .split(RegExp(r'[\s._@-]+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

typedef _ThemeOption = ({String label, ThemeMode mode});

const List<_ThemeOption> _themeOptions = <_ThemeOption>[
  (label: 'System', mode: ThemeMode.system),
  (label: 'Light', mode: ThemeMode.light),
  (label: 'Dark', mode: ThemeMode.dark),
];

/// Apple ID-style account summary: monogram avatar, name and server.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.username,
    required this.serverUrl,
    required this.signedIn,
  });

  final String username;
  final String serverUrl;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Contacts-style neutral monogram, not the brand tint.
                gradient: signedIn
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0xFFA5A9B3), Color(0xFF858993)],
                      )
                    : null,
                color: signedIn ? null : AppColors.tertiaryLabel(theme),
              ),
              child: Text(
                signedIn ? _initialsOf(username) : '?',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  serverUrl.isEmpty ? 'No server configured' : serverUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selection row with a trailing tint checkmark (iOS single-choice list).
class _CheckmarkRow extends StatelessWidget {
  const _CheckmarkRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: GroupedRow(
        title: label,
        onTap: onTap,
        trailing: selected
            ? Icon(Icons.check_rounded, size: 22, color: scheme.primary)
            : const SizedBox(width: 22),
      ),
    );
  }
}

/// Connection status: a status dot followed by a muted label.
class _SessionState extends StatelessWidget {
  const _SessionState({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        StatusDot(color: connected ? AppColors.healthy : AppColors.degraded),
        const SizedBox(width: 7),
        Text(
          connected ? 'Authenticated' : 'No active session',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Destructive action row with a centered label (iOS "Sign Out").
class _CenteredActionRow extends StatelessWidget {
  const _CenteredActionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onTap == null
        ? AppColors.tertiaryLabel(theme)
        : theme.colorScheme.error;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Health monitoring section
// ---------------------------------------------------------------------------

class _HealthMonitorSection extends StatelessWidget {
  const _HealthMonitorSection({required this.monitor});

  final HealthMonitor monitor;

  static const _intervals = <int>[1, 2, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: monitor,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final interval = _closestInterval(monitor.pollInterval.inMinutes);

        return GroupedList(
          header: 'Health monitoring',
          footer: monitor.isPolling
              ? 'Polling active. Argo CD is checked every '
                    '${monitor.pollInterval.inMinutes} min for health and '
                    'sync changes.'
              : 'Detects degraded, recovered and drifted applications '
                    'while the app is open.',
          dividerIndent: 60,
          children: <Widget>[
            GroupedRow(
              leading: const IconWell(
                icon: Icons.monitor_heart_rounded,
                color: _WellColors.pink,
              ),
              title: 'Enable monitoring',
              subtitle: monitor.enabled
                  ? 'Polling every ${monitor.pollInterval.inMinutes} min'
                  : 'Disabled',
              trailing: Switch(
                value: monitor.enabled,
                onChanged: (value) => monitor.setEnabled(value),
              ),
            ),
            if (monitor.enabled) ...<Widget>[
              GroupedRow(
                leading: const IconWell(
                  icon: Icons.timer_rounded,
                  color: _WellColors.orange,
                ),
                title: 'Poll interval',
                trailing: PopupMenuButton<int>(
                  tooltip: 'Poll interval',
                  initialValue: interval,
                  onSelected: (value) =>
                      monitor.setPollInterval(Duration(minutes: value)),
                  itemBuilder: (context) => <PopupMenuEntry<int>>[
                    for (final minutes in _intervals)
                      CheckedPopupMenuItem<int>(
                        value: minutes,
                        checked: minutes == interval,
                        child: Text('$minutes min'),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '$interval min',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.unfold_more_rounded,
                        size: 18,
                        color: AppColors.tertiaryLabel(theme),
                      ),
                    ],
                  ),
                ),
              ),
              GroupedRow(
                leading: const IconWell(
                  icon: Icons.notifications_active_rounded,
                  color: _WellColors.red,
                ),
                title: 'Active events',
                subtitle: monitor.events.isEmpty
                    ? 'No events detected'
                    : '${monitor.events.length} event(s)',
                trailing: monitor.events.isNotEmpty
                    ? TextButton(
                        onPressed: () => monitor.acknowledgeAll(),
                        child: const Text('Clear'),
                      )
                    : null,
              ),
              if (monitor.mutedApps.isNotEmpty)
                GroupedRow(
                  leading: const IconWell(
                    icon: Icons.notifications_off_rounded,
                    color: _WellColors.gray,
                  ),
                  title: 'Muted apps',
                  subtitle: monitor.mutedApps.join(', '),
                  trailing: TextButton(
                    onPressed: () {
                      for (final app in monitor.mutedApps.toList()) {
                        monitor.unmuteApp(app);
                      }
                    },
                    child: const Text('Unmute all'),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  int _closestInterval(int minutes) {
    return _intervals.reduce(
      (a, b) => (a - minutes).abs() < (b - minutes).abs() ? a : b,
    );
  }
}

/// Muted trailing value for a [GroupedRow] that hugs its content so the
/// title keeps the remaining width.
class _RowValue extends StatelessWidget {
  const _RowValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 210),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
