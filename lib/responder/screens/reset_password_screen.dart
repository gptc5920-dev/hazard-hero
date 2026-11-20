import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/responder_providers.dart';
import '../validation/responder_validators.dart';
import '../widgets/backend_connection_chip.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.uid,
    required this.token,
  });

  final String uid;
  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _showPassword = false;
  String? _error;

  bool get _hasLink => widget.uid.isNotEmpty && widget.token.isNotEmpty;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_hasLink || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(responderApiProvider)
          .resetPassword(
            uid: widget.uid,
            token: widget.token,
            newPassword: _password.text,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xff166534),
          ),
          title: const Text('Password reset complete'),
          content: const Text('You can now sign in with your new password.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continue to sign in'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/login');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: BackendConnectionChip(compact: true),
                      ),
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Color(0xfffce8ec),
                        foregroundColor: Color(0xffdd2d4a),
                        child: Icon(Icons.lock_reset_rounded, size: 32),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Reset your password',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose a new password for your responder account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xff76515b)),
                      ),
                      const SizedBox(height: 20),
                      if (!_hasLink)
                        const _ResetError(
                          message:
                              'This reset link is incomplete. Request a new link from the sign-in page.',
                        )
                      else if (_error != null)
                        _ResetError(message: _error!),
                      if (!_hasLink || _error != null)
                        const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        enabled: !_saving && _hasLink,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.password_rounded),
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: ResponderValidators.password,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmation,
                        enabled: !_saving && _hasLink,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                        validator: (value) => value != _password.text
                            ? 'Passwords do not match.'
                            : null,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _saving || !_hasLink ? null : _submit,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_reset_rounded),
                        label: Text(
                          _saving ? 'Resetting password...' : 'Reset password',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _saving ? null : () => context.go('/login'),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Back to sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResetError extends StatelessWidget {
  const _ResetError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}
