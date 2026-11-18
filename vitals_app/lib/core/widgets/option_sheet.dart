import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// One selectable row in [showOptionSheet].
class SheetOption<T> {
  const SheetOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Bottom sheet that lets the person pick one value. Returns the chosen value,
/// or `null` if the sheet is dismissed.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetOption<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(title, style: AppText.sectionTitle),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    for (final option in options)
                      ListTile(
                        leading: option.icon == null
                            ? null
                            : Icon(option.icon, color: AppColors.ink),
                        title: Text(option.label, style: AppText.body),
                        trailing: option.value == selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: AppColors.ink,
                              )
                            : null,
                        onTap: () =>
                            Navigator.of(sheetContext).pop(option.value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
