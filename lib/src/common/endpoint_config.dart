// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:equatable/equatable.dart';

class EndpointConfig extends Equatable {
  const EndpointConfig({
    this.domain = defaultDomain,
    this.enableXmpp = true,
    this.enableSmtp = true,
    this.useDns = false,
    this.useSrv = false,
    this.requireDnssec = false,
    this.xmppHost,
    this.xmppPort = defaultXmppPort,
    this.imapHost,
    this.imapPort = defaultImapPort,
    this.smtpHost,
    this.smtpPort = defaultSmtpPort,
    this.apiPort = defaultApiPort,
    this.apiUseTls = true,
  });

  static const String defaultDomain = 'axi.im';
  static const int defaultXmppPort = 5222;
  static const int defaultImapPort = 993;
  static const int defaultSmtpPort = 465;
  static const int defaultApiPort = 5443;

  final String domain;
  final bool enableXmpp;
  final bool enableSmtp;
  final bool useDns;
  final bool useSrv;
  final bool requireDnssec;
  final String? xmppHost;
  final int xmppPort;
  final String? imapHost;
  final int imapPort;
  final String? smtpHost;
  final int smtpPort;
  final int apiPort;
  final bool apiUseTls;

  EndpointConfig copyWith({
    String? domain,
    bool? enableXmpp,
    bool? enableSmtp,
    bool? useDns,
    bool? useSrv,
    bool? requireDnssec,
    String? xmppHost,
    int? xmppPort,
    String? imapHost,
    int? imapPort,
    String? smtpHost,
    int? smtpPort,
    int? apiPort,
    bool? apiUseTls,
  }) {
    return EndpointConfig(
      domain: domain ?? this.domain,
      enableXmpp: enableXmpp ?? this.enableXmpp,
      enableSmtp: enableSmtp ?? this.enableSmtp,
      useDns: useDns ?? this.useDns,
      useSrv: useSrv ?? this.useSrv,
      requireDnssec: requireDnssec ?? this.requireDnssec,
      xmppHost: xmppHost ?? this.xmppHost,
      xmppPort: xmppPort ?? this.xmppPort,
      imapHost: imapHost ?? this.imapHost,
      imapPort: imapPort ?? this.imapPort,
      smtpHost: smtpHost ?? this.smtpHost,
      smtpPort: smtpPort ?? this.smtpPort,
      apiPort: apiPort ?? this.apiPort,
      apiUseTls: apiUseTls ?? this.apiUseTls,
    );
  }

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'enableXmpp': enableXmpp,
        'enableSmtp': enableSmtp,
        'useDns': useDns,
        'useSrv': useSrv,
        'requireDnssec': requireDnssec,
        'xmppHost': xmppHost,
        'xmppPort': xmppPort,
        'imapHost': imapHost,
        'imapPort': imapPort,
        'smtpHost': smtpHost,
        'smtpPort': smtpPort,
        'apiPort': apiPort,
        'apiUseTls': apiUseTls,
      };

  factory EndpointConfig.fromJson(Map<String, dynamic> json) {
    int readPort(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return EndpointConfig(
      domain: (json['domain'] as String? ?? defaultDomain).trim(),
      enableXmpp: json['enableXmpp'] as bool? ?? true,
      enableSmtp: json['enableSmtp'] as bool? ?? true,
      useDns: json['useDns'] as bool? ?? false,
      useSrv: json['useSrv'] as bool? ?? false,
      requireDnssec: json['requireDnssec'] as bool? ?? false,
      xmppHost: (json['xmppHost'] as String?)?.trim(),
      xmppPort: readPort(json['xmppPort'], defaultXmppPort),
      imapHost: (json['imapHost'] as String?)?.trim(),
      imapPort: readPort(json['imapPort'], defaultImapPort),
      smtpHost: (json['smtpHost'] as String?)?.trim(),
      smtpPort: readPort(json['smtpPort'], defaultSmtpPort),
      apiPort: readPort(json['apiPort'], defaultApiPort),
      apiUseTls: json['apiUseTls'] as bool? ?? true,
    );
  }

  bool get dnsEnabled => useDns;

  bool get xmppEnabled => enableXmpp;

  bool get smtpEnabled => enableSmtp;

  @override
  List<Object?> get props => [
        domain,
        enableXmpp,
        enableSmtp,
        useDns,
        useSrv,
        requireDnssec,
        xmppHost,
        xmppPort,
        imapHost,
        imapPort,
        smtpHost,
        smtpPort,
        apiPort,
        apiUseTls,
      ];
}

class EndpointOverride extends Equatable {
  const EndpointOverride({
    required this.host,
    required this.port,
    this.usedDns = false,
    this.usedSrv = false,
    this.dnssecValidated = false,
  });

  final String host;
  final int port;
  final bool usedDns;
  final bool usedSrv;
  final bool dnssecValidated;

  EndpointOverride copyWith({
    String? host,
    int? port,
    bool? usedDns,
    bool? usedSrv,
    bool? dnssecValidated,
  }) {
    return EndpointOverride(
      host: host ?? this.host,
      port: port ?? this.port,
      usedDns: usedDns ?? this.usedDns,
      usedSrv: usedSrv ?? this.usedSrv,
      dnssecValidated: dnssecValidated ?? this.dnssecValidated,
    );
  }

  @override
  List<Object?> get props => [
        host,
        port,
        usedDns,
        usedSrv,
        dnssecValidated,
      ];
}

class EndpointResolutionException implements Exception {
  const EndpointResolutionException(this.message);

  final String message;

  @override
  String toString() => 'EndpointResolutionException($message)';
}

class EndpointResolver {
  const EndpointResolver({
    this.lookup = InternetAddress.lookup,
  });

  final Future<List<InternetAddress>> Function(String host) lookup;

  Future<EndpointOverride> resolveXmpp(
    EndpointConfig config, {
    EndpointOverride? fallback,
  }) async {
    final resolvedPort =
        config.xmppPort > 0 ? config.xmppPort : EndpointConfig.defaultXmppPort;
    return await _resolve(
      config: config,
      preferredHost: config.xmppHost,
      defaultPort: resolvedPort,
      fallback: fallback,
    );
  }

  Future<EndpointOverride> resolveSmtp(
    EndpointConfig config, {
    EndpointOverride? fallback,
  }) async {
    final resolvedPort =
        config.smtpPort > 0 ? config.smtpPort : EndpointConfig.defaultSmtpPort;
    return await _resolve(
      config: config,
      preferredHost: config.smtpHost,
      defaultPort: resolvedPort,
      fallback: fallback,
    );
  }

  Future<EndpointOverride> _resolve({
    required EndpointConfig config,
    required String? preferredHost,
    required int defaultPort,
    EndpointOverride? fallback,
  }) async {
    final fallbackHost = fallback?.host;
    final fallbackPort = fallback?.port ?? defaultPort;
    final selectedPort = defaultPort > 0 ? defaultPort : fallbackPort;
    if (!config.useDns) {
      final host = _chooseHost(
        preferredHost,
        fallbackHost,
        config.domain,
      );
      return EndpointOverride(
        host: host,
        port: selectedPort,
      );
    }
    if (config.requireDnssec) {
      throw const EndpointResolutionException(
        'DNSSEC validation is required but not available.',
      );
    }
    try {
      final addresses = await lookup(config.domain);
      final host = addresses.isNotEmpty
          ? addresses.first.address
          : _chooseHost(preferredHost, fallbackHost, config.domain);
      return EndpointOverride(
        host: host,
        port: selectedPort,
        usedDns: true,
        usedSrv: false,
      );
    } on SocketException {
      final host = _chooseHost(
        preferredHost,
        fallbackHost,
        config.domain,
      );
      return EndpointOverride(
        host: host,
        port: selectedPort,
      );
    }
  }

  String _chooseHost(String? preferred, String? fallback, String domain) {
    if (preferred != null && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return domain.trim();
  }
}
