/// ตรวจไฟล์สลิปที่ผู้เช่าเลือก (Dart ล้วน ทดสอบได้)
/// กติกา: เป็นรูป jpg / jpeg / png และไม่เกิน 5 MB
/// ฝั่ง backend ต้องตรวจซ้ำอีกครั้งตอนรับไฟล์ (อย่าเชื่อแต่ฝั่งแอป)
library;

const int maxSlipBytes = 5 * 1024 * 1024;

/// ชื่อไฟล์หรือชนิดไฟล์ (mimeType) บอกว่าเป็นรูปที่รับได้หรือไม่
bool isAllowedSlipFile(String name, {String? mimeType}) {
  final mime = (mimeType ?? '').toLowerCase();
  if (mime == 'image/jpeg' || mime == 'image/png') return true;
  final n = name.toLowerCase();
  return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png');
}

/// ข้อความแจ้งผู้ใช้ถ้าไฟล์ไม่ผ่าน (null = ผ่าน)
String? slipError(String name, int sizeBytes, {String? mimeType}) {
  if (!isAllowedSlipFile(name, mimeType: mimeType)) {
    return 'รับเฉพาะรูป JPG หรือ PNG';
  }
  if (sizeBytes > maxSlipBytes) return 'ไฟล์ใหญ่เกิน 5 MB';
  if (sizeBytes <= 0) return 'ไฟล์ว่างเปล่า';
  return null;
}
