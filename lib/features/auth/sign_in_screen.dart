import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:flutter/material.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    _serverController.text = widget.controller.lastServerUrl;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final certificateStatus = widget.controller.certificateStatus;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF4F7FB),
              Color(0xFFE8F0FF),
              Color(0xFFFFF2E8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: const Color(0xFF0E1726),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'ArgoCD Flutter',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sign in to your ArgoCD control plane, persist '
                            'your session locally, and inspect application '
                            'health from the same shell.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFFD8E5FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Connect to ArgoCD',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _serverController,
                              decoration: const InputDecoration(
                                labelText: 'Server URL',
                                hintText: 'https://argocd.example.com',
                                prefixIcon: Icon(Icons.cloud_outlined),
                              ),
                              keyboardType: TextInputType.url,
                              validator: _serverValidator,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter your ArgoCD username.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Enter your ArgoCD password.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 18),
                            if (certificateStatus != null)
                              _CertificateBanner(
                                message: certificateStatus.message,
                              ),
                            if (widget.controller.errorMessage !=
                                null) ...<Widget>[
                              const SizedBox(height: 16),
                              Text(
                                widget.controller.errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: <Widget>[
                                OutlinedButton.icon(
                                  onPressed:
                                      widget.controller.busy ||
                                          _testingConnection
                                      ? null
                                      : _testConnection,
                                  icon: _testingConnection
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.network_ping),
                                  label: Text(
                                    _testingConnection
                                        ? 'Testing...'
                                        : 'Test server',
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: widget.controller.busy
                                      ? null
                                      : _submit,
                                  icon: widget.controller.busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.login),
                                  label: Text(
                                    widget.controller.busy
                                        ? 'Connecting...'
                                        : 'Sign In',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await widget.controller.signIn(
        serverUrl: _serverController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }
  }

  Future<void> _testConnection() async {
    if (!_validateServerOnly()) {
      return;
    }

    setState(() {
      _testingConnection = true;
    });

    try {
      await widget.controller.testConnection(_serverController.text);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Connection verified.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    } finally {
      if (mounted) {
        setState(() {
          _testingConnection = false;
        });
      }
    }
  }

  bool _validateServerOnly() {
    final validator = _serverValidator(_serverController.text);
    if (validator == null) {
      return true;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(validator)));
    return false;
  }

  String? _serverValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter the ArgoCD server URL.';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid HTTP or HTTPS URL.';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Only HTTP and HTTPS URLs are supported.';
    }
    return null;
  }

  String _errorText(Object error) {
    final raw = error.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }
}

class _CertificateBanner extends StatelessWidget {
  const _CertificateBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.verified_user_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
