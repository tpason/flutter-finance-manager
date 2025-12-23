import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_frontend/src/core/config/app_colors.dart';
import 'package:flutter_frontend/src/features/common/widgets/skeleton.dart';

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onLogout;
  final bool isLoading;

  const ProfilePage({
    super.key,
    this.profile,
    required this.onLogout,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          isLoading ? _buildProfileHeaderSkeleton() : _buildProfileHeader(profile),
          const SizedBox(height: 24),
          isLoading ? _buildProfileInfoSkeleton() : _buildProfileInfoCard(profile),
          const SizedBox(height: 16),
          isLoading ? _buildAccountStatusSkeleton() : _buildAccountStatusCard(profile),
          const SizedBox(height: 16),
          isLoading ? _buildLogoutSkeleton() : _buildLogoutButton(context),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic>? profile) {
    final name = profile?['full_name'] ??
        profile?['name'] ??
        profile?['username'] ??
        'User';
    final email = profile?['email'] ?? 'No email';
    final initials = _getInitials(name);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildProfileHeaderSkeleton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.6),
            AppColors.primaryDark.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          const Skeleton(
            width: 80,
            height: 80,
            borderRadius: BorderRadius.all(Radius.circular(40)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Skeleton(width: 160, height: 18),
                SizedBox(height: 10),
                Skeleton(width: 120, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard(Map<String, dynamic>? profile) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Username',
            value: profile?['username'] ?? 'N/A',
            color: AppColors.accentBlue,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: profile?['email'] ?? 'N/A',
            color: AppColors.accentPink,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.payments_outlined,
            label: 'Limit Amount',
            value: _formatLimitAmount(profile?['limit_amount']),
            color: AppColors.accentBlue,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Full Name',
            value: profile?['full_name'] ?? 'N/A',
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Role',
            value: profile?['role'] ?? 'N/A',
            color: Colors.amber,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildProfileInfoSkeleton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Skeleton(width: 180, height: 18),
          SizedBox(height: 20),
          Skeleton(width: double.infinity, height: 18),
          SizedBox(height: 16),
          Skeleton(width: double.infinity, height: 18),
          SizedBox(height: 16),
          Skeleton(width: double.infinity, height: 18),
          SizedBox(height: 16),
          Skeleton(width: double.infinity, height: 18),
        ],
      ),
    );
  }

  Widget _buildAccountStatusCard(Map<String, dynamic>? profile) {
    final isActive = profile?['is_active'] ?? false;
    final isSuperuser = profile?['is_superuser'] ?? false;
    final createdAt = profile?['created_at'];
    final updatedAt = profile?['updated_at'];

    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatusBadge(
                label: 'Active',
                isActive: isActive,
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              if (isSuperuser)
                _buildStatusBadge(
                  label: 'Superuser',
                  isActive: true,
                  color: Colors.purple,
                ),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Member Since',
              value: _formatDate(createdAt),
              color: AppColors.accentPurple,
            ),
          ],
          if (updatedAt != null) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.update_outlined,
              label: 'Last Updated',
              value: _formatDate(updatedAt),
              color: Colors.teal,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildAccountStatusSkeleton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Skeleton(width: 160, height: 18),
          SizedBox(height: 20),
          Skeleton(width: 120, height: 24),
          SizedBox(height: 12),
          Skeleton(width: 100, height: 20),
          SizedBox(height: 16),
          Skeleton(width: double.infinity, height: 18),
          SizedBox(height: 12),
          Skeleton(width: double.infinity, height: 18),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge({
    required String label,
    required bool isActive,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? color : Colors.grey,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: onLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.1),
          foregroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_outlined, size: 20),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildLogoutSkeleton() {
    return const Skeleton(
      width: double.infinity,
      height: 52,
      borderRadius: BorderRadius.all(Radius.circular(18)),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatLimitAmount(dynamic value) {
    if (value == null) return 'N/A';
    int? amount;
    if (value is num) {
      amount = value.toInt();
    } else {
      amount = double.tryParse(value.toString())?.toInt();
    }
    if (amount == null) return 'N/A';
    final raw = amount.toString();
    return raw.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }
}
