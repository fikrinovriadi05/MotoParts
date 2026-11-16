import 'package:flutter/material.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/models/account.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/widgets/glass_card.dart';

/// Daftar pembeli. Admin dapat mengatur ulang password pembeli yang lupa
/// (belum ada server/email, jadi password sementara diberikan langsung).
class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  void _resetDialog(BuildContext context, Account account) {
    final password = TextEditingController(
      text: auth.generateTemporaryPassword(),
    );
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (_, setDialog) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Atur password sementara untuk ${account.name}.'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    decoration: const InputDecoration(
                      labelText: 'Password sementara',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Berikan password ini langsung kepada pembeli dan minta '
                    'ia menggantinya lewat Akun > Ganti Password.',
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final result = auth.resetPassword(account, password.text);
                    if (result != null) {
                      setDialog(() => error = result);
                      return;
                    }
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Password ${account.name} diatur ulang ke: '
                          '${password.text}',
                        ),
                        duration: const Duration(seconds: 10),
                      ),
                    );
                  },
                  child: const Text('Atur Ulang'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pengguna')),
      body: AnimatedBuilder(
        animation: auth,
        builder: (context, _) {
          final users = auth.userAccounts;
          if (users.isEmpty) {
            return Center(
              child: Text(
                'Belum ada pembeli terdaftar.',
                style: TextStyle(color: context.palette.textMuted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final account = users[index];
              return GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                      child: Text(
                        account.firstName.characters.first.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.palette.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.palette.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${account.email} • ${account.phone}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.palette.textMuted,
                              fontSize: AppTextSizes.small,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reset password',
                      onPressed: () => _resetDialog(context, account),
                      icon: Icon(
                        Icons.lock_reset_rounded,
                        color: context.palette.primaryText,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
