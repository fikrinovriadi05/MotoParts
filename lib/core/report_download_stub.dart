import 'dart:typed_data';

/// Platform non-web: tidak dipakai (ekspor lewat lembar berbagi sistem).
void downloadFile(String fileName, Uint8List bytes, String mimeType) {
  throw UnsupportedError('Unduhan langsung hanya ada di web.');
}
