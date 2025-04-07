// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: implicit_dynamic_parameter

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PresenceAdapter extends TypeAdapter<Presence> {
  @override
  final int typeId = 1;

  @override
  Presence read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Presence.unavailable;
      case 1:
        return Presence.xa;
      case 2:
        return Presence.away;
      case 3:
        return Presence.dnd;
      case 4:
        return Presence.chat;
      case 5:
        return Presence.unknown;
      default:
        return Presence.unavailable;
    }
  }

  @override
  void write(BinaryWriter writer, Presence obj) {
    switch (obj) {
      case Presence.unavailable:
        writer.writeByte(0);
        break;
      case Presence.xa:
        writer.writeByte(1);
        break;
      case Presence.away:
        writer.writeByte(2);
        break;
      case Presence.dnd:
        writer.writeByte(3);
        break;
      case Presence.chat:
        writer.writeByte(4);
        break;
      case Presence.unknown:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PresenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$RosterItemImpl _$$RosterItemImplFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      r'_$RosterItemImpl',
      json,
      ($checkedConvert) {
        final val = _$RosterItemImpl(
          jid: $checkedConvert('jid', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          presence: $checkedConvert(
              'presence', (v) => $enumDecode(_$PresenceEnumMap, v)),
          subscription: $checkedConvert(
              'subscription', (v) => $enumDecode(_$SubscriptionEnumMap, v)),
          status: $checkedConvert('status', (v) => v as String?),
          ask: $checkedConvert(
              'ask', (v) => $enumDecodeNullable(_$AskEnumMap, v)),
          avatarPath: $checkedConvert('avatar_path', (v) => v as String?),
          avatarHash: $checkedConvert('avatar_hash', (v) => v as String?),
          contactID: $checkedConvert('contact_i_d', (v) => v as String?),
          contactAvatarPath:
              $checkedConvert('contact_avatar_path', (v) => v as String?),
          contactDisplayName:
              $checkedConvert('contact_display_name', (v) => v as String?),
          groups: $checkedConvert(
              'groups',
              (v) =>
                  (v as List<dynamic>?)?.map((e) => e as String).toList() ??
                  const <String>[]),
          $type: $checkedConvert('runtimeType', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'avatarPath': 'avatar_path',
        'avatarHash': 'avatar_hash',
        'contactID': 'contact_i_d',
        'contactAvatarPath': 'contact_avatar_path',
        'contactDisplayName': 'contact_display_name',
        r'$type': 'runtimeType'
      },
    );

Map<String, dynamic> _$$RosterItemImplToJson(_$RosterItemImpl instance) =>
    <String, dynamic>{
      'jid': instance.jid,
      'title': instance.title,
      'presence': _$PresenceEnumMap[instance.presence]!,
      'subscription': _$SubscriptionEnumMap[instance.subscription]!,
      'status': instance.status,
      'ask': _$AskEnumMap[instance.ask],
      'avatar_path': instance.avatarPath,
      'avatar_hash': instance.avatarHash,
      'contact_i_d': instance.contactID,
      'contact_avatar_path': instance.contactAvatarPath,
      'contact_display_name': instance.contactDisplayName,
      'groups': instance.groups,
      'runtimeType': instance.$type,
    };

const _$PresenceEnumMap = {
  Presence.unavailable: 'unavailable',
  Presence.xa: 'xa',
  Presence.away: 'away',
  Presence.dnd: 'dnd',
  Presence.chat: 'chat',
  Presence.unknown: 'unknown',
};

const _$SubscriptionEnumMap = {
  Subscription.none: 'none',
  Subscription.to: 'to',
  Subscription.from: 'from',
  Subscription.both: 'both',
};

const _$AskEnumMap = {
  Ask.subscribe: 'subscribe',
  Ask.subscribed: 'subscribed',
};

_$RosterItemFromDbImpl _$$RosterItemFromDbImplFromJson(
        Map<String, dynamic> json) =>
    $checkedCreate(
      r'_$RosterItemFromDbImpl',
      json,
      ($checkedConvert) {
        final val = _$RosterItemFromDbImpl(
          jid: $checkedConvert('jid', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          presence: $checkedConvert(
              'presence', (v) => $enumDecode(_$PresenceEnumMap, v)),
          status: $checkedConvert('status', (v) => v as String?),
          avatarPath: $checkedConvert('avatar_path', (v) => v as String?),
          avatarHash: $checkedConvert('avatar_hash', (v) => v as String?),
          subscription: $checkedConvert(
              'subscription', (v) => $enumDecode(_$SubscriptionEnumMap, v)),
          ask: $checkedConvert(
              'ask', (v) => $enumDecodeNullable(_$AskEnumMap, v)),
          contactID: $checkedConvert('contact_i_d', (v) => v as String?),
          contactAvatarPath:
              $checkedConvert('contact_avatar_path', (v) => v as String?),
          contactDisplayName:
              $checkedConvert('contact_display_name', (v) => v as String?),
          groups: $checkedConvert(
              'groups',
              (v) =>
                  (v as List<dynamic>?)?.map((e) => e as String).toList() ??
                  const <String>[]),
          $type: $checkedConvert('runtimeType', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'avatarPath': 'avatar_path',
        'avatarHash': 'avatar_hash',
        'contactID': 'contact_i_d',
        'contactAvatarPath': 'contact_avatar_path',
        'contactDisplayName': 'contact_display_name',
        r'$type': 'runtimeType'
      },
    );

Map<String, dynamic> _$$RosterItemFromDbImplToJson(
        _$RosterItemFromDbImpl instance) =>
    <String, dynamic>{
      'jid': instance.jid,
      'title': instance.title,
      'presence': _$PresenceEnumMap[instance.presence]!,
      'status': instance.status,
      'avatar_path': instance.avatarPath,
      'avatar_hash': instance.avatarHash,
      'subscription': _$SubscriptionEnumMap[instance.subscription]!,
      'ask': _$AskEnumMap[instance.ask],
      'contact_i_d': instance.contactID,
      'contact_avatar_path': instance.contactAvatarPath,
      'contact_display_name': instance.contactDisplayName,
      'groups': instance.groups,
      'runtimeType': instance.$type,
    };
