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
    return all[_preferredIndex(userId)];
  }

  static List<String> forVisibleGrid(List<String> userIds) {
    final List<String> assets = <String>[];
    final Set<int> usedInViewport = <int>{};

    for (int index = 0; index < userIds.length; index += 1) {
      if (index % 4 == 0) {
        usedInViewport.clear();
      }

      int assetIndex = _preferredIndex(userIds[index]);
      while (usedInViewport.contains(assetIndex)) {
        assetIndex = (assetIndex + 1) % all.length;
      }

      usedInViewport.add(assetIndex);
      assets.add(all[assetIndex]);
    }

    return assets;
  }

  static int _preferredIndex(String userId) {
    if (userId.isEmpty) return 0;
    int hash = 5381;
    for (final int codeUnit in userId.codeUnits) {
      hash = ((hash << 5) + hash + codeUnit) & 0x7FFFFFFF;
    }
    return hash % all.length;
  }
}
