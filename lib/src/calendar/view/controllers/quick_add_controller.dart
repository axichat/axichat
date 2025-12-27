import 'package:axichat/src/calendar/view/widgets/recurrence_editor.dart';
import 'task_draft_controller.dart';

/// Declarative controller for the quick add modal. Extends the shared task draft
/// controller with submission bookkeeping specific to the dialog.
class QuickAddController extends TaskDraftController {
  QuickAddController({
    super.initialStart,
    super.initialEnd,
    super.initialDeadline,
    super.initialRecurrence = const RecurrenceFormValue(),
    super.initialImportant = false,
    super.initialUrgent = false,
    super.initialReminders,
    super.initialStatus,
    super.initialTransparency,
    super.initialCategories,
    super.initialUrl,
    super.initialGeo,
    super.initialAdvancedAlarms,
    super.initialOrganizer,
    super.initialAttendees,
  }) : _isSubmitting = false;

  bool _isSubmitting;

  bool get isSubmitting => _isSubmitting;

  void setSubmitting(bool value) {
    if (_isSubmitting == value) return;
    _isSubmitting = value;
    notifyListeners();
  }
}
