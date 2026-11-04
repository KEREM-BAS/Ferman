import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:ferman/engine/engine_service.dart';

/// An [EngineService] for widget tests and goldens: no native library.
class FakeEngineService implements EngineService {
  /// Creates a fake that reports [status].
  new({
    this.fakeStatus = const EngineStatus(
      appVersion: '0.1.0',
      apiVersion: kAppApiVersion,
      isDebugBuild: true,
      pdfium: PdfiumState.loaded,
      pdfiumTag: 'chromium/7881',
    ),
    this.documents = const {},
    this.failingPages = const {},
    this.searchResults = const {},
    this.textless = false,
    this.failures = const {},
    this.passwords = const {},
    this.ownerPasswords = const {},
    this.holds = const {},
    this.pageBlocks = const {},
  });

  /// What [textBlocks] returns, by page, for every document; other pages
  /// have no blocks. [caretAt] and [selection] treat every character of a
  /// line as equally wide.
  final Map<int, PageBlocks> pageBlocks;

  /// The status [status] returns.
  final EngineStatus fakeStatus;

  /// The documents [open] opens, by path; any other path is not found.
  final Map<String, OpenedDocument> documents;

  /// The paths whose [open] fails, with the error.
  final Map<String, EngineException> failures;

  /// The passwords of [documents] that need one (a1-8): [open] fails with
  /// `passwordRequired` without it and `wrongPassword` with another.
  final Map<String, String> passwords;

  /// The owner passwords of [documents] by id (a2-10): [unlockOwner]
  /// lifts their restrictions with it and fails with `wrongPassword` with
  /// another.
  final Map<int, String> ownerPasswords;

  /// The paths whose [open] waits for the future, as a slow file does
  /// (a1-7).
  final Map<String, Future<void>> holds;

  /// The documents whose owner password was given.
  final Set<int> ownerUnlocked = {};

  /// Pages whose items fail as damaged.
  final Set<int> failingPages;

  /// What [search] finds, by query: each list is one page's matches.
  final Map<String, List<List<SearchMatch>>> searchResults;

  /// Whether [search] reports that no page has text, as for a scan.
  final bool textless;

  /// The queries and options of every [search], oldest first.
  final List<(String, SearchOptions)> searches = [];

  /// The wanted sets of every [requestView], oldest first.
  final List<List<WantedItem>> requests = [];

  /// The visibilities of every [showLayers], oldest first.
  final List<List<bool>> layerRequests = [];

  /// Each document's render key, from [showLayers].
  final Map<int, int> _renderKeys = {};
  int _lastRenderKey = 0;

  final Map<int, (int, StreamController<ViewUpdate>)> _views = {};
  int _nextView = 1;

  /// How many views are open.
  int get openViewCount => _views.length;

  @override
  EngineApiVersion apiVersion() => fakeStatus.apiVersion;

  @override
  Future<EngineStatus> status() async => fakeStatus;

  @override
  Future<OpenedDocument> open(String path, {String? password}) async {
    await holds[path];
    if (failures[path] case final error?) throw error;
    if (passwords[path] case final expected? when password != expected) {
      throw password == null
          ? const EngineException(
              kind: EngineErrorKind.passwordRequired,
              messageKey: 'errorPasswordRequired',
            )
          : const EngineException(
              kind: EngineErrorKind.wrongPassword,
              messageKey: 'errorWrongPassword',
            );
    }
    return documents[path] ??
        (throw const EngineException(
          kind: EngineErrorKind.notFound,
          messageKey: 'errorFileNotFound',
        ));
  }

  /// The documents closed, oldest first.
  final List<int> closed = [];

  @override
  Future<Security?> unlockOwner(int document, String password) async {
    final opened = documents.values.where((opened) => opened.id == document);
    if (opened.isEmpty) {
      throw const EngineException(
        kind: EngineErrorKind.notFound,
        messageKey: 'errorFileNotFound',
      );
    }
    final security = opened.first.security;
    if (security == null) return null;
    if (ownerPasswords[document] != password) {
      throw const EngineException(
        kind: EngineErrorKind.wrongPassword,
        messageKey: 'errorWrongPassword',
      );
    }
    ownerUnlocked.add(document);
    return Security(
      method: security.method,
      keyBits: security.keyBits,
      userPasswordRequired: security.userPasswordRequired,
      permissions: security.permissions,
      owner: true,
    );
  }

  /// Ends the document's views.
  @override
  Future<void> close(int document) async {
    closed.add(document);
    for (final (owner, updates) in [..._views.values]) {
      if (owner == document) await updates.close();
    }
    _views.removeWhere((_, view) => view.$1 == document);
  }

  /// Records [visible] and gives every page of [document] a new render key.
  @override
  Future<int> showLayers(int document, List<bool> visible) async {
    layerRequests.add(visible);
    return _renderKeys[document] = ++_lastRenderKey;
  }

  /// The attachments [saveAttachment] saved: document, index, path and
  /// staging, oldest first.
  final List<(int, int, String, String?)> savedAttachments = [];

  /// The error [saveAttachment] throws, if any.
  EngineException? saveFailure;

  /// Records the save; with [staging] it names a staged file there.
  @override
  Future<String?> saveAttachment(
    int document,
    int index,
    String path, {
    String? staging,
  }) async {
    if (saveFailure case final error?) throw error;
    savedAttachments.add((document, index, path, staging));
    return staging == null ? null : '$staging/staged';
  }

  /// Orders [texts] by their code points, stably: no language rules.
  @override
  Future<List<int>> collationOrder(String locale, List<String> texts) async {
    final order = [for (var i = 0; i < texts.length; i++) i]
      ..sort((a, b) {
        final byText = texts[a].compareTo(texts[b]);
        return byText != 0 ? byText : a.compareTo(b);
      });
    return order;
  }

  /// Reports [searchResults] for [query] page by page, then the progress
  /// over every page and [SearchDone].
  @override
  Stream<SearchUpdate> search(
    int document,
    String query,
    SearchOptions options,
  ) async* {
    searches.add((query, options));
    final pages = documents.values
        .firstWhere((open) => open.id == document)
        .pages
        .length;
    for (final matches in searchResults[query] ?? const <List<SearchMatch>>[]) {
      yield SearchMatches(matches);
    }
    yield SearchProgress(searched: pages, pages: pages);
    yield SearchDone(textless: textless);
  }

  @override
  Future<PageBlocks> textBlocks(int document, int page) async =>
      pageBlocks[page] ?? const PageBlocks();

  TextBlock _block(int page, int id) =>
      pageBlocks[page]?.blocks.where((block) => block.id == id).firstOrNull ??
      (throw const EngineException(
        kind: EngineErrorKind.notFound,
        messageKey: 'errorInternal',
      ));

  /// The x of the caret before character [at] of [line].
  static double _x(TextLine line, int at) {
    final count = line.text.runes.length;
    return count == 0
        ? line.bbox.left
        : line.bbox.left + line.bbox.width * at.clamp(0, count) / count;
  }

  /// The caret on the line nearest [point], before the nearest character.
  @override
  Future<BlockCaret> caretAt(
    int document,
    int page,
    int block,
    Offset point,
  ) async {
    final found = _block(page, block);
    var start = 0;
    var best = (distance: double.infinity, index: 0, rect: Rect.zero);
    for (final line in found.lines) {
      final count = line.text.runes.length;
      final distance = point.dy < line.bbox.top
          ? line.bbox.top - point.dy
          : math.max(0, point.dy - line.bbox.bottom).toDouble();
      if (distance < best.distance) {
        final at = count == 0
            ? 0
            : ((point.dx - line.bbox.left) / line.bbox.width * count)
                  .round()
                  .clamp(0, count);
        final x = _x(line, at);
        best = (
          distance: distance,
          index: start + at,
          rect: Rect.fromLTRB(x, line.bbox.top, x, line.bbox.bottom),
        );
      }
      start += count + 1;
    }
    return BlockCaret(index: best.index, rect: best.rect);
  }

  /// The blocks between [anchor] and [focus] in reading order.
  @override
  Future<PageSelection> selection(
    int document,
    int page,
    BlockPosition anchor,
    BlockPosition focus,
  ) async {
    final blocks = pageBlocks[page]?.blocks ?? const <TextBlock>[];
    int order(BlockPosition at) =>
        blocks.indexWhere((block) => block.id == _block(page, at.block).id);
    final forward =
        order(anchor) < order(focus) ||
        (order(anchor) == order(focus) && anchor.index <= focus.index);
    final (from, to) = forward ? (anchor, focus) : (focus, anchor);
    final quads = <Rect>[];
    final texts = <String>[];
    for (var i = order(from); i <= order(to); i++) {
      final block = blocks[i];
      final low = i == order(from) ? from.index : 0;
      final high = i == order(to) ? to.index : block.text.runes.length;
      texts.add(
        String.fromCharCodes(block.text.runes.skip(low).take(high - low)),
      );
      var start = 0;
      for (final line in block.lines) {
        final count = line.text.runes.length;
        final a = (low - start).clamp(0, count);
        final b = (high - start).clamp(0, count);
        if (a < b) {
          quads.add(
            Rect.fromLTRB(
              _x(line, a),
              line.bbox.top,
              _x(line, b),
              line.bbox.bottom,
            ),
          );
        }
        start += count + 1;
      }
    }
    return PageSelection(quads: quads, text: texts.join('\n'));
  }

  /// A view that answers each wanted item with opaque white pixels of its
  /// size, or as damaged on [failingPages].
  @override
  Future<EngineView> openView(int document) async {
    final id = _nextView++;
    final updates = StreamController<ViewUpdate>();
    _views[id] = (document, updates);
    return EngineView(id: id, updates: updates.stream);
  }

  @override
  Future<void> requestView(
    int view,
    int generation,
    List<WantedItem> wanted,
  ) async {
    requests.add(wanted);
    final (owner, updates) =
        _views[view] ??
        (throw const EngineException(
          kind: EngineErrorKind.notFound,
          messageKey: 'errorInternal',
        ));
    final pages = documents.values
        .firstWhere((document) => document.id == owner)
        .pages;
    for (final WantedItem(:item) in wanted) {
      if (updates.isClosed) return;
      if (failingPages.contains(item.page)) {
        updates.add(
          FailedItem(
            item: item,
            generation: generation,
            reason: RenderFailure.pageDamaged,
          ),
        );
        continue;
      }
      final page = pages[item.page];
      final (width, height) = switch (item) {
        ThumbnailItem(:final size) =>
          page.width >= page.height
              ? (size, math.max(1, (size * page.height / page.width).round()))
              : (math.max(1, (size * page.width / page.height).round()), size),
        TileItem(
          :final zoomBucket,
          :final devicePixelRatio,
          :final column,
          :final row,
        ) =>
          () {
            final scale = math.pow(2, zoomBucket / 4) * devicePixelRatio;
            return (
              math.min(512, (page.width * scale).round() - column * 512),
              math.min(512, (page.height * scale).round() - row * 512),
            );
          }(),
      };
      updates.add(
        RenderedItem(
          item: item,
          generation: generation,
          renderKey: _renderKeys[owner] ?? 0,
          x: item is TileItem ? item.column * 512 : 0,
          y: item is TileItem ? item.row * 512 : 0,
          width: width,
          height: height,
          stride: width * 4,
          pixels: Uint8List(width * height * 4)
            ..fillRange(0, width * height * 4, 255),
        ),
      );
    }
  }

  @override
  Future<void> closeView(int view) async {
    await _views.remove(view)?.$2.close();
  }
}
