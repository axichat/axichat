package im.axi.axichat

import android.os.Build
import android.os.Bundle
import android.view.MotionEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView

class MainActivity : FlutterActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
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

  private val flutterView: FlutterView?
    get() = findViewById(FlutterActivity.FLUTTER_VIEW_ID)
}
