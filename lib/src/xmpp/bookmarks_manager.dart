import 'package:moxxmpp/moxxmpp.dart' as mox;

final class MucBookmark {
  const MucBookmark({
    required this.roomBare,
    this.name,
    this.nick,
    this.password,
    this.autojoin = false,
  });

  final mox.JID roomBare;
  final String? name;
  final bool autojoin;
  final String? nick;
  final String? password;

  MucBookmark copyWith({
    mox.JID? roomBare,
    String? name,
    bool? autojoin,
    String? nick,
    String? password,
  }) {
    return MucBookmark(
      roomBare: roomBare ?? this.roomBare,
      name: name ?? this.name,
      autojoin: autojoin ?? this.autojoin,
      nick: nick ?? this.nick,
      password: password ?? this.password,
    );
  }

  static bool _parseBool(String? value, {required bool defaultValue}) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => defaultValue,
    };
  }

  static MucBookmark? fromConferenceXml(mox.XMLNode node) {
    if (node.tag != _conferenceTag) return null;
    final rawJid = node.attributes[_conferenceJidAttr]?.toString().trim();
    if (rawJid == null || rawJid.isEmpty) return null;

    late final mox.JID jid;
    try {
      jid = mox.JID.fromString(rawJid).toBare();
    } on Exception {
      return null;
    }

    final rawName = node.attributes[_conferenceNameAttr]?.toString().trim();
    final rawAutojoin =
        node.attributes[_conferenceAutojoinAttr]?.toString().trim();
    final nick = node.firstTag(_nickTag)?.innerText().trim();
    final password = node.firstTag(_passwordTag)?.innerText().trim();

    return MucBookmark(
      roomBare: jid,
      name: rawName?.isNotEmpty == true ? rawName : null,
      autojoin: _parseBool(rawAutojoin, defaultValue: false),
      nick: nick?.isNotEmpty == true ? nick : null,
      password: password?.isNotEmpty == true ? password : null,
    );
  }

  mox.XMLNode toConferenceXml() {
    final bare = roomBare.toBare();
    final trimmedName = name?.trim();
    final trimmedNick = nick?.trim();
    final trimmedPassword = password?.trim();
    return mox.XMLNode(
      tag: _conferenceTag,
      attributes: {
        _conferenceJidAttr: bare.toString(),
        if (trimmedName?.isNotEmpty == true) _conferenceNameAttr: trimmedName!,
        if (autojoin) _conferenceAutojoinAttr: 'true',
      },
      children: [
        if (trimmedNick?.isNotEmpty == true)
          mox.XMLNode(tag: _nickTag, text: trimmedNick),
        if (trimmedPassword?.isNotEmpty == true)
          mox.XMLNode(tag: _passwordTag, text: trimmedPassword),
      ],
    );
  }
}

const _privateXmlns = 'jabber:iq:private';
const _stanzaErrorXmlns = 'urn:ietf:params:xml:ns:xmpp-stanzas';
const _iqTypeAttr = 'type';
const _iqResultType = 'result';
const _iqErrorType = 'error';
const _errorTag = 'error';
const _itemNotFoundTag = 'item-not-found';
const _privateQueryTag = 'query';
const _bookmarksXmlns = 'storage:bookmarks';
const _storageTag = 'storage';

const _conferenceTag = 'conference';
const _conferenceJidAttr = 'jid';
const _conferenceNameAttr = 'name';
const _conferenceAutojoinAttr = 'autojoin';
const _nickTag = 'nick';
const _passwordTag = 'password';

final class BookmarksManager extends mox.XmppManagerBase {
  BookmarksManager() : super(managerId);

  static const String managerId = 'axi.bookmarks';

  @override
  Future<bool> isSupported() async => true;

  bool _isItemNotFoundResponse(mox.XMLNode stanza) {
    final error = stanza.firstTag(_errorTag);
    return error?.firstTag(_itemNotFoundTag, xmlns: _stanzaErrorXmlns) != null;
  }

  Future<List<MucBookmark>> getBookmarks() async {
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: 'get',
          children: [
            mox.XMLNode.xmlns(
              tag: _privateQueryTag,
              xmlns: _privateXmlns,
              children: [
                mox.XMLNode.xmlns(tag: _storageTag, xmlns: _bookmarksXmlns),
              ],
            ),
          ],
        ),
        shouldEncrypt: false,
      ),
    );

    if (result == null) {
      throw Exception('bookmark fetch failed');
    }

    final stanzaType = result.attributes[_iqTypeAttr]?.toString();
    if (stanzaType != _iqResultType) {
      if (stanzaType == _iqErrorType && _isItemNotFoundResponse(result)) {
        return const [];
      }
      throw Exception('bookmark fetch failed');
    }

    final query = result.firstTag(_privateQueryTag, xmlns: _privateXmlns);
    final storage = query?.firstTag(_storageTag, xmlns: _bookmarksXmlns);
    if (storage == null) return const [];

    final bookmarks = storage
        .findTags(_conferenceTag)
        .map(MucBookmark.fromConferenceXml)
        .whereType<MucBookmark>()
        .toList(growable: false);
    return List<MucBookmark>.unmodifiable(bookmarks);
  }

  Future<void> setBookmarks(List<MucBookmark> all) async {
    await getBookmarks();
    await _writeBookmarks(all);
  }

  Future<void> upsertBookmark(MucBookmark bookmark) async {
    final current = await getBookmarks();
    final normalizedRoom = bookmark.roomBare.toBare().toString();
    final updated = <MucBookmark>[];
    var replaced = false;
    for (final entry in current) {
      if (entry.roomBare.toBare().toString() == normalizedRoom) {
        updated.add(bookmark.copyWith(roomBare: bookmark.roomBare.toBare()));
        replaced = true;
      } else {
        updated.add(entry);
      }
    }
    if (!replaced) {
      updated.add(bookmark.copyWith(roomBare: bookmark.roomBare.toBare()));
    }
    await _writeBookmarks(updated);
  }

  Future<void> removeBookmark(mox.JID roomBareJid) async {
    final current = await getBookmarks();
    final normalizedRoom = roomBareJid.toBare().toString();
    final updated = current
        .where((entry) => entry.roomBare.toBare().toString() != normalizedRoom)
        .toList(growable: false);
    if (updated.length == current.length) return;
    await _writeBookmarks(updated);
  }

  Future<void> _writeBookmarks(List<MucBookmark> all) async {
    final storage = mox.XMLNode.xmlns(
      tag: _storageTag,
      xmlns: _bookmarksXmlns,
      children: all.map((bookmark) => bookmark.toConferenceXml()).toList(),
    );
    final result = await getAttributes().sendStanza(
      mox.StanzaDetails(
        mox.Stanza.iq(
          type: 'set',
          children: [
            mox.XMLNode.xmlns(
              tag: _privateQueryTag,
              xmlns: _privateXmlns,
              children: [storage],
            ),
          ],
        ),
        shouldEncrypt: false,
      ),
    );

    if (result == null || result.attributes['type'] != 'result') {
      throw Exception('bookmark write failed');
    }
  }
}
