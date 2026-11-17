import 'package:flutter/material.dart';
import 'package:motopart/core/format.dart';
import 'package:motopart/models/app_notification.dart';
import 'package:motopart/pages/shared/order_detail_page.dart';
import 'package:motopart/store/notification_store.dart';
import 'package:motopart/store/store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/motion.dart';
import 'package:motopart/widgets/status_badge.dart';

/// Daftar notifikasi akun aktif: perubahan status pesanan, pembayaran, dll.
class NotificationsPage extends StatelessWidget {
  /// Notifikasi toko untuk admin (pesanan baru, pembayaran, stok), bukan
  /// notifikasi pesanan milik pembeli.
  final bool admin;

  const NotificationsPage({super.key, this.admin = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([notifications, store]),
      builder: (context, _) {
        final accountId = admin
            ? NotificationStore.adminAudience
            : store.currentAccountId;
        final items = notifications.forAccount(accountId);
        final unread = notifications.unreadCount(accountId);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifikasi'),
            actions: [
              if (items.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Menu notifikasi',
                  onSelected: (value) {
                    if (value == 'read') notifications.markAllRead(accountId);
                    if (value == 'clear') notifications.clear(accountId);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'read',
                      enabled: unread > 0,
                      child: const Text('Tandai semua dibaca'),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Text('Hapus semua'),
                    ),
                  ],
                ),
            ],
          ),
          body: items.isEmpty
              ? const _EmptyNotifications()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => FadeSlideIn(
                    index: index,
                    child: _NotificationTile(item: items[index], admin: admin),
                  ),
                ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final bool admin;

  const _NotificationTile({required this.item, required this.admin});

  void _open(BuildContext context) {
    notifications.markRead(item);
    final code = item.orderCode;
    if (code == null) return;
    final order = store.orderByCode(code);
    if (order == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailPage(order: order, isAdmin: admin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = item.status;
    final color = status == null
        ? palette.primaryText
        : orderStatusColor(context, status);

    return Material(
      color: item.read
          ? palette.surface
          : palette.accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  status == null
                      ? (item.title.startsWith('Stok')
                            ? Icons.inventory_2_rounded
                            : Icons.notifications_rounded)
                      : orderStatusIcon(status),
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: palette.text,
                            ),
                          ),
                        ),
                        if (!item.read)
                          Container(
                            key: const ValueKey('unread-dot'),
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(left: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: palette.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      style: TextStyle(color: palette.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      formatTanggal(item.createdAt),
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: AppTextSizes.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent.withValues(alpha: 0.14),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 52,
                  color: palette.primaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Belum ada notifikasi.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Kabar terbaru tentang pesananmu akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
