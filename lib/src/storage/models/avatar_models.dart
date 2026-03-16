// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:equatable/equatable.dart';

final class Avatar extends Equatable {
  const Avatar({required this.path, this.hash});

  factory Avatar.tryParse({String? path, String? hash}) {
    final resolvedPath = path?.trim();
    if (resolvedPath == null || resolvedPath.isEmpty) {
      throw const FormatException('Avatar path is required.');
    }
    return Avatar(
      path: resolvedPath,
      hash: hash?.trim().isEmpty == true ? null : hash?.trim(),
    );
  }

  static Avatar? tryParseOrNull({String? path, String? hash}) {
    final resolvedPath = path?.trim();
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return null;
    }
    return Avatar(path: resolvedPath, hash: hash?.trim());
  }

  final String path;
  final String? hash;

  bool get hasHash => hash != null;

  @override
  List<Object?> get props => [path, hash];
}
