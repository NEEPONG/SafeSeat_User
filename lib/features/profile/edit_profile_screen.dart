import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safeseat_mini/core/controllers/user_controller.dart';
import 'package:safeseat_mini/core/utils/app_feedback.dart';
import 'package:safeseat_mini/core/utils/validators.dart';
import 'package:safeseat_mini/features/profile/controllers/profile_controller.dart';
import 'package:safeseat_mini/data/models/car_model.dart';
import 'package:safeseat_mini/features/request_driver/select_location_screen.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import 'dart:convert';
import 'package:latlong2/latlong.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  int? _selectedGender;
  String? _profileImagePath;
  File? _selectedImage;
  LatLng? _homeLatLng;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);

    _profileImagePath = user?.profileImagePath;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phoneNo ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _addressController = TextEditingController(text: user?.homeDisplayName ?? user?.mainAddress ?? '');
    _selectedGender = user?.gender;
    _homeLatLng = user?.homeLatLng;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      AppSnackBar.showWarning(context, 'กรุณากรอกข้อมูลให้ถูกต้องครบถ้วน');
      return;
    }

    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;
    
    final navigator = Navigator.of(context);

    String addressToSave = _addressController.text.trim();
    if (addressToSave.isNotEmpty && _homeLatLng != null) {
      addressToSave = jsonEncode({
        'name': addressToSave,
        'lat': _homeLatLng!.latitude,
        'lng': _homeLatLng!.longitude,
      });
    }

    final success = await ref.read(profileControllerProvider.notifier).editProfileWithImage(
      currentUser: currentUser,
      name: _nameController.text,
      email: _emailController.text,
      gender: _selectedGender,
      address: addressToSave,
      selectedImage: _selectedImage,
    );

    if (success && mounted) {
      AppSnackBar.showSuccess(context, 'บันทึกข้อมูลโปรไฟล์เรียบร้อยแล้ว');
      navigator.pop();
    } else if (mounted) {
      AppSnackBar.showError(context, 'บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
    }
  }

  void _showAddCarDialog() {
    final currentUser = ref.read(userProvider);
    if (currentUser == null) return;

    final brandCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final carFormKey = GlobalKey<FormState>();
    int? selectedCarType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Consumer(
            builder: (context, ref, child) {
              final carTypesAsync = ref.watch(carTypeProvider);
              return Form(
                key: carFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'เพิ่มยานพาหนะใหม่',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0044C9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: brandCtrl,
                      icon: Icons.branding_watermark,
                      hintText: 'ยี่ห้อ (เช่น Toyota)',
                      validator: AppValidators.validateCarBrand,
                    ),
                    _buildTextField(
                      controller: modelCtrl,
                      icon: Icons.car_repair,
                      hintText: 'รุ่น (เช่น Camry)',
                      validator: AppValidators.validateCarModel,
                    ),
                    _buildTextField(
                      controller: colorCtrl,
                      icon: Icons.color_lens,
                      hintText: 'สีรถ (เช่น ดำ)',
                      validator: AppValidators.validateCarColor,
                    ),
                    _buildTextField(
                      controller: plateCtrl,
                      icon: Icons.pin,
                      hintText: 'ทะเบียนรถ (เช่น กค-1234)',
                      validator: AppValidators.validateCarPlate,
                    ),
                    
                    carTypesAsync.when(
                      data: (carTypes) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              prefixIcon:
                                  Icon(Icons.category, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            hint: const Text('ชนิดเกียร์ / ระบบส่งกำลัง (Auto, Manual, EV)'),
                            initialValue: selectedCarType,
                            items: carTypes.map((type) {
                              return DropdownMenuItem(
                                value: type.carTypeId,
                                child: Text(type.carTypeName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              selectedCarType = val;
                            },
                          ),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, stack) =>
                          const Text('Failed to load car types'),
                    ),
                    
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (!carFormKey.currentState!.validate() ||
                              selectedCarType == null) {
                            AppSnackBar.showWarning(
                              context,
                              'กรุณากรอกข้อมูลยานพาหนะและเลือกประเภทรถให้ครบถ้วน',
                            );
                            return;
                          }

                          final newCar = CarModel(
                            userCarId: 0,
                            carBrand: brandCtrl.text.trim(),
                            carColor: colorCtrl.text.trim(),
                            carModel: modelCtrl.text.trim(),
                            carPlate: plateCtrl.text.trim(),
                            carType: selectedCarType!,
                            userId: currentUser.phoneNo,
                          );

                          final navigator = Navigator.of(context);
                          final success = await ref
                              .read(profileControllerProvider.notifier)
                              .addUserCar(newCar);
                          if (!context.mounted) return;

                          if (success) {
                            navigator.pop();
                            AppSnackBar.showSuccess(context, 'เพิ่มยานพาหนะสำเร็จ');
                          } else {
                            AppSnackBar.showError(
                              context,
                              'เกิดข้อผิดพลาดในการเพิ่มยานพาหนะ กรุณาลองใหม่',
                            );
                          }
                        },
                        child: const Text(
                          'บันทึกยานพาหนะ',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(profileControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'แก้ไขโปรไฟล์',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (_profileImagePath != null && _profileImagePath!.isNotEmpty
                                  ? NetworkImage(_profileImagePath!)
                                  : null) as ImageProvider?,
                          child: (_selectedImage == null && (_profileImagePath == null || _profileImagePath!.isEmpty))
                              ? const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0044C9),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ภาพประจำตัว',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Personal Info Section
              const Text(
                'ข้อมูลส่วนตัว',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0044C9),
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('ชื่อ-นามสกุล'),
              _buildTextField(
                controller: _nameController,
                icon: Icons.person_outline,
                hintText: 'ชื่อ-นามสกุล',
                validator: AppValidators.validateName,
              ),

              _buildLabel('เบอร์มือถือ'),
              _buildTextField(
                controller: _phoneController,
                icon: Icons.phone_outlined,
                hintText: 'เบอร์มือถือ',
                readOnly: true,
                validator: AppValidators.validatePhone,
              ),

              _buildLabel('อีเมล'),
              _buildTextField(
                controller: _emailController,
                icon: Icons.email_outlined,
                hintText: 'อีเมล',
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.validateEmail,
              ),

              _buildLabel('เพศ'),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedGender,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.people_outline, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  hint: const Text(
                    'ระบุเพศ',
                    style: TextStyle(color: Colors.grey),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('ชาย')),
                    DropdownMenuItem(value: 1, child: Text('หญิง')),
                    DropdownMenuItem(value: 2, child: Text('อื่นๆ')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedGender = val;
                    });
                  },
                ),
              ),

              _buildLabel('ที่อยู่ตั้งต้น / ตำแหน่งบ้าน'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _addressController,
                      icon: Icons.home_outlined,
                      hintText: 'ระบุที่อยู่บ้าน หรือกดปุ่มปักหมุด',
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.push<Map<String, dynamic>>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SelectLocationScreen(
                            isPickup: false,
                            isPickingForProfile: true,
                          ),
                        ),
                      );
                      if (result != null && result['address'] != null) {
                        setState(() {
                          _addressController.text = result['address'] as String;
                          if (result['latLng'] != null) {
                            _homeLatLng = result['latLng'] as LatLng;
                          }
                        });
                        if (!context.mounted) return;
                        AppSnackBar.showSuccess(context, 'บันทึกพิกัดตำแหน่งบ้านจากแผนที่เรียบร้อย');
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0044C9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.map_outlined, color: Colors.white, size: 22),
                          SizedBox(height: 4),
                          Text(
                            'ปักหมุด',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (_homeLatLng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, bottom: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'พิกัดที่ปักหมุด: ${_homeLatLng!.latitude.toStringAsFixed(5)}, ${_homeLatLng!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: Color(0xFF0F766E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Vehicles Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ยานพาหนะของฉัน',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0044C9),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddCarDialog,
                    icon: const Icon(Icons.add, color: Colors.white, size: 16),
                    label: const Text(
                      'Add Car',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Consumer(
                builder: (context, ref, child) {
                  final currentUser = ref.watch(userProvider);
                  if (currentUser == null) return const SizedBox.shrink();

                  final carsAsyncValue = ref.watch(userCarListProvider(currentUser.phoneNo));
                  
                  return carsAsyncValue.when(
                    data: (cars) {
                      if (cars.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('คุณยังไม่มีข้อมูลยานพาหนะ', style: TextStyle(color: Colors.grey)),
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cars.length,
                        itemBuilder: (itemContext, index) {
                          final car = cars[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.directions_car,
                                    color: Color(0xFF334155),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${car.carBrand} ${car.carModel}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'สี${car.carColor} • ${car.carPlate}',
                                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                                      ),
                                      if (car.carTypeName != null)
                                        Text(
                                          car.carTypeName!,
                                          style: const TextStyle(color: Color(0xFF0044C9), fontSize: 12),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () async {
                                    final confirmed = await AppDialog.showConfirm(
                                      context: context,
                                      title: 'ยืนยันการลบยานพาหนะ',
                                      message: 'คุณแน่ใจหรือไม่ว่าต้องการลบ ${car.carBrand} ${car.carModel} (${car.carPlate}) ออกจากรายการ?',
                                      confirmText: 'ลบยานพาหนะ',
                                      cancelText: 'ยกเลิก',
                                      isDestructive: true,
                                      icon: Icons.directions_car_outlined,
                                      iconColor: const Color(0xFFEF4444),
                                    );

                                     if (confirmed == true) {
                                      final success = await ref
                                          .read(profileControllerProvider.notifier)
                                          .deleteUserCar(car.userCarId, currentUser.phoneNo);
                                      if (!context.mounted) return;
                                       if (success) {
                                        AppSnackBar.showSuccess(context, 'ลบยานพาหนะสำเร็จ');
                                       } else {
                                        AppSnackBar.showError(context, 'ลบยานพาหนะไม่สำเร็จ กรุณาลองใหม่อีกครั้ง');
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => const Center(child: Text('เกิดข้อผิดพลาดในการโหลดข้อมูลรถ')),
                  );
                },
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        color: const Color(0xFFF8FAFC),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : _saveProfile,
            icon: isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined, color: Colors.white),
            label: Text(
              isLoading ? 'กำลังบันทึก...' : 'บันทึกการแก้ไข',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: readOnly ? Colors.grey[600] : Colors.black),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: EdgeInsets.only(bottom: maxLines > 1 ? 40.0 : 0),
            child: Icon(icon, color: Colors.grey),
          ),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
