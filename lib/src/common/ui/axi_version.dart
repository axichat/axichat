import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AxiVersion extends StatelessWidget {
  const AxiVersion({super.key});

  static const versionTag = 'alpha';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return ShadGestureDetector(
          onTap: () => showShadDialog(
            context: context,
            builder: (context) => ShadDialog(
              title: const Text('Welcome to Axichat'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox.square(
                    dimension: 16.0,
                  ),
                  Text(
                    'Current features:',
                    style: context.textTheme.table,
                  ),
                  Text(
                    'Messaging, presence',
                    style: context.textTheme.list,
                  ),
                  const SizedBox.square(
                    dimension: 16.0,
                  ),
                  Text(
                    'Coming next:',
                    style: context.textTheme.table,
                  ),
                  Text(
                    'Groupchat, multimedia',
                    style: context.textTheme.list,
                  ),
                ],
              ),
            ),
          ),
          cursor: SystemMouseCursors.click,
          hoverStrategies: mobileHoverStrategies,
          child: Row(
            children: [
              Text(
                'v${snapshot.requireData.version}',
                style: context.textTheme.h4,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ShadBadge(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  text: const Text(versionTag),
                  backgroundColor:
                      Color.lerp(Colors.deepOrangeAccent, Colors.white, 0.77),
                  hoverBackgroundColor:
                      Color.lerp(Colors.deepOrangeAccent, Colors.white, 0.90),
                  foregroundColor: Colors.deepOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7.0),
                    side: const BorderSide(color: Colors.deepOrange),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
