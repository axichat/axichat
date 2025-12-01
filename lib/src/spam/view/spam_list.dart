import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/chats_list.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/home/home_search_definitions.dart';
import 'package:axichat/src/home/home_search_models.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SpamList extends StatelessWidget {
  const SpamList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filters = spamSearchFilters(l10n);
    return BlocSelector<ChatsCubit, ChatsState, List<Chat>?>(
      selector: (state) {
        final items = state.items;
        if (items == null) return null;
        return items.where((chat) => chat.spam).toList();
      },
      builder: (context, items) {
        if (items == null) {
          return Center(
            child: AxiProgressIndicator(
              color: context.colorScheme.foreground,
            ),
          );
        }

        return BlocBuilder<HomeSearchCubit, HomeSearchState>(
          builder: (context, searchState) => _SpamListBody(
            items: items,
            filters: filters,
            l10n: l10n,
            searchState: searchState,
          ),
        );
      },
    );
  }
}

class _SpamListBody extends StatelessWidget {
  const _SpamListBody({
    required this.items,
    required this.filters,
    required this.l10n,
    this.searchState,
  });

  final List<Chat> items;
  final List<HomeSearchFilter> filters;
  final AppLocalizations l10n;
  final HomeSearchState? searchState;

  @override
  Widget build(BuildContext context) {
    final tabState = searchState?.stateFor(HomeTab.spam);
    final searchActive = searchState?.active ?? false;
    final query =
        searchActive ? (tabState?.query.trim().toLowerCase() ?? '') : '';
    final filterId = tabState?.filterId ?? filters.first.id;
    final sortOrder = tabState?.sort ?? SearchSortOrder.newestFirst;

    var visibleItems = List<Chat>.from(items);

    visibleItems = visibleItems
        .where((chat) => _spamFilterMatches(chat, filterId))
        .toList();

    if (query.isNotEmpty) {
      visibleItems =
          visibleItems.where((chat) => _chatMatchesQuery(chat, query)).toList();
    }

    visibleItems.sort(
      (a, b) => sortOrder.isNewestFirst
          ? b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp)
          : a.lastChangeTimestamp.compareTo(b.lastChangeTimestamp),
    );

    if (visibleItems.isEmpty) {
      return Center(
        child: Text(
          l10n.spamEmpty,
          style: context.textTheme.muted,
        ),
      );
    }

    return ColoredBox(
      color: context.colorScheme.background,
      child: ListView.builder(
        itemCount: visibleItems.length,
        itemBuilder: (context, index) {
          final chat = visibleItems[index];
          return ListItemPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChatListTile(item: chat),
                Align(
                  alignment: Alignment.centerRight,
                  child: ShadButton.secondary(
                    size: ShadButtonSize.sm,
                    onPressed: () => _moveToInbox(context, chat),
                    child: Text(l10n.spamMoveToInbox),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

bool _spamFilterMatches(Chat chat, String filterId) {
  switch (filterId) {
    case 'email':
      return chat.transport.isEmail;
    case 'xmpp':
      return chat.transport.isXmpp;
    default:
      return true;
  }
}

bool _chatMatchesQuery(Chat chat, String query) {
  if (query.isEmpty) return true;
  final lower = query.toLowerCase();
  return chat.title.toLowerCase().contains(lower) ||
      chat.jid.toLowerCase().contains(lower);
}

Future<void> _moveToInbox(BuildContext context, Chat chat) async {
  final l10n = context.l10n;
  final xmppService = context.read<XmppService?>();
  final emailService = RepositoryProvider.of<EmailService?>(context);
  final toaster = ShadToaster.maybeOf(context);
  await xmppService?.toggleChatSpam(jid: chat.jid, spam: false);
  final address = chat.emailAddress?.trim();
  if (chat.transport.isEmail && address?.isNotEmpty == true) {
    await emailService?.spam.unmark(address!);
  }
  toaster?.show(
    FeedbackToast.success(
      title: l10n.spamMoveToastTitle,
      message: l10n.spamMoveToastMessage(chat.title),
    ),
  );
}
