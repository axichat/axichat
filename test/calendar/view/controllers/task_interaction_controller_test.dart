import 'package:flutter_test/flutter_test.dart';

import 'package:axichat/src/calendar/view/controllers/task_interaction_controller.dart';

void main() {
  test('Hover updates do not notify global listeners', () {
    final controller = TaskInteractionController();
    int notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    controller.setHoveringTask('task-1');
    expect(controller.hoveredTaskId.value, 'task-1');
    expect(notifications, 0);

    controller.clearHoveringTask('task-1');
    expect(controller.hoveredTaskId.value, isNull);
    expect(notifications, 0);

    controller.dispose();
  });
}
