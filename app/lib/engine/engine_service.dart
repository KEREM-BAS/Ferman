import 'package:ferman/engine/engine_models.dart';

export 'package:ferman/engine/engine_models.dart';

/// The app's only way to reach the Rust engine. Feature code depends on this
/// interface; the bridge implementation lives in `engine_service_frb.dart`
/// and tests use `FakeEngineService`.
abstract interface class EngineService {
  /// The API version the engine speaks. The only synchronous engine call.
  EngineApiVersion apiVersion();

  /// Versions and build facts of the running engine, including PDFium.
  ///
  /// Throws an [EngineException] when the engine reports an error.
  Future<EngineStatus> status();

  /// Opens the PDF at [path], with [password] if it is encrypted. Without
  /// the password an encrypted file fails with
  /// [EngineErrorKind.passwordRequired]; open it again with the password.
  ///
  /// Throws an [EngineException] with the kind of the file's problem.
  Future<OpenedDocument> open(String path, {String? password});

  /// Closes a document and ends its views.
  Future<void> close(int document);

  /// Shows the layers of [document] whose [visible] is true and hides the
  /// others, in the order of its [OpenedDocument.layers], in every view.
  /// Returns every page's new render key: bitmaps with an older one show the
  /// layers as they were.
  ///
  /// Throws an [EngineException] when the document's layers cannot be
  /// switched ([OpenedDocument.layersSwitchable]).
  Future<int> showLayers(int document, List<bool> visible);

  /// Searches [document] for [query]: each page's matches as they are found,
  /// the progress, then [SearchDone]. Cancelling the subscription stops the
  /// search.
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  );

  /// Opens a view of [document] that renders nothing until [requestView].
  Future<EngineView> openView(int document);

  /// Replaces what [view] wants rendered, in priority order. A [generation]
  /// no newer than the view's last one is ignored.
  Future<void> requestView(int view, int generation, List<WantedItem> wanted);

  /// Closes a view; its updates end.
  Future<void> closeView(int view);

  /// The order of [texts] in the language of [locale], a BCP 47 tag such as
  /// `tr`: their indices, first to last (ICU4X's collator, ADR 0021). Digits
  /// compare by their value and equal texts keep their order.
  Future<List<int>> collationOrder(String locale, List<String> texts);
}

/// Why the engine could not be used.
enum EngineUnavailableReason {
  /// The engine library could not be loaded.
  libraryMissing,

  /// The engine speaks an API version the app does not accept.
  apiMismatch,

  /// This platform has no engine yet (the web build until phase 5).
  unsupportedPlatform,
}

/// Thrown by [EngineService] calls when the engine cannot be used at all.
class EngineUnavailableException implements Exception {
  /// Creates an exception.
  const new(this.reason, {this.engineApiVersion});

  /// Why the engine is unavailable.
  final EngineUnavailableReason reason;

  /// The version the engine reported, for
  /// [EngineUnavailableReason.apiMismatch].
  final EngineApiVersion? engineApiVersion;

  @override
  String toString() => 'EngineUnavailableException($reason)';
}

/// The [EngineService] used when the engine could not be started: every call
/// throws the [EngineUnavailableException] that explains why, so the app
/// still opens and can tell the person what is wrong.
class UnavailableEngineService implements EngineService {
  /// Creates a service that fails with [error].
  const new(this.error);

  /// Why the engine is unavailable.
  final EngineUnavailableException error;

  @override
  EngineApiVersion apiVersion() => throw error;

  @override
  Future<EngineStatus> status() async => throw error;

  @override
  Future<OpenedDocument> open(String path, {String? password}) async =>
      throw error;

  @override
  Future<void> close(int document) async => throw error;

  @override
  Future<int> showLayers(int document, List<bool> visible) async => throw error;

  @override
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  ) => Stream.error(error);

  @override
  Future<EngineView> openView(int document) async => throw error;

  @override
  Future<void> requestView(
    int view,
    int generation,
    List<WantedItem> wanted,
  ) async => throw error;

  @override
  Future<void> closeView(int view) async => throw error;

  @override
  Future<List<int>> collationOrder(String locale, List<String> texts) async =>
      throw error;
}
