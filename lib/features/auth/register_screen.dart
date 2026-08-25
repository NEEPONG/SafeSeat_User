import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/core/utils/validators.dart';
import 'package:safeseat_mini/data/models/car_model.dart';
import 'package:safeseat_mini/features/auth/controllers/auth_controller.dart';
import 'package:safeseat_mini/features/profile/controllers/profile_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // User details controllers
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Car details controllers
  final _carBrandController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carColorController = TextEditingController();
  final _carPlateController = TextEditingController();

  bool _obscurePassword = true;
  bool _acceptTerms = false;
  int? _selectedGender;
  int? _selectedCarType;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _carBrandController.dispose();
    _carModelController.dispose();
    _carColorController.dispose();
    _carPlateController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() ||
        _selectedGender == null ||
        _selectedCarType == null ||
        !_acceptTerms) {
      if (_selectedGender == null) {
        AppSnackBar.showWarning(context, 'กรุณาระบุเพศของคุณ');
      } else if (_selectedCarType == null) {
        AppSnackBar.showWarning(context, 'กรุณาเลือกประเภทรถยนต์ของคุณ');
      } else if (!_acceptTerms) {
        AppSnackBar.showWarning(context, 'กรุณายอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว');
      } else {
        AppSnackBar.showWarning(context, 'กรุณากรอกข้อมูลให้ถูกต้องครบถ้วนตามคำแนะนำ');
      }
      return;
    }

    final initialCar = CarModel(
      userCarId: 0,
      carBrand: _carBrandController.text.trim(),
      carModel: _carModelController.text.trim(),
      carColor: _carColorController.text.trim(),
      carPlate: _carPlateController.text.trim(),
      carType: _selectedCarType!,
      userId: _phoneController.text.trim(),
    );

    final errorMsg = await ref
        .read(authControllerProvider.notifier)
        .register(
          phone: _phoneController.text.trim(),
          name: _nameController.text.trim(),
          gender: _selectedGender!,
          email: _emailController.text.trim(),
          password: _passwordController.text,
          car: initialCar,
        );

    if (mounted) {
      if (errorMsg == null) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, 'สร้างบัญชีผู้ใช้และบันทึกยานพาหนะสำเร็จ');
      } else {
        AppSnackBar.showError(context, errorMsg);
      }
    }
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
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
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
          ),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          errorStyle: const TextStyle(height: 0.9, fontSize: 12),
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
                  'เลือกเพศของคุณ (ชาย / หญิง / อื่นๆ)',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
                    child: Text('ชาย', style: TextStyle(fontSize: 15, color: Color(0xFF0F172A))),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('หญิง', style: TextStyle(fontSize: 15, color: Color(0xFF0F172A))),
                  ),
                  DropdownMenuItem(
                    value: 3,
                    child: Text('อื่นๆ', style: TextStyle(fontSize: 15, color: Color(0xFF0F172A))),
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

  Widget _buildCarTypeDropdown() {
    final carTypesAsync = ref.watch(carTypeProvider);

    return carTypesAsync.when(
      data: (carTypes) {
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
                  Icons.category_outlined,
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
                      'เลือกประเภทรถยนต์ (เช่น รถเก๋ง, รถกระบะ, SUV)',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 4.0),
                      child: Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    value: _selectedCarType,
                    items: carTypes.map((type) {
                      return DropdownMenuItem<int>(
                        value: type.carTypeId,
                        child: Text(
                          type.carTypeName,
                          style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCarType = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.inputColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (err, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: const Text(
          'ไม่สามารถโหลดรายการประเภทรถได้',
          style: TextStyle(color: Colors.red, fontSize: 13),
        ),
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
                'เมื่อลงทะเบียน หมายถึงคุณยอมรับข้อกำหนดในการให้บริการและนโยบายความปลอดภัยของ SafeSeat',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  height: 1.4,
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'สร้างบัญชีผู้ใช้ใหม่',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'กรอกข้อมูลส่วนตัวและยานพาหนะเริ่มต้น เพื่อเริ่มต้นรับบริการคนขับอย่างปลอดภัย',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 24),

                // SECTION 1: ข้อมูลส่วนตัว
                _buildSectionHeader(
                  icon: Icons.person_outline,
                  title: '1. ข้อมูลส่วนบุคคล',
                  subtitle: 'ข้อมูลสำหรับเข้าสู่ระบบและระบุตัวตน',
                ),

                // Phone
                _buildTextFormField(
                  controller: _phoneController,
                  hintText: 'เบอร์มือถือ 10 หลัก (เช่น 0812345678)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: AppValidators.validatePhone,
                ),
                const SizedBox(height: 14),

                // Name
                _buildTextFormField(
                  controller: _nameController,
                  hintText: 'ชื่อ-นามสกุล (ภาษาไทยหรืออังกฤษ 2-50 ตัวอักษร)',
                  icon: Icons.badge_outlined,
                  validator: AppValidators.validateName,
                ),
                const SizedBox(height: 14),

                // Gender
                _buildGenderDropdown(),
                const SizedBox(height: 14),

                // Email
                _buildTextFormField(
                  controller: _emailController,
                  hintText: 'อีเมล (เช่น user@example.com)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: AppValidators.validateEmail,
                ),
                const SizedBox(height: 14),

                // Password
                _buildTextFormField(
                  controller: _passwordController,
                  hintText: 'รหัสผ่าน 8-50 ตัวอักษร (อังกฤษ, ตัวเลข หรือ !#_.)',
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
                const SizedBox(height: 28),

                // SECTION 2: ข้อมูลยานพาหนะเริ่มต้น
                _buildSectionHeader(
                  icon: Icons.directions_car_outlined,
                  title: '2. ข้อมูลยานพาหนะเริ่มต้น (1 คัน)',
                  subtitle: 'ข้อมูลรถยนต์ที่คุณจะใช้เรียกรถบริการ',
                ),

                // Car Brand
                _buildTextFormField(
                  controller: _carBrandController,
                  hintText: 'ยี่ห้อรถยนต์ (เช่น Toyota, Honda, Mazda)',
                  icon: Icons.branding_watermark_outlined,
                  validator: AppValidators.validateCarBrand,
                ),
                const SizedBox(height: 14),

                // Car Model
                _buildTextFormField(
                  controller: _carModelController,
                  hintText: 'รุ่นรถยนต์ (เช่น Camry, Civic, City)',
                  icon: Icons.car_repair_outlined,
                  validator: AppValidators.validateCarModel,
                ),
                const SizedBox(height: 14),

                // Car Color
                _buildTextFormField(
                  controller: _carColorController,
                  hintText: 'สีรถ (เช่น ดำ, ขาว, เทา, บรอนซ์เงิน)',
                  icon: Icons.color_lens_outlined,
                  validator: AppValidators.validateCarColor,
                ),
                const SizedBox(height: 14),

                // Car Plate
                _buildTextFormField(
                  controller: _carPlateController,
                  hintText: 'ป้ายทะเบียน (เช่น กค-1234, 1กข-9999)',
                  icon: Icons.pin_outlined,
                  validator: AppValidators.validateCarPlate,
                ),
                const SizedBox(height: 14),

                // Car Type Dropdown
                _buildCarTypeDropdown(),
                const SizedBox(height: 24),

                // Terms & Conditions
                _buildTermsCheckbox(),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
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
                            'สร้างบัญชีและบันทึกรถยนต์',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
