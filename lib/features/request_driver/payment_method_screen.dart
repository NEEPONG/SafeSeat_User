import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  final String initialMethod;

  const PaymentMethodScreen({super.key, required this.initialMethod});

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  late String _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod;
    // Normalize initial value to match our two choices
    if (!_selectedMethod.startsWith('เงินสด') &&
        !_selectedMethod.startsWith('SafeSeat Wallet')) {
      _selectedMethod = 'SafeSeat Wallet';
    }
  }

  Widget _buildPaymentOption({
    required String title,
    String? subtitle,
    required IconData icon,
    required String value,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    final isSelected = _selectedMethod.startsWith(value);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = value;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.06)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon wrapper
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            // Text details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
            ),
            // Radio Circle
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFFCBD5E1),
                  width: isSelected ? 7 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = AppTheme.primaryColor;

    // Get actual user wallet balance from Riverpod provider
    final user = ref.watch(userProvider);
    final balance = user?.walletBalance ?? 0.0;
    final formattedBalance = 'ยอดคงเหลือ ฿${balance.toStringAsFixed(2)}';

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: themeColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'วิธีชำระเงิน',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Option 1: Cash (เงินสด)
                _buildPaymentOption(
                  title: 'เงินสด',
                  icon: Icons.payments,
                  value: 'เงินสด',
                  iconColor: const Color(0xFF4338CA), // Purple-ish indigo
                  iconBgColor: const Color(0xFFEEF2F6), // Cool grey/light slate
                ),
                const SizedBox(height: 16),

                // Option 2: SafeSeat Wallet
                _buildPaymentOption(
                  title: 'กระเป๋าเงิน SafeSeat',
                  subtitle: formattedBalance,
                  icon: Icons.account_balance_wallet,
                  value: 'SafeSeat Wallet',
                  iconColor: const Color(0xFF4338CA),
                  iconBgColor: const Color(0xFFEEF2F6),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                // Send back the selected method with balance
                String result = _selectedMethod;
                if (result == 'SafeSeat Wallet') {
                  result = 'SafeSeat Wallet (฿${balance.toStringAsFixed(2)})';
                }
                Navigator.of(context).pop(result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: const Text(
                'ยืนยันวิธีชำระเงิน',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
