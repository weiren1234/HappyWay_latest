import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CustomSearchBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CustomSearchBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textController = TextEditingController(text: searchQuery)
      ..selection = TextSelection.fromPosition(TextPosition(offset: searchQuery.length));

    return Column(
      children: [

        Container(
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass(context),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.borderGlass(context)),
            boxShadow: [
              BoxShadow(
                color: isDark ? AppColors.cardShadow : AppColors.cardShadowLight,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: textController,
            onChanged: onSearchChanged,
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primaryText(context)),
            decoration: InputDecoration(
              hintText: 'Search Malaysian destinations or states...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText(context)),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.secondaryText(context)),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: AppColors.secondaryText(context), size: 18),
                      onPressed: () => onSearchChanged(''),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category == selectedCategory;

              return GestureDetector(
                onTap: () => onCategorySelected(category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? AppColors.weatherBlue : AppColors.weatherBlueLight)
                        : AppColors.surfaceGlass(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.cyanAccent(context) : AppColors.borderGlass(context),
                    ),
                  ),
                  child: Text(
                    category,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isSelected
                          ? Colors.white
                          : AppColors.secondaryText(context),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
