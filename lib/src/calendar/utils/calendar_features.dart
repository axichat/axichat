class CalendarFeatures {
  final bool showSyncControls;
  final bool showGuestBanner;
  final bool showUnscheduledTasks;
  final bool showInlineInput;
  final bool enableCloudSync;

  const CalendarFeatures({
    required this.showSyncControls,
    required this.showGuestBanner,
    required this.showUnscheduledTasks,
    required this.showInlineInput,
    required this.enableCloudSync,
  });

  const CalendarFeatures.guest()
      : showSyncControls = false,
        showGuestBanner = true,
        showUnscheduledTasks = true,
        showInlineInput = true,
        enableCloudSync = false;

  const CalendarFeatures.authenticated()
      : showSyncControls = true,
        showGuestBanner = false,
        showUnscheduledTasks = true,
        showInlineInput = true,
        enableCloudSync = true;
}
