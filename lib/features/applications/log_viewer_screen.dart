import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({
    super.key,
    required this.controller,
    required this.applicationName,
    required this.namespace,
    required this.podName,
    required this.containerName,
  });

  final AppController controller;
  final String applicationName;
  final String namespace;
  final String podName;
  final String containerName;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  late Future<String> _future;
  String? _lastLoadedLogs;

  @override
  void initState() {
    super.initState();
    _future = _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.podName}/${widget.containerName}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: _copyLogs,
            icon: const Icon(Icons.copy_all),
            label: const Text('Copy'),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF0E1726),
        child: FutureBuilder<String>(
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
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final logs = snapshot.requireData;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                logs.isEmpty ? 'No logs returned.' : logs,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Color(0xFF14B8A6),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<String> _loadLogs() async {
    final logs = await widget.controller.fetchResourceLogs(
      applicationName: widget.applicationName,
      namespace: widget.namespace,
      podName: widget.podName,
      containerName: widget.containerName,
    );
    _lastLoadedLogs = logs;
    return logs;
  }

  void _refresh() {
    setState(() {
      _future = _loadLogs();
    });
  }

  Future<void> _copyLogs() async {
    final logs = _lastLoadedLogs;
    if (logs == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logs are still loading.')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: logs));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logs copied.')));
  }
}
