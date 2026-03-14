// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'xmpp_activity_cubit.dart';

class XmppActivityState {
  const XmppActivityState({this.operations = const []});

  final List<XmppOperation> operations;

  XmppActivityState copyWith({List<XmppOperation>? operations}) =>
      XmppActivityState(operations: operations ?? this.operations);
}

class XmppOperation {
  XmppOperation({
    required this.id,
    required this.kind,
    required this.startedAt,
    this.status = XmppOperationStatus.inProgress,
  });

  final String id;
  final XmppOperationKind kind;
  final DateTime startedAt;
  final XmppOperationStatus status;

  XmppOperationLabelKey get labelKey => switch (status) {
    XmppOperationStatus.inProgress => switch (kind) {
      XmppOperationKind.pubSubBookmarks =>
        XmppOperationLabelKey.pubSubBookmarksStart,
      XmppOperationKind.pubSubConversations =>
        XmppOperationLabelKey.pubSubConversationsStart,
      XmppOperationKind.pubSubDrafts => XmppOperationLabelKey.pubSubDraftsStart,
      XmppOperationKind.pubSubSpam => XmppOperationLabelKey.pubSubSpamStart,
      XmppOperationKind.pubSubEmailBlocklist =>
        XmppOperationLabelKey.pubSubEmailBlocklistStart,
      XmppOperationKind.pubSubAvatarMetadata =>
        XmppOperationLabelKey.pubSubAvatarMetadataStart,
      XmppOperationKind.pubSubFetch => XmppOperationLabelKey.pubSubFetchStart,
      XmppOperationKind.mamGlobalSync => XmppOperationLabelKey.mamGlobalStart,
      XmppOperationKind.mamMucSync => XmppOperationLabelKey.mamMucStart,
      XmppOperationKind.mamFetch => XmppOperationLabelKey.mamFetchStart,
      XmppOperationKind.mucCreate => XmppOperationLabelKey.mucCreateStart,
      XmppOperationKind.mucJoin => XmppOperationLabelKey.mucJoinStart,
      XmppOperationKind.selfAvatarPublish =>
        XmppOperationLabelKey.selfAvatarPublishStart,
    },
    XmppOperationStatus.success => switch (kind) {
      XmppOperationKind.pubSubBookmarks =>
        XmppOperationLabelKey.pubSubBookmarksSuccess,
      XmppOperationKind.pubSubConversations =>
        XmppOperationLabelKey.pubSubConversationsSuccess,
      XmppOperationKind.pubSubDrafts =>
        XmppOperationLabelKey.pubSubDraftsSuccess,
      XmppOperationKind.pubSubSpam => XmppOperationLabelKey.pubSubSpamSuccess,
      XmppOperationKind.pubSubEmailBlocklist =>
        XmppOperationLabelKey.pubSubEmailBlocklistSuccess,
      XmppOperationKind.pubSubAvatarMetadata =>
        XmppOperationLabelKey.pubSubAvatarMetadataSuccess,
      XmppOperationKind.pubSubFetch => XmppOperationLabelKey.pubSubFetchSuccess,
      XmppOperationKind.mamGlobalSync => XmppOperationLabelKey.mamGlobalSuccess,
      XmppOperationKind.mamMucSync => XmppOperationLabelKey.mamMucSuccess,
      XmppOperationKind.mamFetch => XmppOperationLabelKey.mamFetchSuccess,
      XmppOperationKind.mucCreate => XmppOperationLabelKey.mucCreateSuccess,
      XmppOperationKind.mucJoin => XmppOperationLabelKey.mucJoinSuccess,
      XmppOperationKind.selfAvatarPublish =>
        XmppOperationLabelKey.selfAvatarPublishSuccess,
    },
    XmppOperationStatus.failure => switch (kind) {
      XmppOperationKind.pubSubBookmarks =>
        XmppOperationLabelKey.pubSubBookmarksFailure,
      XmppOperationKind.pubSubConversations =>
        XmppOperationLabelKey.pubSubConversationsFailure,
      XmppOperationKind.pubSubDrafts =>
        XmppOperationLabelKey.pubSubDraftsFailure,
      XmppOperationKind.pubSubSpam => XmppOperationLabelKey.pubSubSpamFailure,
      XmppOperationKind.pubSubEmailBlocklist =>
        XmppOperationLabelKey.pubSubEmailBlocklistFailure,
      XmppOperationKind.pubSubAvatarMetadata =>
        XmppOperationLabelKey.pubSubAvatarMetadataFailure,
      XmppOperationKind.pubSubFetch => XmppOperationLabelKey.pubSubFetchFailure,
      XmppOperationKind.mamGlobalSync => XmppOperationLabelKey.mamGlobalFailure,
      XmppOperationKind.mamMucSync => XmppOperationLabelKey.mamMucFailure,
      XmppOperationKind.mamFetch => XmppOperationLabelKey.mamFetchFailure,
      XmppOperationKind.mucCreate => XmppOperationLabelKey.mucCreateFailure,
      XmppOperationKind.mucJoin => XmppOperationLabelKey.mucJoinFailure,
      XmppOperationKind.selfAvatarPublish =>
        XmppOperationLabelKey.selfAvatarPublishFailure,
    },
  };

  XmppOperation copyWith({XmppOperationStatus? status, DateTime? startedAt}) =>
      XmppOperation(
        id: id,
        kind: kind,
        startedAt: startedAt ?? this.startedAt,
        status: status ?? this.status,
      );
}

enum XmppOperationStatus { inProgress, success, failure }

enum XmppOperationLabelKey {
  pubSubBookmarksStart,
  pubSubBookmarksSuccess,
  pubSubBookmarksFailure,
  pubSubConversationsStart,
  pubSubConversationsSuccess,
  pubSubConversationsFailure,
  pubSubDraftsStart,
  pubSubDraftsSuccess,
  pubSubDraftsFailure,
  pubSubSpamStart,
  pubSubSpamSuccess,
  pubSubSpamFailure,
  pubSubEmailBlocklistStart,
  pubSubEmailBlocklistSuccess,
  pubSubEmailBlocklistFailure,
  pubSubAvatarMetadataStart,
  pubSubAvatarMetadataSuccess,
  pubSubAvatarMetadataFailure,
  pubSubFetchStart,
  pubSubFetchSuccess,
  pubSubFetchFailure,
  mamGlobalStart,
  mamGlobalSuccess,
  mamGlobalFailure,
  mamMucStart,
  mamMucSuccess,
  mamMucFailure,
  mamFetchStart,
  mamFetchSuccess,
  mamFetchFailure,
  mucCreateStart,
  mucCreateSuccess,
  mucCreateFailure,
  mucJoinStart,
  mucJoinSuccess,
  mucJoinFailure,
  selfAvatarPublishStart,
  selfAvatarPublishSuccess,
  selfAvatarPublishFailure,
}
