-- Drift schema v3: add Delta Chat foreign keys
ALTER TABLE messages ADD COLUMN delta_chat_id INTEGER;
ALTER TABLE messages ADD COLUMN delta_msg_id INTEGER;
ALTER TABLE chats ADD COLUMN delta_chat_id INTEGER;
ALTER TABLE chats ADD COLUMN email_address TEXT;
