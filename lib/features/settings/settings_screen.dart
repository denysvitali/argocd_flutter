import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

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
    final session = controller.session;
    final certificateStatus = controller.certificateStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: <Widget>[
          _SectionCard(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: <Widget>[
              _ThemePicker(themeController: themeController),
            ],
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Connection',
            icon: Icons.cloud_outlined,
            children: <Widget>[
              _ConnectionTile(
                icon: Icons.dns_outlined,
                title: 'Server',
                subtitle:
                    session?.serverUrl ?? controller.lastServerUrl,
                trailing: _ConnectionDot(
                  connected: session != null,
                ),
              ),
              const Divider(height: 1),
              _ConnectionTile(
                icon: Icons.person_outline,
                title: 'Username',
                subtitle: session?.username ?? 'Signed out',
              ),
              const Divider(height: 1),
              _ConnectionTile(
                icon: Icons.wifi_outlined,
                title: 'Session state',
                subtitle:
                    session == null ? 'No active session' : 'Authenticated',
                trailing: _ConnectionDot(connected: session != null),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _showServerDialog(context),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit server'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _testConnection(context),
                    icon: const Icon(Icons.network_ping, size: 18),
                    label: const Text('Test connection'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => controller.refreshProjects(),
                    icon: const Icon(Icons.sync_outlined, size: 18),
                    label: const Text('Refresh projects'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Certificates',
            icon: Icons.verified_user_outlined,
            children: <Widget>[
              _ConnectionTile(
                icon: Icons.security_outlined,
                title: 'Support',
                subtitle: certificateStatus?.supported == true
                    ? 'Enabled'
                    : 'Unavailable',
              ),
              const Divider(height: 1),
              _ConnectionTile(
                icon: Icons.info_outline,
                title: 'Details',
                subtitle:
                    certificateStatus?.message ??
                    'Loading certificate support...',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'Actions',
            icon: Icons.bolt_outlined,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => controller.refreshApplications(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh applications'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    side: const BorderSide(
                      color: AppColors.coral,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SectionCard(
            title: 'About',
            icon: Icons.info_outline,
            children: <Widget>[
              _ConnectionTile(
                icon: Icons.apps_outlined,
                title: 'Application',
                subtitle: 'ArgoCD Flutter',
              ),
              const Divider(height: 1),
              _ConnectionTile(
                icon: Icons.flutter_dash_outlined,
                title: 'Framework',
                subtitle: 'Flutter 3.38+',
              ),
              const Divider(height: 1),
              _ConnectionTile(
                icon: Icons.code_outlined,
                title: 'Source',
                subtitle: 'github.com/argocd-flutter',
              ),
              const SizedBox(height: 8),
              const _VersionBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.logout),
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
            FilledButton(
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
      const SnackBar(
        content: Text(
          'Server URL updated. Sign in again to connect to the new server.',
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

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentMode = themeController.themeMode;

    return Row(
      children: <Widget>[
        Expanded(
          child: _ThemeCard(
            icon: Icons.brightness_auto_outlined,
            label: 'System',
            selected: currentMode == ThemeMode.system,
            onTap: () => themeController.setThemeMode(ThemeMode.system),
            theme: theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ThemeCard(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            selected: currentMode == ThemeMode.light,
            onTap: () => themeController.setThemeMode(ThemeMode.light),
            theme: theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ThemeCard(
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            selected: currentMode == ThemeMode.dark,
            onTap: () => themeController.setThemeMode(ThemeMode.dark),
            theme: theme,
          ),
        ),
      ],
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? theme.colorScheme.primary
        : theme.dividerColor;
    final backgroundColor = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: borderColor,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: <Widget>[
                Stack(
                  alignment: Alignment.topRight,
                  children: <Widget>[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        icon,
                        key: ValueKey<bool>(selected),
                        size: 28,
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.teal : AppColors.coral;

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: connected
              ? <BoxShadow>[
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.tag_outlined,
              size: 14,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'v1.0.0+1',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
