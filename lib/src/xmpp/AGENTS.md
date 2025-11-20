# XMPP Service Module

- Basically a wrapper around moxxmpp for better architecture, just like how our Email service is just a wrapper around DeltaChat Core Rust to make it work in this app.

## Service Architecture

- **Modularity** EVERY feature, especially ones that are actual XEPs, should be completely removable from the app with no consequences. This is necessary so the user can decide whether they want to use each service. For example, they may not want to have Delivery Receipts or Message Archive Management, so if ANYTHING is removed EVERYTHING should continue to work; nothing in the service layer, storage layer, bloc layer, or UI layer should break if a feature is disabled. This is PARAMOUNT.
- **Mixin Composition**: Mixins ensure single responsibility and separation of concerns
- **Extensibility**: It should be easy to replicate
- **Error Recovery**: Exceptions should not crash the app, rather revert it to a state where the
  user can reattempt the failed action
- **Resource Management**: The user may logout without closing the app, so all resources and
  connections established during connection must be manually reversed

## Foreground Service

- Uses https://pub.dev/packages/flutter_foreground_task plugin
- Only if user opts in
- Starts the Xmpp connection socket within the native foreground process
- Converts function calls and returns into String primitives so they can be passed between the
  XmppConnection and the XmppService
