import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/core/services/theme_controller.dart';
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
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          _SectionCard(
            title: 'Appearance',
            children: <Widget>[
              SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: <ThemeMode>{themeController.themeMode},
                onSelectionChanged: (selection) {
                  final mode = selection.first;
                  themeController.setThemeMode(mode);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Connection',
            children: <Widget>[
              _Row(
                label: 'Server',
                value: session?.serverUrl ?? controller.lastServerUrl,
              ),
              _Row(label: 'Username', value: session?.username ?? 'Signed out'),
              _Row(
                label: 'Session state',
                value: session == null ? 'No active session' : 'Authenticated',
              ),
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
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Certificates',
            children: <Widget>[
              _Row(
                label: 'Support',
                value: certificateStatus?.supported == true
                    ? 'Enabled'
                    : 'Unavailable',
              ),
              _Row(
                label: 'Details',
                value:
                    certificateStatus?.message ??
                    'Loading certificate support...',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Actions',
            children: <Widget>[
              FilledButton.icon(
                onPressed: controller.busy
                    ? null
                    : () => controller.refreshApplications(),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh applications'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: controller.busy ? null : () => controller.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
    );
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
