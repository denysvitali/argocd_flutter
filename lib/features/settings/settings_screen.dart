import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: <Widget>[
          _SectionCard(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: <Widget>[
              _ThemePicker(themeController: themeController),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _showServerDialog(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit server'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _testConnection(context),
                    icon: const Icon(Icons.network_ping),
                    label: const Text('Test connection'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => controller.refreshProjects(),
                    icon: const Icon(Icons.sync_outlined),
                    label: const Text('Refresh projects'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'Actions',
            icon: Icons.bolt_outlined,
            children: <Widget>[
              FilledButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => controller.refreshApplications(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh applications'),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => _confirmSignOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
                icon: Icons.tag_outlined,
                title: 'Version',
                subtitle: '1.0.0+1',
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
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _ThemeCard(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            selected: currentMode == ThemeMode.light,
            onTap: () => themeController.setThemeMode(ThemeMode.light),
            theme: theme,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
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
        ? theme.colorScheme.primary.withValues(alpha: AppOpacity.light)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: AppOpacity.heavy);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: backgroundColor,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.md,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.md,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: Column(
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
                const SizedBox(height: AppSpacing.md),
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
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.md,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 22,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
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
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? AppColors.teal : AppColors.coral,
      ),
    );
  }
}
