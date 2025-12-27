#ifndef DELTACHAT_WRAPPER_H
#define DELTACHAT_WRAPPER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct dc_context dc_context_t;
typedef struct dc_event dc_event_t;
typedef struct dc_event_emitter dc_event_emitter_t;
typedef struct dc_accounts dc_accounts_t;
typedef struct dc_array dc_array_t;
typedef struct dc_chat dc_chat_t;
typedef struct dc_chatlist dc_chatlist_t;
typedef struct dc_contact dc_contact_t;
typedef struct dc_msg dc_msg_t;

#define DC_MSG_UNDEFINED 0
#define DC_MSG_TEXT 10
#define DC_MSG_IMAGE 20
#define DC_MSG_GIF 21
#define DC_MSG_STICKER 23
#define DC_MSG_AUDIO 40
#define DC_MSG_VOICE 41
#define DC_MSG_VIDEO 50
#define DC_MSG_FILE 60
#define DC_MSG_CALL 71
#define DC_MSG_WEBXDC 80
#define DC_MSG_VCARD 90

#define DC_INFO_UNKNOWN 0
#define DC_INFO_GROUP_NAME_CHANGED 2
#define DC_INFO_GROUP_IMAGE_CHANGED 3
#define DC_INFO_MEMBER_ADDED_TO_GROUP 4
#define DC_INFO_MEMBER_REMOVED_FROM_GROUP 5
#define DC_INFO_AUTOCRYPT_SETUP_MESSAGE 6
#define DC_INFO_SECURE_JOIN_MESSAGE 7
#define DC_INFO_LOCATIONSTREAMING_ENABLED 8
#define DC_INFO_LOCATION_ONLY 9
#define DC_INFO_EPHEMERAL_TIMER_CHANGED 10
#define DC_INFO_PROTECTION_ENABLED 11
#define DC_INFO_INVALID_UNENCRYPTED_MAIL 13
#define DC_INFO_WEBXDC_INFO_MESSAGE 32
#define DC_INFO_CHAT_E2EE 50

#define DC_STATE_UNDEFINED 0
#define DC_STATE_IN_FRESH 10
#define DC_STATE_IN_NOTICED 13
#define DC_STATE_IN_SEEN 16
#define DC_STATE_OUT_PREPARING 18
#define DC_STATE_OUT_DRAFT 19
#define DC_STATE_OUT_PENDING 20
#define DC_STATE_OUT_FAILED 24
#define DC_STATE_OUT_DELIVERED 26
#define DC_STATE_OUT_MDN_RCVD 28

#define DC_MSG_NO_ID 0
#define DC_MSG_ID_MARKER1 1
#define DC_MSG_ID_DAYMARKER 9

#define DC_VIDEOCHATTYPE_UNKNOWN 0
#define DC_VIDEOCHATTYPE_BASICWEBRTC 1

#define DC_CHAT_TYPE_UNDEFINED 0
#define DC_CHAT_TYPE_SINGLE 100
#define DC_CHAT_TYPE_GROUP 120
#define DC_CHAT_TYPE_MAILINGLIST 140
#define DC_CHAT_TYPE_OUT_BROADCAST 160
#define DC_CHAT_TYPE_IN_BROADCAST 165

#define DC_CHAT_NO_CHAT 0
#define DC_CHAT_ID_ARCHIVED_LINK 6
#define DC_CHAT_ID_ALLDONE_HINT 7
#define DC_CHAT_ID_LAST_SPECIAL 9

#define DC_CONTACT_ID_SELF 1
#define DC_CONTACT_ID_INFO 2
#define DC_CONTACT_ID_DEVICE 5
#define DC_CONTACT_ID_LAST_SPECIAL 9

#define DC_EVENT_INFO 100
#define DC_EVENT_WARNING 300
#define DC_EVENT_ERROR 400
#define DC_EVENT_ERROR_SELF_NOT_IN_GROUP 410
#define DC_EVENT_MSGS_CHANGED 2000
#define DC_EVENT_REACTIONS_CHANGED 2001
#define DC_EVENT_INCOMING_REACTION 2002
#define DC_EVENT_INCOMING_WEBXDC_NOTIFY 2003
#define DC_EVENT_MSGS_NOTICED 2008
#define DC_EVENT_INCOMING_MSG 2005
#define DC_EVENT_INCOMING_MSG_BUNCH 2006
#define DC_EVENT_MSG_DELIVERED 2010
#define DC_EVENT_MSG_FAILED 2012
#define DC_EVENT_MSG_READ 2015
#define DC_EVENT_CHAT_MODIFIED 2020
#define DC_EVENT_CHAT_EPHEMERAL_TIMER_MODIFIED 2021
#define DC_EVENT_CHAT_DELETED 2023
#define DC_EVENT_CONTACTS_CHANGED 2030
#define DC_EVENT_LOCATION_CHANGED 2035
#define DC_EVENT_CONFIGURE_PROGRESS 2041
#define DC_EVENT_IMEX_PROGRESS 2051
#define DC_EVENT_IMEX_FILE_WRITTEN 2052
#define DC_EVENT_SECUREJOIN_INVITER_PROGRESS 2060
#define DC_EVENT_SECUREJOIN_JOINER_PROGRESS 2061
#define DC_EVENT_CONNECTIVITY_CHANGED 2100
#define DC_EVENT_SELFAVATAR_CHANGED 2110
#define DC_EVENT_WEBXDC_STATUS_UPDATE 2120
#define DC_EVENT_WEBXDC_INSTANCE_DELETED 2121
#define DC_EVENT_WEBXDC_REALTIME_DATA 2150
#define DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE 2200
#define DC_EVENT_CHANNEL_OVERFLOW 2400
#define DC_EVENT_INCOMING_CALL 2550
#define DC_EVENT_INCOMING_CALL_ACCEPTED 2560
#define DC_EVENT_OUTGOING_CALL_ACCEPTED 2570
#define DC_EVENT_CALL_ENDED 2580

#define DC_IMEX_EXPORT_SELF_KEYS 1
#define DC_IMEX_IMPORT_SELF_KEYS 2
#define DC_IMEX_EXPORT_BACKUP 11
#define DC_IMEX_IMPORT_BACKUP 12

#define DC_GCM_ADDDAYMARKER 0x01

#define DC_QR_ASK_VERIFYCONTACT 200
#define DC_QR_ASK_VERIFYGROUP 202
#define DC_QR_ASK_JOIN_BROADCAST 204
#define DC_QR_FPR_OK 210
#define DC_QR_FPR_MISMATCH 220
#define DC_QR_FPR_WITHOUT_ADDR 230
#define DC_QR_ACCOUNT 250
#define DC_QR_BACKUP2 252
#define DC_QR_BACKUP_TOO_NEW 255
#define DC_QR_WEBRTC 260
#define DC_QR_PROXY 271
#define DC_QR_ADDR 320
#define DC_QR_TEXT 330
#define DC_QR_URL 332
#define DC_QR_ERROR 400
#define DC_QR_WITHDRAW_VERIFYCONTACT 500
#define DC_QR_WITHDRAW_VERIFYGROUP 502
#define DC_QR_WITHDRAW_JOINBROADCAST 504
#define DC_QR_REVIVE_VERIFYCONTACT 510
#define DC_QR_REVIVE_VERIFYGROUP 512
#define DC_QR_REVIVE_JOINBROADCAST 514
#define DC_QR_LOGIN 520

#define DC_SOCKET_AUTO 0
#define DC_SOCKET_SSL 1
#define DC_SOCKET_STARTTLS 2
#define DC_SOCKET_PLAIN 3

#define DC_SHOW_EMAILS_OFF 0
#define DC_SHOW_EMAILS_ACCEPTED_CONTACTS 1
#define DC_SHOW_EMAILS_ALL 2

#define DC_MEDIA_QUALITY_BALANCED 0
#define DC_MEDIA_QUALITY_WORSE 1

#define DC_CONNECTIVITY_NOT_CONNECTED 1000
#define DC_CONNECTIVITY_CONNECTING 2000
#define DC_CONNECTIVITY_WORKING 3000
#define DC_CONNECTIVITY_CONNECTED 4000

#define DC_DOWNLOAD_DONE 0
#define DC_DOWNLOAD_AVAILABLE 10
#define DC_DOWNLOAD_FAILURE 20
#define DC_DOWNLOAD_UNDECIPHERABLE 30
#define DC_DOWNLOAD_IN_PROGRESS 1000

#define DC_CHAT_VISIBILITY_NORMAL 0
#define DC_CHAT_VISIBILITY_ARCHIVED 1
#define DC_CHAT_VISIBILITY_PINNED 2

#define DC_GCL_VERIFIED_ONLY 0x1
#define DC_GCL_ADD_SELF 0x2
#define DC_GCL_ADDRESS 0x4
#define DC_GCL_ARCHIVED_ONLY 0x1
#define DC_GCL_NO_SPECIALS 0x2
#define DC_GCL_ADD_ALLDONE_HINT 0x4
#define DC_GCL_FOR_FORWARDING 0x8

dc_accounts_t* dc_accounts_new(const char* dir, int32_t writable);
void dc_accounts_unref(dc_accounts_t* accounts);
uint32_t dc_accounts_add_account(dc_accounts_t* accounts);
uint32_t dc_accounts_add_closed_account(dc_accounts_t* accounts);
uint32_t dc_accounts_migrate_account(dc_accounts_t* accounts, const char* dbfile);
int32_t dc_accounts_remove_account(dc_accounts_t* accounts, uint32_t account_id);
dc_array_t* dc_accounts_get_all(dc_accounts_t* accounts);
dc_context_t* dc_accounts_get_account(dc_accounts_t* accounts, uint32_t account_id);
void dc_accounts_start_io(dc_accounts_t* accounts);
void dc_accounts_stop_io(dc_accounts_t* accounts);
void dc_accounts_maybe_network(dc_accounts_t* accounts);
void dc_accounts_maybe_network_lost(dc_accounts_t* accounts);
int dc_accounts_background_fetch(dc_accounts_t* accounts, uint64_t timeout);
void dc_accounts_set_push_device_token(
    dc_accounts_t* accounts,
    const char* token);
dc_event_emitter_t* dc_accounts_get_event_emitter(dc_accounts_t* accounts);

dc_context_t* dc_context_new(const char* os_name, const char* dbfile, const char* blobdir);
dc_context_t* dc_context_new_closed(const char* dbfile);
void dc_context_unref(dc_context_t* ctx);
int32_t dc_context_open(dc_context_t* ctx, const char* passphrase);
int32_t dc_context_change_passphrase(dc_context_t* ctx, const char* passphrase);
int32_t dc_context_is_open(dc_context_t* ctx);
int32_t dc_is_configured(dc_context_t* ctx);
void dc_configure(dc_context_t* ctx);
int32_t dc_set_config(dc_context_t* ctx, const char* key, const char* value);
void dc_start_io(dc_context_t* ctx);
void dc_stop_io(dc_context_t* ctx);
void dc_maybe_network(dc_context_t* ctx);
int32_t dc_get_connectivity(dc_context_t* ctx);
char* dc_get_last_error(dc_context_t* ctx);

dc_chatlist_t* dc_get_chatlist(dc_context_t* ctx, int flags, const char* query_str, uint32_t query_id);
void dc_chatlist_unref(dc_chatlist_t* chatlist);
size_t dc_chatlist_get_cnt(const dc_chatlist_t* chatlist);
uint32_t dc_chatlist_get_chat_id(const dc_chatlist_t* chatlist, size_t index);
uint32_t dc_chatlist_get_msg_id(const dc_chatlist_t* chatlist, size_t index);
dc_array_t* dc_get_chat_msgs(dc_context_t* ctx, uint32_t chat_id, uint32_t flags, uint32_t marker1before);
int dc_get_msg_cnt(dc_context_t* ctx, uint32_t chat_id);

dc_event_emitter_t* dc_get_event_emitter(dc_context_t* ctx);
void dc_event_emitter_unref(dc_event_emitter_t* emitter);
dc_event_t* dc_get_next_event(dc_event_emitter_t* emitter);
void dc_event_unref(dc_event_t* event);
int32_t dc_event_get_id(dc_event_t* event);
int32_t dc_event_get_data1_int(dc_event_t* event);
int32_t dc_event_get_data2_int(dc_event_t* event);
char* dc_event_get_data1_str(dc_event_t* event);
char* dc_event_get_data2_str(dc_event_t* event);
uint32_t dc_event_get_account_id(dc_event_t* event);

void dc_str_unref(char* value);

void dc_array_unref(dc_array_t* array);
int32_t dc_array_get_cnt(const dc_array_t* array);
uint32_t dc_array_get_id(const dc_array_t* array, int32_t index);

uint32_t dc_create_contact(dc_context_t* ctx, const char* name, const char* addr);
uint32_t dc_create_chat_by_contact_id(dc_context_t* ctx, uint32_t contact_id);
uint32_t dc_send_text_msg(dc_context_t* ctx, uint32_t chat_id, const char* text);
uint32_t dc_send_msg(dc_context_t* ctx, uint32_t chat_id, dc_msg_t* msg);

dc_chat_t* dc_get_chat(dc_context_t* ctx, uint32_t chat_id);
void dc_chat_unref(dc_chat_t* chat);
char* dc_chat_get_name(dc_chat_t* chat);
char* dc_chat_get_mailinglist_addr(dc_chat_t* chat);
int32_t dc_chat_get_type(const dc_chat_t* chat);
uint32_t dc_chat_get_contact_id(const dc_chat_t* chat);
dc_array_t* dc_get_chat_contacts(dc_context_t* ctx, uint32_t chat_id);

dc_contact_t* dc_get_contact(dc_context_t* ctx, uint32_t contact_id);
void dc_contact_unref(dc_contact_t* contact);
char* dc_contact_get_addr(const dc_contact_t* contact);
char* dc_contact_get_name(const dc_contact_t* contact);
int32_t dc_block_contact(dc_context_t* ctx, uint32_t contact_id);
int32_t dc_unblock_contact(dc_context_t* ctx, uint32_t contact_id);
uint32_t dc_lookup_contact_id_by_addr(dc_context_t* ctx, const char* addr);

dc_msg_t* dc_get_msg(dc_context_t* ctx, uint32_t msg_id);
void dc_msg_unref(dc_msg_t* msg);
char* dc_msg_get_text(dc_msg_t* msg);
char* dc_msg_get_html(dc_msg_t* msg);
char* dc_msg_get_subject(const dc_msg_t* msg);
uint32_t dc_msg_get_chat_id(dc_msg_t* msg);
uint32_t dc_msg_get_id(dc_msg_t* msg);
int32_t dc_msg_get_viewtype(const dc_msg_t* msg);
uint64_t dc_msg_get_timestamp(const dc_msg_t* msg);
int32_t dc_msg_is_outgoing(const dc_msg_t* msg);
int32_t dc_msg_get_state(const dc_msg_t* msg);
dc_msg_t* dc_msg_new(dc_context_t* ctx, int32_t viewtype);
void dc_msg_set_text(dc_msg_t* msg, const char* text);
void dc_msg_set_html(dc_msg_t* msg, const char* html);
void dc_msg_set_subject(dc_msg_t* msg, const char* subject);
void dc_msg_set_file_and_deduplicate(dc_msg_t* msg, const char* file, const char* name, const char* filemime);
char* dc_msg_get_file(const dc_msg_t* msg);
char* dc_msg_get_filename(const dc_msg_t* msg);
char* dc_msg_get_filemime(const dc_msg_t* msg);
uint64_t dc_msg_get_filebytes(const dc_msg_t* msg);
int32_t dc_msg_get_width(const dc_msg_t* msg);
int32_t dc_msg_get_height(const dc_msg_t* msg);

dc_array_t* dc_get_fresh_msgs(dc_context_t* ctx);
int dc_get_fresh_msg_cnt(dc_context_t* ctx, uint32_t chat_id);
void dc_marknoticed_chat(dc_context_t* ctx, uint32_t chat_id);

void dc_markseen_msgs(dc_context_t* ctx, const uint32_t* msg_ids, int msg_cnt);
void dc_delete_msgs(dc_context_t* ctx, const uint32_t* msg_ids, int msg_cnt);

void dc_msg_set_quote(dc_msg_t* msg, const dc_msg_t* quote);
dc_msg_t* dc_msg_get_quoted_msg(const dc_msg_t* msg);
char* dc_msg_get_quoted_text(const dc_msg_t* msg);

void dc_forward_msgs(dc_context_t* ctx, const uint32_t* msg_ids, int msg_cnt, uint32_t chat_id);

void dc_set_draft(dc_context_t* ctx, uint32_t chat_id, dc_msg_t* msg);
dc_msg_t* dc_get_draft(dc_context_t* ctx, uint32_t chat_id);

dc_array_t* dc_search_msgs(dc_context_t* ctx, uint32_t chat_id, const char* query);

void dc_set_chat_visibility(dc_context_t* ctx, uint32_t chat_id, int visibility);

void dc_download_full_msg(dc_context_t* ctx, int msg_id);
int dc_msg_get_download_state(const dc_msg_t* msg);

int dc_resend_msgs(dc_context_t* ctx, const uint32_t* msg_ids, int msg_cnt);
char* dc_msg_get_error(const dc_msg_t* msg);

dc_array_t* dc_get_contacts(dc_context_t* ctx, uint32_t flags, const char* query);
dc_array_t* dc_get_blocked_contacts(dc_context_t* ctx);
int dc_delete_contact(dc_context_t* ctx, uint32_t contact_id);

#ifdef __cplusplus
}
#endif

#endif  // DELTACHAT_WRAPPER_H
