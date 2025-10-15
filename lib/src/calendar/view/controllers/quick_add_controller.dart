import '../widgets/recurrence_editor.dart';
import 'task_draft_controller.dart';

/// Declarative controller for the quick add modal. Extends the shared task draft
/// controller with submission bookkeeping specific to the dialog.
class QuickAddController extends TaskDraftController {
  QuickAddController({
    DateTime? initialStart,
    DateTime? initialEnd,
    DateTime? initialDeadline,
    RecurrenceFormValue initialRecurrence = const RecurrenceFormValue(),
    bool initialImportant = false,
    bool initialUrgent = false,
  })  : _isSubmitting = false,
        super(
          initialStart: initialStart,
          initialEnd: initialEnd,
          initialDeadline: initialDeadline,
          initialRecurrence: initialRecurrence,
          initialImportant: initialImportant,
          initialUrgent: initialUrgent,
        );

  bool _isSubmitting;

  bool get isSubmitting => _isSubmitting;

  void setSubmitting(bool value) {
    if (_isSubmitting == value) return;
    _isSubmitting = value;
    notifyListeners();
  }
}
