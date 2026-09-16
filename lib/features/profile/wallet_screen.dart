import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/core/utils/validators.dart';
import 'package:safeseat_mini/features/profile/controllers/profile_controller.dart';

class WalletScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;

  const WalletScreen({super.key, this.onBackToHome});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customAmountController = TextEditingController();
  final FocusNode _customAmountFocusNode = FocusNode();

  final List<int> _predefinedAmounts = [100, 200, 300, 500, 1000, 2000];

  @override
  void initState() {
    super.initState();
    // Default selected amount is 200, matching the screenshot
    _customAmountController.text = '200';

    // Fetch latest user profile to get current balance on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProvider);
      if (user != null) {
        ref.read(profileControllerProvider.notifier).getUserProfile(user.phoneNo);
      }
    });
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _customAmountFocusNode.dispose();
    super.dispose();
  }

  void _selectPredefinedAmount(int amount) {
    setState(() {
      _customAmountController.text = amount.toString();
      _customAmountFocusNode.unfocus();
    });
    _formKey.currentState?.validate();
  }

  double _getFinalAmount() {
    if (_customAmountController.text.isNotEmpty) {
      return double.tryParse(_customAmountController.text) ?? 0.0;
    }
    return 0.0;
  }

  String _formatCurrency(num value) {
    return value.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  String _formatInteger(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  void _handleConfirmPayment(BuildContext context, double currentBalance) {
    if (!_formKey.currentState!.validate()) {
      AppSnackBar.showWarning(context, 'กรุณากรอกจำนวนเงินให้ถูกต้อง');
      return;
    }

    final amount = _getFinalAmount();
    if (amount <= 0) {
      AppSnackBar.showWarning(context, 'กรุณาระบุจำนวนเงินที่ต้องการเติม');
      return;
    }

    _showQrCodeDialog(context, currentBalance, amount);
  }

  void _showQrCodeDialog(BuildContext context, double currentBalance, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F3D8A), // PromptPay Blue
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Thai QR Payment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // PromptPay text/mini logo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'พร้อมเพย์',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F3D8A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00ADB5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PromptPay',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Fake QR Code box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 200,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Name
                    const Text(
                      'บริษัท เซฟซีท จำกัด (SafeSeat Co., Ltd.)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ref No. TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Amount
                    const Text(
                      'จำนวนเงินที่ต้องชำระ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '฿${_formatCurrency(amount)}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F3D8A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'บาท',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF64748B)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            child: const Text(
                              'ยกเลิก',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              _executeTopUp(context, currentBalance, amount);
                            },
                            child: const Text(
                              'ยืนยันการโอนเงิน',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeTopUp(BuildContext context, double currentBalance, double amount) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    // Show standardized loading dialog
    AppDialog.showLoading(context, message: 'กำลังดำเนินการเติมเงิน...');

    try {
      final success = await ref
          .read(profileControllerProvider.notifier)
          .topUpWallet(user.phoneNo, amount);

      if (!context.mounted) return;
      AppDialog.hideLoading(context);

      if (success) {
        // Show Standard Success Dialog
        AppDialog.showSuccess(
          context: context,
          title: 'เติมเงินสำเร็จ',
          message: 'เติมเงินจำนวน ฿${_formatCurrency(amount)} บาท เข้ากระเป๋า SafeSeat Wallet เรียบร้อยแล้ว',
          buttonText: 'ตกลง',
          onDismiss: () {
            if (mounted) {
              setState(() {
                _customAmountController.text = '200';
              });
            }
          },
        );
      } else {
        if (context.mounted) {
          AppSnackBar.showError(context, 'เกิดข้อผิดพลาดในการบันทึกยอดเงินลงเซิร์ฟเวอร์');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppDialog.hideLoading(context);
        AppSnackBar.showError(context, 'เกิดข้อผิดพลาด: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final double balance = (user.walletBalance).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () {
            if (widget.onBackToHome != null) {
              widget.onBackToHome!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'เติมเงิน (SafeSeat Wallet)',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            tooltip: 'รีเฟรชยอดเงิน',
            onPressed: () {
              final currentUser = ref.read(userProvider);
              if (currentUser != null) {
                ref
                    .read(profileControllerProvider.notifier)
                    .getUserProfile(currentUser.phoneNo);
                AppSnackBar.showSuccess(context, 'อัปเดตยอดคงเหลือล่าสุดเรียบร้อยแล้ว');
              }
            },
          ),
          const SizedBox(width: 6),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wallet Balance Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0D47A1), // Deep Navy Blue
                            Color(0xFF1565C0), // Royal Blue
                            Color(0xFF1976D2), // Bright Blue
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D47A1).withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -25,
                            top: -25,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 45,
                            bottom: -35,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.16),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'ยอดคงเหลือในกระเป๋า',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          color: Color(0xFF6EE7B7),
                                          size: 13,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'SafeSeat Wallet',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '฿ ${_formatCurrency(balance)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'บาท',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'ยอดเงินพร้อมใช้งานสำหรับชำระค่าบริการคนขับและค่าเดินทาง',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Predefined Amounts Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'เลือกจำนวนเงินเติมด่วน',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'หน่วย: บาท',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Predefined Amounts Grid (Interactive highlighting with Thai 'บาท')
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _predefinedAmounts.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemBuilder: (context, index) {
                        final amount = _predefinedAmounts[index];
                        final isSelected = _customAmountController.text == amount.toString();
                        return InkWell(
                          onTap: () => _selectPredefinedAmount(amount),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 2.0 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                if (isSelected)
                                  const Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatInteger(amount),
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        'บาท',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),

                    // Custom Amount Header & TextField
                    const Text(
                      'หรือระบุจำนวนเงินเอง (บาท)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _customAmountController,
                        focusNode: _customAmountFocusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        validator: AppValidators.validateAmount,
                        onChanged: (val) {
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          hintText: 'ระบุจำนวนเงิน (ขั้นต่ำ 20)',
                          hintStyle: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 15,
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.edit_note_rounded,
                            color: Color(0xFF64748B),
                          ),
                          suffixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: const Text(
                              'บาท',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryColor,
                              width: 1.8,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          focusedErrorBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                            borderSide: BorderSide(color: Colors.red, width: 1.8),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Payment Method Header
                    const Text(
                      'ช่องทางการชำระเงิน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Payment Method Card (PromptPay selected)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F3D8A).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.qr_code_2_rounded,
                                color: Color(0xFF0F3D8A),
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'พร้อมเพย์ (PromptPay QR)',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'ฟรีค่าธรรมเนียม',
                                        style: TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'สแกนจ่ายได้ทันทีผ่านทุกแอปพลิเคชันธนาคาร',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Action Area
            Container(
              padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ยอดชำระสุทธิ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '฿ ${_formatCurrency(_getFinalAmount())}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'บาท',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _handleConfirmPayment(context, balance),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.qr_code_scanner_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'สร้าง QR Code เติมเงิน',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 12, color: Color(0xFF94A3B8)),
                      SizedBox(width: 4),
                      Text(
                        'ระบบชำระเงินปลอดภัย ผ่านมาตรฐาน SafeSeat Pay',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
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
