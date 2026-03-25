#!/usr/bin/env python3

from __future__ import annotations

import json
import sys
from pathlib import Path


def main(argv: list[str]) -> int:
    plugin_graph_path = (
        Path(argv[1]) if len(argv) > 1 else Path(".flutter-plugins-dependencies")
    )
    plugin_graph = json.loads(plugin_graph_path.read_text(encoding="utf-8"))
    dev_only_plugins = {
        plugin["name"]
        for plugins in plugin_graph.get("plugins", {}).values()
        if isinstance(plugins, list)
        for plugin in plugins
        if plugin.get("dev_dependency")
    }

    plugin_graph["plugins"] = {
        platform: [
            plugin
            for plugin in plugins
            if plugin.get("name") not in dev_only_plugins
        ]
        for platform, plugins in plugin_graph.get("plugins", {}).items()
    }
    plugin_graph["dependencyGraph"] = [
        plugin
        for plugin in plugin_graph.get("dependencyGraph", [])
        if plugin.get("name") not in dev_only_plugins
    ]

    plugin_graph_path.write_text(
        json.dumps(plugin_graph, separators=(",", ":")),
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
