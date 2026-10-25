import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';


class StaffDeviceMonitoringPage extends ConsumerWidget {
  const StaffDeviceMonitoringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceStatusAsync = ref.watch(deviceStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Monitoring'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: deviceStatusAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('No device data available.'));
          }
          final isOnline = data['online'] as bool? ?? false;
          final lastSeenTimestamp = data['lastSeen'];
          DateTime? lastSeen;
          if (lastSeenTimestamp != null) {
            lastSeen = DateTime.tryParse(lastSeenTimestamp.toString());
          }
          // If we want more robust parsing for firestore timestamp
          if (lastSeenTimestamp != null && lastSeenTimestamp.runtimeType.toString() == 'Timestamp') {
            lastSeen = lastSeenTimestamp.toDate();
          }

          final firmwareVersion = data['firmwareVersion'] as String? ?? 'Unknown';
          final currentOrder = data['currentOrderNumber']?.toString() ?? 'None';

          // Determine if considered offline due to timeout (e.g. > 2 minutes)
          bool actuallyOnline = isOnline;
          if (isOnline && lastSeen != null) {
            if (DateTime.now().difference(lastSeen).inMinutes > 2) {
              actuallyOnline = false;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimatedGlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.kitchen, size: 32, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Kitchen Terminal (ESP32)',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: actuallyOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            actuallyOnline ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(
                              color: actuallyOnline ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(Icons.access_time, 'Last Sync', lastSeen != null ? DateFormat('MMM d, y h:mm:ss a').format(lastSeen) : 'Never'),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.memory, 'Firmware Version', firmwareVersion),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.receipt_long, 'Current Order Queued', currentOrder),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
