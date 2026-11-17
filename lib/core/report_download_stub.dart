/// Platform non-web: tidak dipakai (ekspor lewat lembar berbagi sistem).
void downloadTextFile(String fileName, String content, String mimeType) {
  throw UnsupportedError('Unduhan langsung hanya ada di web.');
}
