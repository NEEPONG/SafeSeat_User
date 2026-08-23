class AppValidators {
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    final regex = RegExp(r'^[0-9]{10}$');
    if (!regex.hasMatch(value)) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    final regex = RegExp(r'^[a-zA-Zก-๙\s]{2,50}$');
    if (!regex.hasMatch(value.trim())) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    final regex = RegExp(r'^[A-Za-z0-9!#_.]{8,50}$');
    if (!regex.hasMatch(value)) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    return null;
  }

  static String? validateNote(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.length > 255) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    final regex = RegExp(r'^[a-zA-Zก-๙\s]{1,255}$');
    if (!regex.hasMatch(trimmed)) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    return null;
  }

  static String? validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    final regex = RegExp(r'^[0-9]{2,5}$');
    if (!regex.hasMatch(value)) {
      return 'กรุณากรอกข้อมูลให้ถูกต้อง';
    }
    return null;
  }

  static String? validateCarBrand(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    final regex = RegExp(r'^[a-zA-Zก-๙]{3,50}$');
    if (!regex.hasMatch(value)) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    return null;
  }

  static String? validateCarModel(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    final regex = RegExp(r'^[a-zA-Zก-๙]{3,50}$');
    if (!regex.hasMatch(value)) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    return null;
  }

  static String? validateCarPlate(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    final regex = RegExp(r'^[a-zA-Zก-๙0-9\-]{2,10}$');
    if (!regex.hasMatch(value)) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    return null;
  }

  static String? validateCarColor(String? value) {
    if (value == null || value.isEmpty) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    final regex = RegExp(r'^[a-zA-Zก-๙]{2,20}$');
    if (!regex.hasMatch(value)) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    return null;
  }

  static String? validateReviewComment(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.length > 250) {
      return 'ความคิดเห็นต้องมีความยาวไม่เกิน 250 ตัวอักษร';
    }
    final regex = RegExp(r'^[a-zA-Zก-๙\s]{1,250}$');
    if (!regex.hasMatch(trimmed)) {
      return 'ความคิดเห็นต้องเป็นภาษาไทยและอังกฤษเท่านั้น';
    }
    return null;
  }

  static String? validateReportDetail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    final trimmed = value.trim();
    if (trimmed.length > 255) {
      return 'กรุณากรอกข้อมูลให้ครบถ้วน';
    }
    return null;
  }
}
