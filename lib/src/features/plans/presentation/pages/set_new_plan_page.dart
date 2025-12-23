import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_frontend/src/core/config/app_colors.dart';
import 'package:flutter_frontend/src/core/logging/logarte_instance.dart';
import 'package:flutter_frontend/src/core/services/master_data_service.dart';
import 'package:flutter_frontend/src/features/home/presentation/pages/home_page.dart';
import 'package:flutter_frontend/src/features/plans/data/category_service.dart';
import 'package:flutter_frontend/src/features/plans/data/transaction_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class SetNewPlanPage extends StatefulWidget {
  const SetNewPlanPage({
    super.key,
    this.title = 'Set New Transaction',
    this.subtitle = 'Log a new transaction quickly.',
    this.nameLabel = 'Name',
    this.descriptionLabel = 'Description',
    this.categoryLabel = 'Category',
    this.amountLabel = 'Amount',
    this.nameHint = 'Transaction title',
    this.descriptionHint = 'Transaction description',
    this.amountHint = 'Type amount',
    this.saveLabel = 'Save Now',
    this.showBackButton = true,
    this.initialTypeIndex = 0,
  });

  final String title;
  final String subtitle;
  final String nameLabel;
  final String descriptionLabel;
  final String categoryLabel;
  final String amountLabel;
  final String nameHint;
  final String descriptionHint;
  final String amountHint;
  final String saveLabel;
  final bool showBackButton;
  final int initialTypeIndex;

  @override
  State<SetNewPlanPage> createState() => _SetNewPlanPageState();
}

class _SetNewPlanPageState extends State<SetNewPlanPage> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategoryCode;
  int _selectedTypeIndex = 0;
  bool _isLoading = false;
  final _transactionService = TransactionService();
  bool _isLoadingCategories = false;
  final NumberFormat _vndNumberFormat = NumberFormat.decimalPattern('vi_VN');

  static const List<String> _transactionTypes = ['expense', 'income'];
  Map<String, List<_CategoryOption>> _categoryOptions = {
    'expense': _fallbackExpenseCategories,
    'income': _fallbackIncomeCategories,
  };

  _CategoryOption? _firstCategoryForType(String type) {
    final list = _categoryOptions[type];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }
  @override
  void initState() {
    super.initState();
    _selectedTypeIndex = widget.initialTypeIndex.clamp(0, _transactionTypes.length - 1);
    _selectedCategoryCode = _firstCategoryForType(_transactionTypes[_selectedTypeIndex])?.code;
    _budgetController.addListener(_onAmountChanged);
    _loadCategories();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      attachLogarteOverlayIfNeeded(context: context);
    });
  }

  void _onAmountChanged() {
    final raw = _budgetController.text;
    final digits = _digitsOnly(raw);
    final formatted = digits.isEmpty ? '' : _vndNumberFormat.format(int.parse(digits));

    // Only update if formatting changes; keep cursor at end
    if (raw != formatted) {
      _budgetController
        ..removeListener(_onAmountChanged)
        ..text = formatted
        ..selection = TextSelection.collapsed(offset: formatted.length)
        ..addListener(_onAmountChanged);
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    final master = MasterDataService.instance;
    try {
      final cached = master.categories;
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _categoryOptions = _mapApiCategories(cached);
          _selectedCategoryCode ??=
              _firstCategoryForType(_transactionTypes[_selectedTypeIndex])?.code;
        });
      }

      await master.clearCategoriesCache();
      await master.preloadCategories(force: true);
      final latest = master.categories;
      if (mounted && latest.isNotEmpty) {
        setState(() {
          _categoryOptions = _mapApiCategories(latest);
          _selectedCategoryCode ??=
              _firstCategoryForType(_transactionTypes[_selectedTypeIndex])?.code;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }


  Map<String, List<_CategoryOption>> _mapApiCategories(List<CategoryDto> items) {
    final result = <String, List<_CategoryOption>>{
      'expense': [],
      'income': [],
    };

    for (final item in items) {
      if (!result.containsKey(item.type)) continue;
      result[item.type]!.add(
        _CategoryOption(
          label: item.name,
          subtitle: item.description ?? '',
          icon: _mapIcon(item.icon),
          color: _mapColor(item.color),
          code: item.id,
        ),
      );
    }

    if (result['expense']!.isEmpty) result['expense'] = _fallbackExpenseCategories;
    if (result['income']!.isEmpty) result['income'] = _fallbackIncomeCategories;
    return result;
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

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController
      ..removeListener(_onAmountChanged)
      ..dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgWarm.withOpacity(0.8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildTitleSection(),
                      const SizedBox(height: 32),
                      _buildInputLabel(widget.nameLabel),
                      _buildTextField(
                        controller: _nameController,
                        hint: widget.nameHint,
                      ),
                      const SizedBox(height: 24),
                      _buildInputLabel(widget.descriptionLabel),
                      _buildTextField(
                        controller: _descriptionController,
                        hint: widget.descriptionHint,
                      ),
                      const SizedBox(height: 24),
                      _buildInputLabel('Type'),
                      const SizedBox(height: 12),
                      _buildTypeSelector(),
                      const SizedBox(height: 24),
                      _buildInputLabel(widget.categoryLabel),
                      const SizedBox(height: 16),
                      _buildCategoryCompact(context),
                      const SizedBox(height: 32),
                      _buildInputLabel(widget.amountLabel),
                      _buildTextField(
                        controller: _budgetController,
                        hint: widget.amountHint,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
                        inputFormatters: const [],
                        trailing: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.calculate_outlined,
                            color: AppColors.accentBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          if (widget.showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48),
          const Spacer(),
          // Container(
          //   width: 54,
          //   height: 54,
          //   decoration: BoxDecoration(
          //     color: Colors.white.withOpacity(0.2),
          //     borderRadius: BorderRadius.circular(18),
          //   ),
          //   // child: const Icon(Icons.share_outlined, color: Colors.white),
          // ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(32),
          ),
          child: const Icon(
            Icons.payments_outlined,
            size: 36,
            color: AppColors.primaryDark,
          ),
        )
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    Widget? trailing,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontSize: 16,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    final labels = ['Expense', 'Income'];
    final colors = [AppColors.accentPink, AppColors.accentBlue];
    final icons = [Icons.south_west_rounded, Icons.north_east_rounded];

    return Row(
      children: List.generate(labels.length, (index) {
        final selected = index == _selectedTypeIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedTypeIndex = index;
                _selectedCategoryCode =
                    _firstCategoryForType(_transactionTypes[_selectedTypeIndex])?.code;
              });
            },
            child: Container(
              margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: colors[index].withOpacity(selected ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? colors[index] : Colors.transparent,
                  width: 1.3,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icons[index], color: colors[index], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: colors[index],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCategoryCompact(BuildContext context) {
    final typeKey = _transactionTypes[_selectedTypeIndex];
    final options = _categoryOptions[typeKey] ?? const <_CategoryOption>[];
    if (_isLoadingCategories && options.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (options.isEmpty) return const SizedBox();

    final primary = options.take(3).toList();
    final selectedCode = _selectedCategoryCode;
    final selectedInPrimary = primary.any((o) => o.code == selectedCode);

    return Row(
      children: [
        ...primary.map(
          (option) => Expanded(
            child: _CategoryChip(
              option: option,
              selected: option.code == selectedCode,
              onTap: () {
                setState(() {
                  _selectedCategoryCode = option.code;
                });
              },
            ),
          ),
        ),
        Expanded(
          child: _CategoryChip(
            option: _CategoryOption(
              label: selectedInPrimary ? 'More' : (options.firstWhere((o) => o.code == selectedCode, orElse: () => options.first).label),
              subtitle: 'See all',
              icon: Icons.apps_rounded,
              color: Colors.grey,
              code: 'more',
            ),
            selected: !selectedInPrimary,
            onTap: () => _showCategoryPicker(context, options),
          ),
        ),
      ],
    );
  }

  void _showCategoryPicker(BuildContext context, List<_CategoryOption> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: options.map((option) {
                  final selected = option.code == _selectedCategoryCode;
                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
                    child: _CategoryCard(
                      option: option,
                      selected: selected,
                      onTap: () {
                        setState(() {
                          _selectedCategoryCode = option.code;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              disabledBackgroundColor: AppColors.accentBlue.withOpacity(0.5),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.saveLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white
                        ),
                      ),
                      SizedBox(width: 8),
                      // Icon(Icons.save_alt_rounded, size: 18),
                    ],
                  ),
          ),
        ),
        // const SizedBox(width: 12),
        // Container(
        //   width: 56,
        //   height: 56,
        //   decoration: BoxDecoration(
        //     color: AppColors.primary,
        //     borderRadius: BorderRadius.circular(18),
        //   ),
        //   child: const Icon(Icons.share, color: Colors.white),
        // ),
      ],
    );
  }

  Future<void> _handleSave() async {
    // Validate inputs
    if (_nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter a name',
        toastLength: Toast.LENGTH_SHORT,
      );
      return;
    }

    if (_budgetController.text.trim().isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please enter an amount',
        toastLength: Toast.LENGTH_SHORT,
      );
      return;
    }

    final amount = _parseAmount(_budgetController.text);
    if (amount == null || amount <= 0) {
      Fluttertoast.showToast(
        msg: 'Please enter a valid amount',
        toastLength: Toast.LENGTH_SHORT,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final type = _transactionTypes[_selectedTypeIndex];
      final typeCategories = _categoryOptions[type] ?? [];
      final selectedCategory = typeCategories.firstWhere(
        (c) => c.code == _selectedCategoryCode,
        orElse: () => _firstCategoryForType(type) ?? const _CategoryOption(
          label: 'Other',
          icon: Icons.category_outlined,
          color: Colors.grey,
          code: 'fallback_other',
        ),
      );

      final result = await _transactionService.createTransaction(
        amount: amount.toDouble(),
        type: type,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? _nameController.text.trim()
            : _descriptionController.text.trim(),
        categoryId: selectedCategory.code,
      );

      if (result['success'] == true) {
        Fluttertoast.showToast(
          msg: 'Transaction created successfully',
          toastLength: Toast.LENGTH_SHORT,
        );
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const HomePage(),
            ),
            (route) => false,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: result['detail'] ?? 'Failed to create transaction',
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString()}',
        toastLength: Toast.LENGTH_SHORT,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int? _parseAmount(String input) {
    final digits = _digitsOnly(input);
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  String _digitsOnly(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');
}

class _CategoryOption {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String code;

  const _CategoryOption({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.code,
  });
}

class _CategoryChip extends StatelessWidget {
  final _CategoryOption option;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: option.color.withOpacity(selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? option.color : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: option.color.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(option.icon, color: option.color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              option.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                fontSize: 10,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final _CategoryOption option;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: option.color.withOpacity(selected ? 0.18 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? option.color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: option.color.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(option.icon, color: option.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (option.subtitle != null)
                    Text(
                      option.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<_CategoryOption> _fallbackExpenseCategories = [
  _CategoryOption(
    label: 'Food & Drinks',
    subtitle: 'Meals, coffee, eating out',
    icon: Icons.restaurant_menu,
    color: AppColors.accentPink,
    code: 'expense_food',
  ),
  _CategoryOption(
    label: 'Shopping',
    subtitle: 'Clothes, cosmetics, accessories',
    icon: Icons.shopping_bag_outlined,
    color: AppColors.accentPurple,
    code: 'expense_shopping',
  ),
  _CategoryOption(
    label: 'Home & Bills',
    subtitle: 'Rent, utilities, household',
    icon: Icons.home_outlined,
    color: AppColors.primary,
    code: 'expense_household',
  ),
  _CategoryOption(
    label: 'Transport',
    subtitle: 'Taxi, fuel, travel',
    icon: Icons.directions_car_filled_outlined,
    color: AppColors.accentBlue,
    code: 'expense_transport',
  ),
  _CategoryOption(
    label: 'Health & Education',
    subtitle: 'Study, hospital, insurance',
    icon: Icons.health_and_safety_outlined,
    color: Colors.teal,
    code: 'expense_health',
  ),
  _CategoryOption(
    label: 'Finance & Invest',
    subtitle: 'Debt, interest, investing',
    icon: Icons.savings_outlined,
    color: Colors.orangeAccent,
    code: 'expense_finance',
  ),
  _CategoryOption(
    label: 'Social & Gifts',
    subtitle: 'Gifts, parties, charity',
    icon: Icons.cake_outlined,
    color: Colors.brown,
    code: 'expense_social',
  ),
  _CategoryOption(
    label: 'Other',
    subtitle: 'Other expense',
    icon: Icons.category_outlined,
    color: Colors.grey,
    code: 'expense_other',
  ),
];

const List<_CategoryOption> _fallbackIncomeCategories = [
  _CategoryOption(
    label: 'Salary',
    subtitle: 'Primary monthly income',
    icon: Icons.attach_money,
    color: AppColors.primary,
    code: 'income_salary',
  ),
  _CategoryOption(
    label: 'Bonus',
    subtitle: 'KPI or year-end bonus',
    icon: Icons.stars_rounded,
    color: Colors.amber,
    code: 'income_bonus',
  ),
  _CategoryOption(
    label: 'Allowance',
    subtitle: 'Meal, commute stipend',
    icon: Icons.card_giftcard,
    color: AppColors.accentPink,
    code: 'income_allowance',
  ),
  _CategoryOption(
    label: 'Side Job',
    subtitle: 'Freelance, overtime',
    icon: Icons.work_outline,
    color: AppColors.accentBlue,
    code: 'income_sidejob',
  ),
  _CategoryOption(
    label: 'Invest Profit',
    subtitle: 'Stocks, crypto, funds',
    icon: Icons.trending_up,
    color: Colors.green,
    code: 'income_investment',
  ),
  _CategoryOption(
    label: 'Small Business',
    subtitle: 'Online sales, services',
    icon: Icons.storefront_outlined,
    color: Colors.deepPurple,
    code: 'income_business',
  ),
  _CategoryOption(
    label: 'Family Support',
    subtitle: 'Money from parents',
    icon: Icons.volunteer_activism_outlined,
    color: Colors.redAccent,
    code: 'income_support',
  ),
  _CategoryOption(
    label: 'Refund',
    subtitle: 'Reimbursement, cashback',
    icon: Icons.refresh_outlined,
    color: Colors.teal,
    code: 'income_refund',
  ),
  _CategoryOption(
    label: 'Other',
    subtitle: 'Other income',
    icon: Icons.category_outlined,
    color: Colors.grey,
    code: 'income_other',
  ),
];
