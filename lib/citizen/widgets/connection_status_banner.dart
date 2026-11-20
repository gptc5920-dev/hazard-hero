import 'package:flutter/material.dart';

import '../localization/citizen_strings.dart';

class CitizenConnectionNotification {
  const CitizenConnectionNotification._();

  static void show(
    BuildContext context, {
    required bool online,
    required CitizenStrings strings,
    DateTime? lastSync,
  }) {
    final message = online
        ? '${strings.text('online')} · ${strings.text('updatingSaved')}'
        : lastSync == null
        ? '${strings.text('offlineMode')} · ${strings.text('connectToSave')}'
        : '${strings.text('offlineMode')} · ${strings.text('showingSaved')} ${_time(lastSync)}';

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
        showCloseIcon: true,
        closeIconColor: Colors.white,
        backgroundColor: online
            ? const Color(0xff166534)
            : const Color(0xffdd2d4a),
        content: Row(
          children: [
            Icon(
              online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _time(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }
  return '${local.month}/${local.day}/${local.year}';
}
