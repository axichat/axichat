import 'package:chat/src/app.dart';
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
