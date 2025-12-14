import 'dart:io';

typedef HostLookup = Future<List<InternetAddress>> Function(String host);

bool isProbablyLocalHostname(String host) {
  final normalized = host.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (normalized == 'localhost') return true;
  if (normalized.endsWith('.localhost')) return true;
  if (normalized.endsWith('.local')) return true;
  return false;
}

bool isSafeInternetAddress(InternetAddress address) {
  if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
    return false;
  }
  final rawAddress = address.rawAddress;
  if (rawAddress.isEmpty) return false;
  if (_isUnspecifiedAddress(rawAddress)) return false;
  return switch (address.type) {
    InternetAddressType.IPv4 => !_isPrivateIpv4(rawAddress),
    InternetAddressType.IPv6 => !_isPrivateIpv6(rawAddress),
    _ => false,
  };
}

Future<bool> isSafeHostForRemoteConnection(
  String host, {
  HostLookup lookup = InternetAddress.lookup,
}) async {
  final normalizedHost = host.trim();
  if (normalizedHost.isEmpty) return false;
  if (isProbablyLocalHostname(normalizedHost)) return false;

  final direct = InternetAddress.tryParse(normalizedHost);
  if (direct != null) return isSafeInternetAddress(direct);

  try {
    final addresses = await lookup(normalizedHost);
    if (addresses.isEmpty) return false;
    return addresses.every(isSafeInternetAddress);
  } on Exception {
    return false;
  }
}

bool _isPrivateIpv4(List<int> rawAddress) {
  if (rawAddress.length != 4) return true;
  final first = rawAddress[0];
  final second = rawAddress[1];

  final tenDot = first == 10;
  final oneSevenTwoDot =
      first == 172 && second >= 16 && second <= 31; // 172.16.0.0/12
  final oneNineTwoDot = first == 192 && second == 168; // 192.168.0.0/16
  final cgnat = first == 100 && second >= 64 && second <= 127; // 100.64.0.0/10

  return tenDot || oneSevenTwoDot || oneNineTwoDot || cgnat;
}

bool _isPrivateIpv6(List<int> rawAddress) {
  if (rawAddress.length != 16) return true;
  if (_isIpv4MappedIpv6(rawAddress)) {
    final mappedIpv4 = rawAddress.sublist(12, 16);
    return _isPrivateIpv4(mappedIpv4);
  }

  final first = rawAddress[0];
  final second = rawAddress[1];

  final uniqueLocal = (first & 0xFE) == 0xFC; // fc00::/7
  final linkLocal = first == 0xFE && (second & 0xC0) == 0x80; // fe80::/10
  final siteLocal = first == 0xFE && (second & 0xC0) == 0xC0; // fec0::/10
  return uniqueLocal || linkLocal || siteLocal;
}

bool _isIpv4MappedIpv6(List<int> rawAddress) {
  if (rawAddress.length != 16) return false;
  for (var index = 0; index < 10; index++) {
    if (rawAddress[index] != 0) return false;
  }
  return rawAddress[10] == 0xFF && rawAddress[11] == 0xFF;
}

bool _isUnspecifiedAddress(List<int> rawAddress) {
  for (final byte in rawAddress) {
    if (byte != 0) return false;
  }
  return true;
}
