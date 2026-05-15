package im.axi.axichat

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.MotionEvent
import android.widget.Toast
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  companion object {
    private const val shareTargetsChannel = "im.axi.axichat/share_targets"
    private const val shareTargetCategory = "im.axi.axichat.dynamic_share_target"
    private const val shareTargetPreferencesName = "im.axi.axichat.share_targets"
    private const val shareTargetIdsKey = "share_target_ids"
    private const val shareTargetSchemaVersionKey = "share_target_schema_version"
    private const val shareTargetSchemaVersion = 5
    private const val shortcutIdExtra = "android.intent.extra.shortcut.ID"
    private const val conversationIdentifierExtra = "conversationIdentifier"
    private const val shortcutIconSizeDp = 108
    private const val shortcutIconTextScale = 0.42f
    private val shortcutIconBackgroundColors = intArrayOf(
        Color.rgb(36, 99, 235),
        Color.rgb(5, 150, 105),
        Color.rgb(217, 119, 6),
        Color.rgb(220, 38, 38),
        Color.rgb(124, 58, 237),
        Color.rgb(8, 145, 178)
    )
    private const val overlayWarningMessage =
        "Screen overlay detected. Tap blocked for your security."
    private const val overlayWarningThrottleMs = 2000L
    private const val overlayBlockDurationMs = 1500L
  }

  private var lastOverlayWarningAt = 0L
  private var overlayBlockUntilMs = 0L

  override fun onCreate(savedInstanceState: Bundle?) {
    if (shouldFinishForTaskHijack(intent)) {
      finish()
      return
    }
    normalizeShareIntent(this, intent)
    super.onCreate(savedInstanceState)
    flutterView?.filterTouchesWhenObscured = true
  }

  override fun onNewIntent(intent: Intent) {
    normalizeShareIntent(this, intent)
    setIntent(intent)
    super.onNewIntent(intent)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareTargetsChannel)
        .setMethodCallHandler(::handleShareTargetMethodCall)
  }

  override fun dispatchTouchEvent(event: MotionEvent): Boolean {
    val nowMs = SystemClock.elapsedRealtime()
    if (nowMs < overlayBlockUntilMs) {
      maybeShowOverlayWarning(nowMs)
      return false
    }
    if (isTouchObscured(event)) {
      overlayBlockUntilMs = nowMs + overlayBlockDurationMs
      maybeShowOverlayWarning(nowMs)
      return false
    }
    return super.dispatchTouchEvent(event)
  }

  private fun isTouchObscured(event: MotionEvent): Boolean {
    val obscured = event.flags and MotionEvent.FLAG_WINDOW_IS_OBSCURED != 0
    val partiallyObscured = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      event.flags and MotionEvent.FLAG_WINDOW_IS_PARTIALLY_OBSCURED != 0
    } else {
      false
    }
    return obscured || partiallyObscured
  }

  private fun maybeShowOverlayWarning(nowMs: Long) {
    if (nowMs - lastOverlayWarningAt < overlayWarningThrottleMs) {
      return
    }
    lastOverlayWarningAt = nowMs
    Toast.makeText(this, overlayWarningMessage, Toast.LENGTH_SHORT).show()
  }

  private fun shouldFinishForTaskHijack(intent: Intent?): Boolean {
    if (isTaskRoot) {
      return false
    }
    if (intent == null) {
      return false
    }
    return Intent.ACTION_MAIN == intent.action &&
        intent.hasCategory(Intent.CATEGORY_LAUNCHER)
  }

  private fun handleShareTargetMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "getMaxShareTargetCount" -> result.success(
          ShortcutManagerCompat.getMaxShortcutCountPerActivity(this)
      )
      "setShareTargets" -> setShareTargets(call.arguments, result)
      "clearShareTargets" -> clearShareTargets(result)
      else -> result.notImplemented()
    }
  }

  private fun setShareTargets(arguments: Any?, result: MethodChannel.Result) {
    try {
      val targets = shareTargetsFromArguments(arguments)
      val shortcuts = targets.map(::shortcutForShareTarget)
      val nextIds = targets.map { it.jid }.toSet()
      val previousIds = storedShareTargetIds()
      val removedIds = if (storedShareTargetSchemaVersion() == shareTargetSchemaVersion) {
        previousIds.minus(nextIds)
      } else {
        previousIds.plus(nextIds)
      }
      removeShareTargets(removedIds)
      if (shortcuts.isNotEmpty()) {
        val published = ShortcutManagerCompat.setDynamicShortcuts(
            this,
            shortcuts
        )
        if (!published) {
          result.error(
              "share_targets_rejected",
              "Android rejected share target shortcut update.",
              null
          )
          return
        }
      }
      storeShareTargetState(nextIds)
      result.success(null)
    } catch (exception: IllegalArgumentException) {
      result.error("share_targets_invalid", exception.message, null)
    } catch (exception: IllegalStateException) {
      result.error("share_targets_unavailable", exception.message, null)
    } catch (exception: SecurityException) {
      result.error("share_targets_denied", exception.message, null)
    }
  }

  private fun clearShareTargets(result: MethodChannel.Result) {
    try {
      removeShareTargets(storedShareTargetIds())
      storeShareTargetState(emptySet())
      result.success(null)
    } catch (exception: IllegalArgumentException) {
      result.error("share_targets_invalid", exception.message, null)
    } catch (exception: IllegalStateException) {
      result.error("share_targets_unavailable", exception.message, null)
    } catch (exception: SecurityException) {
      result.error("share_targets_denied", exception.message, null)
    }
  }

  private fun shareTargetsFromArguments(arguments: Any?): List<ShareTarget> {
    val values = arguments as? List<*> ?: return emptyList()
    return values.mapNotNull { value ->
      val map = value as? Map<*, *> ?: return@mapNotNull null
      val jid = (map["jid"] as? String)?.trim().orEmpty()
      if (jid.isEmpty()) {
        return@mapNotNull null
      }
      val label = (map["label"] as? String)?.trim()
      val avatarPath = (map["avatarPath"] as? String)?.trim()
      val avatarBytes = map["avatarBytes"] as? ByteArray
      val rank = (map["rank"] as? Number)?.toInt() ?: 0
      ShareTarget(
          jid = jid,
          label = if (label.isNullOrEmpty()) jid else label,
          avatarPath = avatarPath?.ifEmpty { null },
          avatarBytes = avatarBytes,
          rank = rank
      )
    }
  }

  private fun shortcutForShareTarget(target: ShareTarget): ShortcutInfoCompat {
    val icon = iconForShareTarget(target)
    val intent = Intent(this, ShareActivity::class.java).apply {
      action = Intent.ACTION_SEND
      type = "*/*"
      putExtra(shortcutIdExtra, target.jid)
      putExtra(conversationIdentifierExtra, target.jid)
    }
    val person = Person.Builder()
        .setKey(target.jid)
        .setName(target.label)
        .setIcon(icon)
        .build()
    return ShortcutInfoCompat.Builder(this, target.jid)
        .setShortLabel(target.label)
        .setLongLabel(target.label)
        .setCategories(setOf(shareTargetCategory))
        .setIntent(intent)
        .setIcon(icon)
        .setPerson(person)
        .setIsConversation()
        .setLongLived(true)
        .addCapabilityBinding("actions.intent.SEND_MESSAGE")
        .setRank(target.rank)
        .build()
  }

  private fun iconForShareTarget(target: ShareTarget): IconCompat {
    val avatarBytes = target.avatarBytes
    if (avatarBytes != null && avatarBytes.isNotEmpty()) {
      val bitmap = BitmapFactory.decodeByteArray(
          avatarBytes,
          0,
          avatarBytes.size
      )
      if (bitmap != null) {
        return IconCompat.createWithAdaptiveBitmap(
            adaptiveShortcutBitmapFor(target, bitmap)
        )
      }
    }
    val avatarPath = target.avatarPath
    if (!avatarPath.isNullOrEmpty()) {
      val avatar = File(avatarPath)
      if (avatar.isFile && avatar.canRead()) {
        val bitmap = BitmapFactory.decodeFile(avatar.path)
        if (bitmap != null) {
          return IconCompat.createWithAdaptiveBitmap(
              adaptiveShortcutBitmapFor(target, bitmap)
          )
        }
      }
    }
    return IconCompat.createWithAdaptiveBitmap(fallbackShortcutBitmapFor(target))
  }

  private fun adaptiveShortcutBitmapFor(target: ShareTarget, source: Bitmap): Bitmap {
    val size = shortcutIconSizePx()
    val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(output)
    canvas.drawColor(shortcutIconBackgroundColorFor(target))
    val sourceWidth = source.width
    val sourceHeight = source.height
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return fallbackShortcutBitmapFor(target)
    }
    val sourceAspectRatio = sourceWidth.toFloat() / sourceHeight.toFloat()
    val destinationAspectRatio = 1f
    val sourceRect = if (sourceAspectRatio > destinationAspectRatio) {
      val croppedWidth = (sourceHeight * destinationAspectRatio).toInt()
      val left = (sourceWidth - croppedWidth) / 2
      Rect(left, 0, left + croppedWidth, sourceHeight)
    } else {
      val croppedHeight = (sourceWidth / destinationAspectRatio).toInt()
      val top = (sourceHeight - croppedHeight) / 2
      Rect(0, top, sourceWidth, top + croppedHeight)
    }
    canvas.drawBitmap(
        source,
        sourceRect,
        RectF(0f, 0f, size.toFloat(), size.toFloat()),
        Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    )
    return output
  }

  private fun fallbackShortcutBitmapFor(target: ShareTarget): Bitmap {
    val size = shortcutIconSizePx()
    val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(output)
    canvas.drawColor(shortcutIconBackgroundColorFor(target))
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = Color.WHITE
      textAlign = Paint.Align.CENTER
      typeface = Typeface.DEFAULT_BOLD
      textSize = size * shortcutIconTextScale
    }
    val label = target.label.trim().ifEmpty { target.jid.trim() }
    val letter = label.firstOrNull()?.uppercaseChar()?.toString() ?: "#"
    val textBaseline = size / 2f - (paint.ascent() + paint.descent()) / 2f
    canvas.drawText(letter, size / 2f, textBaseline, paint)
    return output
  }

  private fun shortcutIconBackgroundColorFor(target: ShareTarget): Int {
    val colorIndex = (target.jid.hashCode() and Int.MAX_VALUE) %
        shortcutIconBackgroundColors.size
    return shortcutIconBackgroundColors[colorIndex]
  }

  private fun shortcutIconSizePx(): Int {
    return (shortcutIconSizeDp * resources.displayMetrics.density)
        .toInt()
        .coerceAtLeast(1)
  }

  private fun removeShareTargets(ids: Set<String>) {
    if (ids.isEmpty()) {
      return
    }
    val idList = ids.toList()
    ShortcutManagerCompat.removeDynamicShortcuts(this, idList)
    ShortcutManagerCompat.removeLongLivedShortcuts(this, idList)
  }

  private fun storedShareTargetIds(): Set<String> {
    return getSharedPreferences(shareTargetPreferencesName, MODE_PRIVATE)
        .getStringSet(shareTargetIdsKey, emptySet())
        ?.toSet()
        ?: emptySet()
  }

  private fun storedShareTargetSchemaVersion(): Int {
    return getSharedPreferences(shareTargetPreferencesName, MODE_PRIVATE)
        .getInt(shareTargetSchemaVersionKey, 0)
  }

  private fun storeShareTargetState(ids: Set<String>) {
    getSharedPreferences(shareTargetPreferencesName, MODE_PRIVATE)
        .edit()
        .putStringSet(shareTargetIdsKey, ids)
        .putInt(shareTargetSchemaVersionKey, shareTargetSchemaVersion)
        .apply()
  }

  private val flutterView: FlutterView?
    get() = findViewById(FlutterActivity.FLUTTER_VIEW_ID)
}

internal fun normalizeShareIntent(context: Context, intent: Intent?) {
  if (intent == null || intent.action != Intent.ACTION_SEND) {
    return
  }
  if (streamExtra(intent) != null) {
    return
  }
  val sharedUri = intent.data ?: return
  intent.putExtra(Intent.EXTRA_STREAM, sharedUri)
  if (intent.type == null) {
    intent.type = context.contentResolver.getType(sharedUri) ?: "*/*"
  }
}

internal fun isShareIntent(intent: Intent?): Boolean {
  return intent?.action == Intent.ACTION_SEND ||
      intent?.action == Intent.ACTION_SEND_MULTIPLE
}

private fun streamExtra(intent: Intent): Uri? {
  return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
  } else {
    @Suppress("DEPRECATION")
    intent.getParcelableExtra(Intent.EXTRA_STREAM)
  }
}

private data class ShareTarget(
    val jid: String,
    val label: String,
    val avatarPath: String?,
    val avatarBytes: ByteArray?,
    val rank: Int
)
