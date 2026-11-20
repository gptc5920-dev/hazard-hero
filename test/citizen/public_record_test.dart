import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/citizen/models/citizen_models.dart';

void main() {
  test('citizen records expose searchable admin content and useful labels', () {
    const record = PublicRecord({
      'id': 'alert-1',
      'title': 'Flood warning',
      'message': 'Move to higher ground',
      'severity_level': 'Critical',
      'alert_type': 'Flood',
      'affected_areas': ['Central', 'Riverside'],
    });

    expect(record.searchableText(), contains('riverside'));
    expect(record.labelsFor('alerts'), ['Critical', 'Flood']);
  });
}
