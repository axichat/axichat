// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiVersion extends StatelessWidget {
  const AxiVersion({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return ShadGestureDetector(
          onTap: () => showFadeScaleDialog(
            context: context,
            builder: (context) => AxiDialog(
              constraints: BoxConstraints(
                maxWidth: context.sizing.dialogMaxWidth,
              ),
              title: Text(
                l10n.axiVersionWelcomeTitle,
                style: context.modalHeaderTextStyle,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox.square(dimension: 16.0),
                  Text(
                    context.l10n.axiVersionCurrentFeatures,
                    style: context.textTheme.table,
                  ),
                  Text(
                    context.l10n.axiVersionCurrentFeaturesList,
                    style: context.textTheme.list,
                  ),
                  const SizedBox.square(dimension: 16.0),
                  Text(
                    context.l10n.axiVersionComingNext,
                    style: context.textTheme.table,
                  ),
                  Text(
                    context.l10n.axiVersionComingNextList,
                    style: context.textTheme.list,
                  ),
                ],
              ),
            ),
          ),
          cursor: SystemMouseCursors.click,
          hoverStrategies: mobileHoverStrategies,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  l10n.axiVersionLabel(snapshot.requireData.version),
                  style: context.textTheme.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ShadBadge(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  backgroundColor: Color.lerp(
                    Colors.deepOrangeAccent,
                    Colors.white,
                    0.77,
                  ),
                  hoverBackgroundColor: Color.lerp(
                    Colors.deepOrangeAccent,
                    Colors.white,
                    0.90,
                  ),
                  foregroundColor: Colors.deepOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.0),
                    side: const BorderSide(color: Colors.deepOrange),
                  ),
                  child: Text(l10n.axiVersionTagAlpha),
                ),
              ),
            ],
          ),
        ).withTapBounce();
      },
    );
  }
}
