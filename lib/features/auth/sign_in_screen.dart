import 'dart:math' as math;

import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/argo_logo.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
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
  bool _obscurePassword = true;
  bool _serverUrlRemembered = false;
  String? _dismissedError;

  @override
  void initState() {
    super.initState();
    final lastUrl = widget.controller.lastServerUrl;
    final lastUsername = widget.controller.lastUsername;
    _serverController.text = lastUrl;
    _usernameController.text = lastUsername;
    _serverUrlRemembered = lastUrl.isNotEmpty;
    _serverController.addListener(_onServerUrlChanged);
  }

  @override
  void dispose() {
    _serverController.removeListener(_onServerUrlChanged);
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onServerUrlChanged() {
    final matches =
        _serverController.text == widget.controller.lastServerUrl &&
        widget.controller.lastServerUrl.isNotEmpty;
    if (matches != _serverUrlRemembered) {
      setState(() {
        _serverUrlRemembered = matches;
      });
    }
  }

  InputDecoration _inputDecoration({
    required String labelText,
    String? hintText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final certificateStatus = widget.controller.certificateStatus;
    final errorMessage = widget.controller.errorMessage;
    final showError = errorMessage != null && errorMessage != _dismissedError;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              scheme.primaryContainer.withValues(alpha: 0.45),
              scheme.surface,
              scheme.tertiaryContainer.withValues(alpha: 0.30),
            ],
            stops: const <double>[0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Center(
                      child: ArgoLockup(
                        logoSize: 64,
                        subtitle: 'Deployment control plane',
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.55),
                        borderRadius: AppRadius.lg,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.bolt_rounded,
                            color: scheme.secondary,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Connect with a token-backed ArgoCD session.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: showError
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ErrorBanner(
                                message: errorMessage,
                                onDismiss: () {
                                  setState(() {
                                    _dismissedError = errorMessage;
                                  });
                                  widget.controller.clearError();
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: AppRadius.lg,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Connect to ArgoCD',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use your ArgoCD server URL and credentials.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _serverController,
                              decoration: _inputDecoration(
                                labelText: 'Server URL',
                                hintText: 'https://argocd.example.com',
                                prefixIcon: const Icon(Icons.cloud_outlined),
                                suffixIcon: _serverUrlRemembered
                                    ? Tooltip(
                                        message:
                                            'This URL was saved from your '
                                            'previous session and will be '
                                            'pre-filled on future sign-ins',
                                        child: Icon(
                                          Icons.bookmark_rounded,
                                          color: scheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.url,
                              validator: _serverValidator,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _usernameController,
                              decoration: _inputDecoration(
                                labelText: 'Username',
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter your ArgoCD username.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: _inputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      key: ValueKey<bool>(_obscurePassword),
                                      size: 20,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Enter your ArgoCD password.';
                                }
                                return null;
                              },
                            ),
                            if (certificateStatus != null) ...<Widget>[
                              const SizedBox(height: 16),
                              _CertificateBanner(
                                message: certificateStatus.message,
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
                                      : const Icon(Icons.network_ping_rounded),
                                  label: Text(
                                    _testingConnection
                                        ? 'Testing...'
                                        : 'Test server',
                                  ),
                                ),
                                _SignInButton(
                                  busy: widget.controller.busy,
                                  onPressed: _submit,
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

    setState(() {
      _dismissedError = null;
    });

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

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const _ShimmerIcon()
          : const Icon(Icons.arrow_forward_rounded),
      label: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          busy ? 'Connecting...' : 'Sign in',
          key: ValueKey<bool>(busy),
        ),
      ),
    );
  }
}

class _ShimmerIcon extends StatefulWidget {
  const _ShimmerIcon();

  @override
  State<_ShimmerIcon> createState() => _ShimmerIconState();
}

class _ShimmerIconState extends State<_ShimmerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final pulse =
            0.4 +
            0.6 *
                ((math.sin(_animationController.value * 2 * math.pi) + 1) / 2);
        return Opacity(opacity: pulse, child: child);
      },
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ErrorBanner extends StatefulWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<_ErrorBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: theme.colorScheme.errorContainer,
          borderRadius: AppRadius.md,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: widget.onDismiss,
                      child: Center(
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
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

class _CertificateBanner extends StatelessWidget {
  const _CertificateBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: AppRadius.base,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.verified_user_outlined,
            color: scheme.tertiary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
