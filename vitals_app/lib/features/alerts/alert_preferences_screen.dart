import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/soft_surface.dart';

/// Static preferences chrome for this prototype (no local settings store).
class AlertPreferencesScreen extends StatelessWidget {
  const AlertPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Checkup preferences')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SoftSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How checkups work', style: AppText.cardTitle),
                const SizedBox(height: 8),
                Text(
                  'Checkups are wellness insights derived from sustained drift '
                  'against your personal baseline. Tiers are Info, Advise, and '
                  'Urgent based on flag level and severity.',
                  style: AppText.bodyMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftSurface(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Push notification preferences will be available in a later release. '
              'VitalWatch provides wellness insights, not medical diagnoses.',
              style: AppText.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
