import 'package:flutter/material.dart';

const int kListPageSize = 10;

/// Scrolls the enclosing scrollable so that [key]'s widget is at the top,
/// once the new page has been laid out.
void scrollToListStart(GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  });
}

int pageCountFor(int totalItems, [int pageSize = kListPageSize]) =>
    totalItems == 0 ? 1 : (totalItems + pageSize - 1) ~/ pageSize;

/// Returns the items of [page] (0-based); [page] is clamped to a valid range.
List<T> pageSlice<T>(List<T> items, int page, [int pageSize = kListPageSize]) {
  final safePage = page.clamp(0, pageCountFor(items.length, pageSize) - 1);
  final start = safePage * pageSize;
  final end = (start + pageSize).clamp(0, items.length);
  return items.sublist(start, end);
}

class PaginationBar extends StatelessWidget {
  final int page;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.page,
    required this.totalItems,
    required this.onPageChanged,
    this.pageSize = kListPageSize,
  });

  @override
  Widget build(BuildContext context) {
    final pageCount = pageCountFor(totalItems, pageSize);
    if (pageCount <= 1) return const SizedBox.shrink();
    final current = page.clamp(0, pageCount - 1);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Page précédente',
            onPressed: current > 0 ? () => onPageChanged(current - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('Page ${current + 1} / $pageCount · $totalItems élément(s)'),
          IconButton(
            tooltip: 'Page suivante',
            onPressed: current < pageCount - 1
                ? () => onPageChanged(current + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
