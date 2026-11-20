import 'main_admin.dart' as admin;

/// Default Hazard Hero entry point.
///
/// Administrator and responder builds must authenticate against the Django
/// API. Citizen and legacy offline builds retain their explicit entry points.
Future<void> main() => admin.main();
