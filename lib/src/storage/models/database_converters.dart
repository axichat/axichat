// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

class JsonConverter<V> extends TypeConverter<Map<String, V>, String> {
  @override
  Map<String, V> fromSql(String fromDb) => jsonDecode(fromDb);

  @override
  String toSql(Map<String, V> value) => jsonEncode(value);
}

class HashesConverter
    extends TypeConverter<Map<mox.HashFunction, String>, String> {
  @override
  Map<mox.HashFunction, String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as Map<String, dynamic>).map(
        (k, v) => MapEntry(mox.HashFunction.fromName(k), v as String),
      );

  @override
  String toSql(Map<mox.HashFunction, String> value) =>
      jsonEncode(value.map((k, v) => MapEntry(k.toName(), v)));
}

class ListConverter<T> extends TypeConverter<List<T>, String> {
  @override
  List<T> fromSql(String fromDb) => List<T>.from(jsonDecode(fromDb));

  @override
  String toSql(List<T> value) => jsonEncode(value);
}

class MapStringDynamicConverter
    extends TypeConverter<Map<String, dynamic>, String> {
  const MapStringDynamicConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) => jsonDecode(fromDb);

  @override
  String toSql(Map<String, dynamic> value) => jsonEncode(value);
}

class MapStringStringConverter
    extends TypeConverter<Map<String, String>, String> {
  const MapStringStringConverter();

  @override
  Map<String, String> fromSql(String fromDb) =>
      Map<String, String>.from(jsonDecode(fromDb));

  @override
  String toSql(Map<String, String> value) => jsonEncode(value);
}
