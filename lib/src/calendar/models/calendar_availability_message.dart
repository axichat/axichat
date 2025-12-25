import 'package:freezed_annotation/freezed_annotation.dart';

import 'calendar_availability.dart';
import 'calendar_date_time.dart';

part 'calendar_availability_message.freezed.dart';
part 'calendar_availability_message.g.dart';

const String _calendarAvailabilityMessageUnionKey = 'type';

@freezed
class CalendarAvailabilityShare with _$CalendarAvailabilityShare {
  const factory CalendarAvailabilityShare({
    required String id,
    required CalendarAvailabilityOverlay overlay,
  }) = _CalendarAvailabilityShare;

  factory CalendarAvailabilityShare.fromJson(Map<String, dynamic> json) =>
      _$CalendarAvailabilityShareFromJson(json);
}

@freezed
class CalendarAvailabilityRequest with _$CalendarAvailabilityRequest {
  const factory CalendarAvailabilityRequest({
    required String id,
    required String shareId,
    required String requesterJid,
    required CalendarDateTime start,
    required CalendarDateTime end,
    String? title,
    String? description,
  }) = _CalendarAvailabilityRequest;

  factory CalendarAvailabilityRequest.fromJson(Map<String, dynamic> json) =>
      _$CalendarAvailabilityRequestFromJson(json);
}

enum CalendarAvailabilityResponseStatus {
  accepted,
  declined;

  bool get isAccepted => this == CalendarAvailabilityResponseStatus.accepted;
  bool get isDeclined => this == CalendarAvailabilityResponseStatus.declined;
}

@freezed
class CalendarAvailabilityResponse with _$CalendarAvailabilityResponse {
  const factory CalendarAvailabilityResponse({
    required String id,
    required String shareId,
    required String requestId,
    required CalendarAvailabilityResponseStatus status,
    String? note,
  }) = _CalendarAvailabilityResponse;

  factory CalendarAvailabilityResponse.fromJson(Map<String, dynamic> json) =>
      _$CalendarAvailabilityResponseFromJson(json);
}

enum CalendarAvailabilityMessageKind {
  share,
  request,
  response;

  bool get isShare => this == CalendarAvailabilityMessageKind.share;
  bool get isRequest => this == CalendarAvailabilityMessageKind.request;
  bool get isResponse => this == CalendarAvailabilityMessageKind.response;
}

@Freezed(
  unionKey: _calendarAvailabilityMessageUnionKey,
  unionValueCase: FreezedUnionCase.snake,
)
class CalendarAvailabilityMessage with _$CalendarAvailabilityMessage {
  const factory CalendarAvailabilityMessage.share({
    required CalendarAvailabilityShare share,
  }) = CalendarAvailabilityShareMessage;

  const factory CalendarAvailabilityMessage.request({
    required CalendarAvailabilityRequest request,
  }) = CalendarAvailabilityRequestMessage;

  const factory CalendarAvailabilityMessage.response({
    required CalendarAvailabilityResponse response,
  }) = CalendarAvailabilityResponseMessage;

  factory CalendarAvailabilityMessage.fromJson(Map<String, dynamic> json) =>
      _$CalendarAvailabilityMessageFromJson(json);

  const CalendarAvailabilityMessage._();
}

extension CalendarAvailabilityMessageX on CalendarAvailabilityMessage {
  CalendarAvailabilityMessageKind get kind => map(
        share: (_) => CalendarAvailabilityMessageKind.share,
        request: (_) => CalendarAvailabilityMessageKind.request,
        response: (_) => CalendarAvailabilityMessageKind.response,
      );

  String get shareId => map(
        share: (message) => message.share.id,
        request: (message) => message.request.shareId,
        response: (message) => message.response.shareId,
      );
}
