## Axichat

### The Center of Decentralization

Download the [latest version](https://github.com/axichat/axichat/releases/latest)

<p float="left">
  <img src="/metadata/en-US/images/phoneScreenshots/1-unread_chats_white.png" width="49%"  alt="Chats page"/>
  <img src="/metadata/en-US/images/phoneScreenshots/4-open_chat_dark.png" width="49%"  alt="Message page"/>
</p>

Take control of your communication with the only XMPP-based instant messenger that:

- Has 1st party custom push notifications. NO FIREBASE, NO GOOGLE seeing your message data/metadata
- Works on android, windows and linux (iOS, macOS coming)
- Doesn't require expertise in XMPP
- Looks good

### Multi-recipient fan-out

- Composer chips let you opt-in any combination of 1:1 chats for a given send. Chips indicate encryption state (lock badge) and per-recipient delivery status.
- A Direct/All toggle in every 1:1 filters the timeline (`Direct` hides multi-recipient threads, `All` shows them) and the choice is stored per chat.
- Fan-out sends reuse a single `share_id` (ULID) for all copies, record share participants, and surface cross-recipient banners inside bubbles ("Also sent to …").
- Subject tokens (e.g., `[s:01HX5R8W7YAYR5K1R7Q7MB5G4W]`) are injected automatically to improve reply correlation. Builders can disable tokens per send by passing `useSubjectToken: false` to `EmailService.fanOutSend`.
- A soft cap of 20 recipients per fan-out (`_maxFanOutRecipients` in `email_service.dart`) prevents accidental blasts; exceeding the limit throws `FanOutValidationException`.
- Current limitation: Delta Chat does not expose raw email headers, so replies can only be correlated via subject tokens. Clients that strip the token fall back to Direct view.
- Dev note: schema v6 adds `message_shares`, `message_participants`, and `message_copies`; run `dart run build_runner build --delete-conflicting-outputs` after pulling and before running `flutter test`/`flutter analyze` to keep Drift output current.
