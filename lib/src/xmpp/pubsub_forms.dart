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

const _boolTrue = '1';
const _boolFalse = '0';

mox.XMLNode _formField(
  String name,
  String value, {
  String? type,
}) =>
    mox.XMLNode(
      tag: _fieldTag,
      attributes: {
        _varAttr: name,
        if (type != null) _typeAttr: type,
      },
      children: [
        mox.XMLNode(
          tag: _valueTag,
          text: value,
        ),
      ],
    );

String _boolValue(bool value) => value ? _boolTrue : _boolFalse;

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
  final String sendLastPublishedItem;

  mox.XMLNode toForm() {
    return mox.XMLNode.xmlns(
      tag: _dataFormTag,
      xmlns: _dataFormXmlns,
      attributes: const {_typeAttr: _dataFormTypeSubmit},
      children: [
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
        _formField(
          _deliverPayloadsField,
          _boolValue(deliverPayloads),
        ),
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
        _formField(_sendLastPublishedItemField, sendLastPublishedItem),
      ],
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
