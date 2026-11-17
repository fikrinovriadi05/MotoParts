/// Informasi aplikasi dan kelompok pengembang untuk halaman "Tentang MotoPart".
class AppInfo {
  const AppInfo._();

  static const name = 'MotoPart';

  /// Samakan dengan `version:` di pubspec.yaml (dijaga tes).
  static const version = '1.0.0';

  static const groupName = 'Kelompok Mobile Programming Moto Part';

  static const members = <TeamMember>[
    TeamMember('Fikri Novriadi', '24101152610051'),
    TeamMember('Irfandi Ramadhan', '24101152610055'),
    TeamMember('Rafly Antoni Saputra', '24101152610067'),
    TeamMember('Muzakki Fernando', '24101152610063'),
  ];
}

class TeamMember {
  final String name;

  /// Nomor induk mahasiswa.
  final String nim;

  const TeamMember(this.name, this.nim);
}
