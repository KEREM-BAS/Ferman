import 'dart:async';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/organize/page_commands.dart';
import 'package:ferman/features/organize/page_range.dart';
import 'package:ferman/features/organize/page_size_fields.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/region.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'crop_session.g.dart';

/// a6-4's Apply to.
enum CropScope {
  /// The reader's page.
  thisPage,

  /// Every page.
  all,

  /// The pages of the range, filtered by parity.
  pages,
}

/// a6-4's "Which pages".
enum PageParity {
  /// All pages in the range.
  all,

  /// Odd pages.
  odd,

  /// Even pages.
  even,
}

/// What less than a point of a page the engine refuses (`crop_pages`).
const double smallestCroppedSide = 1;

/// The crop tool's choices (a6-4), while it is open.
///
/// shortcut: margins stop at the crop box, so a crop saved earlier cannot be
/// given back here though the engine could (negative margins); upgrade once
/// [PageInfo] carries the media box.
@immutable
final class CropSession {
  /// The tool on [document].
  const new({
    required this.document,
    required this.scope,
    this.range = '',
    this.parity = PageParity.all,
    this.margins = const PageMargins(),
    this.detected,
    this.size = PageSizeChoice.keep,
    this.custom = Size.zero,
    this.fit = PageFit.centre,
  });

  /// The document's id.
  final int document;

  /// Which pages it applies to.
  final CropScope scope;

  /// The range of [CropScope.pages] as typed; empty names every page.
  final String range;

  /// Which pages of the range.
  final PageParity parity;

  /// The margins typed or dragged, in displayed points.
  final PageMargins margins;

  /// What "Remove white margins" found for each page by handle, until margins
  /// are typed or dragged, or the pages change.
  final Map<int, PageMargins>? detected;

  /// The page size chosen.
  final PageSizeChoice size;

  /// The size of [PageSizeChoice.custom], in points.
  final Size custom;

  /// What the new size does to the content.
  final PageFit fit;

  /// The margins of the page [handle].
  PageMargins marginsOf(int handle) {
    final found = detected;
    return found == null ? margins : found[handle] ?? const PageMargins();
  }

  /// Whether any margin of the session is more than nothing.
  bool get crops {
    bool some(PageMargins m) =>
        m.top != 0 || m.bottom != 0 || m.left != 0 || m.right != 0;
    final found = detected;
    return found == null ? some(margins) : found.values.any(some);
  }

  /// The indices of the pages it applies to, with [current] the reader's page,
  /// in a document of [count] pages; null for a range it cannot read.
  List<int>? targets(int current, int count) => switch (scope) {
    CropScope.thisPage => [current],
    CropScope.all => [for (var i = 0; i < count; i++) i],
    CropScope.pages => switch (parsePageRange(range, count)) {
      null => null,
      final typed => [
        for (final page
            in typed.isEmpty ? [for (var i = 0; i < count; i++) i] : typed)
          if (switch (parity) {
            PageParity.all => true,
            PageParity.odd => page.isEven,
            PageParity.even => page.isOdd,
          })
            page,
      ],
    },
  };

  /// The first of [pages] of [document] these margins leave nothing of.
  int? tooMuch(OpenedDocument document, List<int> pages) {
    for (final index in pages) {
      final page = document.pages.elementAtOrNull(index);
      if (page == null) continue;
      final m = marginsOf(document.pageHandle(index));
      if (page.width - m.left - m.right < smallestCroppedSide ||
          page.height - m.top - m.bottom < smallestCroppedSide) {
        return index;
      }
    }
    return null;
  }

  /// The new size, null for none.
  Size? get newSize => switch (size) {
    PageSizeChoice.keep => null,
    PageSizeChoice.a4 => Size(
      PaperSize.a4.widthPoints,
      PaperSize.a4.heightPoints,
    ),
    PageSizeChoice.letter => Size(
      PaperSize.letter.widthPoints,
      PaperSize.letter.heightPoints,
    ),
    PageSizeChoice.custom => custom,
  };

  /// A copy with the given values; [detected] goes unless kept.
  CropSession copyWith({
    CropScope? scope,
    String? range,
    PageParity? parity,
    PageMargins? margins,
    Map<int, PageMargins>? detected,
    bool keepDetected = true,
    PageSizeChoice? size,
    Size? custom,
    PageFit? fit,
  }) => CropSession(
    document: document,
    scope: scope ?? this.scope,
    range: range ?? this.range,
    parity: parity ?? this.parity,
    margins: margins ?? this.margins,
    detected: detected ?? (keepDetected ? this.detected : null),
    size: size ?? this.size,
    custom: custom ?? this.custom,
    fit: fit ?? this.fit,
  );
}

/// Whether the crop tool shows: in Organize, on its own document.
@riverpod
bool cropShowing(Ref ref) {
  final session = ref.watch(organizeCropProvider);
  return session != null &&
      ref.watch(shellModeProvider) == FermanMode.organize &&
      ref.watch(viewerProvider.select((view) => view?.document.id)) ==
          session.document;
}

/// The crop tool, as `organizeCropProvider`: null while it is closed. It works
/// on the reader's page in the canvas, with its panel in the right panel's
/// place.
@Riverpod(keepAlive: true)
class OrganizeCrop extends _$OrganizeCrop {
  @override
  CropSession? build() => null;

  /// Opens the tool on [document], for [pages] (indices) when the grid has a
  /// selection and for every page as a6-4 draws it otherwise.
  void start(OpenedDocument document, List<int> pages, RegionFormat format) {
    final first = document.pages.elementAtOrNull(pages.firstOrNull ?? 0);
    final selected = ref.read(selectedPagesProvider).isNotEmpty;
    state = CropSession(
      document: document.id,
      scope: selected ? CropScope.pages : CropScope.all,
      range: selected ? formatPageRange(pages, format) : '',
      custom: first == null ? Size.zero : Size(first.width, first.height),
    );
  }

  /// Closes it: Cancel, or Esc.
  void cancel() => state = null;

  /// Takes the choices [next].
  // ignore: use_setters_to_change_properties
  void change(CropSession next) => state = next;

  /// "Remove white margins": what the engine finds on [pages] (indices), each
  /// page's own. False when no page has content.
  Future<bool> removeWhite(OpenedDocument document, List<int> pages) async {
    final handles = [for (final page in pages) document.pageHandle(page)];
    final found = await ref
        .read(engineServiceProvider)
        .whiteMargins(document.id, handles);
    final session = state;
    if (session == null || found.every((margins) => margins == null)) {
      return false;
    }
    state = session.copyWith(
      detected: {
        for (final (index, handle) in handles.indexed)
          handle: ?found.elementAtOrNull(index),
      },
    );
    return true;
  }

  /// Applies the tool to [pages] (indices) of [document] and closes it: the
  /// crop and the new size are a step each, and the crop's toast says what
  /// happened to the content (G57) and offers Undo of both.
  Future<void> apply(
    OpenedDocument document,
    List<int> pages, {
    required String name,
    required String cropStep,
    required String sizeStep,
    required RegionFormat format,
  }) async {
    final session = state;
    if (session == null) return;
    state = null;
    final engine = ref.read(engineServiceProvider);
    final editor = ref.read(documentEditorProvider.notifier);
    final toasts = ref.read(toastNoticesProvider.notifier);
    final id = document.id;
    final handles = [for (final page in pages) document.pageHandle(page)];
    // The toast goes with the newest step; its Undo takes back all this did.
    var steps = 0;
    void committed() {
      steps++;
      if (ref.read(openDocumentProvider)?.id != id) return;
      ref
          .read(pageCommandsProvider.notifier)
          .offerUndo(
            (l10n) =>
                l10n.cropDone(handles.length, format.integer(handles.length)),
            (l10n) => l10n.cropDoneHidden,
            steps: steps,
          );
    }

    if (session.crops) {
      final crops = {for (final h in handles) h: session.marginsOf(h)};
      final error = await editor.pageChange(
        id,
        () => engine.cropPages(id, crops, cropStep),
        committed: committed,
      );
      if (error != null) {
        showPageChangeFailure(toasts, error, name);
        return;
      }
    }
    if (session.newSize case final size?) {
      final error = await editor.pageChange(
        id,
        () => engine.setPageSize(
          id,
          handles,
          width: size.width,
          height: size.height,
          fit: session.fit,
          name: sizeStep,
        ),
        committed: session.crops ? committed : null,
      );
      if (error != null) showPageChangeFailure(toasts, error, name);
    }
  }
}
