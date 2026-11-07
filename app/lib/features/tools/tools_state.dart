import 'dart:async';

import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tools_state.g.dart';

/// What the Tools row shows beside the canvas: Compress's panel (a9-1) or
/// Version history (a9-8).
enum ToolsPanel {
  /// a9-1.
  compress,

  /// a9-8.
  versions,
}

/// The Tools row's open panel, or null, as `toolsPanelProvider`.
@Riverpod(keepAlive: true)
class ToolsPanelNotifier extends _$ToolsPanelNotifier {
  @override
  ToolsPanel? build() => null;

  /// Shows [panel], or hides it when it shows.
  void toggle(ToolsPanel panel) => state = state == panel ? null : panel;

  /// Shows [panel].
  // ignore: use_setters_to_change_properties
  void show(ToolsPanel panel) => state = panel;

  /// Hides the panel.
  void close() => state = null;
}

/// The preset a9-1 shows chosen: Balanced, as drawn.
@Riverpod(keepAlive: true)
class CompressChoice extends _$CompressChoice {
  @override
  CompressPreset build() => CompressPreset.balanced;

  /// Chooses [preset].
  // ignore: use_setters_to_change_properties
  void pick(CompressPreset preset) => state = preset;
}

/// What Compress would do to the open document as its steps stand (a9-1).
@riverpod
Future<CompressAnalysis?> compressAnalysis(Ref ref) async {
  final document = ref.watch(openDocumentProvider.select((d) => d?.id));
  ref.watch(documentEditorProvider.select((s) => s.history.current));
  if (document == null) return null;
  return await ref.read(engineServiceProvider).compressAnalysis(document);
}

/// What the open document's permissions say about printing (B121); null
/// until the engine answers.
@riverpod
Future<OpGate?> printGate(Ref ref) async {
  final document = ref.watch(openDocumentProvider.select((d) => d?.id));
  if (document == null) return null;
  return await ref
      .read(engineServiceProvider)
      .opGate(document, DocumentOp.print);
}

/// Why the open document cannot be printed, in the language given, or null
/// when it can (B121, G27).
@riverpod
String Function(AppLocalizations)? printRefusal(Ref ref) =>
    ref.watch(printGateProvider).value == OpGate.forbidden
    ? (l10n) => l10n.printForbidden
    : null;

/// The versions of the open document's file, newest first (a9-8), read again
/// after each save.
@riverpod
Future<List<VersionInfo>> documentVersions(Ref ref) async {
  final document = ref.watch(openDocumentProvider.select((d) => d?.id));
  // A save keeps a version, and so does the first change.
  ref
    ..watch(shellDocumentsProvider.select((list) => list.active?.unsaved))
    ..watch(documentEditorProvider.select((s) => s.history.current));
  if (document == null) return const [];
  return await ref.read(engineServiceProvider).versions(document);
}

/// The version a9-8 previews: its id, and its document once open or why not.
@immutable
final class VersionPreview {
  /// The preview of [version].
  const new({required this.version, this.document, this.error});

  /// The version's id.
  final int version;

  /// The version opened read-only, once it is.
  final OpenedDocument? document;

  /// Why it could not be opened.
  final EngineException? error;
}

/// The version a9-8 shows instead of the current document, as
/// `versionPreviewProvider`; the preview's document closes when another is
/// chosen, when the view goes and when another document shows.
@riverpod
class VersionPreviewNotifier extends _$VersionPreviewNotifier {
  @override
  VersionPreview? build() {
    // A version of the document shown: another tab ends the preview.
    ref.watch(openDocumentProvider.select((d) => d?.id));
    // Read now: a dispose callback may not use ref.
    _engine = ref.read(engineServiceProvider);
    ref.onDispose(_closeOpen);
    return null;
  }

  late EngineService _engine;

  OpenedDocument? _open;

  void _closeOpen() {
    if (_open case final open?) {
      unawaited(_engine.close(open.id));
    }
    _open = null;
  }

  /// Previews [version] of [document].
  Future<void> select(int document, int version) async {
    _closeOpen();
    state = VersionPreview(version: version);
    try {
      final opened = await ref
          .read(engineServiceProvider)
          .openVersion(document, version);
      if (!ref.mounted || state?.version != version) {
        unawaited(ref.read(engineServiceProvider).close(opened.id));
        return;
      }
      _open = opened;
      state = VersionPreview(version: version, document: opened);
    } on EngineException catch (error) {
      if (ref.mounted && state?.version == version) {
        state = VersionPreview(version: version, error: error);
      }
    }
  }

  /// Back to the current document.
  void back() {
    _closeOpen();
    state = null;
  }
}
