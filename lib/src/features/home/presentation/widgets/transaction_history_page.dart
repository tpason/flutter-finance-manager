import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_frontend/src/core/config/app_colors.dart';
import 'package:flutter_frontend/src/features/plans/data/transaction_service.dart';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const TransactionHistoryView();
  }
}

class TransactionHistoryView extends StatefulWidget {
  const TransactionHistoryView({super.key});

  @override
  State<TransactionHistoryView> createState() => _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends State<TransactionHistoryView> {
  String _filter = 'all';

  final ScrollController _historyController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isInitialLoading = false;
  String? _nextCursor;
  final _transactionService = TransactionService();

  final List<HistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _historyController.addListener(_onHistoryScroll);
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _items
        : _items.where((i) => _filter == 'income' ? !i.isExpense : i.isExpense).toList();

    final grouped = <String, List<HistoryItem>>{};
    for (final item in filtered) {
      final key = _dateLabel(item.date);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    final sections = grouped.entries.toList()
      ..sort((a, b) => _sortDateKey(a.key, b.key));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Transaction History'),
        elevation: 0.5,
      ),
      body: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Container(
          color: AppColors.card,
          child: Column(
            children: [
              _buildFilters(),
              const SizedBox(height: 8),
              Expanded(
                child: _isInitialLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : sections.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No transactions found',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _historyController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: sections.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isLoadingMore && index == sections.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              final entry = sections[index];
                              return HistorySection(label: entry.key, items: entry.value);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onHistoryScroll() {
    if (!_historyController.hasClients || _isLoadingMore || !_hasMore) return;
    final position = _historyController.position;
    if (position.pixels >= position.maxScrollExtent - 120) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _hasMore = true;
      _nextCursor = null;
      _items.clear();
    });
    await _loadMore(reset: true);
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore({bool reset = false}) async {
    setState(() {
      _isLoadingMore = true;
    });

    final response = await _transactionService.fetchTransactions(
      cursor: reset ? null : _nextCursor,
      type: _filter == 'all' ? null : _filter,
    );

    if (!mounted) return;

    if (response['success'] == true && response['data'] is Map) {
      final data = response['data'] as Map;
      final items = _mapHistoryItems(data['items']);
      final nextCursor = data['next_cursor']?.toString();
      final hasNext = data['has_next'] == true;

      setState(() {
        _items.addAll(items);
        _nextCursor = nextCursor;
        _hasMore = hasNext;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  void dispose() {
    _historyController.dispose();
    super.dispose();
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip('all', 'All'),
          _buildFilterChip('income', 'Income'),
          _buildFilterChip('expense', 'Expense'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppColors.accentBlue.withOpacity(0.15),
        labelStyle: TextStyle(
          color: selected ? AppColors.accentBlue : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() => _filter = value);
          _loadInitial();
        },
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    if (target == today) return 'Today';
    if (target == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${_twoDigits(date.day)} ${_monthName(date.month)} ${date.year}';
  }

  int _sortDateKey(String a, String b) {
    DateTime parse(String key) {
      final now = DateTime.now();
      if (key == 'Today') return DateTime(now.year, now.month, now.day);
      if (key == 'Yesterday') return DateTime(now.year, now.month, now.day - 1);
      final parts = key.split(' ');
      final day = int.tryParse(parts[0]) ?? 1;
      final month = _monthFromName(parts[1]);
      final year = int.tryParse(parts[2]) ?? now.year;
      return DateTime(year, month, day);
    }

    return parse(b).compareTo(parse(a)); // latest first
  }

  int _monthFromName(String name) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final idx = months.indexOf(name);
    return idx == -1 ? 1 : idx + 1;
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  List<HistoryItem> _mapHistoryItems(dynamic raw) {
    final items = <HistoryItem>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final type = (item['type'] ?? '').toString().toLowerCase();
          final isExpense = type == 'expense';
          final amount = double.tryParse(item['amount']?.toString() ?? '') ?? 0.0;
          final date = DateTime.tryParse(item['date']?.toString() ?? '')?.toLocal() ?? DateTime.now();
          final categoryRaw = item['category'];
          final Map<String, dynamic>? category =
              categoryRaw is Map ? Map<String, dynamic>.from(categoryRaw as Map) : null;
          final categoryName = category?['name']?.toString();
          final categoryDescription = category?['description']?.toString();
          final icon = _mapIcon(category?['icon']?.toString());
          final color = _mapColor(category?['color']?.toString());

          items.add(
            HistoryItem(
              title: item['name']?.toString() ?? categoryName ?? 'Transaction',
              subtitle: item['description']?.toString() ?? categoryName ?? '',
              amount: amount,
              isExpense: isExpense,
              date: date,
              icon: icon,
              color: color,
              categoryName: categoryName,
              categoryDescription: categoryDescription,
            ),
          );
        }
      }
    }
    return items;
  }

  Color _mapColor(String? colorKey) {
    switch (colorKey?.toLowerCase()) {
      case 'primary':
        return AppColors.primary;
      case 'blue':
        return AppColors.accentBlue;
      case 'pink':
      case 'accentpink':
      case 'accent_pink':
        return AppColors.accentPink;
      case 'purple':
      case 'accentpurple':
      case 'accent_purple':
        return AppColors.accentPurple;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orangeAccent;
      case 'amber':
        return Colors.amber;
      case 'teal':
        return Colors.teal;
      case 'red':
      case 'redaccent':
      case 'red_accent':
      case 'red accent':
        return Colors.redAccent;
      case 'brown':
        return Colors.brown;
      case 'deeppurple':
      case 'deepurple':
      case 'deep_purple':
        return Colors.deepPurple;
      case 'accentblue':
      case 'accent_blue':
        return AppColors.accentBlue;
      case 'orangeaccent':
      case 'orange_accent':
        return Colors.orangeAccent;
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return AppColors.primary;
    }
  }

  IconData _mapIcon(String? iconName) {
    switch (iconName) {
      case 'attach_money':
        return Icons.attach_money;
      case 'volunteer_activism_outlined':
        return Icons.volunteer_activism_outlined;
      case 'home':
      case 'home_outlined':
        return Icons.home_outlined;
      case 'shopping':
      case 'shopping_bag':
      case 'shopping_bag_outlined':
        return Icons.shopping_bag_outlined;
      case 'restaurant':
      case 'food':
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'health':
      case 'health_and_safety_outlined':
        return Icons.health_and_safety_outlined;
      case 'savings':
      case 'savings_outlined':
        return Icons.savings_outlined;
      case 'travel':
      case 'transport':
      case 'directions_car_filled_outlined':
        return Icons.directions_car_filled_outlined;
      case 'work':
      case 'work_outline':
        return Icons.work_outline;
      case 'chart':
      case 'trending_up':
        return Icons.trending_up;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'stars_rounded':
        return Icons.stars_rounded;
      case 'cake_outlined':
        return Icons.cake_outlined;
      case 'storefront_outlined':
        return Icons.storefront_outlined;
      case 'refresh_outlined':
        return Icons.refresh_outlined;
      case 'category_outlined':
        return Icons.category_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}

class HistorySection extends StatelessWidget {
  final String label;
  final List<HistoryItem> items;

  const HistorySection({super.key, required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        ...items.map((item) => HistoryTile(item: item)).toList(),
      ],
    );
  }
}

class HistoryTile extends StatelessWidget {
  final HistoryItem item;

  const HistoryTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isExpense = item.isExpense;
    final amountFormatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final amountText = (isExpense ? '-' : '+') + amountFormatter.format(item.amount.abs());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.categoryName != null && item.categoryName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.categoryName!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.categoryDescription != null && item.categoryDescription!.isNotEmpty)
                    Text(
                      item.categoryDescription!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isExpense ? Colors.redAccent : Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, hh:mm a').format(item.date),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HistoryItem {
  final String title;
  final String subtitle;
  final double amount;
  final bool isExpense;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String? categoryName;
  final String? categoryDescription;

  const HistoryItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isExpense,
    required this.date,
    required this.icon,
    required this.color,
    this.categoryName,
    this.categoryDescription,
  });
}
