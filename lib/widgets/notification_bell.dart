import 'package:flutter/material.dart';
import 'package:motopart/pages/user/notifications_page.dart';
import 'package:motopart/store/notification_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';

/// Tombol lonceng dengan lencana jumlah notifikasi belum dibaca. Dipakai di
/// header beranda (pembeli, [admin] = false) dan dasbor (admin).
///
/// Lencana digambar manual, bukan widget `Badge`: jumlah keranjang di
/// navigasi bawah memakai `Badge` dan dicari lewat tipenya.
class NotificationBell extends StatelessWidget {
  final bool admin;

  const NotificationBell({super.key, this.admin = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([notifications, store]),
      builder: (context, _) {
        final audience = admin
            ? NotificationStore.adminAudience
            : store.currentAccountId;
        final unread = notifications.unreadCount(audience);

        return IconButton(
          tooltip: unread > 0
              ? 'Notifikasi ($unread belum dibaca)'
              : 'Notifikasi',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsPage(admin: admin)),
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.10),
          ),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white),
              if (unread > 0)
                Positioned(
                  key: const ValueKey('notif-badge'),
                  top: -5,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
