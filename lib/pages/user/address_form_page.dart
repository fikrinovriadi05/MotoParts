import 'package:flutter/material.dart';
import 'package:motopart/core/location_service.dart';
import 'package:motopart/models/shipping_address.dart';
import 'package:motopart/store/auth_store.dart';
import 'package:motopart/theme/app_theme.dart';
import 'package:motopart/widgets/glass_card.dart';
import 'package:motopart/widgets/primary_button.dart';

/// Form tambah/ubah alamat pengiriman. Mengembalikan [ShippingAddress] yang
/// tersimpan lewat `Navigator.pop` (null jika dibatalkan).
class AddressFormPage extends StatefulWidget {
  /// Alamat yang diubah; null untuk alamat baru.
  final ShippingAddress? address;

  const AddressFormPage({super.key, this.address});

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  static const quickLabels = ['Rumah', 'Kantor', 'Bengkel'];

  late final label = TextEditingController(
    text: widget.address?.label ?? 'Rumah',
  );
  late final recipient = TextEditingController(
    text: widget.address?.recipient ?? auth.currentAccount?.name ?? '',
  );
  late final phone = TextEditingController(
    text: widget.address?.phone ?? auth.currentAccount?.phone ?? '',
  );
  late final street = TextEditingController(text: widget.address?.street);
  late final city = TextEditingController(text: widget.address?.city);
  late final postalCode = TextEditingController(
    text: widget.address?.postalCode,
  );
  late final note = TextEditingController(text: widget.address?.note);

  late final bool wasDefault =
      widget.address != null &&
      auth.currentAccount?.defaultAddress?.id == widget.address!.id;
  late bool makeDefault = wasDefault;

  bool get isEdit => widget.address != null;

  /// Titik GPS alamat ini (null jika belum diambil).
  late double? latitude = widget.address?.latitude;
  late double? longitude = widget.address?.longitude;
  bool locating = false;

  bool get hasLocation => latitude != null && longitude != null;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Mengambil lokasi GPS lalu mengisi alamat otomatis (masih bisa diedit).
  Future<void> useGps() async {
    if (locating) return;
    setState(() => locating = true);
    try {
      final loc = await locationService.currentLocation();
      final place = await locationService.reverseGeocode(
        loc.latitude,
        loc.longitude,
      );
      if (!mounted) return;
      setState(() {
        latitude = loc.latitude;
        longitude = loc.longitude;
        if (place != null) {
          if (place.street.isNotEmpty) street.text = place.street;
          if (place.city.isNotEmpty) city.text = place.city;
          if (place.postalCode.isNotEmpty) postalCode.text = place.postalCode;
        }
      });
      _snack(
        place == null
            ? 'Titik lokasi didapat, tetapi alamat tidak bisa diisi otomatis. '
                  'Lengkapi alamat secara manual.'
            : 'Lokasi ditemukan. Periksa dan lengkapi alamat sebelum menyimpan.',
      );
    } on LocationException catch (e) {
      _snack(e.message);
    } on Object {
      // Kesalahan tak terduga: tetap beri tahu pengguna, jangan diam.
      _snack('Lokasi tidak dapat diambil. Isi alamat secara manual.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  /// Alamat pertama otomatis menjadi alamat utama; alamat utama yang sedang
  /// diubah tetap utama (ganti dengan menjadikan alamat lain utama).
  bool get lockedAsDefault =>
      wasDefault ||
      (!isEdit && (auth.currentAccount?.addresses.isEmpty ?? true));

  @override
  void dispose() {
    for (final c in [label, recipient, phone, street, city, postalCode, note]) {
      c.dispose();
    }
    super.dispose();
  }

  void submit() {
    ShippingAddress? saved;
    final String? error;
    if (isEdit) {
      error = auth.updateAddress(
        widget.address!.id,
        label: label.text,
        recipient: recipient.text,
        phone: phone.text,
        street: street.text,
        city: city.text,
        postalCode: postalCode.text,
        note: note.text,
        latitude: latitude,
        longitude: longitude,
        makeDefault: makeDefault,
      );
      saved = widget.address;
    } else {
      error = auth.addAddress(
        label: label.text,
        recipient: recipient.text,
        phone: phone.text,
        street: street.text,
        city: city.text,
        postalCode: postalCode.text,
        note: note.text,
        latitude: latitude,
        longitude: longitude,
        makeDefault: makeDefault,
        onSaved: (a) => saved = a,
      );
    }

    final messenger = ScaffoldMessenger.of(context);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Alamat diperbarui.' : 'Alamat ditambahkan.'),
      ),
    );
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Ubah Alamat' : 'Tambah Alamat')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: locating ? null : useGps,
                        icon: locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_rounded, size: 20),
                        label: Text(
                          locating
                              ? 'Mencari lokasi...'
                              : 'Gunakan Lokasi Saya (GPS)',
                        ),
                      ),
                    ),
                    if (hasLocation) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.gps_fixed_rounded,
                            size: 16,
                            color: palette.primaryText,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Titik GPS: ${latitude!.toStringAsFixed(5)}, '
                              '${longitude!.toStringAsFixed(5)}',
                              style: TextStyle(
                                color: palette.primaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: AppTextSizes.small,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Hapus titik GPS',
                            onPressed: () => setState(() {
                              latitude = null;
                              longitude = null;
                            }),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: label,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Alamat',
                        hintText: 'mis. Rumah, Kantor',
                        prefixIcon: Icon(Icons.bookmark_border_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final q in quickLabels)
                          ActionChip(
                            label: Text(q),
                            onPressed: () => setState(() => label.text = q),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: recipient,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama Penerima',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nomor HP',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: street,
                      minLines: 2,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Lengkap',
                        hintText: 'Jalan, nomor rumah, RT/RW, kelurahan',
                        prefixIcon: Icon(Icons.home_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: city,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Kecamatan / Kota',
                        prefixIcon: Icon(Icons.location_city_rounded),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: postalCode,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Kode Pos (opsional)',
                        counterText: '',
                        prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: note,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Patokan untuk kurir (opsional)',
                        hintText: 'mis. pagar hijau dekat masjid',
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Material sendiri agar efek tap tidak tertutup warna kartu.
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Jadikan alamat utama',
                          style: TextStyle(
                            color: palette.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: makeDefault || lockedAsDefault,
                        onChanged: lockedAsDefault
                            ? null
                            : (v) => setState(() => makeDefault = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                text: 'Simpan Alamat',
                icon: Icons.check_rounded,
                onPressed: submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
