// ignore_for_file: implementation_imports, non_constant_identifier_names

import 'dart:async';
import 'dart:ffi' as ffi;

import 'package:delta_ffi/delta_safe.dart';
import 'package:delta_ffi/src/bindings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeltaAccountsHandle background fetch lifecycle', () {
    late _FakeDeltaChatBindings bindings;

    setUp(() {
      bindings = _FakeDeltaChatBindings(accountsAddress: 0xA11CE);
    });

    Future<DeltaAccountsHandle> createHandle(
      DeltaBackgroundFetchRunner runner,
    ) {
      return DeltaSafe(
        bindings: bindings,
        backgroundFetchRunner: runner,
      ).createAccounts(directory: 'unused');
    }

    test('concurrent backgroundFetch calls reuse the active fetch', () async {
      final fetchStarted = Completer<void>();
      final fetchDone = Completer<bool>();
      var fetchCalls = 0;
      final handle = await createHandle(({
        required accountsAddress,
        required timeoutSeconds,
      }) {
        fetchCalls++;
        expect(accountsAddress, bindings.accountsAddress);
        expect(timeoutSeconds, 5);
        fetchStarted.complete();
        return fetchDone.future;
      });

      final first = handle.backgroundFetch(const Duration(seconds: 5));
      await fetchStarted.future;
      final second = handle.backgroundFetch(const Duration(seconds: 30));

      expect(fetchCalls, 1);
      fetchDone.complete(true);
      expect(await first, isTrue);
      expect(await second, isTrue);
    });

    test(
      'invalid backgroundFetch timeout returns false without native call',
      () async {
        var fetchCalls = 0;
        final handle = await createHandle(({
          required accountsAddress,
          required timeoutSeconds,
        }) async {
          fetchCalls++;
          return true;
        });

        expect(
          await handle.backgroundFetch(const Duration(seconds: 2)),
          isFalse,
        );
        expect(fetchCalls, 0);
      },
    );

    test('stopIo signals and awaits active fetch without running IO', () async {
      final fetchStarted = Completer<void>();
      final fetchDone = Completer<bool>();
      final handle = await createHandle(({
        required accountsAddress,
        required timeoutSeconds,
      }) {
        fetchStarted.complete();
        return fetchDone.future;
      });
      final fetch = handle.backgroundFetch(const Duration(seconds: 5));
      await fetchStarted.future;

      var stopCompleted = false;
      final stop = handle.stopIo().whenComplete(() {
        stopCompleted = true;
      });
      await pumpEventQueue();

      expect(bindings.stopBackgroundFetchCalls, 1);
      expect(bindings.stopIoCalls, 0);
      expect(stopCompleted, isFalse);

      fetchDone.complete(false);
      await stop;
      expect(await fetch, isFalse);
    });

    test('stopIo retries when native fetch is not registered yet', () async {
      final fetchStarted = Completer<void>();
      final fetchDone = Completer<bool>();
      final handle = await createHandle(({
        required accountsAddress,
        required timeoutSeconds,
      }) {
        fetchStarted.complete();
        return fetchDone.future;
      });
      bindings.stopBackgroundFetchMisses = 1;
      final fetch = handle.backgroundFetch(const Duration(seconds: 5));
      await fetchStarted.future;

      var stopCompleted = false;
      final stop = handle.stopIo().whenComplete(() {
        stopCompleted = true;
      });
      await pumpEventQueue();

      expect(bindings.stopBackgroundFetchCalls, 2);
      expect(bindings.stopIoCalls, 0);
      expect(stopCompleted, isFalse);

      fetchDone.complete(false);
      await stop;
      expect(await fetch, isFalse);
    });

    test('dispose waits for active fetch before unref', () async {
      final fetchStarted = Completer<void>();
      final fetchDone = Completer<bool>();
      final handle = await createHandle(({
        required accountsAddress,
        required timeoutSeconds,
      }) {
        fetchStarted.complete();
        return fetchDone.future;
      });
      final fetch = handle.backgroundFetch(const Duration(seconds: 5));
      await fetchStarted.future;

      var disposeCompleted = false;
      final dispose = handle.dispose().whenComplete(() {
        disposeCompleted = true;
      });
      await pumpEventQueue();

      expect(bindings.stopBackgroundFetchCalls, 1);
      expect(bindings.unrefCalls, 0);
      expect(disposeCompleted, isFalse);

      fetchDone.complete(true);
      await dispose;

      expect(await fetch, isTrue);
      expect(bindings.unrefCalls, 1);
      expect(bindings.unrefAccounts, [bindings.accountsAddress]);
    });

    test('dispose retries when native fetch is not registered yet', () async {
      final fetchStarted = Completer<void>();
      final fetchDone = Completer<bool>();
      final handle = await createHandle(({
        required accountsAddress,
        required timeoutSeconds,
      }) {
        fetchStarted.complete();
        return fetchDone.future;
      });
      bindings.stopBackgroundFetchMisses = 1;
      final fetch = handle.backgroundFetch(const Duration(seconds: 5));
      await fetchStarted.future;

      var disposeCompleted = false;
      final dispose = handle.dispose().whenComplete(() {
        disposeCompleted = true;
      });
      await pumpEventQueue();

      expect(bindings.stopBackgroundFetchCalls, 2);
      expect(bindings.unrefCalls, 0);
      expect(disposeCompleted, isFalse);

      fetchDone.complete(false);
      await dispose;

      expect(await fetch, isFalse);
      expect(bindings.unrefCalls, 1);
      expect(bindings.unrefAccounts, [bindings.accountsAddress]);
    });

    test('dispose stops retrying before unref when fetch completes', () async {
      final fetchStarted = Completer<void>();
      final fetchDone = Completer<bool>();
      final handle = await createHandle(({
        required accountsAddress,
        required timeoutSeconds,
      }) {
        fetchStarted.complete();
        return fetchDone.future;
      });
      bindings.stopBackgroundFetchMisses = 1000;
      final fetch = handle.backgroundFetch(const Duration(seconds: 5));
      await fetchStarted.future;

      final dispose = handle.dispose();
      await pumpEventQueue();

      expect(bindings.stopBackgroundFetchCalls, greaterThan(1));
      expect(bindings.unrefCalls, 0);

      fetchDone.complete(true);
      await dispose;
      final stopCallsAtDispose = bindings.stopBackgroundFetchCalls;
      await pumpEventQueue();

      expect(await fetch, isTrue);
      expect(bindings.unrefCalls, 1);
      expect(bindings.stopBackgroundFetchCalls, stopCallsAtDispose);
      expect(bindings.stopAfterUnrefCalls, 0);
    });

    test(
      'dispose still waits and unreferences when stop signal throws',
      () async {
        final fetchStarted = Completer<void>();
        final fetchDone = Completer<bool>();
        final handle = await createHandle(({
          required accountsAddress,
          required timeoutSeconds,
        }) {
          fetchStarted.complete();
          return fetchDone.future;
        });
        final fetch = handle.backgroundFetch(const Duration(seconds: 5));
        await fetchStarted.future;

        bindings.throwOnStopBackgroundFetch = true;
        final dispose = handle.dispose();
        await pumpEventQueue();

        expect(bindings.unrefCalls, 0);

        fetchDone.complete(true);
        await expectLater(dispose, throwsA(isA<UnsupportedError>()));

        expect(await fetch, isTrue);
        expect(bindings.unrefCalls, 1);
        expect(bindings.unrefAccounts, [bindings.accountsAddress]);
      },
    );

    test('backgroundFetch returns false after disposal', () async {
      var fetchCalls = 0;
      final handle = await createHandle(({
        required accountsAddress,
        required timeoutSeconds,
      }) async {
        fetchCalls++;
        return true;
      });

      await handle.dispose();

      expect(await handle.backgroundFetch(const Duration(seconds: 5)), isFalse);
      expect(fetchCalls, 0);
      expect(bindings.unrefCalls, 1);
    });
  });
}

class _FakeDeltaChatBindings extends DeltaChatBindings {
  _FakeDeltaChatBindings({required this.accountsAddress})
    : super.fromLookup(_missingLookup);

  final int accountsAddress;
  int stopBackgroundFetchCalls = 0;
  int stopBackgroundFetchMisses = 0;
  int stopAfterUnrefCalls = 0;
  int stopIoCalls = 0;
  int unrefCalls = 0;
  bool throwOnStopBackgroundFetch = false;
  final List<int> unrefAccounts = <int>[];

  static ffi.Pointer<T> _missingLookup<T extends ffi.NativeType>(
    String symbolName,
  ) {
    throw UnsupportedError('Unexpected Delta FFI lookup: $symbolName');
  }

  @override
  ffi.Pointer<dc_accounts_t> dc_accounts_new(
    ffi.Pointer<ffi.Char> dir,
    int writable,
  ) {
    return ffi.Pointer<dc_accounts_t>.fromAddress(accountsAddress);
  }

  @override
  void dc_accounts_stop_io(ffi.Pointer<dc_accounts_t> accounts) {
    stopIoCalls++;
  }

  @override
  void dc_accounts_unref(ffi.Pointer<dc_accounts_t> accounts) {
    unrefCalls++;
    unrefAccounts.add(accounts.address);
  }

  @override
  int axichat_dc_accounts_stop_background_fetch(
    ffi.Pointer<dc_accounts_t> accounts,
  ) {
    stopBackgroundFetchCalls++;
    if (throwOnStopBackgroundFetch) {
      throw UnsupportedError('stop background fetch unavailable');
    }
    if (unrefCalls > 0) {
      stopAfterUnrefCalls++;
    }
    if (stopBackgroundFetchMisses > 0) {
      stopBackgroundFetchMisses--;
      return 0;
    }
    return accounts.address == accountsAddress ? 1 : 0;
  }
}
