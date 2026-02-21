// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:equatable/equatable.dart';

class EndpointConfig extends Equatable {
  const EndpointConfig({
    this.domain = defaultDomain,
    this.xmppEnabled = true,
    this.smtpEnabled = true,
    this.xmppHost,
    this.xmppPort = defaultXmppPort,
    this.imapHost,
    this.imapPort = defaultImapPort,
    this.smtpHost,
    this.smtpPort = defaultSmtpPort,
    this.apiPort = defaultApiPort,
    this.apiUseTls = true,
    this.emailProvisioningBaseUrl,
    this.emailProvisioningPublicToken,
  });

  static const Object _unset = Object();

  static const String defaultDomain = 'axi.im';
  static const int defaultXmppPort = 5222;
  static const int defaultImapPort = 993;
  static const int defaultSmtpPort = 465;
  static const int defaultApiPort = 5443;

  final String domain;
  final bool xmppEnabled;
  final bool smtpEnabled;
  final String? xmppHost;
  final int xmppPort;
  final String? imapHost;
  final int imapPort;
  final String? smtpHost;
  final int smtpPort;
  final int apiPort;
  final bool apiUseTls;
  final String? emailProvisioningBaseUrl;
  final String? emailProvisioningPublicToken;

  EndpointConfig copyWith({
    String? domain,
    bool? xmppEnabled,
    bool? smtpEnabled,
    Object? xmppHost = _unset,
    int? xmppPort,
    Object? imapHost = _unset,
    int? imapPort,
    Object? smtpHost = _unset,
    int? smtpPort,
    int? apiPort,
    bool? apiUseTls,
    Object? emailProvisioningBaseUrl = _unset,
    Object? emailProvisioningPublicToken = _unset,
  }) {
    return EndpointConfig(
      domain: domain ?? this.domain,
      xmppEnabled: xmppEnabled ?? this.xmppEnabled,
      smtpEnabled: smtpEnabled ?? this.smtpEnabled,
      xmppHost: xmppHost == _unset ? this.xmppHost : xmppHost as String?,
      xmppPort: xmppPort ?? this.xmppPort,
      imapHost: imapHost == _unset ? this.imapHost : imapHost as String?,
      imapPort: imapPort ?? this.imapPort,
      smtpHost: smtpHost == _unset ? this.smtpHost : smtpHost as String?,
      smtpPort: smtpPort ?? this.smtpPort,
      apiPort: apiPort ?? this.apiPort,
      apiUseTls: apiUseTls ?? this.apiUseTls,
      emailProvisioningBaseUrl: emailProvisioningBaseUrl == _unset
          ? this.emailProvisioningBaseUrl
          : emailProvisioningBaseUrl as String?,
      emailProvisioningPublicToken: emailProvisioningPublicToken == _unset
          ? this.emailProvisioningPublicToken
          : emailProvisioningPublicToken as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'xmppEnabled': xmppEnabled,
    'smtpEnabled': smtpEnabled,
    'xmppHost': xmppHost,
    'xmppPort': xmppPort,
    'imapHost': imapHost,
    'imapPort': imapPort,
    'smtpHost': smtpHost,
    'smtpPort': smtpPort,
    'apiPort': apiPort,
    'apiUseTls': apiUseTls,
    'emailProvisioningBaseUrl': emailProvisioningBaseUrl,
    'emailProvisioningPublicToken': emailProvisioningPublicToken,
  };

  factory EndpointConfig.fromJson(Map<String, dynamic> json) {
    int readPort(dynamic value, int fallback) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    String? readOptionalString(dynamic value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return EndpointConfig(
      domain: (json['domain'] as String? ?? defaultDomain).trim(),
      xmppEnabled:
          json['xmppEnabled'] as bool? ?? json['xmppEnabled'] as bool? ?? true,
      smtpEnabled:
          json['smtpEnabled'] as bool? ?? json['smtpEnabled'] as bool? ?? true,
      xmppHost: (json['xmppHost'] as String?)?.trim(),
      xmppPort: readPort(json['xmppPort'], defaultXmppPort),
      imapHost: (json['imapHost'] as String?)?.trim(),
      imapPort: readPort(json['imapPort'], defaultImapPort),
      smtpHost: (json['smtpHost'] as String?)?.trim(),
      smtpPort: readPort(json['smtpPort'], defaultSmtpPort),
      apiPort: readPort(json['apiPort'], defaultApiPort),
      apiUseTls: json['apiUseTls'] as bool? ?? true,
      emailProvisioningBaseUrl: readOptionalString(
        json['emailProvisioningBaseUrl'],
      ),
      emailProvisioningPublicToken: readOptionalString(
        json['emailProvisioningPublicToken'],
      ),
    );
  }

  @override
  List<Object?> get props => [
    domain,
    xmppEnabled,
    smtpEnabled,
    xmppHost,
    xmppPort,
    imapHost,
    imapPort,
    smtpHost,
    smtpPort,
    apiPort,
    apiUseTls,
    emailProvisioningBaseUrl,
    emailProvisioningPublicToken,
  ];
}

class EndpointOverride extends Equatable {
  const EndpointOverride({required this.host, required this.port});

  final String host;
  final int port;

  EndpointOverride copyWith({String? host, int? port}) {
    return EndpointOverride(host: host ?? this.host, port: port ?? this.port);
  }

  @override
  List<Object?> get props => [host, port];
}

class EndpointResolver {
  const EndpointResolver({this.lookup = InternetAddress.lookup});

  final Future<List<InternetAddress>> Function(String host) lookup;

  Future<EndpointOverride> resolveXmpp(
    EndpointConfig config, {
    EndpointOverride? fallback,
  }) async {
    final resolvedPort = config.xmppPort > 0
        ? config.xmppPort
        : EndpointConfig.defaultXmppPort;
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
    final resolvedPort = config.smtpPort > 0
        ? config.smtpPort
        : EndpointConfig.defaultSmtpPort;
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
    final preferred = preferredHost?.trim();
    final preferredIp = preferred == null || preferred.isEmpty
        ? null
        : InternetAddress.tryParse(preferred);
    if (preferredIp != null) {
      return EndpointOverride(host: preferredIp.address, port: selectedPort);
    }
    final host = _chooseHost(preferredHost, fallbackHost, config.domain);
    try {
      final lookupHost = preferred != null && preferred.isNotEmpty
          ? preferred
          : config.domain.trim();
      final addresses = await lookup(lookupHost);
      final resolvedHost = addresses.isNotEmpty
          ? addresses.first.address
          : host;
      return EndpointOverride(host: resolvedHost, port: selectedPort);
    } on SocketException {
      return EndpointOverride(host: host, port: selectedPort);
    } on FormatException {
      return EndpointOverride(host: host, port: selectedPort);
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
