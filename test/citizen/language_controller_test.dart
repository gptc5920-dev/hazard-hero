import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/citizen/core/citizen_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores only supported citizen languages', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = LanguageController(prefs);
    await controller.select('ceb');
    expect(controller.state, 'ceb');
    expect(prefs.getString('citizen_language'), 'ceb');
    await controller.select('fr');
    expect(controller.state, 'ceb');
  });
}
