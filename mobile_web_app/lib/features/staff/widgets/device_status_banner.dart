import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/staff_providers.dart';

class DeviceStatusBanner extends ConsumerWidget {
  const DeviceStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(deviceStatusProvider);

    return statusAsync.when(
      data: (status) {
        if (status == null) return const SizedBox.shrink();

        final isOnline = status['status'] == 'online';
        if (isOnline) return const SizedBox.shrink();

        return Material(
          color: Colors.red.shade100,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red.shade900, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kitchen Terminal is Offline',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
