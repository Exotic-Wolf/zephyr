class CountryFlags {
  static const List<String> isoCountryCodes = <String>[
    'AF', 'AL', 'DZ', 'AD', 'AO', 'AG', 'AR', 'AM', 'AU', 'AT', 'AZ',
    'BS', 'BH', 'BD', 'BB', 'BY', 'BE', 'BZ', 'BJ', 'BT', 'BO', 'BA',
    'BW', 'BR', 'BN', 'BG', 'BF', 'BI', 'CV', 'KH', 'CM', 'CA', 'CF',
    'TD', 'CL', 'CN', 'CO', 'KM', 'CG', 'CD', 'CR', 'CI', 'HR', 'CU',
    'CY', 'CZ', 'DK', 'DJ', 'DM', 'DO', 'EC', 'EG', 'SV', 'GQ', 'ER',
    'EE', 'SZ', 'ET', 'FJ', 'FI', 'FR', 'GA', 'GM', 'GE', 'DE', 'GH',
    'GR', 'GD', 'GT', 'GN', 'GW', 'GY', 'HT', 'HN', 'HU', 'IS', 'IN',
    'ID', 'IR', 'IQ', 'IE', 'IL', 'IT', 'JM', 'JP', 'JO', 'KZ', 'KE',
    'KI', 'KP', 'KR', 'KW', 'KG', 'LA', 'LV', 'LB', 'LS', 'LR', 'LY',
    'LI', 'LT', 'LU', 'MG', 'MW', 'MY', 'MV', 'ML', 'MT', 'MH', 'MR',
    'MU', 'MX', 'FM', 'MD', 'MC', 'MN', 'ME', 'MA', 'MZ', 'MM', 'NA',
    'NR', 'NP', 'NL', 'NZ', 'NI', 'NE', 'NG', 'MK', 'NO', 'OM', 'PK',
    'PW', 'PA', 'PG', 'PY', 'PE', 'PH', 'PL', 'PT', 'QA', 'RO', 'RU',
    'RW', 'KN', 'LC', 'VC', 'WS', 'SM', 'ST', 'SA', 'SN', 'RS', 'SC',
    'SL', 'SG', 'SK', 'SI', 'SB', 'SO', 'ZA', 'SS', 'ES', 'LK', 'SD',
    'SR', 'SE', 'CH', 'SY', 'TJ', 'TZ', 'TH', 'TL', 'TG', 'TO', 'TT',
    'TN', 'TR', 'TM', 'TV', 'UG', 'UA', 'AE', 'GB', 'US', 'UY', 'UZ',
    'VU', 'VA', 'VE', 'VN', 'YE', 'ZM', 'ZW',
  ];

  static String flagEmoji(String countryCode) {
    final String normalized = countryCode.trim().toUpperCase();
    if (normalized.length != 2) {
      return '🏳️';
    }

    final int first = normalized.codeUnitAt(0);
    final int second = normalized.codeUnitAt(1);
    const int asciiA = 65;
    const int asciiZ = 90;
    const int regionalIndicatorOffset = 127397;

    final bool valid =
        first >= asciiA &&
        first <= asciiZ &&
        second >= asciiA &&
        second <= asciiZ;
    if (!valid) {
      return '🏳️';
    }

    return String.fromCharCode(first + regionalIndicatorOffset) +
        String.fromCharCode(second + regionalIndicatorOffset);
  }

  static List<String> allFlagEmojis() {
    return isoCountryCodes.map(flagEmoji).toList(growable: false);
  }
}