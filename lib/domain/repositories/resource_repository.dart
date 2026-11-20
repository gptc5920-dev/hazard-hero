import '../entities/app_user.dart';
import '../entities/emergency_resource.dart';

abstract interface class ResourceRepository {
  Stream<List<EmergencyResource>> watchAll({ResourceKind? kind});
  Future<EmergencyResource> create({
    required AppUser actor,
    required ResourceDraft draft,
  });
  Future<EmergencyResource> update({
    required AppUser actor,
    required String id,
    required ResourceDraft draft,
  });
  Future<void> delete({required AppUser actor, required String id});
}
