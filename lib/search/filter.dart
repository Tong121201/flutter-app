import 'package:flutter/material.dart';

enum SortOption {
  titleAsc,
  titleDesc,
  companyAsc,
  companyDesc,
  dateAsc,
  dateDesc,
}

class FilterBottomSheet extends StatelessWidget {
  final Function(SortOption) onSortSelected;
  final SortOption currentSort;

  const FilterBottomSheet({
    Key? key,
    required this.onSortSelected,
    required this.currentSort,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Sort By',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 3.8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSortOptionCard(
                context,
                'Title A-Z',
                Icons.sort_by_alpha,
                SortOption.titleAsc,
                isReversed: false,
              ),
              _buildSortOptionCard(
                context,
                'Title Z-A',
                Icons.sort_by_alpha,
                SortOption.titleDesc,
                isReversed: true,
              ),
              _buildSortOptionCard(
                context,
                'Company A-Z',
                Icons.business,
                SortOption.companyAsc,
                isReversed: false,
              ),
              _buildSortOptionCard(
                context,
                'Company Z-A',
                Icons.business,
                SortOption.companyDesc,
                isReversed: true,
              ),
              _buildSortOptionCard(
                context,
                'Newest First',
                Icons.access_time,
                SortOption.dateDesc,
                isReversed: false,
              ),
              _buildSortOptionCard(
                context,
                'Oldest First',
                Icons.access_time,
                SortOption.dateAsc,
                isReversed: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSortOptionCard(
      BuildContext context,
      String title,
      IconData icon,
      SortOption option, {
        required bool isReversed,
      }) {
    final isSelected = currentSort == option;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        onSortSelected(option);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.rotate(
                angle: isReversed ? 3.14159 : 0, // PI radians = 180 degrees
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}