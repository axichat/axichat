// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

ShareParams shareParamsForContext(
  BuildContext context, {
  String? text,
  String? subject,
  String? title,
  XFile? previewThumbnail,
  Uri? uri,
  List<XFile>? files,
  List<String>? fileNameOverrides,
  bool downloadFallbackEnabled = true,
  bool mailToFallbackEnabled = true,
  List<CupertinoActivityType>? excludedCupertinoActivities,
}) {
  return shareParamsForOrigin(
    sharePositionOrigin: sharePositionOriginForContext(context),
    text: text,
    subject: subject,
    title: title,
    previewThumbnail: previewThumbnail,
    uri: uri,
    files: files,
    fileNameOverrides: fileNameOverrides,
    downloadFallbackEnabled: downloadFallbackEnabled,
    mailToFallbackEnabled: mailToFallbackEnabled,
    excludedCupertinoActivities: excludedCupertinoActivities,
  );
}

ShareParams shareParamsForOrigin({
  Rect? sharePositionOrigin,
  String? text,
  String? subject,
  String? title,
  XFile? previewThumbnail,
  Uri? uri,
  List<XFile>? files,
  List<String>? fileNameOverrides,
  bool downloadFallbackEnabled = true,
  bool mailToFallbackEnabled = true,
  List<CupertinoActivityType>? excludedCupertinoActivities,
}) {
  return ShareParams(
    text: text,
    subject: subject,
    title: title,
    previewThumbnail: previewThumbnail,
    sharePositionOrigin: sharePositionOrigin,
    uri: uri,
    files: files,
    fileNameOverrides: fileNameOverrides,
    downloadFallbackEnabled: downloadFallbackEnabled,
    mailToFallbackEnabled: mailToFallbackEnabled,
    excludedCupertinoActivities: excludedCupertinoActivities,
  );
}

Rect? sharePositionOriginForContext(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return null;
  }
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}
