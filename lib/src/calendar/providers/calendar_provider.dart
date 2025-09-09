import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../xmpp/xmpp_service.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../models/calendar_model.dart';
import '../sync/calendar_sync_manager.dart';

/// Provides calendar-related dependencies for logged-in users
class CalendarProvider extends StatefulWidget {
  final Widget child;

  const CalendarProvider({
    super.key,
    required this.child,
  });

  @override
  State<CalendarProvider> createState() => _CalendarProviderState();
}

class _CalendarProviderState extends State<CalendarProvider> {
  Box<CalendarModel>? _calendarBox;
  CalendarSyncManager? _syncManager;
  CalendarBloc? _calendarBloc;

  @override
  void initState() {
    super.initState();
    _initializeCalendar();
  }

  Future<void> _initializeCalendar() async {
    try {
      // Get the calendar box (it was opened in buildStateStore)
      if (Hive.isBoxOpen('calendar')) {
        _calendarBox = Hive.box<CalendarModel>('calendar');

        if (_calendarBox != null && mounted) {
          // Create sync manager
          _syncManager = CalendarSyncManager(
            calendarBox: _calendarBox!,
            sendCalendarMessage: (message) async {
              final xmppService = context.read<XmppService>();
              if (xmppService.myJid != null) {
                await xmppService.sendMessage(
                  jid: xmppService.myJid!,
                  text: message,
                );
              }
            },
          );

          // Register sync callback with XmppService
          final xmppService = context.read<XmppService>();
          xmppService.setCalendarSyncCallback(_syncManager!.onCalendarMessage);

          // Create CalendarBloc
          _calendarBloc = CalendarBloc(
            calendarBox: _calendarBox!,
            syncManager: _syncManager!,
          )..add(const CalendarStarted());

          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize calendar: $e');
    }
  }

  @override
  void dispose() {
    _calendarBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_calendarBox == null || _syncManager == null || _calendarBloc == null) {
      return widget.child;
    }

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<Box<CalendarModel>>.value(value: _calendarBox!),
        RepositoryProvider<CalendarSyncManager>.value(value: _syncManager!),
      ],
      child: BlocProvider.value(
        value: _calendarBloc!,
        child: widget.child,
      ),
    );
  }
}
