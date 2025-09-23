import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart' show Storage;

import '../../calendar/guest/guest_calendar_widget.dart' as legacy_guest;
import '../../calendar/view/calendar_widget.dart' as legacy_auth;
import '../bloc/auth_calendar_bloc.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/guest_calendar_bloc.dart';
import '../config/calendar_config.dart';
import '../storage/guest_calendar_storage.dart';
import '../view/calendar_widget.dart';
import '../view/guest_calendar_widget.dart';

class CalendarFactory {
  CalendarFactory({required CalendarConfig config}) : _config = config;

  final CalendarConfig _config;

  bool get useNewCalendar => _config.useNewCalendar;

  Widget buildGuestCalendar() {
    if (!useNewCalendar) {
      return const legacy_guest.GuestCalendarWidget();
    }
    return const _GuestCalendarLoader();
  }

  Widget buildAuthCalendar({
    required Future<Storage> Function() storageBuilder,
  }) {
    if (!useNewCalendar) {
      return const legacy_auth.CalendarWidget();
    }
    return _AuthCalendarLoader(storageBuilder: storageBuilder);
  }
}

class _GuestCalendarLoader extends StatefulWidget {
  const _GuestCalendarLoader();

  @override
  State<_GuestCalendarLoader> createState() => _GuestCalendarLoaderState();
}

class _GuestCalendarLoaderState extends State<_GuestCalendarLoader> {
  late final Future<Storage> _storageFuture;
  GuestCalendarBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _storageFuture = buildGuestCalendarStorage();
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Storage>(
      future: _storageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Unable to load calendar'));
        }
        final storage = snapshot.data!;
        _bloc ??= GuestCalendarBloc(storage: storage)
          ..add(const CalendarEvent.started());
        return BlocProvider<CalendarBloc>.value(
          value: _bloc!,
          child: const GuestCalendarWidget(),
        );
      },
    );
  }
}

class _AuthCalendarLoader extends StatefulWidget {
  const _AuthCalendarLoader({required this.storageBuilder});

  final Future<Storage> Function() storageBuilder;

  @override
  State<_AuthCalendarLoader> createState() => _AuthCalendarLoaderState();
}

class _AuthCalendarLoaderState extends State<_AuthCalendarLoader> {
  late final Future<Storage> _storageFuture;
  AuthCalendarBloc? _bloc;

  @override
  void initState() {
    super.initState();
    _storageFuture = widget.storageBuilder();
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Storage>(
      future: _storageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return const Center(child: Text('Unable to load calendar'));
        }
        final storage = snapshot.data!;
        _bloc ??= AuthCalendarBloc(storage: storage)
          ..add(const CalendarEvent.started());
        return BlocProvider<CalendarBloc>.value(
          value: _bloc!,
          child: const CalendarWidget(),
        );
      },
    );
  }
}
