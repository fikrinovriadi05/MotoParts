import 'package:flutter/material.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/widgets/primary_button.dart';

/// Ubah nama dan nomor telepon. Email tidak bisa diubah.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final name = TextEditingController(text: auth.currentAccount?.name ?? '');
  final phone = TextEditingController(text: auth.currentAccount?.phone ?? '');

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  void submit() {
    final error = auth.updateProfile(name: name.text, phone: phone.text);
    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Data akun berhasil disimpan.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Akun')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              enabled: false,
              controller: TextEditingController(
                text: auth.currentAccount?.email ?? '',
              ),
              decoration: const InputDecoration(
                labelText: 'Email (tidak dapat diubah)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'No. HP',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            text: 'Simpan',
            icon: Icons.check_rounded,
            onPressed: submit,
          ),
        ],
      ),
    );
  }
}
