# Working Notes for lib/src (baseline + key screens)

## Overall assumptions
- Modular Flutter app centered on combining XMPP chat and SMTP; features live under `lib/src/<feature>` with blocs/services per feature. Routing generated via `routes.dart`/`routes.g.dart`.
- Storage relies on Drift/SQLCipher/Hive through `storage/database.dart` and `storage/models.dart` (build_runner required after schema edits). Credential/state stores use secure storage + Hive (`CredentialStore`, `XmppStateStore`).
- Shared UI/theme exports come from `common/ui/ui.dart` and `app.dart`; ShadCN theme + Material mapping are set in `app.dart`.

## Important instructions
- The entire app should be using the same design tokens, spacing, sizing, shape, color (which can be dynamically set through `SettingsCubit` which sits above the app theme in the tree).
- Any UI constants that are inherited through `BuildContext` should be accesses through extension in `app.dart`. Other UI constants should be exported through `common/ui/ui.dart`. Any violations of this rule MUST be rectified.
- You MUST follow `BLOC_GUIDE.md` and BLoC best practices when creating and injecting BLoCs. Each BLoC should only be instantiated ONE time through a closure inside the widget tree. NEVER create duplicate instances of a BLoC
- If you need to pass it to a new tree with a different `BuildContext`, do it the same was as with `ProfileScreen`:
```dart
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.locate});

  final T Function<T>() locate;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: locate<Capability>(),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(
            value: locate<ProfileCubit>(),
          ),
          BlocProvider.value(
            value: locate<ConnectivityCubit>(),
          ),
          BlocProvider.value(
            value: locate<SettingsCubit>(),
          ),
          BlocProvider.value(
            value: locate<AuthenticationCubit>(),
          ),
        ],
        child: _ProfileBody(locate: locate),
      ),
    );
  }
}
```
otherwise, NEVER use `.value()` constructors for BLoCs or repositories.
- ALWAYS access BLoC state through `BlocBuilder`/`BlocListener`/`BlocConsumer`, if you need to call a BLoC function, ALWAYS do it through `context.read()` or `context.watch()`. 

## File-by-file notes
- `app.dart`: App composition. Registers repositories (XmppService, NotificationService, Capability/Policy, CredentialStore, EmailService, CalendarReminderController) and blocs (SettingsCubit, AuthenticationCubit, ShareIntentCubit, optional GuestCalendarBloc). Builds GoRouter with auth-aware redirects, Shad/Material themes, desktop menu/shortcut bindings (Compose/Search/Calendar), and share-intent handler that routes to Compose. Exposes context extensions for theme tokens.
- `home_screen.dart`: Authenticated shell. Builds tabs based on XmppService mixins (Chats/Drafts/Spam/Blocked). Nexus layout: connectivity banner, search panel (HomeSearchCubit), tab views, optional secondary pane (chat or calendar) driven by ChatsCubit state, FABs for chat filter/drafts/blocklist. Provides blocs for ChatsCubit, DraftCubit, ProfileCubit, BlocklistCubit, CalendarBloc (with CalendarSyncManager wiring + callbacks to XmppService), ConnectivityCubit. Includes navigation rail/bottom tabs, selection action bar, search UI with filters/sort, and keyboard shortcuts actions.
