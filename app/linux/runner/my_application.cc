#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include <cstring>

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
  // The "ferman/files" channel (app/lib/platform/file_access.dart): "openUrl"
  // and "show".
  FlMethodChannel* files_channel;
  // The "ferman/print" channel (app/lib/platform/print_service.dart, a9-6).
  FlMethodChannel* print_channel;
  // The print under way, from "begin" until GTK reports it done.
  GtkPrintOperation* print_operation;
  // "begin", waiting for the print dialog's answer.
  FlMethodCall* print_begin;
  // A page Dart sent before GTK asked for it.
  FlMethodCall* print_page;
  // The page just drawn, answered with the page GTK asks for next.
  FlMethodCall* print_drawn;
  // The page GTK asked for before Dart sent it, deferred, and its number.
  GtkPrintContext* print_context;
  gint print_wanted;
  // The pages of the print.
  gint print_count;
  // Whether pages are scaled to the printable area, or printed at their size.
  gboolean print_fit;
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

// Answers a "show" call with whether the file shows.
static void respond_shown(FlMethodCall* method_call, gboolean shown) {
  g_autoptr(FlValue) result = fl_value_new_bool(shown);
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, result, &error)) {
    g_warning("ferman/files: failed to respond: %s", error->message);
  }
}

// Opens the folder of |path| in the default file manager, without the file
// selected: the fallback where no file manager offers FileManager1.
static gboolean open_folder(const gchar* path) {
  g_autofree gchar* folder = g_path_get_dirname(path);
  g_autofree gchar* uri = g_filename_to_uri(folder, nullptr, nullptr);
  return uri != nullptr &&
         g_app_info_launch_default_for_uri(uri, nullptr, nullptr);
}

// The file manager's answer to ShowItems; when it failed, the folder opens.
static void show_items_cb(GObject* source, GAsyncResult* result,
                          gpointer user_data) {
  g_autoptr(FlMethodCall) method_call = FL_METHOD_CALL(user_data);
  g_autoptr(GVariant) reply = g_dbus_connection_call_finish(
      G_DBUS_CONNECTION(source), result, nullptr);
  const gchar* path =
      fl_value_get_string(fl_method_call_get_args(method_call));
  respond_shown(method_call, reply != nullptr || open_folder(path));
}

// Handles a call on the "ferman/files" channel. Linux answers "openUrl" and "show":
// the file selected in the file manager through the freedesktop
// org.freedesktop.FileManager1 ShowItems call on the session bus (a1-9b), or
// its folder opened when there is none. Bookmarks are macOS only, so the
// other calls are not implemented, which Dart treats as none.
static void files_method_call_cb(FlMethodChannel* channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  FlValue* args = fl_method_call_get_args(method_call);
  if (g_strcmp0(fl_method_call_get_name(method_call), "openUrl") == 0) {
    // Only what the engine offers, after the app's prompt (G145); the desktop
    // opens it.
    gboolean opened = FALSE;
    if (fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
      const gchar* url = fl_value_get_string(args);
      g_autofree gchar* scheme = g_uri_parse_scheme(url);
      if (g_ascii_strcasecmp(scheme != nullptr ? scheme : "", "http") == 0 ||
          g_ascii_strcasecmp(scheme != nullptr ? scheme : "", "https") == 0 ||
          g_ascii_strcasecmp(scheme != nullptr ? scheme : "", "mailto") == 0) {
        opened = g_app_info_launch_default_for_uri(url, nullptr, nullptr);
      }
    }
    respond_shown(method_call, opened);
    return;
  }
  if (g_strcmp0(fl_method_call_get_name(method_call), "show") != 0) {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }
  if (fl_value_get_type(args) != FL_VALUE_TYPE_STRING ||
      !g_file_test(fl_value_get_string(args), G_FILE_TEST_EXISTS)) {
    respond_shown(method_call, FALSE);
    return;
  }
  const gchar* path = fl_value_get_string(args);
  g_autofree gchar* uri = g_filename_to_uri(path, nullptr, nullptr);
  GDBusConnection* bus =
      g_application_get_dbus_connection(G_APPLICATION(self));
  if (uri == nullptr || bus == nullptr) {
    respond_shown(method_call, open_folder(path));
    return;
  }
  const gchar* uris[] = {uri, nullptr};
  g_dbus_connection_call(
      bus, "org.freedesktop.FileManager1", "/org/freedesktop/FileManager1",
      "org.freedesktop.FileManager1", "ShowItems",
      g_variant_new("(^ass)", uris, ""), nullptr, G_DBUS_CALL_FLAGS_NONE,
      // The default timeout: a file manager started cold may take seconds,
      // and a fallback after a short one would open a second window.
      -1, nullptr, show_items_cb, g_object_ref(method_call));
}

// Answers a "ferman/print" call with |done|.
static void respond_print(FlMethodCall* method_call, gboolean done) {
  g_autoptr(FlValue) result = fl_value_new_bool(done);
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, result, &error)) {
    g_warning("ferman/print: failed to respond: %s", error->message);
  }
}

// Answers a "page" call with the number of the page GTK wants next (from 0;
// the page count once the print is complete). GTK picks the pages, their
// order and the copies it makes itself from its dialog's Range, Only print,
// Reverse and Copies, so Dart sends the page it names.
static void respond_print_next(FlMethodCall* method_call, gint next) {
  g_autoptr(FlValue) result = fl_value_new_int(next);
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, result, &error)) {
    g_warning("ferman/print: failed to respond: %s", error->message);
  }
}

// Answers the waiting "begin" with |done|.
static void print_answer_begin(MyApplication* self, gboolean done) {
  if (self->print_begin == nullptr) {
    return;
  }
  respond_print(self->print_begin, done);
  g_clear_object(&self->print_begin);
}

// Draws the page of |method_call|'s arguments, 8-bit BGRA, opaque, the top
// row first, on |context|; FALSE when the arguments are not a page.
static gboolean print_draw(MyApplication* self, GtkPrintContext* context,
                           FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return FALSE;
  }
  FlValue* width_value = fl_value_lookup_string(args, "width");
  FlValue* height_value = fl_value_lookup_string(args, "height");
  FlValue* width_points = fl_value_lookup_string(args, "widthPoints");
  FlValue* height_points = fl_value_lookup_string(args, "heightPoints");
  FlValue* pixels = fl_value_lookup_string(args, "pixels");
  if (width_value == nullptr || height_value == nullptr ||
      width_points == nullptr || height_points == nullptr ||
      pixels == nullptr ||
      fl_value_get_type(width_value) != FL_VALUE_TYPE_INT ||
      fl_value_get_type(height_value) != FL_VALUE_TYPE_INT ||
      fl_value_get_type(width_points) != FL_VALUE_TYPE_FLOAT ||
      fl_value_get_type(height_points) != FL_VALUE_TYPE_FLOAT ||
      fl_value_get_type(pixels) != FL_VALUE_TYPE_UINT8_LIST) {
    return FALSE;
  }
  int64_t width = fl_value_get_int(width_value);
  int64_t height = fl_value_get_int(height_value);
  double drawn_width = fl_value_get_float(width_points);
  double drawn_height = fl_value_get_float(height_points);
  if (width <= 0 || height <= 0 || width > G_MAXINT / 4 ||
      height > G_MAXINT || drawn_width <= 0 || drawn_height <= 0 ||
      fl_value_get_length(pixels) <
          static_cast<size_t>(width) * static_cast<size_t>(height) * 4) {
    return FALSE;
  }
  // A surface of its own: the print surface may keep it until the page ends.
  cairo_surface_t* image = cairo_image_surface_create(
      CAIRO_FORMAT_RGB24, static_cast<int>(width), static_cast<int>(height));
  if (cairo_surface_status(image) != CAIRO_STATUS_SUCCESS) {
    cairo_surface_destroy(image);
    return FALSE;
  }
  cairo_surface_flush(image);
  unsigned char* target = cairo_image_surface_get_data(image);
  int stride = cairo_image_surface_get_stride(image);
  const uint8_t* source = fl_value_get_uint8_list(pixels);
  for (int64_t row = 0; row < height; row++) {
    memcpy(target + row * stride, source + row * width * 4, width * 4);
  }
  cairo_surface_mark_dirty(image);
  double area_width = gtk_print_context_get_width(context);
  double area_height = gtk_print_context_get_height(context);
  if (self->print_fit) {
    double scale = MIN(area_width / drawn_width, area_height / drawn_height);
    drawn_width *= scale;
    drawn_height *= scale;
  }
  cairo_t* cr = gtk_print_context_get_cairo_context(context);
  cairo_save(cr);
  cairo_translate(cr, (area_width - drawn_width) / 2,
                  (area_height - drawn_height) / 2);
  cairo_scale(cr, drawn_width / width, drawn_height / height);
  cairo_set_source_surface(cr, image, 0, 0);
  cairo_paint(cr);
  cairo_restore(cr);
  cairo_surface_destroy(image);
  return TRUE;
}

// The page number Dart gave a "page" call, or -1.
static gint print_index(FlMethodCall* method_call) {
  FlValue* args = fl_method_call_get_args(method_call);
  FlValue* index = fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                       ? fl_value_lookup_string(args, "index")
                       : nullptr;
  if (index == nullptr || fl_value_get_type(index) != FL_VALUE_TYPE_INT ||
      fl_value_get_int(index) < 0 || fl_value_get_int(index) > G_MAXINT) {
    return -1;
  }
  return static_cast<gint>(fl_value_get_int(index));
}

// The dialog was accepted: Dart starts sending pages.
static void print_begin_cb(GtkPrintOperation* operation,
                           GtkPrintContext* context, gpointer user_data) {
  print_answer_begin(MY_APPLICATION(user_data), TRUE);
}

// GTK wants page |page_nr|: the page drawn before learns it is next; drawn
// now when Dart sent it, deferred otherwise, and a page Dart sent that is not
// this one is answered with the one GTK wants.
static void print_draw_page_cb(GtkPrintOperation* operation,
                               GtkPrintContext* context, gint page_nr,
                               gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->print_drawn != nullptr) {
    g_autoptr(FlMethodCall) drawn = self->print_drawn;
    self->print_drawn = nullptr;
    respond_print_next(drawn, page_nr);
  }
  if (self->print_page != nullptr) {
    g_autoptr(FlMethodCall) page = self->print_page;
    self->print_page = nullptr;
    if (print_index(page) != page_nr) {
      respond_print_next(page, page_nr);
    } else if (print_draw(self, context, page)) {
      self->print_drawn = FL_METHOD_CALL(g_object_ref(page));
      return;
    } else {
      respond_print(page, FALSE);
      gtk_print_operation_cancel(operation);
      return;
    }
  }
  gtk_print_operation_set_defer_drawing(operation);
  self->print_context = context;
  self->print_wanted = page_nr;
}

// The print ended, sent, cancelled or failed: whatever still waits hears so.
static void print_done_cb(GtkPrintOperation* operation,
                          GtkPrintOperationResult result, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  print_answer_begin(self, FALSE);
  if (self->print_page != nullptr) {
    respond_print(self->print_page, FALSE);
    g_clear_object(&self->print_page);
  }
  // The last page drawn: complete, or stopped.
  if (self->print_drawn != nullptr) {
    if (result == GTK_PRINT_OPERATION_RESULT_APPLY) {
      respond_print_next(self->print_drawn, self->print_count);
    } else {
      respond_print(self->print_drawn, FALSE);
    }
    g_clear_object(&self->print_drawn);
  }
  self->print_context = nullptr;
  if (self->print_operation == operation) {
    g_clear_object(&self->print_operation);
  }
}

// The value of |key| in the map |args|, or nullptr.
static FlValue* print_argument(FlValue* args, const gchar* key) {
  return fl_value_get_type(args) == FL_VALUE_TYPE_MAP
             ? fl_value_lookup_string(args, key)
             : nullptr;
}

// Handles a call on the "ferman/print" channel (decision 29): "begin" shows
// the GTK print dialog for "pages" pages, "page" draws page "index" as Dart
// sends it, after the one before, so a long document never waits in memory,
// and answers with the page GTK wants next, "end" lets GTK send what was
// drawn and "abort" cancels.
static void print_method_call_cb(FlMethodChannel* channel,
                                 FlMethodCall* method_call,
                                 gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);
  if (g_strcmp0(method, "begin") == 0) {
    if (self->print_operation != nullptr) {
      gtk_print_operation_cancel(self->print_operation);
    }
    FlValue* name = print_argument(args, "name");
    FlValue* pages = print_argument(args, "pages");
    FlValue* fit = print_argument(args, "fit");
    if (pages == nullptr || fl_value_get_type(pages) != FL_VALUE_TYPE_INT ||
        fl_value_get_int(pages) <= 0 || fl_value_get_int(pages) > G_MAXINT) {
      respond_print(method_call, FALSE);
      return;
    }
    self->print_count = static_cast<gint>(fl_value_get_int(pages));
    self->print_fit = fit == nullptr ||
                      fl_value_get_type(fit) != FL_VALUE_TYPE_BOOL ||
                      fl_value_get_bool(fit);
    GtkPrintOperation* operation = gtk_print_operation_new();
    self->print_operation = operation;
    self->print_begin = FL_METHOD_CALL(g_object_ref(method_call));
    gtk_print_operation_set_n_pages(operation,
                                    static_cast<gint>(fl_value_get_int(pages)));
    if (name != nullptr && fl_value_get_type(name) == FL_VALUE_TYPE_STRING) {
      gtk_print_operation_set_job_name(operation, fl_value_get_string(name));
    }
    gtk_print_operation_set_unit(operation, GTK_UNIT_POINTS);
    gtk_print_operation_set_allow_async(operation, TRUE);
    g_signal_connect(operation, "begin-print", G_CALLBACK(print_begin_cb),
                     self);
    g_signal_connect(operation, "draw-page", G_CALLBACK(print_draw_page_cb),
                     self);
    g_signal_connect(operation, "done", G_CALLBACK(print_done_cb), self);
    GtkPrintOperationResult result = gtk_print_operation_run(
        operation, GTK_PRINT_OPERATION_ACTION_PRINT_DIALOG, self->window,
        nullptr);
    if (result == GTK_PRINT_OPERATION_RESULT_ERROR ||
        result == GTK_PRINT_OPERATION_RESULT_CANCEL) {
      print_answer_begin(self, FALSE);
    }
    return;
  }
  if (g_strcmp0(method, "page") == 0) {
    if (self->print_operation == nullptr || self->print_page != nullptr ||
        self->print_drawn != nullptr || print_index(method_call) < 0) {
      respond_print(method_call, FALSE);
    } else if (self->print_context == nullptr) {
      self->print_page = FL_METHOD_CALL(g_object_ref(method_call));
    } else if (print_index(method_call) != self->print_wanted) {
      respond_print_next(method_call, self->print_wanted);
    } else {
      GtkPrintContext* context = self->print_context;
      self->print_context = nullptr;
      if (print_draw(self, context, method_call)) {
        // Answered at the next draw-page, or when the print is done.
        self->print_drawn = FL_METHOD_CALL(g_object_ref(method_call));
        gtk_print_operation_draw_page_finish(self->print_operation);
      } else {
        respond_print(method_call, FALSE);
        gtk_print_operation_draw_page_finish(self->print_operation);
        gtk_print_operation_cancel(self->print_operation);
      }
    }
    return;
  }
  if (g_strcmp0(method, "end") == 0) {
    // GTK sends the print once the last page is drawn.
    respond_print(method_call, self->print_operation != nullptr);
    return;
  }
  if (g_strcmp0(method, "abort") == 0) {
    if (self->print_operation != nullptr) {
      gtk_print_operation_cancel(self->print_operation);
      if (self->print_context != nullptr) {
        self->print_context = nullptr;
        gtk_print_operation_draw_page_finish(self->print_operation);
      }
    }
    respond_print(method_call, TRUE);
    return;
  }
  g_autoptr(FlMethodResponse) response =
      FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  fl_method_call_respond(method_call, response, nullptr);
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
  self->files_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), "ferman/files",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->files_channel, files_method_call_cb, self, nullptr);
  self->print_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), "ferman/print",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->print_channel, print_method_call_cb, self, nullptr);

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
  g_clear_object(&self->files_channel);
  g_clear_object(&self->print_channel);
  g_clear_object(&self->print_begin);
  g_clear_object(&self->print_page);
  g_clear_object(&self->print_drawn);
  g_clear_object(&self->print_operation);
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
