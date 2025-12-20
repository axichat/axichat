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

#define DC_MSG_TEXT 10
#define DC_MSG_IMAGE 20
#define DC_MSG_GIF 21
#define DC_MSG_AUDIO 40
#define DC_MSG_VOICE 41
#define DC_MSG_VIDEO 50
#define DC_MSG_FILE 60

#define DC_CHAT_TYPE_UNDEFINED 0
#define DC_CHAT_TYPE_SINGLE 100
#define DC_CHAT_TYPE_GROUP 200
#define DC_CHAT_TYPE_VERIFIED_GROUP 300
#define DC_CHAT_TYPE_BROADCAST 400

#define DC_EVENT_ERROR 400
#define DC_EVENT_ERROR_SELF_NOT_IN_GROUP 410
#define DC_EVENT_CONFIGURE_PROGRESS 2041
#define DC_EVENT_INCOMING_MSG_BUNCH 2006
#define DC_EVENT_ACCOUNTS_BACKGROUND_FETCH_DONE 2200
#define DC_EVENT_CONNECTIVITY_CHANGED 2100
#define DC_EVENT_CHANNEL_OVERFLOW 2400

#define DC_CONNECTIVITY_NOT_CONNECTED 1000
#define DC_CONNECTIVITY_CONNECTING 2000
#define DC_CONNECTIVITY_WORKING 3000
#define DC_CONNECTIVITY_CONNECTED 4000

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
void dc_msg_set_subject(dc_msg_t* msg, const char* subject);
void dc_msg_set_file_and_deduplicate(dc_msg_t* msg, const char* file, const char* name, const char* filemime);
char* dc_msg_get_file(const dc_msg_t* msg);
char* dc_msg_get_filename(const dc_msg_t* msg);
char* dc_msg_get_filemime(const dc_msg_t* msg);
uint64_t dc_msg_get_filebytes(const dc_msg_t* msg);
int32_t dc_msg_get_width(const dc_msg_t* msg);
int32_t dc_msg_get_height(const dc_msg_t* msg);

#ifdef __cplusplus
}
#endif

#endif  // DELTACHAT_WRAPPER_H
