import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

import 'calendar_hover_title_scope.dart';

class CalendarHoverTitleBubble extends StatelessWidget {
  const CalendarHoverTitleBubble({super.key});

  static const double _maxWidth = 420.0;
  static const Duration _fadeDuration = Duration(milliseconds: 120);
  static const Duration _sizeDuration = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    final controller = CalendarHoverTitleScope.maybeOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }

    final colors = context.colorScheme;

    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final String title = controller.title ?? '';
          final bool visible = title.isNotEmpty;

          return AnimatedSwitcher(
            duration: _fadeDuration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: !visible
                ? const SizedBox.shrink()
                : AnimatedSize(
                    duration: _sizeDuration,
                    alignment: Alignment.bottomLeft,
                    curve: Curves.easeOut,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.popover,
                          borderRadius: context.radius,
                          border: Border.all(color: colors.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: calendarInsetLg,
                            vertical: calendarInsetMd,
                          ),
                          child: Text(
                            title,
                            style: context.textTheme.small.copyWith(
                              color: colors.foreground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
