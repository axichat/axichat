# Calendar Module Critical Issues

## 1. BLoC Implementation Problems (CRITICAL)

### Current State
- BaseCalendarBloc extends HydratedBloc but doesn't properly wire custom storage
- Storage builders exist but are never connected to BLoCs
- No AuthCalendarBloc implementation for encrypted storage
- Missing `hydrate()` calls and improper constructor patterns

### Required Fixes
- ✅ Accept Storage parameter in BaseCalendarBloc constructor
- ✅ Pass storage to HydratedBloc super constructor
- ✅ Create AuthCalendarBloc with encrypted storage
- ✅ Update GuestCalendarBloc to use unencrypted storage
- ✅ Implement CalendarBlocFactory for proper initialization
- ✅ Add CalendarProvider widget for lifecycle management

### References
- See detailed plan: `.claude/plans/calendar-bloc-hydrated-storage-fix.md`
- Must follow BLOC_GUIDE.md patterns
- hydrated_bloc documentation: https://pub.dev/packages/hydrated_bloc

## 2. Mobile Responsivity Issues (HIGH PRIORITY)

### Current Problems
- Side-by-side layout overflows on screens <600px
- Fixed widths don't adapt to mobile constraints
- Desktop dialogs appear as tiny windows on mobile
- No touch gestures or mobile-first patterns

### Required Adaptations

#### Layout Changes
- ✅ Replace side-by-side with tab navigation on mobile
- ✅ Calendar grid as first tab, tasks sidebar as second tab
- ✅ Collapsible navigation bar to save vertical space
- ✅ Floating action button for quick task creation

#### Dialog Adaptations
- ✅ Convert all dialogs to modal bottom sheets on mobile
- ✅ Replace dropdowns with bottom sheet selectors
- ✅ Add drag handles and proper mobile styling
- ✅ Ensure max height constraints for small screens

#### Advanced Drag-and-Drop
- ✅ Allow dragging tasks from sidebar tab
- ✅ Auto-switch to calendar tab when drag starts
- ✅ Show visual drop zone overlay
- ✅ Allow dragging back to cancel (switch tabs on hover)
- ✅ Haptic feedback for drag interactions

#### Touch Gestures
- ✅ Swipe left/right to navigate weeks/months
- ✅ Pull-to-refresh for sync
- ✅ Long-press for quick actions
- ✅ Pinch-to-zoom on calendar grid
- ✅ Swipe tasks for complete/delete actions

### References
- See detailed plan: `.claude/plans/calendar-mobile-responsivity-adaptation.md`
- Material Design mobile guidelines
- Flutter responsive design best practices

## 3. Code Quality Issues (MEDIUM PRIORITY)

### Problems Identified
- Massive code duplication (fieldDecoration repeated 3+ times)
- 25+ withOpacity() calls instead of semantic colors
- Monster widgets (task_sidebar.dart: 1,817 lines)
- No single source of truth for UI themes

### References
- See plan: `.claude/plans/calendar-cleanup-refactor-deduplication.md`

## Implementation Priority

1. **Week 1**: Fix BLoC hydrated storage (CRITICAL - data loss risk)
2. **Week 2**: Implement mobile responsivity (HIGH - unusable on mobile)
3. **Week 3**: Code cleanup and refactoring (MEDIUM - maintainability)

## Testing Requirements

### BLoC Testing
- Verify encrypted storage for auth users
- Verify unencrypted storage for guests
- Test state persistence across restarts
- Test auth/guest mode switching

### Mobile Testing
- Test on all screen sizes (320px - 1920px)
- Test portrait and landscape orientations
- Test all touch gestures
- Test drag-and-drop between tabs
- Performance testing (60fps target)

## Success Criteria

- ✅ No data loss - proper state persistence
- ✅ Security - encrypted storage for auth users
- ✅ Mobile usability - no overflows, native feel
- ✅ Performance - smooth 60fps on all devices
- ✅ Code quality - DRY principles, <400 lines per file