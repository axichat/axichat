import 'dart:typed_data';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SignupAvatarSelector extends StatefulWidget {
  const SignupAvatarSelector({
    super.key,
    required this.bytes,
    required this.username,
    required this.processing,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String username;
  final bool processing;
  final VoidCallback onTap;

  @override
  State<SignupAvatarSelector> createState() => _SignupAvatarSelectorState();
}

class _SignupAvatarSelectorState extends State<SignupAvatarSelector> {
  static const _size = 56.0;
  bool _hovered = false;
  int _previewVersion = 0;

  @override
  void didUpdateWidget(covariant SignupAvatarSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _previewVersion++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final displayJid = widget.username.isEmpty
        ? 'avatar@axichat'
        : '${widget.username}@preview';
    final overlayVisible = _hovered || widget.processing;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _hovered = true),
        onTapUp: (_) => setState(() => _hovered = false),
        onTapCancel: () => setState(() => _hovered = false),
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: _size,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: AxiAvatar(
                  key: ValueKey(_previewVersion),
                  jid: displayJid,
                  size: _size,
                  subscription: Subscription.none,
                  presence: null,
                  avatarBytes: widget.bytes,
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: overlayVisible ? 0.8 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: colors.background.withAlpha((0.45 * 255).round()),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
                child: widget.processing
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.foreground,
                          ),
                        ),
                      )
                    : Icon(
                        LucideIcons.pencil,
                        color: colors.foreground,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
