# XMPP Service Module

## Service Architecture

- **Mixin Composition**: Mixins ensure single responsibility and separation of concerns
- **Modularity**: Mixins should be totally independent. Removing one should not break any other
  features, but remove its own feature entirely from the app
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
