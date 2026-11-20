import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/api/api_exception.dart';
import '../core/responder_providers.dart';
import '../validation/responder_validators.dart';

class ResponderSignupScreen extends ConsumerStatefulWidget {
  const ResponderSignupScreen({super.key});

  @override
  ConsumerState<ResponderSignupScreen> createState() => _ResponderSignupState();
}

class _ResponderSignupState extends ConsumerState<ResponderSignupScreen> {
  final form = GlobalKey<FormState>();
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final office = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool hidden = true;
  bool submitting = false;
  bool submitted = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [
      firstName,
      lastName,
      email,
      phone,
      office,
      password,
      confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !submitting,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Responder sign up'),
        leading: IconButton(
          tooltip: 'Back to login',
          onPressed: submitting ? null : () => context.go('/login'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: submitted ? _success() : _form(),
          ),
        ),
      ),
    ),
  );

  Widget _success() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(
        Icons.mark_email_read_outlined,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 20),
      Text(
        'Account created',
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const Text(
        'Your account is awaiting admin verification. Once an administrator verifies your account, you can sign in with your email and password.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => context.go('/login'),
        child: const Text('Back to login'),
      ),
    ],
  );

  Widget _form() => AutofillGroup(
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create your responder account',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Register to access responder tools and equipment inventory. An administrator must verify your account before you can sign in.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: firstName,
            enabled: !submitting,
            decoration: const InputDecoration(labelText: 'First name'),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
            validator: (value) => ResponderValidators.requiredText(
              value,
              label: 'First name',
              maxLength: 100,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: lastName,
            enabled: !submitting,
            decoration: const InputDecoration(labelText: 'Last name'),
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            validator: (value) => ResponderValidators.requiredText(
              value,
              label: 'Last name',
              maxLength: 100,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: email,
            enabled: !submitting,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: ResponderValidators.email,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phone,
            enabled: !submitting,
            decoration: const InputDecoration(
              labelText: 'Phone number (optional)',
            ),
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: (value) =>
                ResponderValidators.phone(value, required: false),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: office,
            enabled: !submitting,
            decoration: const InputDecoration(
              labelText: 'Office / response team (optional)',
            ),
            validator: (value) => ResponderValidators.optionalText(
              value,
              label: 'Office',
              maxLength: 160,
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: password,
            enabled: !submitting,
            obscureText: hidden,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Password',
              helperText:
                  'Use at least 8 characters and avoid common passwords.',
              suffixIcon: IconButton(
                tooltip: hidden ? 'Show passwords' : 'Hide passwords',
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(hidden ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            validator: ResponderValidators.password,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: confirmation,
            enabled: !submitting,
            obscureText: hidden,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (value) => value != password.text
                ? 'Passwords do not match.'
                : ResponderValidators.password(value),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              semanticsLabel: 'Sign-up failed: $error',
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: submitting ? null : _submit,
            icon: submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_outlined),
            label: Text(submitting ? 'Creating account…' : 'Create account'),
          ),
          TextButton(
            onPressed: submitting ? null : () => context.go('/login'),
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    if (submitting || !form.currentState!.validate()) return;
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await ref
          .read(responderApiProvider)
          .signup(
            firstName: firstName.text,
            lastName: lastName.text,
            email: email.text,
            password: password.text,
            passwordConfirm: confirmation.text,
            phoneNumber: phone.text,
            office: office.text,
          );
      if (mounted) {
        password.clear();
        confirmation.clear();
        setState(() {
          submitted = true;
          submitting = false;
        });
      }
    } catch (failure) {
      if (mounted)
        setState(() {
          submitting = false;
          error = failure is ApiException && failure.statusCode == 404
              ? 'Sign-up is not available on the server yet. Please contact your administrator.'
              : userFacingErrorMessage(failure);
        });
    }
  }
}
