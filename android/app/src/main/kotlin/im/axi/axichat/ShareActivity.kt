package im.axi.axichat

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class ShareActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    forwardIntentToMainActivity(intent)
    finish()
  }

  override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    setIntent(intent)
    forwardIntentToMainActivity(intent)
    finish()
  }

  private fun forwardIntentToMainActivity(source: Intent?) {
    val forwardedIntent = if (isShareIntent(source)) {
      shareIntentForMainActivity(source)
    } else {
      launcherIntentForMainActivity()
    }
    startActivity(forwardedIntent)
  }

  private fun shareIntentForMainActivity(source: Intent?): Intent {
    val forwardedIntent = Intent(source).apply {
      setClass(this@ShareActivity, MainActivity::class.java)
      setSelector(null)
      setFlags((source?.flags ?: 0) and uriPermissionGrantFlags)
      addFlags(
          Intent.FLAG_ACTIVITY_NEW_TASK or
              Intent.FLAG_ACTIVITY_CLEAR_TOP or
              Intent.FLAG_ACTIVITY_SINGLE_TOP or
              Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
      )
    }
    normalizeShareIntent(this, forwardedIntent)
    return forwardedIntent
  }

  private fun launcherIntentForMainActivity(): Intent {
    return Intent(this, MainActivity::class.java).apply {
      action = Intent.ACTION_MAIN
      addCategory(Intent.CATEGORY_LAUNCHER)
      addFlags(
          Intent.FLAG_ACTIVITY_NEW_TASK or
              Intent.FLAG_ACTIVITY_CLEAR_TOP or
              Intent.FLAG_ACTIVITY_SINGLE_TOP or
              Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
      )
    }
  }

  private companion object {
    private const val uriPermissionGrantFlags =
        Intent.FLAG_GRANT_READ_URI_PERMISSION or
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
            Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
            Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
  }
}
