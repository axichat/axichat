#!/usr/bin/env python3

from __future__ import annotations

import sys
from pathlib import Path

PLUGIN_STUB = """package de.ffuf.in_app_update

import android.app.Activity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class InAppUpdatePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "de.ffuf.in_app_update/methods")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "de.ffuf.in_app_update/stateEvents")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "checkForUpdate" -> result.success(mapOf(
                "updateAvailability" to 1,
                "immediateAllowed" to false,
                "immediateAllowedPreconditions" to emptyList<Int>(),
                "flexibleAllowed" to false,
                "flexibleAllowedPreconditions" to emptyList<Int>(),
                "availableVersionCode" to null,
                "installStatus" to 0,
                "packageName" to (activity?.packageName ?: ""),
                "clientVersionStalenessDays" to null,
                "updatePriority" to 0
            ))
            "performImmediateUpdate", "startFlexibleUpdate", "completeFlexibleUpdate" -> result.error(
                "IN_APP_UPDATE_FAILED",
                "Play in-app updates are unavailable in this build.",
                null
            )
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}

    override fun onCancel(arguments: Any?) {}

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
"""

REMOVED_GRADLE_SNIPPETS = (
    "com.google.android.play:app-update",
    "com.google.android.play:app-update-ktx",
)


def patch_plugin(plugin_root: Path) -> None:
    build_gradle = plugin_root / "android" / "build.gradle"
    if build_gradle.exists():
        original_lines = build_gradle.read_text(encoding="utf-8").splitlines()
        filtered_lines = [
            line
            for line in original_lines
            if not any(snippet in line for snippet in REMOVED_GRADLE_SNIPPETS)
        ]
        build_gradle.write_text("\n".join(filtered_lines) + "\n", encoding="utf-8")

    kotlin_dir = (
        plugin_root
        / "android"
        / "src"
        / "main"
        / "kotlin"
        / "de"
        / "ffuf"
        / "in_app_update"
    )
    kotlin_dir.mkdir(parents=True, exist_ok=True)
    plugin_file = kotlin_dir / "InAppUpdatePlugin.kt"
    plugin_file.write_text(PLUGIN_STUB, encoding="utf-8")

    print(f"Patched {plugin_root}")


def main(argv: list[str]) -> int:
    pub_cache = Path(argv[1]) if len(argv) > 1 else Path.cwd() / ".pub-cache"
    hosted_pub = pub_cache / "hosted" / "pub.dev"
    if not hosted_pub.exists():
        print(f"No hosted pub cache at {hosted_pub}; skipping.")
        return 0

    plugin_roots = sorted(
        path
        for path in hosted_pub.iterdir()
        if path.is_dir() and path.name.startswith("in_app_update-")
    )
    if not plugin_roots:
        print(f"No in_app_update package found under {hosted_pub}; skipping.")
        return 0

    for plugin_root in plugin_roots:
        patch_plugin(plugin_root)

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
