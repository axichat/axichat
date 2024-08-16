// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'profile_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ProfileState {
  String get jid => throw _privateConstructorUsedError;
  String get resource => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get fingerprint => throw _privateConstructorUsedError;
  Presence get presence => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ProfileStateCopyWith<ProfileState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProfileStateCopyWith<$Res> {
  factory $ProfileStateCopyWith(
          ProfileState value, $Res Function(ProfileState) then) =
      _$ProfileStateCopyWithImpl<$Res, ProfileState>;
  @useResult
  $Res call(
      {String jid,
      String resource,
      String title,
      String fingerprint,
      Presence presence,
      String? status});
}

/// @nodoc
class _$ProfileStateCopyWithImpl<$Res, $Val extends ProfileState>
    implements $ProfileStateCopyWith<$Res> {
  _$ProfileStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jid = null,
    Object? resource = null,
    Object? title = null,
    Object? fingerprint = null,
    Object? presence = null,
    Object? status = freezed,
  }) {
    return _then(_value.copyWith(
      jid: null == jid
          ? _value.jid
          : jid // ignore: cast_nullable_to_non_nullable
              as String,
      resource: null == resource
          ? _value.resource
          : resource // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      fingerprint: null == fingerprint
          ? _value.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      presence: null == presence
          ? _value.presence
          : presence // ignore: cast_nullable_to_non_nullable
              as Presence,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ProfileStateImplCopyWith<$Res>
    implements $ProfileStateCopyWith<$Res> {
  factory _$$ProfileStateImplCopyWith(
          _$ProfileStateImpl value, $Res Function(_$ProfileStateImpl) then) =
      __$$ProfileStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String jid,
      String resource,
      String title,
      String fingerprint,
      Presence presence,
      String? status});
}

/// @nodoc
class __$$ProfileStateImplCopyWithImpl<$Res>
    extends _$ProfileStateCopyWithImpl<$Res, _$ProfileStateImpl>
    implements _$$ProfileStateImplCopyWith<$Res> {
  __$$ProfileStateImplCopyWithImpl(
      _$ProfileStateImpl _value, $Res Function(_$ProfileStateImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? jid = null,
    Object? resource = null,
    Object? title = null,
    Object? fingerprint = null,
    Object? presence = null,
    Object? status = freezed,
  }) {
    return _then(_$ProfileStateImpl(
      jid: null == jid
          ? _value.jid
          : jid // ignore: cast_nullable_to_non_nullable
              as String,
      resource: null == resource
          ? _value.resource
          : resource // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      fingerprint: null == fingerprint
          ? _value.fingerprint
          : fingerprint // ignore: cast_nullable_to_non_nullable
              as String,
      presence: null == presence
          ? _value.presence
          : presence // ignore: cast_nullable_to_non_nullable
              as Presence,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ProfileStateImpl implements _ProfileState {
  const _$ProfileStateImpl(
      {required this.jid,
      required this.resource,
      required this.title,
      this.fingerprint = '',
      this.presence = Presence.chat,
      this.status});

  @override
  final String jid;
  @override
  final String resource;
  @override
  final String title;
  @override
  @JsonKey()
  final String fingerprint;
  @override
  @JsonKey()
  final Presence presence;
  @override
  final String? status;

  @override
  String toString() {
    return 'ProfileState(jid: $jid, resource: $resource, title: $title, fingerprint: $fingerprint, presence: $presence, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProfileStateImpl &&
            (identical(other.jid, jid) || other.jid == jid) &&
            (identical(other.resource, resource) ||
                other.resource == resource) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.fingerprint, fingerprint) ||
                other.fingerprint == fingerprint) &&
            (identical(other.presence, presence) ||
                other.presence == presence) &&
            (identical(other.status, status) || other.status == status));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, jid, resource, title, fingerprint, presence, status);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$ProfileStateImplCopyWith<_$ProfileStateImpl> get copyWith =>
      __$$ProfileStateImplCopyWithImpl<_$ProfileStateImpl>(this, _$identity);
}

abstract class _ProfileState implements ProfileState {
  const factory _ProfileState(
      {required final String jid,
      required final String resource,
      required final String title,
      final String fingerprint,
      final Presence presence,
      final String? status}) = _$ProfileStateImpl;

  @override
  String get jid;
  @override
  String get resource;
  @override
  String get title;
  @override
  String get fingerprint;
  @override
  Presence get presence;
  @override
  String? get status;
  @override
  @JsonKey(ignore: true)
  _$$ProfileStateImplCopyWith<_$ProfileStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
