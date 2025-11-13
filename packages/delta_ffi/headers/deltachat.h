#ifndef DELTACHAT_WRAPPER_H
#define DELTACHAT_WRAPPER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct dc_context dc_context_t;
typedef struct dc_event dc_event_t;
typedef struct dc_event_emitter dc_event_emitter_t;
typedef struct dc_chat dc_chat_t;
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

dc_event_emitter_t* dc_get_event_emitter(dc_context_t* ctx);
void dc_event_emitter_unref(dc_event_emitter_t* emitter);
dc_event_t* dc_get_next_event(dc_event_emitter_t* emitter);
void dc_event_unref(dc_event_t* event);
int32_t dc_event_get_id(dc_event_t* event);
int32_t dc_event_get_data1_int(dc_event_t* event);
int32_t dc_event_get_data2_int(dc_event_t* event);
char* dc_event_get_data1_str(dc_event_t* event);
char* dc_event_get_data2_str(dc_event_t* event);

void dc_str_unref(char* value);

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

dc_contact_t* dc_get_contact(dc_context_t* ctx, uint32_t contact_id);
void dc_contact_unref(dc_contact_t* contact);
char* dc_contact_get_addr(const dc_contact_t* contact);
char* dc_contact_get_name(const dc_contact_t* contact);

dc_msg_t* dc_get_msg(dc_context_t* ctx, uint32_t msg_id);
void dc_msg_unref(dc_msg_t* msg);
char* dc_msg_get_text(dc_msg_t* msg);
uint32_t dc_msg_get_chat_id(dc_msg_t* msg);
uint32_t dc_msg_get_id(dc_msg_t* msg);
int32_t dc_msg_get_viewtype(const dc_msg_t* msg);
uint64_t dc_msg_get_timestamp(const dc_msg_t* msg);
int32_t dc_msg_is_outgoing(const dc_msg_t* msg);
dc_msg_t* dc_msg_new(dc_context_t* ctx, int32_t viewtype);
void dc_msg_set_text(dc_msg_t* msg, const char* text);
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
