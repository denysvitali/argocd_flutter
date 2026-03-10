import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
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
    _serverController.text = lastUrl;
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
    final matches = _serverController.text == widget.controller.lastServerUrl &&
        widget.controller.lastServerUrl.isNotEmpty;
    if (matches != _serverUrlRemembered) {
      setState(() {
        _serverUrlRemembered = matches;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final certificateStatus = widget.controller.certificateStatus;
    final errorMessage = widget.controller.errorMessage;
    final showError = errorMessage != null && errorMessage != _dismissedError;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.canvas,
              AppColors.blueLight,
              AppColors.peach,
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
                    // Logo / branding area
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: AppColors.ink,
                      ),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.cobalt.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.cloud_sync_outlined,
                              size: 36,
                              color: AppColors.cobalt,
                            ),
                          ),
                          const SizedBox(height: 20),
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
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textOnDarkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Error banner
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
                    // Form card
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
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _serverController,
                              decoration: InputDecoration(
                                labelText: 'Server URL',
                                hintText: 'https://argocd.example.com',
                                prefixIcon:
                                    const Icon(Icons.cloud_outlined),
                                suffixIcon: _serverUrlRemembered
                                    ? Tooltip(
                                        message: 'Server URL remembered '
                                            'from last session',
                                        child: Icon(
                                          Icons.bookmark,
                                          color: theme.colorScheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.url,
                              validator: _serverValidator,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
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
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                ),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const _ShimmerIcon()
            : const Icon(Icons.login),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            busy ? 'Connecting...' : 'Sign In',
            key: ValueKey<bool>(busy),
          ),
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
      duration: const Duration(milliseconds: 1200),
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
        return Opacity(
          opacity: 0.3 + 0.7 * _animationController.value,
          child: child,
        );
      },
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.close,
                size: 20,
                color: theme.colorScheme.onErrorContainer,
              ),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Dismiss',
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvasSubtle,
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
