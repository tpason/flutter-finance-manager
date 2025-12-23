import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:flutter_frontend/src/core/config/app_colors.dart';

class AnalyticsEntry {
  final String title;
  final String subtitle;
  final String total;
  final String incomeText;
  final String expenseText;
  final String change;
  final bool isExpense;
  final bool isIncome;
  final List<CategoryStat> categories;

  const AnalyticsEntry({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.incomeText,
    required this.expenseText,
    required this.change,
    required this.isExpense,
    required this.isIncome,
    required this.categories,
  });
}

class CategoryStat {
  final String name;
  final String display;
  final double amount;

  const CategoryStat({
    required this.name,
    required this.display,
    required this.amount,
  });
}

class AnalyticsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String total;
  final String incomeText;
  final String expenseText;
  final String change;
  final bool isExpense;
  final bool isIncome;
  final List<CategoryStat> categories;

  const AnalyticsCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.total,
    required this.incomeText,
    required this.expenseText,
    required this.change,
    required this.isExpense,
    required this.isIncome,
    required this.categories,
  });

  Color get _chipColor => isExpense && !isIncome
      ? AppColors.accentPink
      : (!isExpense && isIncome)
          ? AppColors.accentBlue
          : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 24 * 2;
    final maxAbs = categories.isNotEmpty
        ? categories.map((c) => c.amount.abs()).reduce((a, b) => a > b ? a : b)
        : 1.0;
    final chartData = _buildChartData();

    return Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _chipColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (isIncome)
                      Text(
                        'Income',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isExpense ? AppColors.accentBlue : _chipColor,
                          fontSize: 11,
                        ),
                      ),
                    if (isIncome && isExpense) const SizedBox(width: 6),
                    if (isExpense)
                      Text(
                        'Expense',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isIncome ? AppColors.accentPink : _chipColor,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: incomeText,
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.teal.shade300,
                  ),
                ),
                const TextSpan(
                  text: ' • ',
                  style: TextStyle(
                    fontSize: 22,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: '-$expenseText',
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.red.shade300,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            change,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: change.startsWith('-') ? Colors.redAccent : Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 170,
            child: chartData.isEmpty
                ? const Center(
                    child: Text(
                      'No data',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sections: chartData,
                      centerSpaceRadius: 32,
                      sectionsSpace: 1.5,
                      startDegreeOffset: -90,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          ...categories.take(4).map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            c.display,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final pct = maxAbs == 0 ? 0 : (c.amount.abs() / maxAbs);
                          final barColor =
                              c.amount < 0 ? Colors.redAccent : AppColors.accentBlue;
                          return Stack(
                            children: [
                              Container(
                                height: 6,
                                width: constraints.maxWidth,
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              Container(
                                height: 6,
                                width: constraints.maxWidth * pct,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildChartData() {
    if (categories.isEmpty) return [];
    final absTotal = categories.map((e) => e.amount.abs()).fold<double>(0, (a, b) => a + b);
    if (absTotal == 0) return [];

    const palette = [
      Color(0xFF6C63FF),
      Color(0xFF00BFA6),
      Color(0xFFFFA726),
      Color(0xFFFF7043),
      Color(0xFF29B6F6),
      Color(0xFFAB47BC),
    ];

    return List.generate(categories.length, (i) {
      final c = categories[i];
      final value = c.amount.abs();
      final pct = value / absTotal * 100;
      final displayPct = (pct > 0 && pct < 1) ? 1 : pct;
      return PieChartSectionData(
        value: value,
        color: palette[i % palette.length],
        radius: 38,
        title: '${displayPct.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    });
  }
}
