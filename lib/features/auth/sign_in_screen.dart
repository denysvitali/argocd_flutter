import 'package:argocd_flutter/core/services/app_controller.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
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

  /// Borderless field decoration for rows inside the inset-grouped form card.
  InputDecoration _fieldDecoration(
    ThemeData theme, {
    required String labelText,
    String? hintText,
    Widget? suffixIcon,
  }) {
    const none = InputBorder.none;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: false,
      border: none,
      enabledBorder: none,
      focusedBorder: none,
      errorBorder: none,
      focusedErrorBorder: none,
      disabledBorder: none,
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      floatingLabelStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final certificateStatus = widget.controller.certificateStatus;
    final errorMessage = widget.controller.errorMessage;
    final showError = errorMessage != null && errorMessage != _dismissedError;
    final busy = widget.controller.busy;
    final secondaryDisabled = busy || _testingConnection;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: ArgoLogo(size: 64)),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      'Sign in to Argo CD',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use your Argo CD account or single sign-on.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Material(
                        color: scheme.surfaceContainerLow,
                        borderRadius: AppRadius.md,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            TextFormField(
                              controller: _serverController,
                              decoration: _fieldDecoration(
                                theme,
                                labelText: 'Server URL',
                                hintText: 'https://argocd.example.com',
                                suffixIcon: _serverUrlRemembered
                                    ? Tooltip(
                                        message:
                                            'This URL was saved from your '
                                            'previous session and will be '
                                            'pre-filled on future sign-ins',
                                        child: Icon(
                                          Icons.bookmark_rounded,
                                          size: 18,
                                          color: scheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const <String>[AutofillHints.url],
                              validator: _serverValidator,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                            ),
                            const _FieldSeparator(),
                            TextFormField(
                              controller: _usernameController,
                              decoration: _fieldDecoration(
                                theme,
                                labelText: 'Username',
                              ),
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const <String>[
                                AutofillHints.username,
                              ],
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Enter your ArgoCD username.';
                                }
                                return null;
                              },
                            ),
                            const _FieldSeparator(),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const <String>[
                                AutofillHints.password,
                              ],
                              onFieldSubmitted: (_) {
                                if (!busy && !_testingConnection) {
                                  _submit();
                                }
                              },
                              decoration: _fieldDecoration(
                                theme,
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: AppColors.tertiaryLabel(theme),
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
                          ],
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: showError
                        ? _InlineError(
                            message: errorMessage,
                            onDismiss: () {
                              setState(() {
                                _dismissedError = errorMessage;
                              });
                              widget.controller.clearError();
                            },
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (certificateStatus != null)
                    _Footnote(message: certificateStatus.message),
                  const SizedBox(height: 24),
                  _SignInButton(
                    busy: busy,
                    enabled: !_testingConnection,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: secondaryDisabled ? null : _submitSso,
                    child: const Text('Sign in with SSO'),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: secondaryDisabled ? null : _testConnection,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_testingConnection) ...<Widget>[
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _testingConnection ? 'Testing...' : 'Test server',
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

  Future<void> _submitSso() async {
    if (!_validateServerOnly()) {
      return;
    }

    setState(() {
      _dismissedError = null;
    });

    try {
      await widget.controller.signInWithSso(serverUrl: _serverController.text);
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
  const _SignInButton({
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: busy || !enabled ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: busy
            ? Row(
                key: const ValueKey<bool>(true),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Connecting...'),
                ],
              )
            : const Text('Sign in', key: ValueKey<bool>(false)),
      ),
    );
  }
}

/// Inset hairline between rows of the grouped form card.
class _FieldSeparator extends StatelessWidget {
  const _FieldSeparator();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 16,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// Muted footnote beneath the form (certificate trust note).
class _Footnote extends StatelessWidget {
  const _Footnote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: ExcludeSemantics(
              child: Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.tertiaryLabel(theme),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline red footnote describing the last sign-in failure.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.statusForeground(theme, theme.colorScheme.error);

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: ExcludeSemantics(
                child: Icon(Icons.error_rounded, size: 15, color: color),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
            const SizedBox(width: 4),
            InkResponse(
              onTap: onDismiss,
              radius: 14,
              child: Tooltip(
                message: 'Dismiss',
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.tertiaryLabel(theme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
