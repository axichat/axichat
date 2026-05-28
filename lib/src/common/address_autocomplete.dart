// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/endpoint_config.dart';

const List<String> _popularAddressAutocompleteDomains = <String>[
  EndpointConfig.defaultDomain,
  'gmail.com',
  'outlook.com',
  'hotmail.com',
  'tuta.com',
  'protonmail.com',
  'aol.com',
  'yahoo.com',
  'icloud.com',
  'proton.me',
  'live.com',
  'msn.com',
  'me.com',
  'mac.com',
  'fastmail.com',
  'hey.com',
  'mail.com',
  'zoho.com',
  'gmx.com',
  'tutanota.com',
];

List<String> addressAutocompleteSuggestions({
  required String input,
  required Iterable<String> knownDomains,
  Iterable<String> knownAddresses = const <String>[],
  Iterable<String> excludedAddresses = const <String>[],
  String? primaryDomain,
  bool requireEmailAddress = true,
  int limit = 8,
}) {
  if (limit <= 0) {
    return const <String>[];
  }
  final trimmed = input.trim();
  final query = trimmed.toLowerCase();
  final excluded = excludedAddresses
      .map(normalizedAddressValue)
      .whereType<String>()
      .toSet();
  final normalizedPrimaryDomain = _normalizedAutocompleteDomain(primaryDomain);
  final knownDomainCounts = _knownDomainCounts(knownAddresses);
  final results = <String>[];
  final seen = <String>{};

  bool add(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return false;
    }
    final normalized = normalizedAddressValue(value);
    if (normalized == null ||
        normalized.isEmpty ||
        excluded.contains(normalized) ||
        seen.contains(normalized)) {
      return false;
    }
    if (requireEmailAddress) {
      if (!value.isValidEmailAddress) {
        return false;
      }
    } else if (!value.isValidJid) {
      return false;
    }
    results.add(value);
    seen.add(normalized);
    return results.length >= limit;
  }

  for (final address in knownAddresses) {
    if (query.isEmpty || address.toLowerCase().startsWith(query)) {
      if (add(address)) {
        return List<String>.unmodifiable(results);
      }
    }
  }

  final parts = addressAutocompleteParts(trimmed);
  if (parts != null) {
    final typedDomain = parts.domainPart.toLowerCase();
    final normalizedLocal = parts.localPart.toLowerCase();
    final knownAddressKeys = knownAddresses
        .map(normalizedAddressValue)
        .whereType<String>()
        .toSet();
    final candidateDomains = <String>{
      ...knownDomains.map(_normalizedAutocompleteDomain).whereType<String>(),
      ...knownDomainCounts.keys,
      ?normalizedPrimaryDomain,
    };
    final domainEntries =
        candidateDomains
            .map(
              (domain) => (
                domain: domain,
                knownCount: knownDomainCounts[domain] ?? 0,
                hasExactAddress: knownAddressKeys.contains(
                  '$normalizedLocal@$domain',
                ),
              ),
            )
            .where((entry) {
              if (typedDomain.isEmpty) {
                return entry.domain == normalizedPrimaryDomain ||
                    entry.domain == EndpointConfig.defaultDomain ||
                    entry.knownCount > 0 ||
                    _popularDomainRank(entry.domain) != null;
              }
              return entry.domain.startsWith(typedDomain);
            })
            .toList()
          ..sort((a, b) {
            if (a.hasExactAddress != b.hasExactAddress) {
              return a.hasExactAddress ? -1 : 1;
            }
            final aSection = _domainAutocompleteSection(
              domain: a.domain,
              knownCount: a.knownCount,
              primaryDomain: normalizedPrimaryDomain,
            );
            final bSection = _domainAutocompleteSection(
              domain: b.domain,
              knownCount: b.knownCount,
              primaryDomain: normalizedPrimaryDomain,
            );
            if (aSection != bSection) {
              return aSection.compareTo(bSection);
            }
            if (aSection == _AutocompleteDomainSection.known.index &&
                a.knownCount != b.knownCount) {
              return b.knownCount.compareTo(a.knownCount);
            }
            final aRank = _popularDomainRank(a.domain);
            final bRank = _popularDomainRank(b.domain);
            if (aRank != null || bRank != null) {
              if (aRank == null) {
                return 1;
              }
              if (bRank == null) {
                return -1;
              }
              return aRank.compareTo(bRank);
            }
            return a.domain.compareTo(b.domain);
          });
    for (final entry in domainEntries) {
      if (add('${parts.localPart}@${entry.domain}')) {
        return List<String>.unmodifiable(results);
      }
    }
  }

  return List<String>.unmodifiable(results);
}

int? _popularDomainRank(String domain) {
  final index = _popularAddressAutocompleteDomains.indexOf(domain);
  return index < 0 ? null : index;
}

Map<String, int> _knownDomainCounts(Iterable<String> knownAddresses) {
  final addressesByDomain = <String, Set<String>>{};
  for (final address in knownAddresses) {
    final normalizedAddress = normalizedAddressValue(address);
    if (normalizedAddress == null) {
      continue;
    }
    final domain = addressDomainPart(normalizedAddress);
    if (domain == null || domain.isEmpty) {
      continue;
    }
    (addressesByDomain[domain] ??= <String>{}).add(normalizedAddress);
  }
  return {
    for (final entry in addressesByDomain.entries)
      entry.key: entry.value.length,
  };
}

String? _normalizedAutocompleteDomain(String? raw) {
  final trimmed = raw?.trim().toLowerCase();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

int _domainAutocompleteSection({
  required String domain,
  required int knownCount,
  required String? primaryDomain,
}) {
  if (domain == primaryDomain) {
    return _AutocompleteDomainSection.primary.index;
  }
  if (domain == EndpointConfig.defaultDomain) {
    return _AutocompleteDomainSection.axi.index;
  }
  if (knownCount > 0) {
    return _AutocompleteDomainSection.known.index;
  }
  if (_popularDomainRank(domain) != null) {
    return _AutocompleteDomainSection.popular.index;
  }
  return _AutocompleteDomainSection.other.index;
}

enum _AutocompleteDomainSection { primary, axi, known, popular, other }
