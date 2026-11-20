import '../entities/app_user.dart';
import '../entities/emergency_resource.dart';

class AuthorizationService {
  const AuthorizationService();

  bool canManageUsers(AppUser user) =>
      user.isActive && user.role == UserRole.admin;

  bool canManageResource(AppUser user, ResourceKind kind) {
    if (!user.isActive) return false;
    if (user.role == UserRole.admin) return true;
    if (user.role != UserRole.responder) return false;
    return kind == ResourceKind.alert ||
        kind == ResourceKind.evacuationCenter ||
        kind == ResourceKind.hotline ||
        kind == ResourceKind.guide;
  }

  void requireResourceAccess(AppUser user, ResourceKind kind) {
    if (!canManageResource(user, kind)) {
      throw const AuthorizationException(
        'You are not authorized to manage this resource.',
      );
    }
  }

  void requireAdmin(AppUser user) {
    if (!canManageUsers(user)) {
      throw const AuthorizationException('Administrator access is required.');
    }
  }
}

class AuthorizationException implements Exception {
  const AuthorizationException(this.message);
  final String message;
  @override
  String toString() => message;
}
