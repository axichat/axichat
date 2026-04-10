#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <glib.h>
#include <glib/gstdio.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static gchar* build_executable_dir() {
  g_autofree gchar* executable_path = g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path == nullptr) {
    return nullptr;
  }

  return g_path_get_dirname(executable_path);
}

static gchar* build_first_existing_path(const gchar* base_dir,
                                        const gchar* const* relative_candidates,
                                        guint candidate_count,
                                        GFileTest file_test) {
  for (guint i = 0; i < candidate_count; ++i) {
    g_autofree gchar* candidate =
        g_build_filename(base_dir, relative_candidates[i], nullptr);
    if (g_file_test(candidate, file_test)) {
      return g_strdup(candidate);
    }
  }

  return nullptr;
}

static void prepend_env_directory(const gchar* variable_name,
                                  const gchar* directory,
                                  const gchar* fallback_suffix = nullptr) {
  const gchar* current_value = g_getenv(variable_name);
  if (current_value == nullptr || *current_value == '\0') {
    if (fallback_suffix == nullptr) {
      g_setenv(variable_name, directory, TRUE);
    } else {
      g_autofree gchar* new_value =
          g_strdup_printf("%s:%s", directory, fallback_suffix);
      g_setenv(variable_name, new_value, TRUE);
    }
    return;
  }

  g_autofree gchar* new_value = g_strdup_printf("%s:%s", directory, current_value);
  g_setenv(variable_name, new_value, TRUE);
}

// The bundled WPE runtime uses bundle-relative helper/resource paths, so the
// process must start from the bundle root before plugin registration.
static void configure_wpe_environment() {
  g_autofree gchar* executable_dir = build_executable_dir();
  if (executable_dir == nullptr) {
    return;
  }

  g_chdir(executable_dir);

  g_autofree gchar* bundle_lib_dir = g_build_filename(executable_dir, "lib", nullptr);
  if (g_file_test(bundle_lib_dir, G_FILE_TEST_IS_DIR)) {
    prepend_env_directory("LD_LIBRARY_PATH", bundle_lib_dir);
  }

  const gchar* runtime_candidates[] = {
      "lib/wpe-webkit-2.0",
      "lib/wpe-webkit-1.1",
      "lib/wpe-webkit-1.0",
  };
  g_autofree gchar* runtime_dir = build_first_existing_path(
      executable_dir, runtime_candidates, G_N_ELEMENTS(runtime_candidates),
      G_FILE_TEST_IS_DIR);
  if (runtime_dir != nullptr) {
    prepend_env_directory("PATH", runtime_dir);

    g_autofree gchar* injected_bundle_dir =
        g_build_filename(runtime_dir, "injected-bundle", nullptr);
    if (g_file_test(injected_bundle_dir, G_FILE_TEST_IS_DIR)) {
      g_setenv("WEBKIT_INJECTED_BUNDLE_PATH", injected_bundle_dir, TRUE);
    }
  }

  g_autofree gchar* share_dir = g_build_filename(executable_dir, "share", nullptr);
  if (g_file_test(share_dir, G_FILE_TEST_IS_DIR)) {
    prepend_env_directory("XDG_DATA_DIRS", share_dir, "/usr/local/share:/usr/share");
  }

  const gchar* data_candidates[] = {
      "share/wpe-webkit-2.0",
      "share/wpe-webkit-1.1",
      "share/wpe-webkit-1.0",
  };
  g_autofree gchar* inspector_resources_dir = build_first_existing_path(
      executable_dir, data_candidates, G_N_ELEMENTS(data_candidates),
      G_FILE_TEST_IS_DIR);
  if (inspector_resources_dir != nullptr) {
    g_setenv("WEBKIT_INSPECTOR_RESOURCES_PATH", inspector_resources_dir, TRUE);
  }
}

static gchar* build_icon_path() {
  g_autofree gchar* executable_dir = build_executable_dir();
  if (executable_dir == nullptr) {
    return nullptr;
  }

  const gchar* relative_candidates[] = {
      "data/app_icon.png",
      "data/flutter_assets/assets/icons/generated/app_icon_linux.png",
      "share/icons/hicolor/256x256/apps/im.axi.axichat.png",
      "share/icons/hicolor/512x512/apps/im.axi.axichat.png",
  };
  return build_first_existing_path(executable_dir, relative_candidates,
                                   G_N_ELEMENTS(relative_candidates),
                                   G_FILE_TEST_IS_REGULAR);
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_icon_name(window, APPLICATION_ID);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Axichat");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Axichat");
  }

  g_autofree gchar* icon_path = build_icon_path();
  if (icon_path != nullptr) {
    g_autoptr(GError) error = nullptr;
    gtk_window_set_icon_from_file(window, icon_path, &error);
    if (error != nullptr) {
      g_warning("Failed to set window icon from %s: %s", icon_path, error->message);
    }
  } else {
    g_warning("Failed to resolve application icon path.");
  }

  gtk_window_set_default_size(window, 1360, 760);
  configure_wpe_environment();

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
#if !defined(NDEBUG)
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);
#else
  // Drop external args in release builds to reduce untrusted input.
  self->dart_entrypoint_arguments = g_new0(gchar*, 1);
#endif

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
