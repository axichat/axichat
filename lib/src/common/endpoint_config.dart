// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:equatable/equatable.dart';

class EndpointConfig extends Equatable {
  const EndpointConfig({
    this.domain = defaultDomain,
    this.xmppEnabled = true,
    this.smtpEnabled = true,
    this.imapHost,
    this.imapPort = defaultImapPort,
    this.smtpHost,
    this.smtpPort = defaultSmtpPort,
    this.apiPort = defaultApiPort,
    this.apiUseTls = true,
    this.emailProvisioningBaseUrl,
    this.emailProvisioningPublicToken,
    this.fpushComponentJid = '',
    this.fpushIosPushModule = defaultFpushIosPushModule,
  });

  static const Object _unset = Object();

  static const String axiImDomain = 'axi.im';
  static const String defaultDomain = axiImDomain;
  static const int defaultXmppPort = 5222;
  static const int defaultImapPort = 993;
  static const int defaultSmtpPort = 465;
  static const int defaultApiPort = 5443;
  static const String legacyDefaultFpushComponentJid = 'push.axi.im';
  static const String defaultFpushIosPushModule = 'apns';

  final String domain;
  final bool xmppEnabled;
  final bool smtpEnabled;
  final String? imapHost;
  final int imapPort;
  final String? smtpHost;
  final int smtpPort;
  final int apiPort;
  final bool apiUseTls;
  final String? emailProvisioningBaseUrl;
  final String? emailProvisioningPublicToken;
  final String fpushComponentJid;
  final String fpushIosPushModule;

  bool get isDefaultDomain => domain.trim().toLowerCase() == defaultDomain;

  bool get isAxiImDomain => domain.trim().toLowerCase() == axiImDomain;

  bool get requiresCustomSignupEndpoint => isAxiImDomain;

  String get resolvedFpushComponentJid {
    final configured = fpushComponentJid.trim();
    if (configured.isNotEmpty &&
        configured.toLowerCase() != legacyDefaultFpushComponentJid) {
      return configured;
    }
    return fpushComponentJidForDomain(domain);
  }

  static String fpushComponentJidForDomain(String domain) {
    final normalizedDomain = domain.trim().toLowerCase();
    final effectiveDomain = normalizedDomain.isEmpty
        ? defaultDomain
        : normalizedDomain;
    return 'push.$effectiveDomain';
  }

  EndpointConfig copyWith({
    String? domain,
    bool? xmppEnabled,
    bool? smtpEnabled,
    Object? imapHost = _unset,
    int? imapPort,
    Object? smtpHost = _unset,
    int? smtpPort,
    int? apiPort,
    bool? apiUseTls,
    Object? emailProvisioningBaseUrl = _unset,
    Object? emailProvisioningPublicToken = _unset,
    String? fpushComponentJid,
    String? fpushIosPushModule,
  }) {
    return EndpointConfig(
      domain: domain ?? this.domain,
      xmppEnabled: xmppEnabled ?? this.xmppEnabled,
      smtpEnabled: smtpEnabled ?? this.smtpEnabled,
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
      fpushComponentJid: fpushComponentJid ?? this.fpushComponentJid,
      fpushIosPushModule: fpushIosPushModule ?? this.fpushIosPushModule,
    );
  }

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'xmppEnabled': xmppEnabled,
    'smtpEnabled': smtpEnabled,
    'imapHost': imapHost,
    'imapPort': imapPort,
    'smtpHost': smtpHost,
    'smtpPort': smtpPort,
    'apiPort': apiPort,
    'apiUseTls': apiUseTls,
    'emailProvisioningBaseUrl': emailProvisioningBaseUrl,
    'emailProvisioningPublicToken': emailProvisioningPublicToken,
    'fpushComponentJid': fpushComponentJid,
    'fpushIosPushModule': fpushIosPushModule,
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
      fpushComponentJid: readOptionalString(json['fpushComponentJid']) ?? '',
      fpushIosPushModule:
          readOptionalString(json['fpushIosPushModule']) ??
          defaultFpushIosPushModule,
    );
  }

  @override
  List<Object?> get props => [
    domain,
    xmppEnabled,
    smtpEnabled,
    imapHost,
    imapPort,
    smtpHost,
    smtpPort,
    apiPort,
    apiUseTls,
    emailProvisioningBaseUrl,
    emailProvisioningPublicToken,
    fpushComponentJid,
    fpushIosPushModule,
  ];
}
