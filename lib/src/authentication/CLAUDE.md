# Authentication Module - Strategic Architecture

## Core Responsibilities

The `AuthenticationCubit` is the central orchestrator for all authentication operations in Axichat:
- User login/logout lifecycle with XMPP connection management
- Secure credential persistence via `CredentialStore`
- Database encryption setup with per-user isolation
- App lifecycle integration for seamless user experience

## App Lifecycle Integration Strategy

**Critical Design Decision**: The cubit uses `AppLifecycleListener` for automatic connection management:
- Auto-login on app resume/show/restart (if credentials stored)
- Auto-logout on app detachment to prevent resource leaks
- Notification deep-linking when `launchedFromNotification` is true
- Foreground service integration via `withForeground` flag

This ensures users don't manually reconnect after app suspension while maintaining security.

## Database Security Architecture

**Per-User Database Isolation**: Each user gets a unique 8-character database prefix and separate passphrase for SQLCipher encryption. This prevents data leakage between different user accounts on the same device.

Storage pattern:
- `${jid}_database_prefix` → unique prefix per user
- `${databasePrefix}_database_passphrase` → encryption key per database

## Password Security Flow

**SCRAM-SHA Hashing Strategy**: 
1. Plain password sent to XMPP server for authentication
2. Server returns SCRAM-SHA hashed version
3. **Only hashed version stored locally** (never plaintext)
4. Subsequent logins use `preHashed = true` flag
5. Database credentials always persisted (required), user credentials only if `rememberMe = true`

## Common Pitfalls to Avoid

1. **Don't call login() with partial credentials** - Either provide both username/password or neither
2. **Don't store plain passwords** - Always use the hashed version returned from connect()
3. **Don't forget lifecycle cleanup** - AppLifecycleListener handles most cases automatically
4. **Don't assume immediate state changes** - All operations are async with proper error handling