import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/soft_surface.dart';

/// Static emergency resources. VitalWatch never diagnoses emergencies.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  static const emergencyNumber = '112';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Emergency resources')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftSurface(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('If you need urgent help', style: AppText.screenTitle),
                const SizedBox(height: 12),
                Text(
                  'VitalWatch is not an emergency service and does not detect '
                  'medical emergencies. If you feel unsafe or need immediate help, '
                  'contact local emergency services.',
                  style: AppText.bodyMuted,
                ),
                const SizedBox(height: 20),
                Text('Local emergency number', style: AppText.cardTitle),
                const SizedBox(height: 8),
                Text(
                  emergencyNumber,
                  style: AppText.screenTitle.copyWith(
                    color: AppColors.flagRed,
                    fontSize: 36,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'VitalWatch provides wellness insights, not medical diagnoses.',
            style: AppText.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
