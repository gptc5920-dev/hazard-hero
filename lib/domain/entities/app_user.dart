enum UserRole { admin, responder, citizen }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final bool isActive;
}

class AuthSession {
  const AuthSession({required this.id, required this.user});
  final String id;
  final AppUser user;
}
