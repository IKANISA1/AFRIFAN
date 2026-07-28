import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../extensions.dart';
import '../tokens/color_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/shape_tokens.dart';
import '../tokens/size_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_bottom_sheet.dart';
import 'afri_button.dart';
import 'afri_material_buttons.dart';
import 'glass_card.dart';

class AfriFilterOption {
  const AfriFilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

class AfriFilterSortResult {
  const AfriFilterSortResult({
    required this.sortBy,
    required this.selectedTypes,
    this.dateRange,
    this.amountRange,
  });

  final String sortBy;
  final Set<String> selectedTypes;
  final DateTimeRange? dateRange;
  final RangeValues? amountRange;
}

Future<AfriFilterSortResult?> showAfriFilterSortSheet({
  required BuildContext context,
  required String title,
  required List<AfriFilterOption> sortOptions,
  List<AfriFilterOption> typeOptions = const <AfriFilterOption>[],
  String? initialSortBy,
  Set<String> initialSelectedTypes = const <String>{},
  DateTimeRange? initialDateRange,
  RangeValues? initialAmountRange,
  double minAmount = 0,
  double maxAmount = 10000,
  bool showDateRange = true,
  bool showAmountRange = false,
}) {
  return showAfriBottomSheet<AfriFilterSortResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      var sortBy =
          initialSortBy ??
          (sortOptions.isEmpty ? 'default' : sortOptions.first.value);
      final selectedTypes = initialSelectedTypes.toSet();
      var dateRange = initialDateRange;
      var amountRange = initialAmountRange ?? RangeValues(minAmount, maxAmount);

      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickDateRange() async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              initialDateRange: dateRange,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                      surface: ColorTokens.surface,
                      onSurface: ColorTokens.onSurface,
                      primary: Theme.of(context).colorScheme.primary,
                      onPrimary: Colors.white,
                    ),
                    dialogTheme: DialogThemeData(
                      backgroundColor: ColorTokens.surface,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => dateRange = picked);
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: SizeTokens.sheetHandleWidth,
                  height: SizeTokens.sheetHandleHeight,
                  decoration: BoxDecoration(
                    color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.35),
                    borderRadius: ShapeTokens.buttonRadius,
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: TypographyTokens.headlineSmall()),
                  ),
                  AfriTextButton(
                    onPressed: () {
                      setState(() {
                        sortBy = sortOptions.isEmpty
                            ? 'default'
                            : sortOptions.first.value;
                        selectedTypes.clear();
                        dateRange = null;
                        amountRange = RangeValues(minAmount, maxAmount);
                      });
                    },
                    child: Text(
                      'RESET',
                      style: TypographyTokens.labelLarge().copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              if (sortOptions.isNotEmpty) ...[
                Text('SORT', style: TypographyTokens.labelSmall()),
                const SizedBox(height: SpacingTokens.spacing2),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing2,
                  children: sortOptions
                      .map(
                        (option) => ChoiceChip(
                          selected: sortBy == option.value,
                          label: Text(option.label),
                          onSelected: (_) =>
                              setState(() => sortBy = option.value),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
              ],
              if (showDateRange) ...[
                Text('DATE RANGE', style: TypographyTokens.labelSmall()),
                const SizedBox(height: SpacingTokens.spacing2),
                GlassCard(
                  animate: false,
                  onTap: pickDateRange,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateRange == null
                              ? 'Select range'
                              : '${dateRange!.start.day}/${dateRange!.start.month}/${dateRange!.start.year}  →  ${dateRange!.end.day}/${dateRange!.end.month}/${dateRange!.end.year}',
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing3),
                      const Icon(AfriIcons.calendar),
                    ],
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
              ],
              if (typeOptions.isNotEmpty) ...[
                Text('TYPE', style: TypographyTokens.labelSmall()),
                const SizedBox(height: SpacingTokens.spacing2),
                Wrap(
                  spacing: SpacingTokens.spacing2,
                  runSpacing: SpacingTokens.spacing2,
                  children: typeOptions
                      .map(
                        (option) => FilterChip(
                          selected: selectedTypes.contains(option.value),
                          label: Text(option.label),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedTypes.add(option.value);
                              } else {
                                selectedTypes.remove(option.value);
                              }
                            });
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
              ],
              if (showAmountRange) ...[
                Text('AMOUNT RANGE', style: TypographyTokens.labelSmall()),
                const SizedBox(height: SpacingTokens.spacing2),
                GlassCard(
                  animate: false,
                  child: Column(
                    children: [
                      RangeSlider(
                        values: amountRange,
                        min: minAmount,
                        max: maxAmount,
                        labels: RangeLabels(
                          amountRange.start.round().toString(),
                          amountRange.end.round().toString(),
                        ),
                        onChanged: (value) =>
                            setState(() => amountRange = value),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${context.afriCurrencySymbol} ${amountRange.start.round()}',
                            style: TypographyTokens.bodySmall(),
                          ),
                          Text(
                            '${context.afriCurrencySymbol} ${amountRange.end.round()}',
                            style: TypographyTokens.bodySmall(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing5),
              ],
              AfriButton(
                label: 'Apply filters',
                fullWidth: true,
                onTap: () => context.pop(
                  AfriFilterSortResult(
                    sortBy: sortBy,
                    selectedTypes: selectedTypes,
                    dateRange: dateRange,
                    amountRange: showAmountRange ? amountRange : null,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
