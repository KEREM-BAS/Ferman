import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart' show ToastTone;
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/link_open_dialog.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/open_problem_notice.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/text_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_access.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart' show TextSelection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'links.g.dart';

/// a3-6's link text, `#2A4DAF`: the colour of a new link's line, if it has one.
const AnnotationColor _linkColour = AnnotationColor(
  0x2A / 0xFF,
  0x4D / 0xFF,
  0xAF / 0xFF,
);

/// The longest target the prompt shows; a longer one is refused, since the
/// prompt must show all of it and a document can make it any length.
const int _longestTarget = 8192;

/// The open document's links as its history stands now (a3-6).
@riverpod
Future<LinkList> documentLinks(Ref ref) async {
  final document = ref.watch(openDocumentProvider.select((open) => open?.id));
  ref.watch(documentEditorProvider.select((s) => s.history.current));
  if (document == null) return const LinkList(links: []);
  return await ref.read(engineServiceProvider).links(document);
}

/// What the open document's permissions say about its links; null until the
/// engine answers, and without a document.
@riverpod
Future<OpGate?> linkGate(Ref ref) async {
  final document = ref.watch(openDocumentProvider.select((open) => open?.id));
  if (document == null) return null;
  return await ref
      .read(engineServiceProvider)
      .opGate(document, DocumentOp.comment);
}

/// Why the open document's links cannot change, in the language given, or null
/// when they can.
@riverpod
String Function(AppLocalizations)? linkRefusal(Ref ref) {
  if (ref.watch(openDocumentProvider)?.readOnly != null) {
    return (l10n) => l10n.editTipReadOnly;
  }
  return ref.watch(linkGateProvider).value == OpGate.forbidden
      ? (l10n) => l10n.editTipRestricted
      : null;
}

/// The topmost of [links] on the page with handle [page] at [point], for the
/// pointer's shape; a click asks the engine.
LinkInfo? linkOver(List<LinkInfo> links, int page, Offset point) {
  for (final link in links.reversed) {
    if (link.page == page && link.rect.contains(point)) return link;
  }
  return null;
}

/// A mail link's address, without its `mailto:` and anything after a `?`.
String mailAddressOf(String target) {
  final address = target.replaceFirst(
    RegExp('^mailto:', caseSensitive: false),
    '',
  );
  final query = address.indexOf('?');
  return query < 0 ? address : address.substring(0, query);
}

/// A link not written yet: the text it goes on, in displayed points.
@immutable
final class LinkDraft {
  /// A draft on the page with handle [page].
  const new({required this.page, required this.quads});

  /// Its page's handle.
  final int page;

  /// The boxes of its text's lines.
  final List<Rect> quads;

  /// The box around them.
  Rect get rect => quads.reduce((a, b) => a.expandToInclude(b));
}

/// What the Link tool is doing (a3-6).
@immutable
final class LinkToolState {
  /// A state.
  const new({this.on = false, this.selected, this.draft});

  /// Whether the tool is on: outlines on the canvas, the Links panel.
  final bool on;

  /// The link the panel marks and the Edit link popover shows.
  final int? selected;

  /// The link Add link's popover is writing.
  final LinkDraft? draft;
}

/// Edit's Link tool, and following a link anywhere.
@riverpod
class LinkTool extends _$LinkTool {
  EngineService get _engine => ref.read(engineServiceProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ref.read(appLocaleProvider));

  @override
  LinkToolState build() {
    ref
      ..watch(shellModeProvider)
      ..watch(openDocumentProvider.select((document) => document?.id));
    return const LinkToolState();
  }

  /// Turns the tool on, which commits the typing, or off.
  void show({required bool on}) {
    if (on == state.on) return;
    if (on) unawaited(ref.read(documentEditorProvider.notifier).finish());
    ref.read(canvasSelectionProvider.notifier).select(null);
    state = LinkToolState(on: on);
  }

  /// The tool's button and its key.
  void toggle() => show(on: !state.on);

  /// Closes the popover, and marks [handle] when given.
  void mark(int? handle) =>
      state = LinkToolState(on: state.on, selected: handle);

  /// Marks [link] from the panel, and shows it unless it is in view.
  void select(LinkInfo link) {
    mark(link.handle);
    final view = ref.read(viewerProvider);
    final page = view?.document.pageIndexOf(link.page);
    if (view == null || page == null) return;
    final placed = view.placement.rects.elementAtOrNull(page);
    final scale = view.scale;
    if (placed != null &&
        view.visible.contains(placed.topLeft + link.rect.center * scale)) {
      return;
    }
    ref.read(viewerProvider.notifier)
      ..goToPage(page)
      ..scrollBy(
        Offset(
          0,
          math.max(0, link.rect.top * scale - view.viewport.height / 3),
        ),
      );
  }

  /// Add link (⇧⌘K, the panel's +): on the canvas's selection, or without one
  /// the tool comes on, so text can be selected.
  void addSelection() {
    final selection = ref.read(canvasSelectionProvider);
    final view = ref.read(viewerProvider);
    show(on: true);
    if (selection == null ||
        view == null ||
        selection.quads.isEmpty ||
        ref.read(linkRefusalProvider) != null) {
      return;
    }
    state = LinkToolState(
      on: true,
      draft: LinkDraft(
        page: view.document.pageHandle(selection.page),
        quads: selection.quads,
      ),
    );
  }

  /// a3-1c's Add link on [selection] of the block being edited, whose text in
  /// the field is [text]. The typing commits first, so the engine's boxes are
  /// those of the text just committed.
  Future<void> addFromEditor(String text, TextSelection selection) async {
    final active = ref.read(documentEditorProvider).active;
    if (active == null || !selection.isValid || selection.isCollapsed) return;
    // The engine counts in code points, the field in UTF-16.
    int points(int offset) => text.substring(0, offset).runes.length;
    final start = points(selection.start);
    final end = points(selection.end);
    await ref.read(documentEditorProvider.notifier).finish();
    try {
      final blocks = await _engine.textBlocks(active.document, active.page);
      final block = blockOver(blocks.blocks, active.block.frame);
      if (block == null) return;
      final covered = await _engine.selection(
        active.document,
        active.page,
        BlockPosition(block: block.id, index: start),
        BlockPosition(block: block.id, index: end),
      );
      final document = ref.read(viewerProvider)?.document;
      if (covered.quads.isEmpty || document?.id != active.document) return;
      state = LinkToolState(
        on: true,
        draft: LinkDraft(
          page: document!.pageHandle(active.page),
          quads: covered.quads,
        ),
      );
    } on EngineException catch (error) {
      _failed(error);
    }
  }

  /// Writes the popover's link: the draft, or the marked one, which keeps what
  /// it does when [destination] is null. A failure leaves the popover open.
  Future<void> save(LinkDestination? destination, LinkLook look) async {
    final document = ref.read(openDocumentProvider)?.id;
    final draft = state.draft;
    final handle = state.selected;
    if (document == null) return;
    if (draft != null && destination != null) {
      final name = _l10n.linkStepAdd;
      await _change(document, () async {
        final commit = await _engine.addLink(
          document,
          draft.page,
          NewLink(
            rect: draft.rect,
            quads: [
              for (final quad in draft.quads)
                [
                  quad.topLeft,
                  quad.topRight,
                  quad.bottomLeft,
                  quad.bottomRight,
                ],
            ],
            destination: destination,
            look: look,
            color: _linkColour,
          ),
          name,
        );
        return commit.revision;
      });
    } else if (handle != null) {
      final name = _l10n.linkStepEdit;
      await _change(document, () async {
        final commit = await _engine.updateLink(
          document,
          handle,
          LinkChange(destination: destination, look: look),
          name,
        );
        return commit.revision;
      });
    }
  }

  /// Remove link: one step, as any other.
  Future<void> remove() async {
    final document = ref.read(openDocumentProvider)?.id;
    final handle = state.selected;
    if (document == null || handle == null) return;
    final name = _l10n.linkStepRemove;
    await _change(document, () => _engine.deleteLink(document, handle, name));
  }

  /// Takes [change] as one step; a signed document asks first (a3-16a).
  Future<void> _change(
    int document,
    Future<RevisionInfo> Function() change,
  ) async {
    final failure = await ref
        .read(documentEditorProvider.notifier)
        .pageChange(document, change);
    if (failure != null) {
      _failed(failure);
      return;
    }
    ref.read(canvasSelectionProvider.notifier).select(null);
    mark(null);
  }

  void _failed(EngineException error) {
    final name = ref.read(shellDocumentsProvider).active?.name ?? '';
    ref
        .read(toastNoticesProvider.notifier)
        .show(
          tone: ToastTone.danger,
          title: (l10n) => l10n.linkFailedTitle,
          message: (l10n) => engineMessage(l10n, error, name),
        );
  }

  /// Follows [link] (G145): a page of this document just goes; a web or e-mail
  /// address asks first, with all of it showing; everything else says why
  /// nothing opens. The target is untrusted, and only the prompt's button
  /// hands it to the system.
  void follow(LinkInfo link) {
    final toasts = ref.read(toastNoticesProvider.notifier);
    final view = ref.read(viewerProvider);
    final target = _shortened(link.target);
    void refused(ToastText message) => toasts.show(
      tone: ToastTone.warning,
      title: (l10n) => l10n.linkRefusedTitle,
      message: message,
    );
    switch (link.kind) {
      case LinkKind.page:
        if (view?.document.pageIndexOf(link.targetPage ?? -1)
            case final page?) {
          ref.read(viewerProvider.notifier).goToPage(page);
        }
      case LinkKind.web || LinkKind.mail
          when link.target.length > _longestTarget:
        refused((l10n) => l10n.linkRefusedAddress(target));
      case LinkKind.web || LinkKind.mail:
        ref
            .read(organizeDialogProvider.notifier)
            .show(LinkOpenDialog(link: link));
      case LinkKind.broken:
        final pages = view?.document.pages.length ?? 0;
        final count = bidiIsolate(
          RegionFormat.forRegion(ref.read(regionProvider).region)
              .integer(pages),
        );
        toasts.show(
          tone: ToastTone.warning,
          title: (l10n) => l10n.linkBrokenTitle,
          message: (l10n) => l10n.linksBrokenMeta(pages, count),
        );
      case LinkKind.script:
        refused((l10n) => l10n.linkRefusedScript);
      case LinkKind.launch:
        refused((l10n) => l10n.linkRefusedLaunch(target));
      case LinkKind.file:
        refused((l10n) => l10n.linkRefusedFile(target));
      case LinkKind.address:
        refused((l10n) => l10n.linkRefusedAddress(target));
      case LinkKind.action:
        refused((l10n) => l10n.linkRefusedAction);
      case LinkKind.nothing:
        break;
    }
  }

  /// Hands [link]'s address to the system, which is all Ferman does with it:
  /// the prompt's button.
  Future<void> open(LinkInfo link) async {
    if (link.kind != LinkKind.web && link.kind != LinkKind.mail) return;
    if (await ref.read(fileAccessProvider).openUrl(link.target)) return;
    ref
        .read(toastNoticesProvider.notifier)
        .show(tone: ToastTone.danger, title: (l10n) => l10n.linkOpenFailed);
  }
}

/// A file or address from a document in a toast: its start, isolated.
String _shortened(String text) {
  const most = 80;
  final runes = text.runes;
  return bidiIsolate(
    runes.length > most ? '${String.fromCharCodes(runes.take(most))}…' : text,
  );
}
