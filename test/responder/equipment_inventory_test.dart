import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/responder/inventory/equipment.dart';
import 'package:hazard_hero/responder/inventory/equipment_providers.dart';
import 'package:hazard_hero/responder/inventory/equipment_repository.dart';
import 'package:hazard_hero/responder/inventory/equipment_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'inventory persists edits and deletion without exposing another account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = EquipmentRepository(prefs, 'responder-a');
      final controller = EquipmentController(repository);
      await controller.upsert(
        Equipment(
          id: 'radio',
          name: 'Radio',
          quantity: 5,
          inUse: 2,
          location: 'Station 1',
        ),
      );
      expect(EquipmentRepository(prefs, 'responder-b').load(), isEmpty);
      final reloaded = EquipmentController(
        EquipmentRepository(prefs, 'responder-a'),
      );
      expect(reloaded.state.requireValue.single.available, 3);
      expect(reloaded.state.requireValue.single.location, 'Station 1');
      await reloaded.upsert(
        Equipment(
          id: 'radio',
          name: 'Radio',
          quantity: 5,
          inUse: 1,
          condition: 'Needs maintenance',
        ),
      );
      expect(repository.load().single.available, 0);
      expect(repository.load().single.inUse, 1);
      await reloaded.remove('radio');
      expect(repository.load(), isEmpty);
      controller.dispose();
      reloaded.dispose();
    },
  );

  test('equipment rejects invalid stock and excludes unserviceable stock', () {
    expect(
      () => Equipment(id: 'a', name: 'Radio', quantity: 2, inUse: 3),
      throwsArgumentError,
    );
    expect(
      () => Equipment(id: 'a', name: 'Radio', quantity: 0),
      throwsArgumentError,
    );
    expect(
      () => Equipment(id: 'a', name: '   ', quantity: 1),
      throwsArgumentError,
    );
    expect(
      Equipment(
        id: 'a',
        name: 'Radio',
        quantity: 2,
        condition: 'Out of service',
      ).available,
      0,
    );
  });

  test('corrupted inventory is preserved and cannot be overwritten', () async {
    SharedPreferences.setMockInitialValues({
      'responder_equipment_v1_a': 'invalid json',
    });
    final prefs = await SharedPreferences.getInstance();
    final controller = EquipmentController(EquipmentRepository(prefs, 'a'));
    expect(controller.state.hasError, isTrue);
    await expectLater(
      controller.upsert(Equipment(id: 'r', name: 'Radio', quantity: 1)),
      throwsStateError,
    );
    expect(prefs.getString('responder_equipment_v1_a'), 'invalid json');
    controller.dispose();
  });

  testWidgets(
    'responder can add, filter, edit, and delete equipment on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = EquipmentRepository(prefs, 'mobile');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            equipmentProvider.overrideWith((_) => EquipmentController(repo)),
          ],
          child: const MaterialApp(home: EquipmentScreen()),
        ),
      );
      await tester.tap(find.text('Add equipment'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Equipment name'),
        'Rescue rope',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Total quantity'),
        '4',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity in use'),
        '5',
      );
      await tester.tap(find.text('Save equipment'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a whole number between 0 and 4.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity in use'),
        '1',
      );
      await tester.tap(find.text('Save equipment'));
      await tester.pumpAndSettle();
      expect(find.text('Rescue rope'), findsOneWidget);
      expect(repo.load().single.available, 3);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Out of service'));
      await tester.pumpAndSettle();
      expect(find.text('Rescue rope'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Equipment actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Total quantity'),
        '6',
      );
      await tester.tap(find.text('Save equipment'));
      await tester.pumpAndSettle();
      expect(repo.load().single.quantity, 6);

      await tester.tap(find.byTooltip('Equipment actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repo.load(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
