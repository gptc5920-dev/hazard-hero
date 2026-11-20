import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/responder/core/modules.dart';

void main() {
  test('alert date fields use date-time pickers', () {
    final alerts = responderModules.singleWhere(
      (module) => module.path == 'alerts',
    );
    final startsAt = alerts.fields.singleWhere(
      (field) => field.name == 'starts_at',
    );
    final expiresAt = alerts.fields.singleWhere(
      (field) => field.name == 'expires_at',
    );

    expect(startsAt.dateTime, isTrue);
    expect(expiresAt.dateTime, isTrue);
    expect(startsAt.required, isTrue);
    expect(expiresAt.required, isTrue);
  });
}
