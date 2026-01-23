// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:moxxmpp/moxxmpp.dart' as mox;

const _dataFormXmlns = 'jabber:x:data';
const _dataFormTypeSubmit = 'submit';
const _dataFormTypeHidden = 'hidden';
const _dataFormTag = 'x';
const _fieldTag = 'field';
const _valueTag = 'value';
const _varAttr = 'var';
const _typeAttr = 'type';
const _formTypeField = 'FORM_TYPE';
const _nodeConfigFormType = 'http://jabber.org/protocol/pubsub#node_config';

const _accessModelField = 'pubsub#access_model';
const _publishModelField = 'pubsub#publish_model';
const _deliverNotificationsField = 'pubsub#deliver_notifications';
const _deliverPayloadsField = 'pubsub#deliver_payloads';
const _persistItemsField = 'pubsub#persist_items';
const _maxItemsField = 'pubsub#max_items';
const _notifyRetractField = 'pubsub#notify_retract';
const _notifyDeleteField = 'pubsub#notify_delete';
const _notifyConfigField = 'pubsub#notify_config';
const _notifySubField = 'pubsub#notify_sub';
const _presenceBasedDeliveryField = 'pubsub#presence_based_delivery';
const _sendLastPublishedItemField = 'pubsub#send_last_published_item';

const _optionTag = 'option';
const _boolTrue = '1';
const _boolFalse = '0';

enum SendLastPublishedItemSetting {
  never,
  onSubscribe,
  onPublish,
  onSubAndPresence;

  static SendLastPublishedItemSetting? fromString(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'never' => SendLastPublishedItemSetting.never,
      'on_subscribe' => SendLastPublishedItemSetting.onSubscribe,
      'on_publish' => SendLastPublishedItemSetting.onPublish,
      'on_sub_and_presence' => SendLastPublishedItemSetting.onSubAndPresence,
      _ => null,
    };
  }

  String get value => switch (this) {
        SendLastPublishedItemSetting.never => 'never',
        SendLastPublishedItemSetting.onSubscribe => 'on_subscribe',
        SendLastPublishedItemSetting.onPublish => 'on_publish',
        SendLastPublishedItemSetting.onSubAndPresence => 'on_sub_and_presence',
      };
}

const List<SendLastPublishedItemSetting> _sendLastPreferenceOrder =
    <SendLastPublishedItemSetting>[
  SendLastPublishedItemSetting.onSubscribe,
  SendLastPublishedItemSetting.onSubAndPresence,
  SendLastPublishedItemSetting.onPublish,
  SendLastPublishedItemSetting.never,
];

mox.XMLNode _formField(String name, String value, {String? type}) =>
    mox.XMLNode(
      tag: _fieldTag,
      attributes: {_varAttr: name, if (type != null) _typeAttr: type},
      children: [mox.XMLNode(tag: _valueTag, text: value)],
    );

String _boolValue(bool value) => value ? _boolTrue : _boolFalse;

mox.XMLNode? _findField(mox.XMLNode form, String name) {
  for (final child in form.children) {
    if (child.tag != _fieldTag) continue;
    final rawVar = child.attributes[_varAttr]?.toString().trim();
    if (rawVar == name) {
      return child;
    }
  }
  return null;
}

List<String> _fieldOptionValues(mox.XMLNode field) {
  final values = <String>[];
  for (final child in field.children) {
    if (child.tag != _optionTag) continue;
    final optionNode = child.firstTag(_valueTag);
    final optionValue = optionNode?.innerText().trim();
    if (optionValue == null || optionValue.isEmpty) {
      continue;
    }
    values.add(optionValue);
  }
  return values;
}

List<String> _fieldValues(mox.XMLNode field) {
  final values = <String>[];
  for (final child in field.children) {
    if (child.tag != _valueTag) continue;
    final value = child.innerText().trim();
    if (value.isNotEmpty) {
      values.add(value);
    }
  }
  return values;
}

String? resolveSendLastPublishedItemValue(mox.XMLNode form) {
  final field = _findField(form, _sendLastPublishedItemField);
  if (field == null) return null;
  final optionValues = _fieldOptionValues(field);
  final rawValues = optionValues.isEmpty ? _fieldValues(field) : optionValues;
  if (rawValues.isEmpty) return null;
  final allowed = <SendLastPublishedItemSetting>[];
  for (final rawValue in rawValues) {
    final parsed = SendLastPublishedItemSetting.fromString(rawValue);
    if (parsed != null) {
      allowed.add(parsed);
    }
  }
  if (allowed.isEmpty) return null;
  for (final preferred in _sendLastPreferenceOrder) {
    if (allowed.contains(preferred)) {
      return preferred.value;
    }
  }
  return allowed.first.value;
}

final class AxiPubSubNodeConfig {
  const AxiPubSubNodeConfig({
    required this.accessModel,
    required this.publishModel,
    required this.deliverNotifications,
    required this.deliverPayloads,
    required this.maxItems,
    required this.notifyRetract,
    required this.notifyDelete,
    required this.notifyConfig,
    required this.notifySub,
    required this.presenceBasedDelivery,
    required this.persistItems,
    required this.sendLastPublishedItem,
  });

  final mox.AccessModel accessModel;
  final String publishModel;
  final bool deliverNotifications;
  final bool deliverPayloads;
  final String maxItems;
  final bool notifyRetract;
  final bool notifyDelete;
  final bool notifyConfig;
  final bool notifySub;
  final bool presenceBasedDelivery;
  final bool persistItems;
  final String? sendLastPublishedItem;

  bool get hasSendLastPublishedItem {
    final normalized = sendLastPublishedItem?.trim();
    return normalized != null && normalized.isNotEmpty;
  }

  AxiPubSubNodeConfig withSendLastPublishedItem(String? value) =>
      AxiPubSubNodeConfig(
        accessModel: accessModel,
        publishModel: publishModel,
        deliverNotifications: deliverNotifications,
        deliverPayloads: deliverPayloads,
        maxItems: maxItems,
        notifyRetract: notifyRetract,
        notifyDelete: notifyDelete,
        notifyConfig: notifyConfig,
        notifySub: notifySub,
        presenceBasedDelivery: presenceBasedDelivery,
        persistItems: persistItems,
        sendLastPublishedItem: value,
      );

  AxiPubSubNodeConfig withoutSendLastPublishedItem() => AxiPubSubNodeConfig(
        accessModel: accessModel,
        publishModel: publishModel,
        deliverNotifications: deliverNotifications,
        deliverPayloads: deliverPayloads,
        maxItems: maxItems,
        notifyRetract: notifyRetract,
        notifyDelete: notifyDelete,
        notifyConfig: notifyConfig,
        notifySub: notifySub,
        presenceBasedDelivery: presenceBasedDelivery,
        persistItems: persistItems,
        sendLastPublishedItem: null,
      );

  mox.XMLNode toForm() {
    final fields = <mox.XMLNode>[
      _formField(
        _formTypeField,
        _nodeConfigFormType,
        type: _dataFormTypeHidden,
      ),
      _formField(_accessModelField, accessModel.value),
      _formField(_publishModelField, publishModel),
      _formField(
        _deliverNotificationsField,
        _boolValue(deliverNotifications),
      ),
      _formField(_deliverPayloadsField, _boolValue(deliverPayloads)),
      _formField(_maxItemsField, maxItems),
      _formField(_persistItemsField, _boolValue(persistItems)),
      _formField(_notifyRetractField, _boolValue(notifyRetract)),
      _formField(_notifyDeleteField, _boolValue(notifyDelete)),
      _formField(_notifyConfigField, _boolValue(notifyConfig)),
      _formField(_notifySubField, _boolValue(notifySub)),
      _formField(
        _presenceBasedDeliveryField,
        _boolValue(presenceBasedDelivery),
      ),
    ];
    final sendLastValue = sendLastPublishedItem?.trim();
    if (sendLastValue != null && sendLastValue.isNotEmpty) {
      fields.add(_formField(_sendLastPublishedItemField, sendLastValue));
    }
    return mox.XMLNode.xmlns(
      tag: _dataFormTag,
      xmlns: _dataFormXmlns,
      attributes: const {_typeAttr: _dataFormTypeSubmit},
      children: fields,
    );
  }

  mox.NodeConfig toNodeConfig() => mox.NodeConfig(
        accessModel: accessModel,
        publishModel: publishModel,
        deliverNotifications: deliverNotifications,
        deliverPayloads: deliverPayloads,
        maxItems: maxItems,
        notifyRetract: notifyRetract,
        persistItems: persistItems,
        sendLastPublishedItem: sendLastPublishedItem,
      );
}
