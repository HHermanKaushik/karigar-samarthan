import 'package:flutter/material.dart';

class CategoryInput extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryInput({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'icon': Icons.brush, 'label': 'Pottery'},
      {'icon': Icons.checkroom, 'label': 'Textiles'},
      {'icon': Icons.diamond, 'label': 'Jewelry'},
      {'icon': Icons.chair, 'label': 'Woodwork'},
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final label = cat['label'] as String;
        final isSelected = selectedCategory == label;

        return InkWell(
          onTap: () => onCategorySelected(label),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  cat['icon'] as IconData,
                  size: 32,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(height: 8),
                Text(label, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        );
      },
    );
  }
}