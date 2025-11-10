Email‑Backed Chat for Flutter via Delta Chat Core (Rust) + Dart FFI (Build Hooks / Code Assets)

Goal: Add an email-backed transport to your existing Flutter chat app using the Delta Chat Core (
Rust) engine through Dart FFI. Package and ship the native library with Dart build hooks & code
assets, and auto‑provision a Chatmail account silently when users register a profile.

Why this approach

Delta Chat Core exposes a stable C API we can bind to from Dart. It handles IMAP/SMTP, Autocrypt,
groups, attachments, and an event system.
c.delta.chat
+2
c.delta.chat
+2

Build hooks + code assets (formerly “native assets”) let Dart/Flutter build and bundle native
libraries portably; lookup is handled by annotations like @Native and DefaultAsset.
Dart
+2
Dart
+2

Chatmail relays allow “first‑login‑creates‑account” provisioning for frictionless onboarding (e.g.,
nine.testrun.org) so you can make an account behind the scenes.
Delta.Chat
+1

Table of contents

Scope & success criteria

Architecture overview

Repo layout & packages

Toolchain & environment

Native build: hooks + code assets

FFI bindings (ffigen)

Safe Dart wrappers + event isolate

Data model mapping & DB migrations

Transport adapter integration

Silent Chatmail provisioning flow

Backgrounding & notifications

Security & secrets

Testing strategy

CI/CD & release

Rollout plan & milestones

Risk register / watchlist

Appendix: reference snippets

1) Scope & success criteria

In scope

Keep current Flutter UI/domain. Add EmailTransport implemented atop Delta Core via FFI.

Mirror Delta Core data into your existing DB (idempotent upserts).

On user profile creation, silently create a Chatmail account and start syncing.

Basic feature set: sign‑in, send/receive text, attachments, groups, delivery/read updates.

Done when

A new user can create a chat profile → Chatmail is provisioned silently → messages send/receive in
your existing UI → state persists across restarts → basic background fetch works per‑OS constraints.

2) Architecture overview