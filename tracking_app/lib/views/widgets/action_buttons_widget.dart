import 'package:flutter/material.dart';

class ActionButtonsWidget extends StatelessWidget {
  final bool isLivenessVerified;
  final bool isLoading;
  final bool isTrackingLocation;
  final VoidCallback onRegisterFace;
  final VoidCallback onCheckIn;
  final VoidCallback onToggleTracking;
  final VoidCallback onReset;

  const ActionButtonsWidget({
    super.key,
    required this.isLivenessVerified,
    required this.isLoading,
    required this.isTrackingLocation,
    required this.onRegisterFace,
    required this.onCheckIn,
    required this.onToggleTracking,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Nút Đăng ký mặt gốc
            ElevatedButton.icon(
              onPressed: isLivenessVerified ? onRegisterFace : null,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Đăng Ký Mặt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

            // Nút Điểm danh
            ElevatedButton.icon(
              onPressed: isLivenessVerified ? onCheckIn : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Điểm Danh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLivenessVerified ? Colors.green.shade700 : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Nút Bật/Tắt Live Tracking
            OutlinedButton.icon(
              onPressed: onToggleTracking,
              icon: Icon(
                isTrackingLocation ? Icons.location_on : Icons.location_off,
                color: isTrackingLocation ? Colors.red : Colors.grey.shade700,
              ),
              label: Text(
                isTrackingLocation ? 'Dừng Live Tracking' : 'Bật Live Tracking',
                style: TextStyle(
                  color: isTrackingLocation ? Colors.red : Colors.grey.shade800,
                ),
              ),
            ),

            // Nút Quét lại khuôn mặt
            IconButton(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              tooltip: 'Quét lại',
              color: Colors.blueGrey,
            ),
          ],
        ),
      ],
    );
  }
}

