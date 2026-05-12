// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiCheckboxFormField extends FormField<bool> {
  AxiCheckboxFormField({
    super.key,
    bool initialValue = false,
    super.enabled = true,
    Widget? inputLabel,
    Widget? inputSublabel,
    ValueChanged<bool>? onChanged,
    super.validator,
    super.autovalidateMode,
  }) : super(
         initialValue: initialValue,
         builder: (state) {
           final context = state.context;
           final colors = context.colorScheme;
           final textTheme = context.textTheme;
           final spacing = context.spacing;
           final sizing = context.sizing;
           final animationDuration = context.select<SettingsCubit, Duration>(
             (cubit) => cubit.animationDuration,
           );
           final value = state.value ?? false;
           final isEnabled = state.widget.enabled;
           final labelStyle = textTheme.small.copyWith(
             color: isEnabled ? colors.foreground : colors.mutedForeground,
             fontWeight: FontWeight.w600,
           );
           final sublabelStyle = textTheme.muted;
           final borderColor = state.hasError
               ? colors.destructive
               : (value ? colors.primary : colors.border);
           final highlightColor = state.hasError
               ? colors.destructive.withValues(
                   alpha: context.motion.tapHoverAlpha,
                 )
               : Colors.transparent;

           void handleChanged(bool newValue) {
             if (!isEnabled) return;
             state.didChange(newValue);
             onChanged?.call(newValue);
           }

           Widget row = AnimatedContainer(
             duration: animationDuration,
             curve: Curves.easeInOut,
             padding: EdgeInsets.symmetric(
               horizontal: spacing.s,
               vertical: spacing.xs,
             ),
             decoration: ShapeDecoration(
               color: highlightColor,
               shape: RoundedSuperellipseBorder(
                 borderRadius: BorderRadius.circular(context.radii.squircle),
               ),
             ),
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.center,
               children: [
                 SizedBox(
                   width: sizing.inputSuffixButtonSize,
                   height: sizing.inputSuffixButtonSize,
                   child: Center(
                     child: AnimatedScale(
                       scale: value ? 1 : 0.92,
                       duration: animationDuration,
                       curve: Curves.easeOut,
                       child: Checkbox(
                         value: value,
                         onChanged: isEnabled
                             ? (checked) => handleChanged(checked ?? !value)
                             : null,
                         fillColor: WidgetStateProperty.resolveWith((states) {
                           if (states.contains(WidgetState.disabled)) {
                             return colors.mutedForeground.withValues(
                               alpha: 0.2,
                             );
                           }
                           if (states.contains(WidgetState.selected)) {
                             return colors.primary;
                           }
                           return Colors.transparent;
                         }),
                         materialTapTargetSize:
                             MaterialTapTargetSize.shrinkWrap,
                         visualDensity: VisualDensity.compact,
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(
                             context.radii.squircleSm,
                           ),
                         ),
                         side: BorderSide(
                           color: borderColor,
                           width: context.borderSide.width,
                         ),
                         activeColor: colors.primary,
                         checkColor: colors.primaryForeground,
                       ),
                     ),
                   ),
                 ),
                 SizedBox(width: spacing.s),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       if (inputLabel != null)
                         DefaultTextStyle(style: labelStyle, child: inputLabel),
                       if (inputSublabel != null) ...[
                         SizedBox(height: spacing.xs),
                         DefaultTextStyle(
                           style: sublabelStyle,
                           child: inputSublabel,
                         ),
                       ],
                     ],
                   ),
                 ),
               ],
             ),
           );

           row = ShadFocusable(
             canRequestFocus: isEnabled,
             builder: (context, _, child) => child ?? const SizedBox.shrink(),
             child: ShadGestureDetector(
               cursor: isEnabled ? SystemMouseCursors.click : MouseCursor.defer,
               hoverStrategies: ShadTheme.of(context).hoverStrategies,
               onTap: isEnabled ? () => handleChanged(!value) : null,
               child: row,
             ),
           );

           row = AxiTapBounce(enabled: isEnabled, child: row);

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               row,
               if (state.hasError && state.errorText != null)
                 Padding(
                   padding: EdgeInsets.only(left: spacing.xs, top: spacing.xs),
                   child: Text(
                     state.errorText!,
                     style: textTheme.label.copyWith(color: colors.destructive),
                   ),
                 ),
             ],
           );
         },
       );
}
