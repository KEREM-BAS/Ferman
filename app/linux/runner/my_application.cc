#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  // The "ferman/window" channel (see app/lib/app/platform_window.dart).
  FlMethodChannel* window_channel;
  // The window, once activated; cleared when it is destroyed.
  GtkWindow* window;
  // The "ferman/open" channel (ADR 0021, app/lib/platform/open_requests.dart).
  FlMethodChannel* open_channel;
  // The files a second launch asked for before Dart called "ready".
  GPtrArray* kept_paths;
  // Whether Dart called "ready": later files go out at once as "open".
  gboolean open_ready;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Handles a call on the "ferman/window" channel. Linux answers only
// "doubleClickSettings" (the GTK double-click time and distance, so the title
// bar counts double-clicks as the desktop does); the macOS and Windows calls
// are not implemented here, which the Flutter side expects.
static void window_method_call_cb(FlMethodChannel* channel,
                                  FlMethodCall* method_call,
                                  gpointer user_data) {
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(method_call),
                "doubleClickSettings") == 0) {
    gint time = 0;
    gint distance = 0;
    g_object_get(gtk_settings_get_default(), "gtk-double-click-time", &time,
                 "gtk-double-click-distance", &distance, nullptr);
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "interval", fl_value_new_int(time));
    fl_value_set_string_take(result, "distance",
                             fl_value_new_float(static_cast<double>(distance)));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("ferman/window: failed to respond: %s", error->message);
  }
}

// Handles a call on the "ferman/open" channel: "ready" answers with the files
// kept so far, and from then on each request is sent as "open".
static void open_method_call_cb(FlMethodChannel* channel,
                                FlMethodCall* method_call,
                                gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(method_call), "ready") == 0) {
    g_autoptr(FlValue) result = fl_value_new_list();
    for (guint i = 0; i < self->kept_paths->len; i++) {
      fl_value_append_take(
          result, fl_value_new_string(static_cast<const gchar*>(
                      g_ptr_array_index(self->kept_paths, i))));
    }
    g_ptr_array_set_size(self->kept_paths, 0);
    self->open_ready = TRUE;
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("ferman/open: failed to respond: %s", error->message);
  }
}

// Sets the window icon from data/app_icon.png beside the executable (made by
// tools/app-icons, installed by CMakeLists.txt). Without it the window keeps
// the desktop's generic icon; a packaged Ferman's .desktop file names its own.
static void set_window_icon(GtkWindow* window) {
  g_autofree gchar* executable = g_file_read_link("/proc/self/exe", nullptr);
  if (executable == nullptr) {
    return;
  }
  g_autofree gchar* directory = g_path_get_dirname(executable);
  g_autofree gchar* icon =
      g_build_filename(directory, "data", "app_icon.png", nullptr);
  g_autoptr(GError) error = nullptr;
  if (!gtk_window_set_icon_from_file(window, icon, &error)) {
    g_warning("Could not load the window icon %s: %s", icon, error->message);
  }
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// The local path of |file| when Dart can take it: not a remote location, and
// valid UTF-8 (the platform channel and Dart's strings need it); else null.
static gchar* dart_path(GFile* file) {
  gchar* path = g_file_get_path(file);
  if (path != nullptr && !g_utf8_validate(path, -1, nullptr)) {
    g_warning("Not opening a file whose name is not UTF-8");
    g_clear_pointer(&path, g_free);
  }
  return path;
}

// Implements GApplication::activate. A second launch activates the running
// instance over D-Bus, which brings its window forward once it shows (it
// shows with Flutter's first frame).
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  if (self->window != nullptr) {
    if (gtk_widget_get_visible(GTK_WIDGET(self->window))) {
      gtk_window_present(self->window);
    }
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  g_object_add_weak_pointer(G_OBJECT(window),
                            reinterpret_cast<gpointer*>(&self->window));

  // Ferman draws its own title bar on Linux too, with client-side
  // decorations and the caption buttons at the end (G15, Q12). A GTK header
  // bar makes the window client-side decorated on every desktop; when the
  // app switches to its own title bar, window_manager hides the header bar
  // and the window keeps its shadow and resize edges. Until then the header
  // bar is the title bar.
  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_header_bar_set_title(header_bar, "Ferman");
  gtk_header_bar_set_show_close_button(header_bar, TRUE);
  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  gtk_window_set_title(window, "Ferman");
  set_window_icon(window);

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

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

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "ferman/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->window_channel, window_method_call_cb, self, nullptr);
  self->open_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), "ferman/open",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->open_channel, open_method_call_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::open: the files a second launch forwarded over
// D-Bus (G_APPLICATION_HANDLES_OPEN). They open in this instance's window,
// which comes forward.
static void my_application_open(GApplication* application, GFile** files,
                                gint n_files, const gchar* hint) {
  MyApplication* self = MY_APPLICATION(application);
  my_application_activate(application);
  g_autoptr(FlValue) paths = fl_value_new_list();
  for (gint i = 0; i < n_files; i++) {
    g_autofree gchar* path = dart_path(files[i]);
    if (path == nullptr) {
      continue;
    }
    if (self->open_ready) {
      fl_value_append_take(paths, fl_value_new_string(path));
    } else {
      g_ptr_array_add(self->kept_paths, g_strdup(path));
    }
  }
  if (self->open_ready && fl_value_get_length(paths) > 0) {
    fl_method_channel_invoke_method(self->open_channel, "open", paths, nullptr,
                                    nullptr, nullptr);
  }
}

// Implements GApplication::local_command_line. The arguments after the
// binary name are files, made absolute here: the first instance passes them
// to Dart, and a later one (GApplication's D-Bus uniqueness, ADR 0021)
// forwards them to the running instance and exits. Without a session bus
// GApplication registers as non-unique, and every launch is its own
// instance.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  g_autoptr(GPtrArray) files = g_ptr_array_new_with_free_func(g_object_unref);
  g_autoptr(GPtrArray) paths = g_ptr_array_new_with_free_func(g_free);
  for (gchar** argument = *arguments + 1; *argument != nullptr; argument++) {
    GFile* file = g_file_new_for_commandline_arg(*argument);
    gchar* path = dart_path(file);
    if (path == nullptr) {
      g_object_unref(file);
      continue;
    }
    g_ptr_array_add(files, file);
    g_ptr_array_add(paths, path);
  }
  g_ptr_array_add(paths, nullptr);
  self->dart_entrypoint_arguments = g_strdupv(
      reinterpret_cast<gchar**>(paths->pdata));

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  if (g_application_get_is_remote(application) && files->len > 0) {
    g_application_open(application, reinterpret_cast<GFile**>(files->pdata),
                       static_cast<gint>(files->len), "");
  } else {
    g_application_activate(application);
  }
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->window_channel);
  g_clear_object(&self->open_channel);
  g_clear_pointer(&self->kept_paths, g_ptr_array_unref);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->open = my_application_open;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {
  self->kept_paths = g_ptr_array_new_with_free_func(g_free);
}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

#ifdef NDEBUG
  const gchar* id = APPLICATION_ID;
#else
  // A debug build (flutter run, the integration test) never hands its files
  // to an installed Ferman, nor takes those of a later launch of one.
  const gchar* id = APPLICATION_ID ".debug";
#endif
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", id, "flags",
                                     G_APPLICATION_HANDLES_OPEN, nullptr));
}
