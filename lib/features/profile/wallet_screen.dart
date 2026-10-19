import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/features/profile/controllers/profile_controller.dart';

class WalletScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackToHome;
  const WalletScreen({super.key, this.onBackToHome});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '200');
  final _amountFocus = FocusNode();
  static const _amounts = [100, 200, 300, 500, 1000, 2000];
  bool _submitting = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshBalance());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _refreshBalance() async {
    final user = ref.read(userProvider);
    if (user == null || _refreshing) return;
    setState(() => _refreshing = true);
    await ref
        .read(profileControllerProvider.notifier)
        .getUserProfile(user.phoneNo);
    if (mounted) setState(() => _refreshing = false);
  }

  String _formatAmount(num amount) => amount
      .toStringAsFixed(2)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );

  String? _validateAmount(String? value) {
    final amount = int.tryParse(value ?? '');
    if (amount == null || amount < 20 || amount > 99999) {
      return 'ระบุจำนวนเงินตั้งแต่ 20 ถึง 99,999 บาท';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final user = ref.read(userProvider);
    if (user == null) return;
    final amount = int.parse(_amountController.text);
    _amountFocus.unfocus();
    setState(() => _submitting = true);
    final success = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => TopUpQrSheet(
        amount: amount,
        onConfirm: () => ref
            .read(profileControllerProvider.notifier)
            .topUpWallet(user.phoneNo, amount.toDouble()),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success == true) {
      AppSnackBar.showSuccess(
        context,
        'เติมเงิน ฿${_formatAmount(amount)} สำเร็จ',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('กระเป๋าเงิน'),
        automaticallyImplyLeading: widget.onBackToHome == null,
        leading: widget.onBackToHome == null
            ? null
            : IconButton(
                tooltip: 'กลับหน้าแรก',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBackToHome,
              ),
        actions: [
          IconButton(
            tooltip: 'อัปเดตยอดคงเหลือ',
            onPressed: _refreshing ? null : _refreshBalance,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryDark, AppTheme.primaryColor],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'ยอดคงเหลือ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '฿ ${_formatAmount(user.walletBalance)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'กระเป๋าเงิน SafeSeat',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'เลือกจำนวนเงิน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _amounts.map((amount) {
                    final selected = _amountController.text == '$amount';
                    return ChoiceChip(
                      label: Text('${amount.toString()} บาท'),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _amountController.text = '$amount');
                        _amountFocus.unfocus();
                        _formKey.currentState?.validate();
                      },
                      selectedColor: AppTheme.primaryColor.withValues(
                        alpha: 0.10,
                      ),
                      backgroundColor: AppTheme.surfaceColor,
                      side: BorderSide(
                        color: selected
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                      ),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.primaryColor
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const Text(
                  'หรือระบุจำนวนเงิน',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    validator: _validateAmount,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'ขั้นต่ำ 20 บาท',
                      prefixIcon: Icon(Icons.payments_outlined),
                      suffixText: 'บาท',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: keyboardOpen
          ? null
          : SafeArea(
              top: false,
              child: Container(
                color: AppTheme.surfaceColor,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'จำนวนเงิน',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            Flexible(
                              child: Text(
                                '฿ ${_formatAmount(int.tryParse(_amountController.text) ?? 0)}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('ต่อไป'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Confirmation step for an in-app balance top-up. The pattern is decorative:
/// it does not encode a payment address or a scannable QR payload.
class TopUpQrSheet extends StatefulWidget {
  final int amount;
  final Future<bool> Function() onConfirm;

  const TopUpQrSheet({
    super.key,
    required this.amount,
    required this.onConfirm,
  });

  @override
  State<TopUpQrSheet> createState() => _TopUpQrSheetState();
}

class _TopUpQrSheetState extends State<TopUpQrSheet> {
  bool _processing = false;

  Future<void> _confirm() async {
    if (_processing) return;
    setState(() => _processing = true);
    bool success;
    try {
      success = await widget.onConfirm();
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _processing = false);
      AppSnackBar.showError(context, 'เติมเงินไม่สำเร็จ กรุณาลองอีกครั้ง');
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.amount
        .toStringAsFixed(2)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );

    return PopScope(
      canPop: !_processing,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: Material(
              color: AppTheme.surfaceColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'เติมเงิน',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'กระเป๋าเงิน SafeSeat',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: const SizedBox.square(
                        dimension: 192,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _SafeSeatCodePainter(),
                              ),
                            ),
                            Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: AppTheme.primaryColor,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'จำนวนเงินที่เติม',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '฿ $amount',
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ตรวจสอบจำนวนเงินก่อนยืนยัน',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _processing
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('ยกเลิก'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _processing ? null : _confirm,
                            child: _processing
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('ยืนยันเติมเงิน'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafeSeatCodePainter extends CustomPainter {
  const _SafeSeatCodePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cells = 27;
    final cell = size.shortestSide / cells;
    final paint = Paint()..color = AppTheme.primaryDark;
    for (var row = 0; row < cells; row++) {
      for (var column = 0; column < cells; column++) {
        if (row >= 9 && row <= 17 && column >= 9 && column <= 17) {
          continue;
        }
        // A fixed mosaic without QR finder patterns or encoded data.
        final visible = (row * 37 + column * 73 + row * column * 11) % 9 < 4;
        if (!visible) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              column * cell + cell * 0.1,
              row * cell + cell * 0.1,
              cell * 0.8,
              cell * 0.8,
            ),
            Radius.circular(cell * 0.2),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
