import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/features/auth/login_screen.dart';
import 'package:safeseat_mini/features/profile/edit_profile_screen.dart';
import 'package:safeseat_mini/features/profile/wallet_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = user.name.trim().isEmpty ? 'ผู้ใช้งาน' : user.name.trim();
    final imagePath = user.profileImagePath;
    final homeName = user.homeDisplayName?.trim();
    final hasHome = homeName != null && homeName.isNotEmpty;
    void openEditProfile() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('โปรไฟล์'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _Surface(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.10,
                        ),
                        backgroundImage:
                            imagePath != null && imagePath.isNotEmpty
                            ? NetworkImage(imagePath)
                            : null,
                        child: imagePath == null || imagePath.isEmpty
                            ? const Icon(
                                Icons.person_rounded,
                                size: 38,
                                color: AppTheme.primaryColor,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.phoneNo,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.edit_outlined,
                  title: 'แก้ไขข้อมูลส่วนตัว',
                  subtitle: 'ชื่อ อีเมล รูปภาพ และยานพาหนะ',
                  onTap: openEditProfile,
                ),
                const SizedBox(height: 28),
                const _SectionHeading('กระเป๋าเงิน'),
                const SizedBox(height: 12),
                _Surface(
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              _IconBadge(Icons.account_balance_wallet_outlined),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'SafeSeat Wallet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'ยอดคงเหลือ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '฿ ${user.walletBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'ดูยอดเงินและเติมเงิน',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const _SectionHeading('สถานที่บันทึก'),
                const SizedBox(height: 12),
                _Surface(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _IconBadge(Icons.home_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'บ้าน',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasHome ? homeName : 'ยังไม่ได้ระบุที่อยู่บ้าน',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (user.homeLatLng != null) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'บันทึกพิกัดแล้ว',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: openEditProfile,
                        child: Text(hasHome ? 'แก้ไข' : 'ตั้งค่า'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _showLogoutDialog(context, ref),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('ออกจากระบบ'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(
                        color: AppTheme.errorColor.withValues(alpha: 0.45),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.showConfirm(
      context: context,
      title: 'ออกจากระบบ',
      message: 'คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบบัญชีของคุณ?',
      confirmText: 'ออกจากระบบ',
      cancelText: 'ยกเลิก',
      isDestructive: true,
      icon: Icons.logout_rounded,
      iconColor: AppTheme.errorColor,
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(userProvider.notifier).clearUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  const _SectionHeading(this.title);
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppTheme.textPrimary,
    ),
  );
}

class _Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.surfaceColor,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: child,
    ),
  );
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge(this.icon);
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: AppTheme.primaryColor.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: AppTheme.primaryColor, size: 22),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => _Surface(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _IconBadge(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    ),
  );
}
