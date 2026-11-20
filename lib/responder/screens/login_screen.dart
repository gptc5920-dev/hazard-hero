import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/responder_providers.dart';
import '../validation/responder_validators.dart';

class ResponderLoginScreen extends ConsumerStatefulWidget {
  const ResponderLoginScreen({super.key, this.admin = false});
  final bool admin;

  @override
  ConsumerState<ResponderLoginScreen> createState() => _ResponderLoginState();
}

class _ResponderLoginState extends ConsumerState<ResponderLoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool hidden = true;
  bool remember = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final formPanel = Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 40 : 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _loginCard(auth),
              ),
            ),
          );
          if (!wide) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xfffce8ec), Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: formPanel,
            );
          }
          return Row(
            children: [
              if (widget.admin)
                const Expanded(flex: 5, child: _LoginStoryPanel()),
              Expanded(flex: 4, child: formPanel),
            ],
          );
        },
      ),
    );
  }

  Widget _loginCard(AuthState auth) {
    final card = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                widget.admin ? 'Hazard Hero Admin' : 'Hazard Hero Responder',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              AutoSizeText(
                widget.admin
                    ? 'Welcome back, administrator'
                    : 'Welcome back, responder',
                maxLines: 1,
                minFontSize: 20,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                widget.admin
                    ? 'Sign in to manage alerts and public preparedness content.'
                    : 'Sign in for emergency information and your equipment inventory.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: ResponderValidators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: password,
                obscureText: hidden,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(auth),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(
                      hidden ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (value.length > 128) {
                    return 'Password must be 128 characters or fewer';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Checkbox(
                    value: remember,
                    onChanged: (value) =>
                        setState(() => remember = value ?? true),
                  ),
                  const Expanded(child: Text('Remember this session')),
                  TextButton(
                    onPressed: () => _forgot(context),
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: auth.loading ? null : () => _submit(auth),
                icon: auth.loading
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(auth.loading ? 'Signing in…' : 'Sign in securely'),
              ),
              if (!widget.admin) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: auth.loading ? null : () => context.go('/signup'),
                  child: const Text('New responder? Sign up'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return card;
  }

  void _submit(AuthState auth) {
    if (auth.loading || !(form.currentState?.validate() ?? false)) return;
    ref
        .read(authProvider.notifier)
        .login(email.text.trim(), password.text, remember: remember);
  }

  Future<void> _forgot(BuildContext context) async {
    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: email.text,
        onSubmit: ref.read(responderApiProvider).forgotPassword,
      ),
    );
    if (sent == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If that account exists, password reset instructions were sent.',
          ),
        ),
      );
    }
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onSubmit,
  });

  final String initialEmail;
  final Future<void> Function(String email) onSubmit;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _email;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_email.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(Icons.mark_email_read_outlined),
    title: const Text('Reset password'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            enabled: !_sending,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.send,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Email address'),
            validator: ResponderValidators.email,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _sending ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _sending ? null : _submit,
        child: Text(_sending ? 'Sending...' : 'Send instructions'),
      ),
    ],
  );
}

class _LoginStoryPanel extends StatelessWidget {
  const _LoginStoryPanel();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(56),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xff9f1d35), Color(0xffc42642), Color(0xffdd2d4a)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xffdd2d4a),
                child: Icon(Icons.health_and_safety_rounded),
              ),
              SizedBox(width: 12),
              Text(
                'HAZARD HERO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const Spacer(),
          const AutoSizeText(
            'Clear information.\nFaster response.',
            maxLines: 2,
            minFontSize: 34,
            style: TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: const Text(
              'Coordinate emergency content from one operational console while citizens receive the same trusted information online or offline.',
              style: TextStyle(
                color: Color(0xffffe8ed),
                fontSize: 17,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StoryChip(Icons.warning_amber_rounded, 'Alert publishing'),
              _StoryChip(Icons.translate_rounded, 'Translations'),
              _StoryChip(Icons.history_rounded, 'Audit trail'),
            ],
          ),
          const Spacer(),
          const Text(
            'Authorized emergency personnel only',
            style: TextStyle(color: Color(0xffffd9e0), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _StoryChip extends StatelessWidget {
  const _StoryChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withAlpha(20),
      border: Border.all(color: Colors.white.withAlpha(40)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
