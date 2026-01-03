// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';

const _checkboxAnimationDuration = Duration(milliseconds: 220);

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
            final textTheme = Theme.of(context).textTheme;
            final value = state.value ?? false;
            final isEnabled = state.widget.enabled;
            final labelStyle = textTheme.bodyMedium?.copyWith(
              color: isEnabled ? colors.foreground : colors.mutedForeground,
              fontWeight: FontWeight.w600,
            );
            final sublabelStyle = textTheme.bodySmall?.copyWith(
              color: colors.mutedForeground,
            );
            final borderColor = state.hasError
                ? colors.destructive
                : (value ? colors.primary : colors.border);
            final highlightColor = state.hasError
                ? colors.destructive.withValues(alpha: 0.08)
                : (value
                    ? colors.primary.withValues(alpha: 0.08)
                    : Colors.transparent);

            void handleChanged(bool newValue) {
              if (!isEnabled) return;
              state.didChange(newValue);
              onChanged?.call(newValue);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isEnabled ? () => handleChanged(!value) : null,
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: AnimatedContainer(
                        duration: _checkboxAnimationDuration,
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: highlightColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: AnimatedScale(
                                  scale: value ? 1 : 0.92,
                                  duration: _checkboxAnimationDuration,
                                  curve: Curves.easeOut,
                                  child: Checkbox(
                                    value: value,
                                    onChanged: isEnabled
                                        ? (checked) =>
                                            handleChanged(checked ?? !value)
                                        : null,
                                    fillColor: WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states
                                            .contains(WidgetState.disabled)) {
                                          return colors.mutedForeground
                                              .withValues(alpha: 0.2);
                                        }
                                        if (states
                                            .contains(WidgetState.selected)) {
                                          return colors.primary;
                                        }
                                        return Colors.transparent;
                                      },
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.padded,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    side: BorderSide(
                                      color: borderColor,
                                      width: 1.4,
                                    ),
                                    activeColor: colors.primary,
                                    checkColor: colors.primaryForeground,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (inputLabel != null)
                                    DefaultTextStyle(
                                      style: labelStyle ??
                                          TextStyle(
                                            color: colors.foreground,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      child: inputLabel,
                                    ),
                                  if (inputSublabel != null) ...[
                                    const SizedBox(height: 4),
                                    DefaultTextStyle(
                                      style: sublabelStyle ??
                                          TextStyle(
                                            color: colors.mutedForeground,
                                          ),
                                      child: inputSublabel,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.hasError && state.errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 6),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(
                        color: colors.destructive,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
}
