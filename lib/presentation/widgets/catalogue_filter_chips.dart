import 'package:flutter/material.dart';

import '../../application/state/catalogue_state.dart';
import '../../core/theme/app_palette.dart';

/// Horizontal chip selector for filtering the POI catalogue.
class CatalogueFilterChips extends StatelessWidget {
  const CatalogueFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onSelected,
  });

  final QuickFilter selectedFilter;
  final ValueChanged<QuickFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: QuickFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = QuickFilter.values[index];
          final isSelected = filter == selectedFilter;

          return FilterChip(
            label: Text(filter.label),
            selected: isSelected,
            showCheckmark: false,
            backgroundColor: AppPalette.surface,
            selectedColor: AppPalette.accent,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppPalette.ink,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: isSelected ? AppPalette.accent : AppPalette.divider,
            ),
            onSelected: (_) => onSelected(filter),
          );
        },
      ),
    );
  }
}
