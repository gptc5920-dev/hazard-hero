import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/async_state_widgets.dart';
import '../core/responder_providers.dart';
import '../validation/responder_validators.dart';
import '../widgets/backend_connection_chip.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final _profileForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _position = TextEditingController();
  final _office = TextEditingController();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _showPasswords = false;
  String? _loadError;
  String? _profileError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _middleName,
      _lastName,
      _email,
      _phone,
      _position,
      _office,
      _oldPassword,
      _newPassword,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await ref.read(responderApiProvider).profile();
      if (!mounted) return;
      _firstName.text = profile['first_name']?.toString() ?? '';
      _middleName.text = profile['middle_name']?.toString() ?? '';
      _lastName.text = profile['last_name']?.toString() ?? '';
      _email.text = profile['email']?.toString() ?? '';
      _phone.text = profile['phone_number']?.toString() ?? '';
      _position.text = profile['position']?.toString() ?? '';
      _office.text = profile['office']?.toString() ?? '';
      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile || !(_profileForm.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _savingProfile = true;
      _profileError = null;
    });
    final body = <String, dynamic>{
      'first_name': _firstName.text.trim(),
      'middle_name': _middleName.text.trim(),
      'last_name': _lastName.text.trim(),
      'email': _email.text.trim().toLowerCase(),
      'phone_number': _phone.text.trim(),
      'position': _position.text.trim(),
      'office': _office.text.trim(),
    };
    try {
      final api = ref.read(responderApiProvider);
      final profile = await api.updateProfile(body);
      if (!mounted) return;
      ref.read(authProvider.notifier).applyProfile(profile);
      setState(() {
        _savingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = error.toString();
        _savingProfile = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_savingPassword || !(_passwordForm.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _savingPassword = true;
      _passwordError = null;
    });
    try {
      await ref
          .read(responderApiProvider)
          .changePassword(
            oldPassword: _oldPassword.text,
            newPassword: _newPassword.text,
          );
      if (!mounted) return;
      _oldPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _savingPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _passwordError = error.toString();
        _savingPassword = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 600 ? 14.0 : 24.0;
        if (_loading) return const AppLoading();
        if (_loadError != null) {
          return AppError(message: _loadError!, onRetry: _loadProfile);
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 40),
          children: [
            _AccountHeader(onRefresh: _loadProfile),
            const SizedBox(height: 14),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  children: [
                    _profileCard(),
                    const SizedBox(height: 14),
                    _passwordCard(),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _profileCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _profileForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              icon: Icons.badge_outlined,
              title: 'Profile information',
              subtitle: 'This information identifies you in audit records.',
            ),
            const SizedBox(height: 18),
            if (_profileError != null) ...[
              _InlineError(message: _profileError!),
              const SizedBox(height: 14),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  _textField(
                    _firstName,
                    'First name',
                    validator: (value) => ResponderValidators.requiredText(
                      value,
                      label: 'First name',
                      maxLength: 100,
                    ),
                  ),
                  _textField(
                    _middleName,
                    'Middle name',
                    validator: (value) => ResponderValidators.optionalText(
                      value,
                      label: 'Middle name',
                      maxLength: 100,
                    ),
                  ),
                  _textField(
                    _lastName,
                    'Last name',
                    validator: (value) => ResponderValidators.requiredText(
                      value,
                      label: 'Last name',
                      maxLength: 100,
                    ),
                  ),
                  _textField(
                    _email,
                    'Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: ResponderValidators.email,
                  ),
                  _textField(
                    _phone,
                    'Phone number',
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        ResponderValidators.phone(value, required: false),
                  ),
                  _textField(_position, 'Position'),
                  _textField(_office, 'Office'),
                ];
                if (constraints.maxWidth < 720) {
                  return Column(
                    children: [
                      for (final field in fields)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: field,
                        ),
                    ],
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final field in fields)
                      SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: field,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _savingProfile ? null : _saveProfile,
                icon: _savingProfile
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _savingProfile ? 'Saving profile...' : 'Save profile',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _passwordCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _passwordForm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionTitle(
              icon: Icons.lock_reset_rounded,
              title: 'Change password',
              subtitle: 'Use a unique password of at least eight characters.',
            ),
            const SizedBox(height: 18),
            if (_passwordError != null) ...[
              _InlineError(message: _passwordError!),
              const SizedBox(height: 14),
            ],
            _passwordField(
              _oldPassword,
              'Current password',
              validator: (value) => (value ?? '').isEmpty
                  ? 'Current password is required.'
                  : null,
            ),
            const SizedBox(height: 12),
            _passwordField(
              _newPassword,
              'New password',
              validator: ResponderValidators.password,
            ),
            const SizedBox(height: 12),
            _passwordField(
              _confirmPassword,
              'Confirm new password',
              validator: (value) =>
                  value != _newPassword.text ? 'Passwords do not match.' : null,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _savingPassword ? null : _changePassword,
                icon: _savingPassword
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.password_rounded),
                label: Text(
                  _savingPassword ? 'Changing password...' : 'Change password',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    enabled: !_savingProfile,
    keyboardType: keyboardType,
    decoration: InputDecoration(labelText: label),
    validator: validator,
  );

  Widget _passwordField(
    TextEditingController controller,
    String label, {
    required String? Function(String?) validator,
  }) => TextFormField(
    controller: controller,
    enabled: !_savingPassword,
    obscureText: !_showPasswords,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        tooltip: _showPasswords ? 'Hide passwords' : 'Show passwords',
        onPressed: () => setState(() => _showPasswords = !_showPasswords),
        icon: Icon(
          _showPasswords ? Icons.visibility_off_outlined : Icons.visibility,
        ),
      ),
    ),
    validator: validator,
  );
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xfffce8ec),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.manage_accounts, color: Color(0xffdd2d4a)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My account',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Text(
              'Manage your responder identity and security.',
              style: TextStyle(color: Color(0xff76515b), fontSize: 12),
            ),
          ],
        ),
      ),
      const BackendConnectionChip(compact: true),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        tooltip: 'Reload profile',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xffdd2d4a)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            Text(subtitle, style: const TextStyle(color: Color(0xff76515b))),
          ],
        ),
      ),
    ],
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

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
      style: TextStyle(
        color: Theme.of(context).colorScheme.onErrorContainer,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
