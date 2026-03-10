package im.axi.axichat

import android.app.Application
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import com.pravera.flutter_foreground_task.service.ForegroundServiceManager
import io.flutter.embedding.engine.FlutterEngine

class AxiApplication : Application() {
  private val foregroundTaskLifecycleListener =
      object : FlutterForegroundTaskLifecycleListener {
        override fun onEngineCreate(flutterEngine: FlutterEngine?) = Unit

        override fun onTaskStart(starter: FlutterForegroundTaskStarter) {
          TaskRemovedWatcherService.start(applicationContext)
        }

        override fun onTaskRepeatEvent() = Unit

        override fun onTaskDestroy() {
          TaskRemovedWatcherService.stop(applicationContext)
        }

        override fun onEngineWillDestroy() = Unit
      }

  override fun onCreate() {
    super.onCreate()
    FlutterForegroundTaskPlugin.addTaskLifecycleListener(
      foregroundTaskLifecycleListener,
    )
    if (ForegroundServiceManager().isRunningService()) {
      TaskRemovedWatcherService.start(applicationContext)
    }
  }
}
