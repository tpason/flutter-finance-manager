import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_frontend/src/core/config/app_colors.dart';
import 'package:flutter_frontend/src/core/services/storage_service.dart';
import 'package:flutter_frontend/src/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_frontend/src/features/plans/data/transaction_service.dart';
import 'package:flutter_frontend/src/features/plans/presentation/pages/add_plan_page.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';
import 'package:flutter_frontend/src/features/home/data/quote_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_frontend/src/features/home/presentation/widgets/analytics_card.dart';
import 'package:flutter_frontend/src/features/plans/presentation/pages/set_new_plan_page.dart';
import 'package:flutter_frontend/src/features/profiles/presentation/pages/profile_page.dart';
import 'package:flutter_frontend/src/features/home/presentation/widgets/stat_cards.dart';
import 'package:flutter_frontend/src/features/home/presentation/widgets/transaction_history_page.dart';
import 'package:flutter_frontend/src/features/common/widgets/skeleton.dart';
import 'package:intl/intl.dart';

String formatUpdatedTime(String isoDate) {
  final DateTime updatedAt = DateTime.parse(isoDate).toLocal();
  final DateTime now = DateTime.now();

  final Duration diff = now.difference(updatedAt);

  if (diff.inSeconds < 30) {
    return 'Updated just now';
  }

  if (diff.inMinutes < 1) {
    return 'Updated ${diff.inSeconds} sec';
  }

  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return 'Updated $m min';
  }

  if (diff.inHours < 24 && now.day == updatedAt.day) {
    return 'Updated today';
  }

  if (diff.inHours < 48 &&
      now.subtract(const Duration(days: 1)).day == updatedAt.day) {
    return 'Updated yesterday';
  }

  if (diff.inDays < 7) {
    return 'Updated this week';
  }

  // Older than a week → show date
  final DateFormat formatter = DateFormat('MMM dd, hh:mm a');
  return 'Updated ${formatter.format(updatedAt)}';
}

DateTimeRange getCurrentMonthRange({DateTime? now}) {
  final DateTime today = now ?? DateTime.now();

  // Start of month: day = 1
  final DateTime startDate = DateTime(
    today.year,
    today.month,
    1,
  );

  // End of month:
  // Day 0 of next month = last day of current month
  final DateTime endDate = DateTime(
    today.year,
    today.month + 1,
    0,
    23,
    59,
    59,
    999,
  );

  return DateTimeRange(start: startDate, end: endDate);
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const HomePage({super.key, this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin<HomePage> {
  int _currentIndex = 0;
  final _pageController = PageController(initialPage: 0);
  final ScrollController _statsScrollController = ScrollController();
  final ScrollController _homeScrollController = ScrollController();
  bool _showPrevButton = false;
  bool _showNextButton = true;
  QuoteService? _quoteService;
  Quote? _currentQuote;
  bool _isLoadingQuote = false;
  bool _isRefreshingQuote = false;
  final _storageService = StorageService();
  final _transactionService = TransactionService();
  Map<String, dynamic>? _userProfile;
  int _selectedAnalyticsIndex = 0;
  DateTime? _lastQuoteReloadAt;
  static const _quoteReloadInterval = Duration(seconds: 5);
  bool _isProfileLoading = true;
  double? _monthlyExpenseTotal;
  String? _expenseSummaryUpdatedAt;
  bool _isSummaryLoading = false;
  List<Map<String, dynamic>> _newTransactions = [];
  bool _isNewTransactionLoading = false;
  bool _isTransactionTimeFrameLoading = false;
  String? _summaryError;
  double? _limitAmount;
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
  );
  final NumberFormat _vndNumberFormat = NumberFormat.decimalPattern('vi_VN');
  List<StatItem> _quickStats = [];
  static const List<String> _analyticsTypes = [
    'today',
    'yesterday',
    'this_week',
    'this_month',
    'this_year',
  ];
  List<AnalyticsEntry> _analytics = [];
  String? _analyticsError;

  // Fallback quotes
  static const List<Quote> _fallbackQuotes = [
    Quote(text: 'The only way to do great work is to love what you do.', author: 'Steve Jobs'),
    Quote(text: 'Innovation distinguishes between a leader and a follower.', author: 'Steve Jobs'),
    Quote(text: 'Life is what happens to you while you\'re busy making other plans.', author: 'John Lennon'),
    Quote(text: 'The future belongs to those who believe in the beauty of their dreams.', author: 'Eleanor Roosevelt'),
    Quote(text: 'It is during our darkest moments that we must focus to see the light.', author: 'Aristotle'),
    Quote(text: 'Be yourself; everyone else is already taken.', author: 'Oscar Wilde'),
    Quote(text: 'So many books, so little time.', author: 'Frank Zappa'),
    Quote(text: 'A room without books is like a body without a soul.', author: 'Marcus Tullius Cicero'),
  ];

  @override
  void initState() {
    super.initState();
    _analytics = _analyticsTypes.map(_placeholderAnalytics).toList();
    _statsScrollController.addListener(_onStatsScroll);
    _homeScrollController.addListener(_onHomeScroll);
    // Check initial scroll position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNavigationButtons();
    });
    // Initialize quote service and load quote after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeQuote();
    });
    // Load user profile from storage
    _loadUserProfile();
    _loadTransactionsTimeFrame(type: _analyticsTypes[_selectedAnalyticsIndex]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      attachLogarteOverlayIfNeeded(context: context);
    });
  }

  AnalyticsEntry _placeholderAnalytics(String type) {
    return AnalyticsEntry(
      title: _timeframeLabel(type),
      subtitle: 'By category',
      total: 'Loading...',
      incomeText: '—',
      expenseText: '—',
      change: '...',
      isExpense: true,
      isIncome: true,
      categories: const [],
    );
  }

  String _timeframeLabel(String type) {
    switch (type) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case 'this_week':
        return 'This Week';
      case 'this_month':
        return 'This Month';
      case 'this_year':
        return 'This Year';
      default:
        return type;
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isProfileLoading = true;
    });
    final profile = await _storageService.getUserProfile();
    if (!mounted) return;

    final resolvedProfile = profile ?? widget.userData;
    setState(() {
      _userProfile = resolvedProfile;
      _limitAmount = _extractLimitAmount(resolvedProfile);
      _isProfileLoading = false;
    });

    await _loadExpenseSummary();
    await _loadNewTransaction();
  }

  double? _extractLimitAmount(Map<String, dynamic>? profile) {
    final limit = profile?['limit_amount'];
    if (limit is num) return limit.toDouble();
    if (limit is String) return double.tryParse(limit);
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _loadExpenseSummary() async {
    if (!mounted) return;
    setState(() {
      _isSummaryLoading = true;
      _summaryError = null;
    });

    final range = getCurrentMonthRange();

    try {
      final response = await _transactionService.sumTransaction(
        start_date: range.start.toIso8601String(),
        end_date: range.end.toIso8601String(),
        type: 'expense',
      );

      if (!mounted) return;

      if (response['success'] == true && response['data'] is Map) {
        final data = response['data'] as Map;
        final total = _parseDouble(data['total'] ?? data['sum']);
        final updatedAt = data['lasted_update_at'] ?? data['updated_at'] ?? data['last_updated_at'];

        setState(() {
          _monthlyExpenseTotal = total ?? 0;
          _expenseSummaryUpdatedAt = updatedAt?.toString();
          _isSummaryLoading = false;
        });
      } else {
        setState(() {
          _summaryError = response['message']?.toString() ?? 'Unable to load summary';
          _isSummaryLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryError = 'Unable to load summary';
        _isSummaryLoading = false;
      });
    }
  }

  Future<void> _loadNewTransaction() async {
    if (!mounted) return;
    setState(() {
      _isNewTransactionLoading = true;
    });


    try {
      final response = await _transactionService.newTransaction();

      if (!mounted) return;

      if (response['success'] == true && response['data'] is Map) {
        final data = response['data'] as Map;
        final items = _extractTransactions(data['items']);
        final mappedStats = _mapTransactionsToQuickStats(items);

        setState(() {
          _newTransactions = items;
          _quickStats = mappedStats;
          _isNewTransactionLoading = false;
        });
      } else {
        setState(() {
          _isNewTransactionLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isNewTransactionLoading = false;
      });
    }
  }

  Future<void> _loadTransactionsTimeFrame({String type = 'today'}) async {
    if (!mounted) return;
    setState(() {
      _isTransactionTimeFrameLoading = true;
      _analyticsError = null;
    });

    try {
      final response = await _transactionService.transactionsTimeFrame(type: type);

      if (!mounted) return;

      if (response['success'] == true && response['data'] is Map) {
        final data = Map<String, dynamic>.from(response['data'] as Map);
        final entry = _buildAnalyticsEntryFromResponse(type, data);

        setState(() {
          final idx = _analyticsTypes.indexOf(type);
          if (idx >= 0 && idx < _analytics.length) {
            _analytics[idx] = entry;
          } else {
            _analytics.add(entry);
          }
          _isTransactionTimeFrameLoading = false;
        });
      } else {
        setState(() {
          _analyticsError = response['message']?.toString() ?? 'Unable to load analytics';
          _isTransactionTimeFrameLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyticsError = 'Unable to load analytics';
        _isTransactionTimeFrameLoading = false;
      });
    }
  }

  AnalyticsEntry _buildAnalyticsEntryFromResponse(String type, Map<String, dynamic> data) {
    final totalIncome = _parseDouble(data['total_income']) ?? 0;
    final totalExpense = _parseDouble(data['total_expense']) ?? 0;
    final net = _parseDouble(data['net']) ?? (totalIncome - totalExpense);
    final incomeText = _currencyFormatter.format(totalIncome);
    final expenseText = _currencyFormatter.format(totalExpense.abs());
    final netText = _currencyFormatter.format(net.abs());
    final changePrefix = net >= 0 ? '+' : '-';

    return AnalyticsEntry(
      title: _timeframeLabel(type),
      subtitle: 'By category',
      total: '$incomeText • -$expenseText',
      incomeText: incomeText,
      expenseText: expenseText,
      change: '$changePrefix$netText net',
      isExpense: totalExpense != 0,
      isIncome: totalIncome != 0,
      categories: _buildCategoryStats(data['categories']),
    );
  }

  List<CategoryStat> _buildCategoryStats(dynamic rawCategories) {
    final categories = <CategoryStat>[];
    if (rawCategories is List) {
      for (final item in rawCategories) {
        if (item is Map) {
          final type = (item['type'] ?? '').toString().toLowerCase();
          final isExpense = type == 'expense';
          final total = _parseDouble(item['total']) ?? 0;
          final signedAmount = isExpense ? -total.abs() : total.abs();
          final formatted = _currencyFormatter.format(total.abs());

          categories.add(
            CategoryStat(
              name: item['category_name']?.toString() ?? 'Category',
              display: isExpense ? '-$formatted' : formatted,
              amount: signedAmount,
            ),
          );
        }
      }
    }
    return categories;
  }


  List<Map<String, dynamic>> _extractTransactions(dynamic raw) {
    final results = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final tx = Map<String, dynamic>.from(item as Map);
          final category = tx['category'];
          if (category is Map) {
            tx['category'] = Map<String, dynamic>.from(category as Map);
          }
          results.add(tx);
        }
      }
    }
    return results;
  }

  List<StatItem> _mapTransactionsToQuickStats(List<Map<String, dynamic>> items) {
    final stats = <StatItem>[];
    for (final item in items) {
      final categoryRaw = item['category'];
      final Map<String, dynamic>? category =
          categoryRaw is Map ? Map<String, dynamic>.from(categoryRaw as Map) : null;
      final type = (item['type'] ?? '').toString().toLowerCase();
      final amount = _parseDouble(item['amount']) ?? 0;
      final amountText = _vndNumberFormat.format(amount.round());

      stats.add(
        StatItem(
          label: category?['name']?.toString() ?? 'Transaction',
          subtitle: "${item['name']?.toString() ?? ''} ${_buildTransactionSubtitle(item, category)}",
          value: amountText,
          icon: _mapIcon(category?['icon']?.toString()),
          change: type == 'income' ? '+ Income' : '- Expense',
          color: _mapColor(category?['color']?.toString()),
          date: _buildTransactionDate(item),
        ),
      );
    }
    return stats;
  }

  String _buildTransactionSubtitle(
    Map<String, dynamic> item,
    Map<String, dynamic>? category,
  ) {
    final desc = item['description']?.toString();
    if (desc != null && desc.isNotEmpty) return "-- $desc";

    final categoryDesc = category?['description']?.toString();
    if (categoryDesc != null && categoryDesc.isNotEmpty) return "- $categoryDesc";

    return 'Recent transaction';
  }

  String _buildTransactionDate(
    Map<String, dynamic> item,
  ) {
    final rawDate = item['date']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        return DateFormat('dd MMM yyyy, HH:mm').format(parsed.toLocal());
      }
    }

    return '';
  }

  Color _mapColor(String? colorKey) {
    switch (colorKey?.toLowerCase()) {
      case 'primary':
        return AppColors.primary;
      case 'blue':
        return AppColors.accentBlue;
      case 'pink':
        return AppColors.accentPink;
      case 'purple':
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
        return Colors.red;
      case 'redaccent':
      case 'red_accent':
      case 'red accent':
        return Colors.redAccent;
      case 'brown':
        return Colors.brown;
      case 'deepurple':
      case 'deep_purple':
      case 'deeppurple':
        return Colors.deepPurple;
      case 'accentpink':
      case 'accent_pink':
        return AppColors.accentPink;
      case 'accentblue':
      case 'accent_blue':
        return AppColors.accentBlue;
      case 'accentpurple':
      case 'accent_purple':
        return AppColors.accentPurple;
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

  String _formatSummaryUpdatedAt() {
    final iso = _expenseSummaryUpdatedAt;
    if (iso == null || iso.isEmpty) return 'Awaiting updates';
    try {
      return formatUpdatedTime(iso);
    } catch (_) {
      return 'Updated recently';
    }
  }

  void _onHomeScroll() {
    // Detect scroll to top to reload quote
    if (_homeScrollController.hasClients) {
      final position = _homeScrollController.position;
      if (position.pixels <= 0 && !_isRefreshingQuote && !_isLoadingQuote) {
        _reloadQuote();
      }
    }
  }

  void _initializeQuote({bool forceNew = false}) {
    try {
      _quoteService ??= QuoteService();
      
      // Show random fallback quote immediately
      final randomIndex = DateTime.now().millisecondsSinceEpoch % _fallbackQuotes.length;
      if (mounted) {
        setState(() {
          _currentQuote = _fallbackQuotes[randomIndex];
        });
      }
      
      // Then try to load from API
      _loadQuote();
    } catch (e) {
      logarte.log('Error initializing quote service: $e');
      // Use fallback quote
      final randomIndex = DateTime.now().millisecondsSinceEpoch % _fallbackQuotes.length;
      if (mounted) {
        setState(() {
          _currentQuote = _fallbackQuotes[randomIndex];
        });
      }
    }
  }

  Future<void> _reloadQuote() async {
    if (_isRefreshingQuote || _isLoadingQuote) return;

    final now = DateTime.now();
    if (_lastQuoteReloadAt != null && now.difference(_lastQuoteReloadAt!) < _quoteReloadInterval) {
      return;
    }
    _lastQuoteReloadAt = now;
    
    setState(() {
      _isRefreshingQuote = true;
    });
    
    // Show random fallback quote immediately
    final randomIndex = DateTime.now().millisecondsSinceEpoch % _fallbackQuotes.length;
    if (mounted) {
      setState(() {
        _currentQuote = _fallbackQuotes[randomIndex];
      });
    }
    
    // Then try to load from API
    await _loadQuote();
    
    if (mounted) {
      setState(() {
        _isRefreshingQuote = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _reloadQuote(),
      _loadExpenseSummary(),
      _loadNewTransaction(),
      _loadTransactionsTimeFrame(type: _analyticsTypes[_selectedAnalyticsIndex]),
    ]);
  }

  Future<void> _loadQuote() async {
    if (_isLoadingQuote || _quoteService == null) return;
    
    try {
      setState(() {
        _isLoadingQuote = true;
      });
      
      // Try to load quote from API
      final quote = await _quoteService!.getRandomQuote();
      
      // Use API quote if available, otherwise keep fallback
      if (quote != null && mounted) {
        setState(() {
          _currentQuote = quote;
          _isLoadingQuote = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingQuote = false;
        });
      }
    } catch (e) {
      logarte.log('Error loading quote: $e');
      if (mounted) {
        setState(() {
          _isLoadingQuote = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _statsScrollController.removeListener(_onStatsScroll);
    _homeScrollController.removeListener(_onHomeScroll);
    _statsScrollController.dispose();
    _homeScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onStatsScroll() {
    _updateNavigationButtons();
  }

  void _updateNavigationButtons() {
    if (!_statsScrollController.hasClients || !mounted) return;
    try {
      final position = _statsScrollController.position;
      if (mounted) {
        setState(() {
          _showPrevButton = position.pixels > 0.1;
          _showNextButton = position.pixels < position.maxScrollExtent - 0.1;
        });
      }
    } catch (e) {
      // Ignore errors during scroll position updates
    }
  }

  void _scrollStats(BuildContext context, bool forward) {
    if (!_statsScrollController.hasClients || !mounted) return;
    try {
      final position = _statsScrollController.position;
      final screenWidth = MediaQuery.of(context).size.width;
      final cardWidth = screenWidth * 0.45 + 16; // width + margin
      final currentPosition = position.pixels;
      final maxScroll = position.maxScrollExtent;
      
      if (maxScroll <= 0) return; // No scroll needed
      
      final targetPosition = forward
          ? currentPosition + cardWidth
          : currentPosition - cardWidth;

      _statsScrollController.animateTo(
        targetPosition.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } catch (e) {
      // Ignore errors during scroll animation
    }
  }

  // Quick stats are populated from the latest transactions

  String get _displayName {
    final profile = _userProfile ?? widget.userData;
    logarte.log('HomePage profile source: $profile');
    if (profile == null) return 'sam';

    final name = profile['full_name'] ??
        profile['name'] ??
        profile['username'] ??
        profile['email'] ??
        'sam';

    logarte.log('Resolved _displayName: $name');
    return name;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.bgWarm,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            // Reload quote when returning to home page
            if (index == 0) {
              _reloadQuote();
            }
          },
          children: [
            _buildHomeContent(context),
            const AddPlanPage(),
            _buildProfilePlaceholder(context),
          ],
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _currentIndex,
        backgroundColor: AppColors.bgWarm,
        color: Colors.white,
        buttonBackgroundColor: AppColors.card,
        height: 60,
        animationCurve: Curves.easeOutCubic,
        animationDuration: const Duration(milliseconds: 450),
        items: const [
          Icon(Icons.home_filled, size: 28, color: AppColors.primary),
          Icon(Icons.add, size: 28, color: AppColors.primary),
          Icon(Icons.person_outline, size: 28, color: AppColors.primary),
        ],
        onTap: (i) {
          _pageController.animateToPage(
            i,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        controller: _homeScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(context),
            const SizedBox(height: 12),
            _buildHeader(),
            const SizedBox(height: 28),
            _buildIncomeCard(),
            const SizedBox(height: 20),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildAnalyticsSection(context),
            const SizedBox(height: 20),
            _buildAddNewCTA(context),
            const SizedBox(height: 80), // spacing above nav bar
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePlaceholder(BuildContext context) {
    final profile = _userProfile ?? widget.userData;
    return ProfilePage(
      profile: profile,
      onLogout: () => _handleLogout(context),
      isLoading: _isProfileLoading,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 48,
          height: 48,
          // decoration: BoxDecoration(
          //   color: Colors.white.withOpacity(0.25),
          //   borderRadius: BorderRadius.circular(16),
          // ),
          // child: const Icon(Icons.grid_view_rounded, color: Colors.white),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              _handleLogout(context);
            }
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'logout',
              child: Text('Logout'),
            ),
          ],
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person_outline, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final isQuoteLoading = _currentQuote == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (_isProfileLoading
                ? const Skeleton(width: 180, height: 32)
                : Text(
                    'Hi, $_displayName',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ))
            .animate()
            .fadeIn(duration: 500.ms, curve: Curves.easeOutCubic)
            .slideY(begin: 0.1, end: 0, duration: 500.ms),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _reloadQuote,
          child: isQuoteLoading
              ? Row(
                  children: const [
                    Skeleton(
                        width: 14, height: 14, borderRadius: BorderRadius.all(Radius.circular(7))),
                    SizedBox(width: 6),
                    Skeleton(
                        width: 120,
                        height: 14,
                        borderRadius: BorderRadius.all(Radius.circular(4))),
                  ],
                ).animate().fadeIn(duration: 400.ms)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '"${_currentQuote!.text}"',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 800.ms, delay: 200.ms)
                              .slideY(begin: 0.2, end: 0, duration: 800.ms, delay: 200.ms, curve: Curves.easeOutCubic),
                        ),
                        const SizedBox(width: 8),
                        if (_isRefreshingQuote)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.7),
                              ),
                            ),
                          )
                              .animate(
                                onPlay: (controller) => controller.repeat(),
                              )
                              .rotate(duration: 800.ms)
                        else
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: Colors.white.withOpacity(0.5),
                          )
                              .animate()
                              .fadeIn(duration: 300.ms),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '— ${_currentQuote!.author}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 500.ms)
                        .slideX(begin: -0.15, end: 0, duration: 600.ms, delay: 500.ms, curve: Curves.easeOutCubic),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildIncomeCard() {
    final total = _monthlyExpenseTotal ?? 0;
    final limitAmount = _limitAmount ?? 0;
    final ratio = limitAmount > 0 ? total / limitAmount : 0.0;
    final isOverLimit = ratio > 1;
    final progressValue = ratio.isFinite ? ratio.clamp(0.0, 1.0) : 0.0;
    final percentage = (ratio.isFinite ? ratio * 100 : 0).round();
    final displayPercentage = isOverLimit ? '100%+' : '$percentage%';
    final subtitle = _summaryError ??
        (_isSummaryLoading ? 'Fetching summary...' : _formatSummaryUpdatedAt());
    final limitAmountSubtitle = _limitAmount != null
        ? 'Limit: ${_currencyFormatter.format(_limitAmount!)}${isOverLimit ? ' • Over limit' : ''}'
        : 'Limit: —';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isSummaryLoading
                    ? const Skeleton(width: 120, height: 32)
                    : Text(
                        _currencyFormatter.format(total),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                const SizedBox(height: 4),
                _isSummaryLoading
                    ? const Skeleton(width: 150, height: 14)
                    : Text(
                        limitAmountSubtitle,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _summaryError != null || isOverLimit
                              ? Colors.redAccent
                              : AppColors.textSecondary,
                        ),
                      ),
                const SizedBox(height: 4),
                _isSummaryLoading
                    ? const Skeleton(width: 150, height: 14)
                    : Text(
                        subtitle,
                        style: TextStyle(
                          color: _summaryError != null
                              ? Colors.redAccent
                              : AppColors.textSecondary,
                        ),
                      ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progressValue),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: (isOverLimit ? Colors.redAccent : AppColors.accentBlue)
                            .withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(
                          isOverLimit ? Colors.redAccent : AppColors.accentBlue,
                        ),
                      ),
                    ),
                    Text(
                      displayPercentage,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOverLimit ? Colors.redAccent : AppColors.textPrimary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    if (_isNewTransactionLoading && _newTransactions.isEmpty && _quickStats.isEmpty) {
      return Container(
        height: 155,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_quickStats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.bar_chart_outlined,
                size: 48,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'No statistics available',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add transactions to see your stats',
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 155,
      child: Stack(
        children: [
          ListView.builder(
            controller: _statsScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _quickStats.length,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemBuilder: (context, index) {
              if (index >= _quickStats.length) return const SizedBox.shrink();
              final stat = _quickStats[index];
              final screenWidth = MediaQuery.of(context).size.width;
              return Container(
                width: screenWidth * 0.45,
                margin: EdgeInsets.only(
                  right: index == _quickStats.length - 1 ? 0 : 16,
                ),
                child: StatCard(
                  label: stat.label,
                  subtitle: stat.subtitle,
                  value: "${stat.value} ₫",
                  icon: stat.icon,
                  change: stat.change,
                  color: stat.color,
                  date: stat.date,
                ),
              );
            },
          ),
          // Previous button
          if (_showPrevButton)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showPrevButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _scrollStats(context, false),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Next button
          if (_showNextButton)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showNextButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _scrollStats(context, true),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(BuildContext context) {
    final hasEntry =
        _analytics.isNotEmpty && _selectedAnalyticsIndex < _analytics.length;
    final analyticsEntry = hasEntry
        ? _analytics[_selectedAnalyticsIndex]
        : _placeholderAnalytics(_analyticsTypes[_selectedAnalyticsIndex]);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Spending & Income',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: _openHistoryPage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.history, size: 16, color: AppColors.textPrimary),
                      SizedBox(width: 6),
                      Text(
                        'History',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAnalyticsTabs(),
          if (_isTransactionTimeFrameLoading)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_analyticsError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _analyticsError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          AnalyticsCard(
            title: analyticsEntry.title,
            subtitle: analyticsEntry.subtitle,
            total: analyticsEntry.total,
            incomeText: analyticsEntry.incomeText,
            expenseText: analyticsEntry.expenseText,
            change: analyticsEntry.change,
            categories: analyticsEntry.categories,
            isExpense: analyticsEntry.isExpense,
            isIncome: analyticsEntry.isIncome,
          ),
        ],
      ),
    );
  }

  Widget _buildTag({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildAnalyticsTabs() {
    final labels = _analyticsTypes.map(_timeframeLabel).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _selectedAnalyticsIndex == index;
          return Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 10),
            child: ChoiceChip(
              label: Text(labels[index]),
              selected: selected,
              selectedColor: AppColors.primary.withOpacity(0.15),
              labelStyle: TextStyle(
                color: selected ? AppColors.primaryDark : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: AppColors.card,
              shape: StadiumBorder(
                side: BorderSide(
                  color: selected
                      ? AppColors.primary.withOpacity(0.35)
                      : AppColors.textSecondary.withOpacity(0.15),
                ),
              ),
              onSelected: (_) {
                setState(() {
                  _selectedAnalyticsIndex = index;
                });
                _loadTransactionsTimeFrame(type: _analyticsTypes[index]);
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAddNewCTA(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSetPlanPage(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ADD NEW',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.settings, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _openSetPlanPage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SetNewPlanPage(),
      ),
    );
  }

  void _openHistoryPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TransactionHistoryPage(),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    await StorageService().clearAuthData();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }
}
