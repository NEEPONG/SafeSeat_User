import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/core/utils/validators.dart';
import 'package:safeseat_mini/features/auth/controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _acceptTerms = false;
  int? _selectedGender;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() ||
        _selectedGender == null ||
        !_acceptTerms) {
      if (_selectedGender == null) {
        AppSnackBar.showWarning(context, 'กรุณาระบุเพศของคุณ');
      } else if (!_acceptTerms) {
        AppSnackBar.showWarning(context, 'กรุณายอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว');
      } else {
        AppSnackBar.showWarning(context, 'กรุณากรอกข้อมูลให้ถูกต้องครบถ้วน');
      }
      return;
    }

    final errorMsg = await ref
        .read(authControllerProvider.notifier)
        .register(
          _phoneController.text.trim(),
          _nameController.text.trim(),
          _selectedGender!,
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (mounted) {
      if (errorMsg == null) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, 'สร้างบัญชีผู้ใช้สำเร็จ กรุณาเข้าสู่ระบบ');
      } else {
        AppSnackBar.showError(context, errorMsg);
      }
    }
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.inputColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 18),
            ),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          errorStyle: const TextStyle(height: 0.8),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.inputColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wc_outlined,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                isExpanded: true,
                hint: const Text(
                  'กรุณาเลือกเพศของคุณ',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
                icon: const Padding(
                  padding: EdgeInsets.only(right: 4.0),
                  child: Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(
                    value: 1,
                    child: Text('ชาย'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('หญิง'),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('อื่นๆ'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() {
                _acceptTerms = value ?? false;
              });
            },
            activeColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ยอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'เมื่อลงทะเบียน หมายถึงคุณยอมรับข้อกำหนดในการให้บริการและนโยบายความปลอดภัยของเรา',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'สร้างบัญชีผู้ใช้',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'กรอกข้อมูลของคุณเพื่อเริ่มต้นใช้งานและร่วมเดินทางกับเรา',
                  style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 28),

                // Phone
                _buildTextFormField(
                  controller: _phoneController,
                  hintText: 'เบอร์มือถือ (ตัวเลข 10 หลัก)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: AppValidators.validatePhone,
                ),
                const SizedBox(height: 16),

                // Name
                _buildTextFormField(
                  controller: _nameController,
                  hintText: 'ชื่อ-นามสกุล',
                  icon: Icons.person_outline,
                  validator: AppValidators.validateName,
                ),
                const SizedBox(height: 16),

                // Gender
                _buildGenderDropdown(),
                const SizedBox(height: 16),

                // Email
                _buildTextFormField(
                  controller: _emailController,
                  hintText: 'อีเมล (example@gmail.com)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.validateEmail,
                ),
                const SizedBox(height: 16),

                // Password
                _buildTextFormField(
                  controller: _passwordController,
                  hintText: 'รหัสผ่าน',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  validator: AppValidators.validatePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Terms & Conditions
                _buildTermsCheckbox(),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'สร้างบัญชี',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Already have account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'มีบัญชีอยู่แล้ว? ',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'เข้าสู่ระบบ',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
