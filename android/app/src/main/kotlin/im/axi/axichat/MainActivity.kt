package im.axi.axichat

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView

class MainActivity : FlutterActivity() {
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
    if (isTouchObscured(event)) {
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
