import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'equipment.dart';

/// Device-local stock records, kept separate for each authenticated account.
class EquipmentRepository {
  EquipmentRepository(this.preferences, String accountId)
    : key = 'responder_equipment_v1_$accountId';

  final SharedPreferences preferences;
  final String key;

  List<Equipment> load() {
    final stored = preferences.getString(key);
    if (stored == null) return [];
    return (jsonDecode(stored) as List)
        .map((row) => Equipment.fromJson((row as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> save(List<Equipment> records) async {
    final saved = await preferences.setString(
      key,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
    if (!saved)
      throw StateError('Equipment could not be saved. Please try again.');
  }
}
