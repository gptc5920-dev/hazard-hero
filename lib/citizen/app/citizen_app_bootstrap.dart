import 'package:shared_preferences/shared_preferences.dart';

class CitizenAppBootstrap {
  static Future<SharedPreferences> initialize() =>
      SharedPreferences.getInstance();
}
