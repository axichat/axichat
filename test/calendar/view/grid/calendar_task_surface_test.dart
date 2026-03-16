import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/grid/task_interaction_controller.dart';
import 'package:axichat/src/calendar/view/tasks/resizable_task_widget.dart';
import 'package:axichat/src/calendar/view/grid/calendar_task_draggable.dart';
import 'package:axichat/src/calendar/view/grid/calendar_task_geometry.dart';
import 'package:axichat/src/calendar/view/grid/calendar_task_surface.dart';
import 'package:axichat/src/localization/app_localizations.dart';

void main() {
  testWidgets('CalendarTaskSurface reuses popover controller across rebuilds', (
    tester,
  ) async {
    final interactionController = TaskInteractionController();
    final task = CalendarTask.create(title: 'Persistent Menu');

    final callbacks = CalendarTaskTileCallbacks(
      onResizePreview: (_) {},
      onResizeEnd: (_) {},
      onResizePointerMove: (_) {},
      onDragStarted: () {},
      resolveDragOriginSlot: (task) => task.scheduledTime,
      onDragUpdate: (_) {},
      onDragEnded: (_) {},
      onEnterSelectionMode: () {},
      onToggleSelection: () {},
      onTap: (_, _) {},
    );

    bool isPopoverOpen = false;
    late void Function(void Function()) triggerRebuild;

    const geometry = CalendarTaskGeometry(
      rect: Rect.fromLTWH(0, 0, 240, 72),
      narrowedWidth: 200,
      splitWidthFactor: 200 / 240,
    );

    final ValueNotifier<bool> cancelHoverNotifier = ValueNotifier(false);

    CalendarTaskEntryBindings buildBindings() => CalendarTaskEntryBindings(
      isSelectionMode: false,
      isSelected: false,
      isPopoverOpen: isPopoverOpen,
      splitPreviewAnimationDuration: Duration.zero,
      contextMenuGroupId: const ValueKey<String>('calendar-menu'),
      contextMenuBuilderFactory: (_) =>
          (context, request) => const <Widget>[],
      enableContextMenuLongPress: false,
      resizeHandleExtent: 12,
      interactionController: interactionController,
      cancelBucketHoverNotifier: cancelHoverNotifier,
      callbacks: callbacks,
      geometryProvider: (_) => geometry,
      globalRectProvider: (_) => geometry.rect,
      stepHeight: 16,
      minutesPerStep: 15,
      hourHeight: 48,
      viewportScrollOffsetProvider: () => 0,
      addGeometryListener: (_) {},
      removeGeometryListener: (_) {},
      requiresLongPressToDrag: false,
      longPressToDragDelay: Duration.zero,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              triggerRebuild = setState;
              return SizedBox(
                width: 240,
                height: 72,
                child: CalendarTaskSurface(
                  task: task,
                  isDayView: true,
                  bindings: buildBindings(),
                ),
              );
            },
          ),
        ),
      ),
    );

    final dynamic initialState = tester.state(find.byType(CalendarTaskSurface));
    final initialController = initialState.menuController;

    isPopoverOpen = true;
    triggerRebuild(() {});
    await tester.pump();

    final dynamic updatedState = tester.state(find.byType(CalendarTaskSurface));
    expect(updatedState.menuController, same(initialController));
  });

  testWidgets('CalendarTaskSurface rebuilds when geometry becomes available', (
    tester,
  ) async {
    final interactionController = TaskInteractionController();
    final task = CalendarTask.create(
      title: 'Geometry Task',
      scheduledTime: DateTime(2024, 1, 15, 9),
    );

    CalendarTaskGeometry geometry = CalendarTaskGeometry.empty;

    late void Function(void Function()) triggerRebuild;
    final ValueNotifier<bool> cancelHoverNotifier = ValueNotifier(false);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              triggerRebuild = setState;
              return SizedBox(
                width: 240,
                height: 72,
                child: CalendarTaskSurface(
                  task: task,
                  isDayView: true,
                  bindings: CalendarTaskEntryBindings(
                    isSelectionMode: false,
                    isSelected: false,
                    isPopoverOpen: false,
                    splitPreviewAnimationDuration: Duration.zero,
                    contextMenuGroupId: const ValueKey<String>('geometry-menu'),
                    contextMenuBuilderFactory: (_) =>
                        (_, _) => const <Widget>[],
                    enableContextMenuLongPress: false,
                    resizeHandleExtent: 12,
                    interactionController: interactionController,
                    cancelBucketHoverNotifier: cancelHoverNotifier,
                    callbacks: CalendarTaskTileCallbacks(
                      onResizePreview: (_) {},
                      onResizeEnd: (_) {},
                      onResizePointerMove: (_) {},
                      onDragStarted: () {},
                      resolveDragOriginSlot: (task) => task.scheduledTime,
                      onDragUpdate: (_) {},
                      onDragEnded: (_) {},
                      onEnterSelectionMode: () {},
                      onToggleSelection: () {},
                      onTap: (_, _) {},
                    ),
                    geometryProvider: (_) => geometry,
                    globalRectProvider: (_) => geometry.rect,
                    stepHeight: 16,
                    minutesPerStep: 15,
                    hourHeight: 48,
                    viewportScrollOffsetProvider: () => 0,
                    addGeometryListener: (_) {},
                    removeGeometryListener: (_) {},
                    requiresLongPressToDrag: false,
                    longPressToDragDelay: Duration.zero,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(ResizableTaskWidget), findsNothing);

    geometry = const CalendarTaskGeometry(
      rect: Rect.fromLTWH(0, 0, 240, 72),
      narrowedWidth: 200,
      splitWidthFactor: 200 / 240,
    );
    triggerRebuild(() {});
    await tester.pump();

    expect(find.byType(ResizableTaskWidget), findsOneWidget);
  });

  testWidgets(
    'CalendarTaskSurface starts drag from body but not from resize handle',
    (tester) async {
      final interactionController = TaskInteractionController();
      final task = CalendarTask.create(
        title: 'Drag Ownership Task',
        scheduledTime: DateTime(2024, 1, 1, 10),
        duration: const Duration(hours: 1),
      );
      bool dragStarted = false;
      CalendarTask? resizePreview;

      const geometry = CalendarTaskGeometry(
        rect: Rect.fromLTWH(0, 0, 240, 72),
        narrowedWidth: 200,
        splitWidthFactor: 200 / 240,
      );

      final ValueNotifier<bool> cancelHoverNotifier = ValueNotifier(false);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: SizedBox(
              width: 240,
              height: 72,
              child: CalendarTaskSurface(
                task: task,
                isDayView: true,
                bindings: CalendarTaskEntryBindings(
                  isSelectionMode: false,
                  isSelected: false,
                  isPopoverOpen: false,
                  splitPreviewAnimationDuration: Duration.zero,
                  contextMenuGroupId: const ValueKey<String>('drag-menu'),
                  contextMenuBuilderFactory: (_) =>
                      (_, _) => const <Widget>[],
                  enableContextMenuLongPress: false,
                  resizeHandleExtent: 12,
                  interactionController: interactionController,
                  cancelBucketHoverNotifier: cancelHoverNotifier,
                  callbacks: CalendarTaskTileCallbacks(
                    onResizePreview: (task) => resizePreview = task,
                    onResizeEnd: (_) {},
                    onResizePointerMove: (_) {},
                    onDragStarted: () => dragStarted = true,
                    resolveDragOriginSlot: (task) => task.scheduledTime,
                    onDragUpdate: (_) {},
                    onDragEnded: (_) {},
                    onEnterSelectionMode: () {},
                    onToggleSelection: () {},
                    onTap: (_, _) {},
                  ),
                  geometryProvider: (_) => geometry,
                  globalRectProvider: (_) => geometry.rect,
                  stepHeight: 16,
                  minutesPerStep: 15,
                  hourHeight: 48,
                  viewportScrollOffsetProvider: () => 0,
                  addGeometryListener: (_) {},
                  removeGeometryListener: (_) {},
                  requiresLongPressToDrag: false,
                  longPressToDragDelay: Duration.zero,
                ),
              ),
            ),
          ),
        ),
      );

      final Finder surfaceFinder = find.byType(CalendarTaskSurface);
      final Rect rect = tester.getRect(surfaceFinder);

      final TestGesture bodyGesture = await tester.startGesture(
        rect.center,
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await tester.pump();
      await bodyGesture.moveBy(const Offset(0, 24));
      await tester.pump();

      expect(
        interactionController.activeInteractionSession?.source,
        CalendarInteractionSource.taskSurface,
      );
      expect(
        interactionController.activeInteractionSession?.kind,
        CalendarInteractionKind.drag,
      );

      await bodyGesture.up();
      await tester.pump();

      expect(dragStarted, isTrue);
      expect(resizePreview, isNull);

      dragStarted = false;
      resizePreview = null;

      final TestGesture handleGesture = await tester.startGesture(
        Offset(rect.center.dx, rect.top + 2),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryButton,
      );
      await tester.pump();
      await handleGesture.moveTo(Offset(rect.center.dx, rect.top + 24));
      await tester.pump();
      await handleGesture.up();
      await tester.pump();

      expect(dragStarted, isFalse);
      expect(resizePreview, isNotNull);
    },
  );

  testWidgets(
    'CalendarTaskSurface touch long press drags from body but resizes from handle',
    (tester) async {
      final interactionController = TaskInteractionController();
      final task = CalendarTask.create(
        title: 'Touch Drag Ownership Task',
        scheduledTime: DateTime(2024, 1, 1, 10),
        duration: const Duration(hours: 1),
      );
      bool dragStarted = false;
      CalendarTask? resizePreview;

      const geometry = CalendarTaskGeometry(
        rect: Rect.fromLTWH(0, 0, 240, 72),
        narrowedWidth: 200,
        splitWidthFactor: 200 / 240,
      );

      final ValueNotifier<bool> cancelHoverNotifier = ValueNotifier(false);

      Widget buildSurface() {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: SizedBox(
              width: 240,
              height: 72,
              child: CalendarTaskSurface(
                task: task,
                isDayView: true,
                bindings: CalendarTaskEntryBindings(
                  isSelectionMode: false,
                  isSelected: false,
                  isPopoverOpen: false,
                  splitPreviewAnimationDuration: Duration.zero,
                  contextMenuGroupId: const ValueKey<String>('touch-drag-menu'),
                  contextMenuBuilderFactory: (_) =>
                      (_, _) => const <Widget>[],
                  enableContextMenuLongPress: false,
                  resizeHandleExtent: 12,
                  interactionController: interactionController,
                  cancelBucketHoverNotifier: cancelHoverNotifier,
                  callbacks: CalendarTaskTileCallbacks(
                    onResizePreview: (task) => resizePreview = task,
                    onResizeEnd: (_) {},
                    onResizePointerMove: (_) {},
                    onDragStarted: () => dragStarted = true,
                    resolveDragOriginSlot: (task) => task.scheduledTime,
                    onDragUpdate: (_) {},
                    onDragEnded: (_) {},
                    onEnterSelectionMode: () {},
                    onToggleSelection: () {},
                    onTap: (_, _) {},
                  ),
                  geometryProvider: (_) => geometry,
                  globalRectProvider: (_) => geometry.rect,
                  stepHeight: 16,
                  minutesPerStep: 15,
                  hourHeight: 48,
                  viewportScrollOffsetProvider: () => 0,
                  addGeometryListener: (_) {},
                  removeGeometryListener: (_) {},
                  requiresLongPressToDrag: true,
                  longPressToDragDelay: const Duration(milliseconds: 300),
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildSurface());

      final Finder surfaceFinder = find.byType(CalendarTaskSurface);
      final Rect rect = tester.getRect(surfaceFinder);

      final TestGesture bodyGesture = await tester.startGesture(
        rect.center,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 325));
      await bodyGesture.moveBy(const Offset(0, 24));
      await tester.pump();

      expect(
        interactionController.activeInteractionSession?.source,
        CalendarInteractionSource.taskSurface,
      );
      expect(
        interactionController.activeInteractionSession?.kind,
        CalendarInteractionKind.drag,
      );

      await bodyGesture.up();
      await tester.pump();

      expect(dragStarted, isTrue);
      expect(resizePreview, isNull);

      dragStarted = false;
      resizePreview = null;

      await tester.pumpWidget(buildSurface());
      await tester.pump();
      final Rect refreshedRect = tester.getRect(
        find.byType(CalendarTaskSurface),
      );

      final TestGesture handleGesture = await tester.startGesture(
        Offset(refreshedRect.center.dx, refreshedRect.top + 2),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 225));
      await handleGesture.moveTo(
        Offset(refreshedRect.center.dx, refreshedRect.top + 24),
      );
      await tester.pump();
      await handleGesture.up();
      await tester.pump();

      expect(dragStarted, isFalse);
      expect(resizePreview, isNotNull);
    },
  );

  testWidgets('CalendarTaskSurface touch long press drag does not also tap', (
    tester,
  ) async {
    final interactionController = TaskInteractionController();
    final task = CalendarTask.create(
      title: 'Touch Drag Tap Exclusivity Task',
      scheduledTime: DateTime(2024, 1, 1, 10),
      duration: const Duration(hours: 1),
    );
    bool dragStarted = false;
    bool tapped = false;

    const geometry = CalendarTaskGeometry(
      rect: Rect.fromLTWH(0, 0, 240, 72),
      narrowedWidth: 200,
      splitWidthFactor: 200 / 240,
    );

    final ValueNotifier<bool> cancelHoverNotifier = ValueNotifier(false);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: ShadTheme(
          data: ShadThemeData(
            colorScheme: const ShadSlateColorScheme.light(),
            brightness: Brightness.light,
          ),
          child: SizedBox(
            width: 240,
            height: 72,
            child: CalendarTaskSurface(
              task: task,
              isDayView: true,
              bindings: CalendarTaskEntryBindings(
                isSelectionMode: false,
                isSelected: false,
                isPopoverOpen: false,
                splitPreviewAnimationDuration: Duration.zero,
                contextMenuGroupId: const ValueKey<String>(
                  'touch-drag-tap-menu',
                ),
                contextMenuBuilderFactory: (_) =>
                    (_, _) => const <Widget>[],
                enableContextMenuLongPress: false,
                resizeHandleExtent: 12,
                interactionController: interactionController,
                cancelBucketHoverNotifier: cancelHoverNotifier,
                callbacks: CalendarTaskTileCallbacks(
                  onResizePreview: (_) {},
                  onResizeEnd: (_) {},
                  onResizePointerMove: (_) {},
                  onDragStarted: () => dragStarted = true,
                  resolveDragOriginSlot: (task) => task.scheduledTime,
                  onDragUpdate: (_) {},
                  onDragEnded: (_) {},
                  onEnterSelectionMode: () {},
                  onToggleSelection: () {},
                  onTap: (_, _) => tapped = true,
                ),
                geometryProvider: (_) => geometry,
                globalRectProvider: (_) => geometry.rect,
                stepHeight: 16,
                minutesPerStep: 15,
                hourHeight: 48,
                viewportScrollOffsetProvider: () => 0,
                addGeometryListener: (_) {},
                removeGeometryListener: (_) {},
                requiresLongPressToDrag: true,
                longPressToDragDelay: const Duration(milliseconds: 300),
              ),
            ),
          ),
        ),
      ),
    );

    final Rect rect = tester.getRect(find.byType(CalendarTaskSurface));
    final TestGesture gesture = await tester.startGesture(
      rect.center,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 325));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(dragStarted, isTrue);
    expect(tapped, isFalse);
  });

  testWidgets(
    'CalendarTaskSurface keeps the source draggable mounted during an active drag',
    (tester) async {
      final TaskInteractionController interactionController =
          TaskInteractionController();
      final CalendarTask task = CalendarTask.create(
        title: 'Mounted Drag Source',
        scheduledTime: DateTime(2024, 1, 1, 10),
        duration: const Duration(hours: 1),
      );

      const CalendarTaskGeometry geometry = CalendarTaskGeometry(
        rect: Rect.fromLTWH(0, 0, 240, 72),
        narrowedWidth: 200,
        splitWidthFactor: 200 / 240,
      );

      final ValueNotifier<bool> cancelHoverNotifier = ValueNotifier(false);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: ShadTheme(
            data: ShadThemeData(
              colorScheme: const ShadSlateColorScheme.light(),
              brightness: Brightness.light,
            ),
            child: SizedBox(
              width: 240,
              height: 72,
              child: CalendarTaskSurface(
                task: task,
                isDayView: true,
                bindings: CalendarTaskEntryBindings(
                  isSelectionMode: false,
                  isSelected: false,
                  isPopoverOpen: false,
                  splitPreviewAnimationDuration: Duration.zero,
                  contextMenuGroupId: const ValueKey<String>('mounted-menu'),
                  contextMenuBuilderFactory: (_) =>
                      (_, _) => const <Widget>[],
                  enableContextMenuLongPress: false,
                  resizeHandleExtent: 12,
                  interactionController: interactionController,
                  cancelBucketHoverNotifier: cancelHoverNotifier,
                  callbacks: CalendarTaskTileCallbacks(
                    onResizePreview: (_) {},
                    onResizeEnd: (_) {},
                    onResizePointerMove: (_) {},
                    onDragStarted: () {},
                    resolveDragOriginSlot: (task) => task.scheduledTime,
                    onDragUpdate: (_) {},
                    onDragEnded: (_) {},
                    onEnterSelectionMode: () {},
                    onToggleSelection: () {},
                    onTap: (_, _) {},
                  ),
                  geometryProvider: (_) => geometry,
                  globalRectProvider: (_) => geometry.rect,
                  stepHeight: 16,
                  minutesPerStep: 15,
                  hourHeight: 48,
                  viewportScrollOffsetProvider: () => 0,
                  addGeometryListener: (_) {},
                  removeGeometryListener: (_) {},
                  requiresLongPressToDrag: false,
                  longPressToDragDelay: Duration.zero,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CalendarTaskDraggable), findsOneWidget);

      interactionController.beginDrag(
        task: task,
        snapshot: task.copyWith(),
        bounds: geometry.rect,
        pointerNormalized: 0.5,
        pointerGlobalX: geometry.rect.center.dx,
        originSlot: task.scheduledTime,
      );
      await tester.pump();

      expect(find.byType(CalendarTaskDraggable), findsOneWidget);
    },
  );
}
