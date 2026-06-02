pub use deltachat::*;

use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::io::Write;
use std::os::raw::c_char;
use std::ptr;
use std::sync::{Arc, LazyLock, Mutex};
use std::time::Duration;

use brotli::DecompressorWriter;
use deltachat_core::chat::ChatId;
use deltachat_core::constants::{Blocked, Chattype, DC_CHAT_ID_LAST_SPECIAL};
use deltachat_core::contact::{self, Origin};
use deltachat_core::context::Context;
use deltachat_core::key::{DcKey, SignedPublicKey, SignedSecretKey};
use deltachat_core::message::MsgId;
use deltachat_core::sql;
use deltachat_core::EventType;
use mailparse::{parse_mail, DispositionType, ParsedMail};
use pgp::types::PublicKeyTrait;
use serde_json::json;
use tokio::runtime::Runtime;
use tokio::sync::Notify;

const STORED_MIME_QUERY: &str = "SELECT mime_headers, mime_compressed FROM msgs WHERE id=?";
const RFC724_MID_QUERY: &str = "SELECT rfc724_mid FROM msgs WHERE id=?";
const RFC724_MID_MESSAGE_IDS_QUERY: &str = r#"
SELECT related.id
FROM msgs AS source
JOIN msgs AS related
  ON related.rfc724_mid = source.rfc724_mid
 AND related.chat_id = source.chat_id
 AND related.from_id = source.from_id
WHERE source.id = ?
  AND source.rfc724_mid != ''
  AND related.hidden = 0
ORDER BY related.timestamp ASC, related.id ASC
"#;
const MSG_DEBUG_INFO_QUERY: &str = r#"
SELECT id, rfc724_mid, server_folder, server_uid, chat_id, from_id, to_id,
       timestamp, type, state, msgrmsg, bytes, hidden,
       COALESCE(download_state, -1), COALESCE(mime_compressed, 0),
       COALESCE(LENGTH(txt), 0), COALESCE(LENGTH(subject), 0),
       COALESCE(LENGTH(param), 0),
       CASE WHEN mime_headers IS NULL THEN 0 ELSE LENGTH(mime_headers) END,
       mime_in_reply_to, mime_references
FROM msgs
WHERE id=?
"#;
const IMAP_MATCH_COUNT_QUERY: &str = r#"
SELECT COUNT(*)
FROM imap
WHERE rfc724_mid = (SELECT rfc724_mid FROM msgs WHERE id=?)
  AND rfc724_mid != ''
"#;
const STORED_MIME_COLUMN_BYTES: usize = 0;
const STORED_MIME_COLUMN_COMPRESSED: usize = 1;
const BROTLI_BUFFER_SIZE: usize = 4096;
const NULL_BYTE: u8 = 0;
const AXICHAT_OPENPGP_KEY_KIND_PUBLIC: i32 = 1;
const AXICHAT_OPENPGP_KEY_KIND_PRIVATE: i32 = 2;
const PUBLIC_KEY_ARMOR_BEGIN: &str = "-----BEGIN PGP PUBLIC KEY BLOCK-----";
const PRIVATE_KEY_ARMOR_BEGIN: &str = "-----BEGIN PGP PRIVATE KEY BLOCK-----";
const CONTACT_ID_LAST_SPECIAL: u32 = 9;

static _RUNTIME: LazyLock<Runtime> =
    LazyLock::new(|| Runtime::new().expect("failed to create tokio runtime"));
static _ACTIVE_BACKGROUND_FETCHES: LazyLock<Mutex<HashMap<usize, Arc<Notify>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn _block_on<T>(future: impl std::future::Future<Output = T>) -> T {
    _RUNTIME.block_on(future)
}

fn _register_active_background_fetch(accounts: usize) -> Option<Arc<Notify>> {
    let mut active = _ACTIVE_BACKGROUND_FETCHES
        .lock()
        .expect("active background fetch registry poisoned");
    if active.contains_key(&accounts) {
        return None;
    }
    let signal = Arc::new(Notify::new());
    active.insert(accounts, signal.clone());
    Some(signal)
}

fn _stop_active_background_fetch(accounts: usize) -> bool {
    let active = _ACTIVE_BACKGROUND_FETCHES
        .lock()
        .expect("active background fetch registry poisoned");
    let Some(signal) = active.get(&accounts) else {
        return false;
    };
    signal.notify_one();
    true
}

fn _finish_active_background_fetch(accounts: usize) {
    _ACTIVE_BACKGROUND_FETCHES
        .lock()
        .expect("active background fetch registry poisoned")
        .remove(&accounts);
}

struct _ActiveBackgroundFetchGuard {
    accounts: usize,
}

impl Drop for _ActiveBackgroundFetchGuard {
    fn drop(&mut self) {
        _finish_active_background_fetch(self.accounts);
    }
}

fn _read_stored_mime(context: &Context, msg_id: MsgId) -> Option<Vec<u8>> {
    let query = context.sql();
    let fetched = _block_on(query.query_row(STORED_MIME_QUERY, (msg_id,), |row| {
        let bytes = sql::row_get_vec(row, STORED_MIME_COLUMN_BYTES)?;
        let compressed: Option<bool> = row.get(STORED_MIME_COLUMN_COMPRESSED)?;
        Ok((bytes, compressed.unwrap_or(false)))
    }))
    .ok()?;
    let (bytes, compressed) = fetched;
    if bytes.is_empty() {
        return None;
    }
    if !compressed {
        return Some(bytes);
    }
    _decompress_stored_mime(&bytes)
}

fn _read_msg_rfc724_mid(context: &Context, msg_id: MsgId) -> Option<String> {
    let value: String =
        _block_on(context.sql().query_get_value(RFC724_MID_QUERY, (msg_id,))).ok()??;
    let sanitized = value.replace('\0', "").trim().to_string();
    if sanitized.is_empty() {
        return None;
    }
    Some(sanitized)
}

fn _read_msg_ids_by_rfc724_mid(context: &Context, msg_id: MsgId) -> Vec<u32> {
    _block_on(
        context
            .sql()
            .query_map_vec(RFC724_MID_MESSAGE_IDS_QUERY, (msg_id,), |row| {
                let msg_id: MsgId = row.get(0)?;
                Ok(msg_id.to_u32())
            }),
    )
    .unwrap_or_default()
}

fn _read_msg_debug_info(context: &Context, msg_id: MsgId) -> String {
    let related_ids = _read_msg_ids_by_rfc724_mid(context, msg_id);
    let imap_match_count: i64 = _block_on(
        context
            .sql()
            .query_get_value(IMAP_MATCH_COUNT_QUERY, (msg_id,)),
    )
    .ok()
    .flatten()
    .unwrap_or_default();
    _block_on(
        context
            .sql()
            .query_row(MSG_DEBUG_INFO_QUERY, (msg_id,), |row| {
                let rfc724_mid: String = row.get(1)?;
                let server_folder: String = row.get(2)?;
                let mime_in_reply_to: Option<String> = row.get(19)?;
                let mime_references: Option<String> = row.get(20)?;
                Ok(json!({
                    "ok": true,
                    "id": row.get::<_, i64>(0)?,
                    "rfc724Mid": _debug_string_stats(&rfc724_mid),
                    "serverFolder": _debug_string_stats(&server_folder),
                    "serverUid": row.get::<_, i64>(3)?,
                    "chatId": row.get::<_, i64>(4)?,
                    "fromId": row.get::<_, i64>(5)?,
                    "toId": row.get::<_, i64>(6)?,
                    "timestamp": row.get::<_, i64>(7)?,
                    "type": row.get::<_, i64>(8)?,
                    "state": row.get::<_, i64>(9)?,
                    "msgrmsg": row.get::<_, i64>(10)?,
                    "bytes": row.get::<_, i64>(11)?,
                    "hidden": row.get::<_, i64>(12)?,
                    "downloadState": row.get::<_, i64>(13)?,
                    "mimeCompressed": row.get::<_, i64>(14)?,
                    "txtLength": row.get::<_, i64>(15)?,
                    "subjectLength": row.get::<_, i64>(16)?,
                    "paramLength": row.get::<_, i64>(17)?,
                    "mimeHeadersLength": row.get::<_, i64>(18)?,
                    "mimeInReplyTo": _debug_optional_string_stats(mime_in_reply_to.as_deref()),
                    "mimeReferences": _debug_optional_string_stats(mime_references.as_deref()),
                    "relatedByRfc724Mid": related_ids,
                    "imapMatchCount": imap_match_count,
                })
                .to_string())
            }),
    )
    .unwrap_or_else(|error| {
        json!({
            "ok": false,
            "id": msg_id.to_u32(),
            "error": error.to_string(),
        })
        .to_string()
    })
}

#[derive(Default)]
struct _Rfc822BodyParts {
    plain_text: Option<String>,
    html_body: Option<String>,
}

impl _Rfc822BodyParts {
    fn is_empty(&self) -> bool {
        self.plain_text.is_none() && self.html_body.is_none()
    }

    fn is_complete(&self) -> bool {
        self.plain_text.is_some() && self.html_body.is_some()
    }
}

fn _read_msg_rfc822_body_json(context: &Context, msg_id: MsgId) -> String {
    let Some(raw_mime) = _read_stored_mime(context, msg_id) else {
        return json!({
            "ok": false,
            "reason": "missing_mime",
        })
        .to_string();
    };
    _rfc822_body_json_from_raw_mime(&raw_mime)
}

fn _rfc822_body_json_from_raw_mime(raw_mime: &[u8]) -> String {
    let mail = match parse_mail(&raw_mime) {
        Ok(mail) => mail,
        Err(error) => {
            return json!({
                "ok": false,
                "reason": "parse_failed",
                "error": error.to_string(),
            })
            .to_string();
        }
    };
    let mut parts = _Rfc822BodyParts::default();
    _collect_rfc822_body_parts(&mail, &mut parts);
    json!({
        "ok": !parts.is_empty(),
        "reason": if parts.is_empty() { Some("missing_body") } else { None },
        "plainText": parts.plain_text,
        "htmlBody": parts.html_body,
    })
    .to_string()
}

fn _collect_rfc822_body_parts(mail: &ParsedMail<'_>, parts: &mut _Rfc822BodyParts) {
    if parts.is_complete() {
        return;
    }
    let mimetype = mail.ctype.mimetype.to_ascii_lowercase();
    if mail.get_content_disposition().disposition == DispositionType::Attachment {
        return;
    }
    if mimetype == "message/rfc822" {
        if let Ok(raw_body) = mail.get_body_raw() {
            if let Ok(nested) = parse_mail(&raw_body) {
                _collect_rfc822_body_parts(&nested, parts);
            }
        }
        return;
    }
    if !mail.subparts.is_empty() {
        for subpart in &mail.subparts {
            _collect_rfc822_body_parts(subpart, parts);
            if parts.is_complete() {
                return;
            }
        }
        return;
    }
    if mimetype == "text/plain" && parts.plain_text.is_none() {
        parts.plain_text = mail.get_body().ok().and_then(_clean_rfc822_body_part);
        return;
    }
    if mimetype == "text/html" && parts.html_body.is_none() {
        parts.html_body = mail.get_body().ok().and_then(_clean_rfc822_body_part);
    }
}

fn _clean_rfc822_body_part(value: String) -> Option<String> {
    let cleaned = value.replace('\0', "").trim().to_string();
    if cleaned.is_empty() {
        return None;
    }
    Some(cleaned)
}

fn _debug_optional_string_stats(value: Option<&str>) -> serde_json::Value {
    match value {
        Some(value) => _debug_string_stats(value),
        None => serde_json::Value::Null,
    }
}

fn _debug_string_stats(value: &str) -> serde_json::Value {
    let normalized = value.split_whitespace().collect::<Vec<_>>().join(" ");
    if normalized.is_empty() {
        return serde_json::Value::Null;
    }
    json!({
        "len": normalized.len(),
        "hash": _debug_fingerprint(&normalized),
    })
}

fn _debug_fingerprint(value: &str) -> String {
    let mut hash: u32 = 0x811c9dc5;
    for byte in value.as_bytes() {
        hash ^= u32::from(*byte);
        hash = hash.wrapping_mul(0x01000193);
    }
    format!("{hash:08x}")
}

fn _decompress_stored_mime(compressed: &[u8]) -> Option<Vec<u8>> {
    if compressed.is_empty() {
        return None;
    }
    let mut decompressor = DecompressorWriter::new(Vec::new(), BROTLI_BUFFER_SIZE);
    if decompressor.write_all(compressed).is_err() {
        return None;
    }
    if decompressor.flush().is_err() {
        return None;
    }
    let bytes = std::mem::take(decompressor.get_mut());
    if bytes.is_empty() {
        return None;
    }
    Some(bytes)
}

fn _headers_to_c_string(headers: &[u8]) -> *mut std::os::raw::c_char {
    let sanitized: Vec<u8> = headers
        .iter()
        .copied()
        .filter(|byte| *byte != NULL_BYTE)
        .collect();
    let decoded = String::from_utf8_lossy(&sanitized).to_string();
    CString::new(decoded)
        .unwrap_or_else(|_| CString::new(Vec::new()).unwrap())
        .into_raw()
}

fn _string_to_c(value: String) -> *mut c_char {
    CString::new(value)
        .unwrap_or_else(|_| CString::new("{}").unwrap())
        .into_raw()
}

unsafe fn _c_string_arg(value: *const c_char) -> Option<String> {
    if value.is_null() {
        return None;
    }
    Some(CStr::from_ptr(value).to_string_lossy().to_string())
}

fn _json_error(reason: &str) -> String {
    json!({
        "ok": false,
        "reason": reason,
    })
    .to_string()
}

fn _armor_block_count(armored: &str, marker: &str) -> usize {
    armored.match_indices(marker).count()
}

fn _key_user_ids(public_key: &SignedPublicKey) -> Vec<String> {
    public_key
        .details
        .users
        .iter()
        .filter_map(|user| String::from_utf8(user.id.id().to_vec()).ok())
        .collect()
}

fn _user_id_matches_address(user_id: &str, expected_addr: &str) -> bool {
    let expected = expected_addr.trim().to_ascii_lowercase();
    if expected.is_empty() {
        return false;
    }
    let normalized = user_id.trim().to_ascii_lowercase();
    if normalized == expected {
        return true;
    }
    let Some(start) = normalized.rfind('<') else {
        return false;
    };
    let Some(end) = normalized[start + 1..].find('>') else {
        return false;
    };
    normalized[start + 1..start + 1 + end].trim() == expected
}

fn _has_encryption_capability(public_key: &SignedPublicKey) -> bool {
    public_key.primary_key.is_encryption_key()
        || public_key
            .public_subkeys
            .iter()
            .any(|subkey| subkey.is_encryption_key())
}

fn _public_key_metadata_json(
    public_key: SignedPublicKey,
    expected_addr: &str,
    kind: &str,
) -> String {
    let user_ids = _key_user_ids(&public_key);
    let has_expected_address = user_ids
        .iter()
        .any(|user_id| _user_id_matches_address(user_id, expected_addr));
    let has_encryption_capability = _has_encryption_capability(&public_key);
    json!({
        "ok": true,
        "kind": kind,
        "fingerprint": public_key.dc_fingerprint().hex(),
        "userIds": user_ids,
        "hasExpectedAddress": has_expected_address,
        "hasEncryptionCapability": has_encryption_capability,
    })
    .to_string()
}

fn _inspect_openpgp_key_json(armored: &str, expected_addr: &str, expected_kind: i32) -> String {
    let public_blocks = _armor_block_count(armored, PUBLIC_KEY_ARMOR_BEGIN);
    let private_blocks = _armor_block_count(armored, PRIVATE_KEY_ARMOR_BEGIN);
    match expected_kind {
        AXICHAT_OPENPGP_KEY_KIND_PUBLIC => {
            if private_blocks > 0 {
                return _json_error("wrong_key_kind");
            }
            if public_blocks != 1 {
                return if public_blocks == 0 {
                    _json_error("no_public_key")
                } else {
                    _json_error("ambiguous_key")
                };
            }
            match SignedPublicKey::from_asc(armored) {
                Ok(public_key) => _public_key_metadata_json(public_key, expected_addr, "public"),
                Err(_) => _json_error("invalid_key"),
            }
        }
        AXICHAT_OPENPGP_KEY_KIND_PRIVATE => {
            if public_blocks > 0 && private_blocks == 0 {
                return _json_error("wrong_key_kind");
            }
            if private_blocks != 1 {
                return if private_blocks == 0 {
                    _json_error("no_private_key")
                } else {
                    _json_error("ambiguous_key")
                };
            }
            match SignedSecretKey::from_asc(armored).map(|key| key.signed_public_key()) {
                Ok(public_key) => _public_key_metadata_json(public_key, expected_addr, "private"),
                Err(_) => _json_error("invalid_key"),
            }
        }
        _ => _json_error("unsupported_key_kind"),
    }
}

fn _vcard_escape(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('\r', "")
        .replace('\n', "\\n")
        .replace(';', "\\;")
        .replace(',', "\\,")
}

fn _contact_public_key_import_json(
    context: &Context,
    address: &str,
    display_name: &str,
    armored: &str,
) -> String {
    let metadata = _inspect_openpgp_key_json(armored, address, AXICHAT_OPENPGP_KEY_KIND_PUBLIC);
    let Ok(parsed_metadata) = serde_json::from_str::<serde_json::Value>(&metadata) else {
        return _json_error("invalid_key");
    };
    if !parsed_metadata
        .get("ok")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
    {
        return metadata;
    }
    if !parsed_metadata
        .get("hasEncryptionCapability")
        .and_then(serde_json::Value::as_bool)
        .unwrap_or(false)
    {
        return _json_error("no_encryption_capability");
    }
    let public_key = match SignedPublicKey::from_asc(armored) {
        Ok(key) => key,
        Err(_) => return _json_error("invalid_key"),
    };
    let key_base64 = public_key.to_base64();
    let name = if display_name.trim().is_empty() {
        address
    } else {
        display_name.trim()
    };
    let vcard = format!(
        "BEGIN:VCARD\r\nVERSION:4.0\r\nFN:{}\r\nEMAIL:{}\r\nKEY:data:application/pgp-keys;base64\\,{}\r\nEND:VCARD\r\n",
        _vcard_escape(name),
        _vcard_escape(address),
        key_base64,
    );
    let import_result = _block_on(contact::import_vcard(context, &vcard));
    let contact_ids = match import_result {
        Ok(ids) => ids,
        Err(_) => return _json_error("import_failed"),
    };
    let Some(contact_id) = contact_ids.first().copied() else {
        return _json_error("import_failed");
    };
    let chat_id = match _block_on(ChatId::create_for_contact(context, contact_id)) {
        Ok(chat_id) => chat_id,
        Err(_) => return _json_error("import_failed"),
    };
    json!({
        "ok": true,
        "kind": "public",
        "fingerprint": public_key.dc_fingerprint().hex(),
        "userIds": _key_user_ids(&public_key),
        "hasExpectedAddress": parsed_metadata
            .get("hasExpectedAddress")
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false),
        "hasEncryptionCapability": true,
        "contactId": contact_id.to_u32(),
        "chatId": chat_id.to_u32(),
    })
    .to_string()
}

fn _normalized_match(left: &str, right: &str) -> bool {
    left.trim().eq_ignore_ascii_case(right.trim())
}

fn _contact_public_key_removal_json(
    context: &Context,
    address: &str,
    fingerprint: &str,
    contact_id: u32,
    chat_id: u32,
) -> String {
    if address.trim().is_empty() {
        return _json_error("missing_address");
    }
    if fingerprint.trim().is_empty() {
        return _json_error("missing_fingerprint");
    }
    if contact_id <= CONTACT_ID_LAST_SPECIAL {
        return _json_error("invalid_contact");
    }
    if chat_id <= DC_CHAT_ID_LAST_SPECIAL.to_u32() {
        return _json_error("invalid_chat");
    }

    let expected_fingerprint = fingerprint.trim().to_ascii_uppercase();
    _block_on(async move {
        let contact = match context
            .sql()
            .query_row_optional(
                "SELECT addr, fingerprint
                 FROM contacts
                 WHERE id=? AND id>?",
                (contact_id, CONTACT_ID_LAST_SPECIAL),
                |row| {
                    let addr: String = row.get(0)?;
                    let fingerprint: String = row.get(1)?;
                    Ok((addr, fingerprint))
                },
            )
            .await
        {
            Ok(contact) => contact,
            Err(_) => return _json_error("contact_lookup_failed"),
        };
        let Some((stored_address, stored_fingerprint)) = contact else {
            return _json_error("contact_not_found");
        };
        if stored_fingerprint.trim().is_empty() {
            return _json_error("contact_not_key_contact");
        }
        if !_normalized_match(&stored_address, address) {
            return _json_error("address_mismatch");
        }
        if !_normalized_match(&stored_fingerprint, &expected_fingerprint) {
            return _json_error("fingerprint_mismatch");
        }

        let chat_has_contact = match context
            .sql()
            .exists(
                "SELECT COUNT(*)
                 FROM chats_contacts
                 WHERE chat_id=? AND contact_id=?
                 AND add_timestamp>=remove_timestamp",
                (chat_id, contact_id),
            )
            .await
        {
            Ok(exists) => exists,
            Err(_) => return _json_error("chat_lookup_failed"),
        };
        if !chat_has_contact {
            return _json_error("chat_contact_mismatch");
        }

        let fallback_contact_id: Option<u32> = match context
            .sql()
            .query_get_value(
                "SELECT id
                 FROM contacts
                 WHERE addr=? COLLATE NOCASE
                 AND id>?
                 AND id<>?
                 AND origin>=?
                 AND fingerprint<>? COLLATE NOCASE
                 ORDER BY
                   (
                     SELECT COUNT(*)
                     FROM chats c
                     INNER JOIN chats_contacts cc
                     ON c.id=cc.chat_id
                     WHERE c.type=?
                     AND c.id>?
                     AND c.blocked=?
                     AND cc.contact_id=contacts.id
                     AND cc.add_timestamp>=cc.remove_timestamp
                   ) DESC,
                   last_seen DESC,
                   fingerprint DESC
                 LIMIT 1",
                (
                    address.trim(),
                    CONTACT_ID_LAST_SPECIAL,
                    contact_id,
                    Origin::IncomingReplyTo as u32,
                    expected_fingerprint.as_str(),
                    Chattype::Single,
                    DC_CHAT_ID_LAST_SPECIAL,
                    Blocked::Not,
                ),
            )
            .await
        {
            Ok(contact_id) => contact_id,
            Err(_) => return _json_error("fallback_lookup_failed"),
        };

        let mutation_result = if let Some(fallback_contact_id) = fallback_contact_id {
            let cleanup_fingerprint = expected_fingerprint.clone();
            let fallback_already_in_chat = match context
                .sql()
                .exists(
                    "SELECT COUNT(*)
                     FROM chats_contacts
                     WHERE chat_id=? AND contact_id=?",
                    (chat_id, fallback_contact_id),
                )
                .await
            {
                Ok(exists) => exists,
                Err(_) => return _json_error("fallback_chat_lookup_failed"),
            };
            context
                .sql()
                .transaction(move |transaction| {
                    if fallback_already_in_chat {
                        transaction.execute(
                            "UPDATE chats_contacts
                             SET add_timestamp=0, remove_timestamp=0
                             WHERE chat_id=? AND contact_id=?",
                            (chat_id, fallback_contact_id),
                        )?;
                        transaction.execute(
                            "DELETE FROM chats_contacts
                             WHERE chat_id=? AND contact_id=?",
                            (chat_id, contact_id),
                        )?;
                    } else {
                        transaction.execute(
                            "UPDATE chats_contacts
                             SET contact_id=?
                             WHERE chat_id=? AND contact_id=?",
                            (fallback_contact_id, chat_id, contact_id),
                        )?;
                    }
                    transaction.execute(
                        "UPDATE contacts
                         SET origin=?, fingerprint='', verifier=0
                         WHERE id=?",
                        (Origin::Hidden, contact_id),
                    )?;
                    transaction.execute(
                        "DELETE FROM public_keys
                         WHERE fingerprint=? COLLATE NOCASE
                         AND NOT EXISTS (
                           SELECT 1 FROM contacts WHERE fingerprint=? COLLATE NOCASE
                         )",
                        (cleanup_fingerprint.as_str(), cleanup_fingerprint.as_str()),
                    )?;
                    Ok(fallback_contact_id)
                })
                .await
        } else {
            let cleanup_fingerprint = expected_fingerprint.clone();
            context
                .sql()
                .transaction(move |transaction| {
                    transaction.execute(
                        "UPDATE contacts
                         SET fingerprint='', verifier=0
                         WHERE id=?",
                        (contact_id,),
                    )?;
                    transaction.execute(
                        "DELETE FROM public_keys
                         WHERE fingerprint=? COLLATE NOCASE
                         AND NOT EXISTS (
                           SELECT 1 FROM contacts WHERE fingerprint=? COLLATE NOCASE
                         )",
                        (cleanup_fingerprint.as_str(), cleanup_fingerprint.as_str()),
                    )?;
                    Ok(contact_id)
                })
                .await
        };

        let fallback_contact_id = match mutation_result {
            Ok(contact_id) => contact_id,
            Err(_) => return _json_error("update_failed"),
        };

        let pinned_key_still_active = match context
            .sql()
            .exists(
                "SELECT COUNT(*)
                 FROM chats_contacts cc
                 LEFT JOIN contacts c ON c.id=cc.contact_id
                 WHERE cc.chat_id=?
                 AND cc.add_timestamp>=cc.remove_timestamp
                 AND c.fingerprint=? COLLATE NOCASE",
                (chat_id, expected_fingerprint.as_str()),
            )
            .await
        {
            Ok(exists) => exists,
            Err(_) => return _json_error("verification_failed"),
        };
        if pinned_key_still_active {
            return _json_error("active_key_still_present");
        }

        let chat_has_active_contact = match context
            .sql()
            .exists(
                "SELECT COUNT(*)
                 FROM chats_contacts
                 WHERE chat_id=?
                 AND add_timestamp>=remove_timestamp",
                (chat_id,),
            )
            .await
        {
            Ok(exists) => exists,
            Err(_) => return _json_error("verification_failed"),
        };
        if !chat_has_active_contact {
            return _json_error("chat_without_active_contact");
        }

        context.emit_event(EventType::ContactsChanged(None));

        json!({
            "ok": true,
            "contactId": contact_id,
            "chatId": chat_id,
            "fallbackContactId": fallback_contact_id,
            "fingerprint": expected_fingerprint,
        })
        .to_string()
    })
}

#[no_mangle]
pub unsafe extern "C" fn dc_get_msg_mime_headers(
    context: *mut dc_context_t,
    msg_id: u32,
) -> *mut std::os::raw::c_char {
    if context.is_null() {
        return ptr::null_mut();
    }
    let ctx = &*context;
    let headers = match _read_stored_mime(ctx, MsgId::new(msg_id)) {
        Some(headers) => headers,
        None => return ptr::null_mut(),
    };
    _headers_to_c_string(&headers)
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_get_msg_rfc724_mid(
    context: *mut dc_context_t,
    msg_id: u32,
) -> *mut c_char {
    if context.is_null() {
        return ptr::null_mut();
    }
    let ctx = &*context;
    match _read_msg_rfc724_mid(ctx, MsgId::new(msg_id)) {
        Some(rfc724_mid) => _string_to_c(rfc724_mid),
        None => ptr::null_mut(),
    }
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_get_msg_ids_by_rfc724_mid(
    context: *mut dc_context_t,
    msg_id: u32,
) -> *mut c_char {
    if context.is_null() {
        return _string_to_c("[]".to_string());
    }
    let ctx = &*context;
    let ids = _read_msg_ids_by_rfc724_mid(ctx, MsgId::new(msg_id));
    _string_to_c(serde_json::to_string(&ids).unwrap_or_else(|_| "[]".to_string()))
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_get_msg_debug_info(
    context: *mut dc_context_t,
    msg_id: u32,
) -> *mut c_char {
    if context.is_null() {
        return _string_to_c(_json_error("missing_context"));
    }
    let ctx = &*context;
    _string_to_c(_read_msg_debug_info(ctx, MsgId::new(msg_id)))
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_get_msg_rfc822_body(
    context: *mut dc_context_t,
    msg_id: u32,
) -> *mut c_char {
    if context.is_null() || msg_id == 0 {
        return ptr::null_mut();
    }
    let ctx = &*(context as *mut Context);
    _string_to_c(_read_msg_rfc822_body_json(ctx, MsgId::new(msg_id)))
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_inspect_openpgp_key(
    armored: *const c_char,
    expected_addr: *const c_char,
    expected_kind: i32,
) -> *mut c_char {
    let Some(armored) = _c_string_arg(armored) else {
        return _string_to_c(_json_error("missing_key"));
    };
    let expected_addr = _c_string_arg(expected_addr).unwrap_or_default();
    _string_to_c(_inspect_openpgp_key_json(
        &armored,
        &expected_addr,
        expected_kind,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_import_contact_public_key(
    context: *mut dc_context_t,
    address: *const c_char,
    display_name: *const c_char,
    armored_public_key: *const c_char,
) -> *mut c_char {
    if context.is_null() {
        return _string_to_c(_json_error("missing_context"));
    }
    let Some(address) = _c_string_arg(address) else {
        return _string_to_c(_json_error("missing_address"));
    };
    let display_name = _c_string_arg(display_name).unwrap_or_default();
    let Some(armored_public_key) = _c_string_arg(armored_public_key) else {
        return _string_to_c(_json_error("missing_key"));
    };
    let ctx = &*context;
    _string_to_c(_contact_public_key_import_json(
        ctx,
        &address,
        &display_name,
        &armored_public_key,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_remove_contact_public_key(
    context: *mut dc_context_t,
    address: *const c_char,
    fingerprint: *const c_char,
    contact_id: u32,
    chat_id: u32,
) -> *mut c_char {
    if context.is_null() {
        return _string_to_c(_json_error("missing_context"));
    }
    let Some(address) = _c_string_arg(address) else {
        return _string_to_c(_json_error("missing_address"));
    };
    let Some(fingerprint) = _c_string_arg(fingerprint) else {
        return _string_to_c(_json_error("missing_fingerprint"));
    };
    let ctx = &*context;
    _string_to_c(_contact_public_key_removal_json(
        ctx,
        &address,
        &fingerprint,
        contact_id,
        chat_id,
    ))
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_accounts_background_fetch(
    accounts: *mut dc_accounts_t,
    timeout_seconds: u64,
) -> i32 {
    if accounts.is_null() || timeout_seconds <= 2 {
        eprintln!("ignoring careless call to axichat_dc_accounts_background_fetch()");
        return 0;
    }

    let accounts_key = accounts as usize;
    let Some(stop_signal) = _register_active_background_fetch(accounts_key) else {
        return 0;
    };
    let _active_fetch = _ActiveBackgroundFetchGuard {
        accounts: accounts_key,
    };

    {
        let accounts = &*accounts;
        let background_fetch = {
            let accounts = _block_on(accounts.read());
            accounts.background_fetch(Duration::from_secs(timeout_seconds))
        };
        _block_on(async {
            tokio::select! {
                _ = background_fetch => 1,
                _ = stop_signal.notified() => 0,
            }
        })
    }
}

#[no_mangle]
pub unsafe extern "C" fn axichat_dc_accounts_stop_background_fetch(
    accounts: *mut dc_accounts_t,
) -> i32 {
    if accounts.is_null() {
        eprintln!("ignoring careless call to axichat_dc_accounts_stop_background_fetch()");
        return 0;
    }
    if _stop_active_background_fetch(accounts as usize) {
        return 1;
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;
    use deltachat_core::context::ContextBuilder;
    use serde_json::Value;
    use std::path::PathBuf;

    fn unique_accounts_key() -> usize {
        static NEXT_KEY: LazyLock<Mutex<usize>> = LazyLock::new(|| Mutex::new(1000));
        let mut key = NEXT_KEY.lock().expect("test key registry poisoned");
        *key += 1;
        *key
    }

    fn unique_db_path(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "axichat-delta-ffi-{name}-{}-{}",
            std::process::id(),
            unique_accounts_key()
        ));
        std::fs::create_dir_all(&dir).expect("create test database directory");
        dir.join("db.sqlite")
    }

    fn decode_rfc822_body_json(raw: String) -> Value {
        serde_json::from_str(&raw).expect("valid RFC822 body JSON")
    }

    #[test]
    fn rfc822_body_parser_extracts_full_multipart_mime() {
        let raw_mime = br#"From: alice@example.org
To: bob@example.org
Subject: Multipart
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="outer"

--outer
Content-Type: multipart/alternative; boundary="alt"

--alt
Content-Type: text/plain; charset=utf-8

Plain body.

--alt
Content-Type: text/html; charset=utf-8

<html><body><p>HTML body.</p></body></html>

--alt--
--outer
Content-Type: text/plain
Content-Disposition: attachment; filename="notes.txt"

Attachment body.
--outer--
"#;

        let decoded = decode_rfc822_body_json(_rfc822_body_json_from_raw_mime(raw_mime));

        assert_eq!(decoded["ok"], true);
        assert_eq!(decoded["plainText"], "Plain body.");
        assert_eq!(
            decoded["htmlBody"],
            "<html><body><p>HTML body.</p></body></html>"
        );
    }

    #[test]
    fn rfc822_body_parser_reports_header_only_values() {
        let raw_mime = br#"From: alice@example.org
To: bob@example.org
Subject: Header only
MIME-Version: 1.0
"#;

        let decoded = decode_rfc822_body_json(_rfc822_body_json_from_raw_mime(raw_mime));

        assert_eq!(decoded["ok"], false);
        assert_eq!(decoded["reason"], "missing_body");
    }

    #[test]
    fn rfc822_body_parser_ignores_attached_message_rfc822_body() {
        let raw_mime = br#"From: alice@example.org
To: bob@example.org
Subject: Attached EML
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="outer"

--outer
Content-Type: message/rfc822
Content-Disposition: attachment; filename="forwarded.eml"

From: carol@example.org
To: dave@example.org
Subject: Nested
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8

Nested attachment body.

--outer--
"#;

        let decoded = decode_rfc822_body_json(_rfc822_body_json_from_raw_mime(raw_mime));

        assert_eq!(decoded["ok"], false);
        assert_eq!(decoded["reason"], "missing_body");
    }

    #[test]
    fn rfc822_body_reader_parses_delta_stored_mime_blob() {
        let db_path = unique_db_path("stored-mime");
        let db_dir = db_path
            .parent()
            .expect("test database path has a parent")
            .to_path_buf();
        let raw_mime = br#"From: alice@example.org
To: bob@example.org
Subject: Stored MIME
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="alt"

--alt
Content-Type: text/plain; charset=utf-8

Stored plain body.

--alt
Content-Type: text/html; charset=utf-8

<p>Stored HTML body.</p>

--alt--
"#;

        let context = _block_on(async {
            let context = ContextBuilder::new(db_path)
                .open()
                .await
                .expect("open test Delta context");
            context
                .sql()
                .execute(
                    "INSERT INTO msgs (
                        id, rfc724_mid, chat_id, from_id, to_id, timestamp,
                        timestamp_sent, timestamp_rcvd, type, state, msgrmsg,
                        txt, subject, mime_headers, mime_compressed
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        9001,
                        "stored-mime@example.org",
                        1,
                        1,
                        2,
                        1,
                        1,
                        1,
                        20,
                        10,
                        2,
                        "",
                        "Stored MIME",
                        raw_mime.as_slice(),
                        false,
                    ),
                )
                .await
                .expect("insert stored MIME message");
            context
        });
        let decoded =
            decode_rfc822_body_json(_read_msg_rfc822_body_json(&context, MsgId::new(9001)));
        drop(context);
        std::fs::remove_dir_all(db_dir).expect("remove test database directory");

        assert_eq!(decoded["ok"], true);
        assert_eq!(decoded["plainText"], "Stored plain body.");
        assert_eq!(decoded["htmlBody"], "<p>Stored HTML body.</p>");
    }

    #[test]
    fn duplicate_active_fetch_is_rejected() {
        let key = unique_accounts_key();
        let first = _register_active_background_fetch(key);
        assert!(first.is_some());
        let second = _register_active_background_fetch(key);
        assert!(second.is_none());
        _finish_active_background_fetch(key);
    }

    #[test]
    fn stop_signals_active_fetch_only() {
        let key = unique_accounts_key();
        let other_key = unique_accounts_key();
        let signal = _register_active_background_fetch(key).unwrap();

        assert!(_stop_active_background_fetch(key));
        assert!(!_stop_active_background_fetch(other_key));
        assert!(_block_on(async {
            tokio::time::timeout(Duration::from_millis(100), signal.notified())
                .await
                .is_ok()
        }));

        _finish_active_background_fetch(key);
    }

    #[test]
    fn stop_without_active_fetch_does_not_create_pending_stop() {
        let key = unique_accounts_key();

        assert!(!_stop_active_background_fetch(key));
        let signal = _register_active_background_fetch(key).unwrap();
        assert!(!_block_on(async {
            tokio::time::timeout(Duration::from_millis(10), signal.notified())
                .await
                .is_ok()
        }));

        _finish_active_background_fetch(key);
    }

    #[test]
    fn cleanup_removes_active_entry() {
        let key = unique_accounts_key();

        assert!(_register_active_background_fetch(key).is_some());
        _finish_active_background_fetch(key);
        assert!(_register_active_background_fetch(key).is_some());

        _finish_active_background_fetch(key);
    }
}
