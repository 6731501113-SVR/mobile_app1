import 'package:image_picker/image_picker.dart';

import 'payment_controller.dart';

/// เลือกรูปสลิปจากแกลเลอรีจริงด้วย image_picker (ใช้ได้บน Chrome และ Android)
class GallerySlipPicker implements SlipPicker {
  final ImagePicker _picker = ImagePicker();

  @override
  Future<PickedSlip?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PickedSlip(
      name: file.name,
      bytes: await file.readAsBytes(),
      mimeType: file.mimeType,
    );
  }
}
