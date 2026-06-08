class HostCardCoverAssets {
  const HostCardCoverAssets._();

  static const List<String> all = <String>[
    'assets/images/host_covers/host_cover_jazz.jpg',
    'assets/images/host_covers/host_cover_beach.jpg',
    'assets/images/host_covers/host_cover_club.jpg',
    'assets/images/host_covers/host_cover_rooftop.jpg',
    'assets/images/host_covers/host_cover_cafe.jpg',
    'assets/images/host_covers/host_cover_music.jpg',
  ];

  static String forUserId(String userId) {
    return forUser(userId: userId);
  }

  static String forUser({
    required String userId,
    String? displayName,
    String? countryCode,
  }) {
    return all[_preferredIndex(_seedFor(userId, displayName, countryCode))];
  }

  static bool isBundledAsset(String value) {
    return value.trim().startsWith('assets/');
  }

  static String _seedFor(
    String userId,
    String? displayName,
    String? countryCode,
  ) {
    final String name = displayName?.trim() ?? '';
    final String country = countryCode?.trim().toUpperCase() ?? '';
    return <String>[
      if (name.isNotEmpty) name,
      if (country.isNotEmpty) country,
      userId,
    ].join('|');
  }

  static int _preferredIndex(String seed) {
    if (seed.isEmpty) return 0;
    int hash = 0x811C9DC5;
    for (final int codeUnit in seed.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash % all.length;
  }
}
