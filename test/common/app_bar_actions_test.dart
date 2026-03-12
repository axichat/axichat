import 'package:axichat/src/common/ui/app_bar_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom app bar icons are preserved when converted to menu actions', () {
    final icon = Container(key: const ValueKey<String>('custom-icon'));
    final action = AppBarActionItem(
      label: 'Pinned',
      iconData: Icons.push_pin,
      icon: icon,
      onPressed: () {},
    );

    final menuAction = action.toMenuAction();

    expect(menuAction.leading, same(icon));
    expect(menuAction.icon, Icons.push_pin);
  });
}
