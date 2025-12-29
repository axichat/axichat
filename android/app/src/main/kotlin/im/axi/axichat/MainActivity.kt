package im.axi.axichat

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.MotionEvent
import android.view.WindowManager
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView

class MainActivity : FlutterActivity() {
  companion object {
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
    super.onCreate(savedInstanceState)
    window.setFlags(
      WindowManager.LayoutParams.FLAG_SECURE,
      WindowManager.LayoutParams.FLAG_SECURE,
    )
    flutterView?.filterTouchesWhenObscured = true
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

  private val flutterView: FlutterView?
    get() = findViewById(FlutterActivity.FLUTTER_VIEW_ID)
}
