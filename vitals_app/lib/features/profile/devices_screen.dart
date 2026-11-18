import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/ink_app_bar.dart';
import '../../core/widgets/widgets.dart';
import '../../providers/data_providers.dart';

class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    final daysCount = ref.watch(dataDaysCountProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: InkAppBar(
        title: 'Devices',
        subtitle: 'Sync & sources',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          message: 'Could not load sync status.',
          onRetry: () => ref.invalidate(userProvider),
        ),
        data: (user) {
          final last = user?.lastSyncedAt;
          final isDemo = user?.isDemo ?? false;

          if (!isDemo && last == null && daysCount == 0) {
            return const EmptyState(
              icon: Icons.watch_outlined,
              title: 'No device connected',
              message: 'Connect your watch to start building your baseline',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              SoftSurface(
                color: AppColors.skyCard,
                radius: 28,
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDemo
                                ? Icons.science_outlined
                                : Icons.watch_outlined,
                            color: AppColors.ink,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isDemo ? 'Demo account' : 'Health Connect',
                                style:
                                    AppText.cardTitle.copyWith(fontSize: 20),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDemo
                                    ? 'Synthetic data — no device sync'
                                    : (last == null
                                        ? 'Not synced yet'
                                        : 'Last synced ${DateFormat.yMMMd().add_jm().format(last)}'),
                                style: AppText.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SoftSurface(
                      radius: 20,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$daysCount',
                            style: GoogleFonts.manrope(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'days of readings stored',
                              style: AppText.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SoftSurface(
                color: AppColors.mintCard,
                radius: 28,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About sync',
                      style: AppText.cardTitle.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDemo
                          ? 'Demo mode uses synthetic daily readings so you can explore charts and flags without a wearable.'
                          : 'VitalWatch reads daily summaries from Health Connect and stores them securely for baseline and pattern detection.',
                      style: AppText.bodyMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'VitalWatch provides wellness insights, not medical diagnoses.',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
