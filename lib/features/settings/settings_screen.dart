import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

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
            title: 'Connection',
            children: <Widget>[
              _Row(
                label: 'Server',
                value: session?.serverUrl ?? controller.lastServerUrl,
              ),
              _Row(label: 'Username', value: session?.username ?? 'Signed out'),
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
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2EAF3)),
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
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: const Color(0xFF68788B)),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
