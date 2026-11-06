// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Edits the open document's text through the engine's transactions, as
/// `documentEditorProvider` (ARCHITECTURE §3.6).
///
/// A click on an editable block opens its editor ([open]) and begins a
/// transaction; typing replaces the block's text in it ([type]). The
/// typing commits as one history step, named as [open] says, on blur,
/// Esc, a mode switch (the canvas calls [finish]), a tab switch or save
/// ([finish], which also closes
/// the editor), and after [idle] without input ([commit], which keeps the
/// editor open; typing on begins a new transaction). Undo and redo commit
/// the typing first, so ⌘Z undoes a typing burst. Every engine call runs
/// one after another, in the order they were asked for.
///
/// Text that no longer fits its block comes back with "Keep and warn"
/// applied and the overflow choices in [EditorState.asking]; [resolve]
/// picks another, in the open transaction or, once the typing committed,
/// by undoing that step and writing the text again with the choice, so
/// either way it is one step.
///
/// Text with characters its font lacks comes back with missing-glyph step
/// 3 in [EditorState.glyphs] (ADR 0006): drawn provisionally in the
/// closest candidate, or not at all with "Ask each time" (the
/// [settingsProvider]'s policy, which the engine gets as it changes). With
/// "Keep the original font and mark the character" nothing waits: the text
/// applies, and [EditorState.markedChars] names the characters.
/// [chooseFont] and [keepAsIs] answer it in the open transaction; the idle
/// commit waits for the answer, and closing the editor in any other way
/// answers "Keep as is" first. A commit that set characters in another
/// font shows the "Font substituted" toast once ([EditorState.toast]).
///
/// Each commit, undo and redo marks the shell's document unsaved; [save]
/// writes the committed steps to the file (an incremental update) and
/// marks it saved, or "Couldn't save" when it fails, and returns the
/// failure for `documentSaverProvider` to show; [write] does the same for
/// Save as and Optimize and clean.

@ProviderFor(DocumentEditor)
final documentEditorProvider = DocumentEditorProvider._();

/// Edits the open document's text through the engine's transactions, as
/// `documentEditorProvider` (ARCHITECTURE §3.6).
///
/// A click on an editable block opens its editor ([open]) and begins a
/// transaction; typing replaces the block's text in it ([type]). The
/// typing commits as one history step, named as [open] says, on blur,
/// Esc, a mode switch (the canvas calls [finish]), a tab switch or save
/// ([finish], which also closes
/// the editor), and after [idle] without input ([commit], which keeps the
/// editor open; typing on begins a new transaction). Undo and redo commit
/// the typing first, so ⌘Z undoes a typing burst. Every engine call runs
/// one after another, in the order they were asked for.
///
/// Text that no longer fits its block comes back with "Keep and warn"
/// applied and the overflow choices in [EditorState.asking]; [resolve]
/// picks another, in the open transaction or, once the typing committed,
/// by undoing that step and writing the text again with the choice, so
/// either way it is one step.
///
/// Text with characters its font lacks comes back with missing-glyph step
/// 3 in [EditorState.glyphs] (ADR 0006): drawn provisionally in the
/// closest candidate, or not at all with "Ask each time" (the
/// [settingsProvider]'s policy, which the engine gets as it changes). With
/// "Keep the original font and mark the character" nothing waits: the text
/// applies, and [EditorState.markedChars] names the characters.
/// [chooseFont] and [keepAsIs] answer it in the open transaction; the idle
/// commit waits for the answer, and closing the editor in any other way
/// answers "Keep as is" first. A commit that set characters in another
/// font shows the "Font substituted" toast once ([EditorState.toast]).
///
/// Each commit, undo and redo marks the shell's document unsaved; [save]
/// writes the committed steps to the file (an incremental update) and
/// marks it saved, or "Couldn't save" when it fails, and returns the
/// failure for `documentSaverProvider` to show; [write] does the same for
/// Save as and Optimize and clean.
final class DocumentEditorProvider
    extends $NotifierProvider<DocumentEditor, EditorState> {
  /// Edits the open document's text through the engine's transactions, as
  /// `documentEditorProvider` (ARCHITECTURE §3.6).
  ///
  /// A click on an editable block opens its editor ([open]) and begins a
  /// transaction; typing replaces the block's text in it ([type]). The
  /// typing commits as one history step, named as [open] says, on blur,
  /// Esc, a mode switch (the canvas calls [finish]), a tab switch or save
  /// ([finish], which also closes
  /// the editor), and after [idle] without input ([commit], which keeps the
  /// editor open; typing on begins a new transaction). Undo and redo commit
  /// the typing first, so ⌘Z undoes a typing burst. Every engine call runs
  /// one after another, in the order they were asked for.
  ///
  /// Text that no longer fits its block comes back with "Keep and warn"
  /// applied and the overflow choices in [EditorState.asking]; [resolve]
  /// picks another, in the open transaction or, once the typing committed,
  /// by undoing that step and writing the text again with the choice, so
  /// either way it is one step.
  ///
  /// Text with characters its font lacks comes back with missing-glyph step
  /// 3 in [EditorState.glyphs] (ADR 0006): drawn provisionally in the
  /// closest candidate, or not at all with "Ask each time" (the
  /// [settingsProvider]'s policy, which the engine gets as it changes). With
  /// "Keep the original font and mark the character" nothing waits: the text
  /// applies, and [EditorState.markedChars] names the characters.
  /// [chooseFont] and [keepAsIs] answer it in the open transaction; the idle
  /// commit waits for the answer, and closing the editor in any other way
  /// answers "Keep as is" first. A commit that set characters in another
  /// font shows the "Font substituted" toast once ([EditorState.toast]).
  ///
  /// Each commit, undo and redo marks the shell's document unsaved; [save]
  /// writes the committed steps to the file (an incremental update) and
  /// marks it saved, or "Couldn't save" when it fails, and returns the
  /// failure for `documentSaverProvider` to show; [write] does the same for
  /// Save as and Optimize and clean.
  DocumentEditorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentEditorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentEditorHash();

  @$internal
  @override
  DocumentEditor create() => DocumentEditor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditorState>(value),
    );
  }
}

String _$documentEditorHash() => r'0558d1d1b17e9679218b02c9275bd144d0c664ab';

/// Edits the open document's text through the engine's transactions, as
/// `documentEditorProvider` (ARCHITECTURE §3.6).
///
/// A click on an editable block opens its editor ([open]) and begins a
/// transaction; typing replaces the block's text in it ([type]). The
/// typing commits as one history step, named as [open] says, on blur,
/// Esc, a mode switch (the canvas calls [finish]), a tab switch or save
/// ([finish], which also closes
/// the editor), and after [idle] without input ([commit], which keeps the
/// editor open; typing on begins a new transaction). Undo and redo commit
/// the typing first, so ⌘Z undoes a typing burst. Every engine call runs
/// one after another, in the order they were asked for.
///
/// Text that no longer fits its block comes back with "Keep and warn"
/// applied and the overflow choices in [EditorState.asking]; [resolve]
/// picks another, in the open transaction or, once the typing committed,
/// by undoing that step and writing the text again with the choice, so
/// either way it is one step.
///
/// Text with characters its font lacks comes back with missing-glyph step
/// 3 in [EditorState.glyphs] (ADR 0006): drawn provisionally in the
/// closest candidate, or not at all with "Ask each time" (the
/// [settingsProvider]'s policy, which the engine gets as it changes). With
/// "Keep the original font and mark the character" nothing waits: the text
/// applies, and [EditorState.markedChars] names the characters.
/// [chooseFont] and [keepAsIs] answer it in the open transaction; the idle
/// commit waits for the answer, and closing the editor in any other way
/// answers "Keep as is" first. A commit that set characters in another
/// font shows the "Font substituted" toast once ([EditorState.toast]).
///
/// Each commit, undo and redo marks the shell's document unsaved; [save]
/// writes the committed steps to the file (an incremental update) and
/// marks it saved, or "Couldn't save" when it fails, and returns the
/// failure for `documentSaverProvider` to show; [write] does the same for
/// Save as and Optimize and clean.

abstract class _$DocumentEditor extends $Notifier<EditorState> {
  EditorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<EditorState, EditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<EditorState, EditorState>,
              EditorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether Edit's Undo history panel (a3-10) shows in place of the right
/// panel, as `editHistoryOpenProvider`.

@ProviderFor(EditHistoryOpen)
final editHistoryOpenProvider = EditHistoryOpenProvider._();

/// Whether Edit's Undo history panel (a3-10) shows in place of the right
/// panel, as `editHistoryOpenProvider`.
final class EditHistoryOpenProvider
    extends $NotifierProvider<EditHistoryOpen, bool> {
  /// Whether Edit's Undo history panel (a3-10) shows in place of the right
  /// panel, as `editHistoryOpenProvider`.
  EditHistoryOpenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'editHistoryOpenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$editHistoryOpenHash();

  @$internal
  @override
  EditHistoryOpen create() => EditHistoryOpen();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$editHistoryOpenHash() => r'5d3cb4611a493661487cb3bf9eabe3e1062c318b';

/// Whether Edit's Undo history panel (a3-10) shows in place of the right
/// panel, as `editHistoryOpenProvider`.

abstract class _$EditHistoryOpen extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
