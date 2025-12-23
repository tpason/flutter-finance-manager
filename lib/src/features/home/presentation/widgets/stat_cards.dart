import 'package:flutter/material.dart';

import 'package:flutter_frontend/src/core/config/app_colors.dart';

class StatItem {
  final String label;
  final String subtitle;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
  final String date;

  const StatItem({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
    String? date,
  }) : date = date ?? '';
}

class StatCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
  final String date;

  const StatCard({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
    String? date,
  }) : date = date ?? '';

  @override
  Widget build(BuildContext context) {
    final bool isNegative = change.startsWith('-');
    final Color accentColor = isNegative ? Colors.red.shade400 : Colors.teal.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: accentColor,
              height: 1.05,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withOpacity(0.7),
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              date,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.2,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
