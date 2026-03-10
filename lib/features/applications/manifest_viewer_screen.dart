import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManifestViewerScreen extends StatefulWidget {
  const ManifestViewerScreen({
    super.key,
    required this.controller,
    required this.applicationName,
    required this.namespace,
    required this.resourceName,
    required this.kind,
    required this.group,
    required this.version,
  });

  final AppController controller;
  final String applicationName;
  final String namespace;
  final String resourceName;
  final String kind;
  final String group;
  final String version;

  @override
  State<ManifestViewerScreen> createState() => _ManifestViewerScreenState();
}

class _ManifestViewerScreenState extends State<ManifestViewerScreen> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadManifest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.kind}: ${widget.resourceName}'),
        actions: <Widget>[
          FutureBuilder<String>(
            future: _future,
            builder: (context, snapshot) {
              return IconButton(
                tooltip: 'Copy',
                onPressed: snapshot.hasData
                    ? () => _copyManifest(snapshot.requireData)
                    : null,
                icon: const Icon(Icons.copy),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshManifest,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refreshManifest,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final manifest = snapshot.requireData;
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: AppColors.ink,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  manifest,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: AppColors.border,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String> _loadManifest() {
    return widget.controller.fetchResourceManifest(
      applicationName: widget.applicationName,
      namespace: widget.namespace,
      resourceName: widget.resourceName,
      kind: widget.kind,
      group: widget.group,
      version: widget.version,
    );
  }

  void _refreshManifest() {
    setState(() {
      _future = _loadManifest();
    });
  }

  Future<void> _copyManifest(String manifest) async {
    await Clipboard.setData(ClipboardData(text: manifest));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}
