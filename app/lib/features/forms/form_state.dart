import 'dart:async';
import 'dart:math' as math;

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/navigation/ferman_mode.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/forms/form_dialogs.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/save/document_saver.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color, Offset, Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'form_state.g.dart';

/// The open document's form as its committed steps leave it, in tab order,
/// read again after each step, undo and redo (a5-1); null without a
/// document. Reading generates
/// nothing (M4 decision 19). Kept, as the commands read it.
@Riverpod(keepAlive: true)
Future<FormInfo?> documentForm(Ref ref) async {
  final document = ref.watch(openDocumentProvider.select((d) => d?.id));
  ref.watch(documentEditorProvider.select((s) => s.history.current));
  if (document == null) return null;
  return await ref.read(engineServiceProvider).formFields(document);
}

/// The fields Tab and the field navigation move through: every field that
/// takes a value, in tab order.
List<FieldInfo> fillableFields(FormInfo form) => [
  for (final field in form.fields)
    if (!field.readOnly && field.kind != FieldKind.push) field,
];

/// What the open document's permissions and signatures say about filling it;
/// null until the engine answers (G35, G47's signed-form notice).
@riverpod
Future<OpGate?> fillGate(Ref ref) async {
  final document = ref.watch(openDocumentProvider);
  if (document == null) return null;
  ref.watch(documentEditorProvider.select((s) => s.history.current));
  return await ref
      .read(engineServiceProvider)
      .opGate(document.id, DocumentOp.fill);
}

/// Why the open document cannot be filled, in the language given, or null
/// when it can.
@riverpod
String Function(AppLocalizations)? fillRefusal(Ref ref) {
  if (ref.watch(openDocumentProvider)?.readOnly != null) {
    return (l10n) => l10n.editTipReadOnly;
  }
  return ref.watch(fillGateProvider).value == OpGate.forbidden
      ? (l10n) => l10n.editTipRestricted
      : null;
}

/// Fill & Sign's tools (a5-1, a5-4): the form's fields, or one of Fill
/// anything's.
enum FillTool {
  /// Fill fields: the form's own fields.
  fields,

  /// Text on a line or in a box; a comb takes one character a cell.
  text,

  /// A check.
  check,

  /// A cross.
  cross,

  /// A dot.
  dot,

  /// Today's date, as text.
  date,
}

/// Fill anything's ink (a5-4's Ink).
enum FillInk {
  /// Black: the page's ink.
  black,

  /// The board's blue, `#1A3170` (`--ink-800`).
  blue;

  /// Its colour on the page, which no theme changes.
  Color colorIn(FermanTheme theme) => switch (this) {
    black => theme.ramps.paper900,
    blue => theme.ramps.ink800,
  };
}

/// Fill & Sign's choices, which stay across documents.
@immutable
final class FillTools {
  /// Fill fields, snapping, one character a comb cell, in black.
  const new({
    this.tool = FillTool.fields,
    this.snap = true,
    this.comb = true,
    this.ink = FillInk.black,
  });

  /// The tool chosen.
  final FillTool tool;

  /// Snap to lines and boxes.
  final bool snap;

  /// One character per comb box.
  final bool comb;

  /// The ink of what Fill anything places.
  final FillInk ink;

  /// The tool that applies to [form]: one without fields has only Fill
  /// anything, which starts with Text.
  FillTool effective(FormInfo? form) =>
      tool == FillTool.fields && form != null && form.fields.isEmpty
      ? FillTool.text
      : tool;

  /// A copy with the given values.
  FillTools copyWith({FillTool? tool, bool? snap, bool? comb, FillInk? ink}) =>
      FillTools(
        tool: tool ?? this.tool,
        snap: snap ?? this.snap,
        comb: comb ?? this.comb,
        ink: ink ?? this.ink,
      );
}

/// Fill & Sign's choices, as `fillToolsProvider`.
@Riverpod(keepAlive: true)
class FillToolsState extends _$FillToolsState {
  @override
  FillTools build() => const FillTools();

  /// Picks [tool].
  void pick(FillTool tool) => state = state.copyWith(tool: tool);

  /// Sets the options.
  void options({bool? snap, bool? comb, FillInk? ink}) =>
      state = state.copyWith(snap: snap, comb: comb, ink: ink);
}

/// A document's form as the person works on it: the field they are in, the
/// panel's switches, and what the commits said.
@immutable
final class FormView {
  /// Highlighted, without tab order, before any commit.
  const new({
    this.current,
    this.highlight = true,
    this.order = false,
    this.bannerHidden = false,
    this.attempted = false,
    this.fonts = const [],
    this.fontsSaid = false,
    this.marked = const {},
  });

  /// The field the person is in, by handle.
  final int? current;

  /// Highlight fields.
  final bool highlight;

  /// Show tab order.
  final bool order;

  /// Whether the form's bar was hidden.
  final bool bannerHidden;

  /// Whether Finish was asked for with required fields empty: they show as
  /// errors from then on (a5-2b).
  final bool attempted;

  /// The bundled families a commit drew characters in, shown once in the
  /// panel until dismissed (M4 decision 18).
  final List<String> fonts;

  /// Whether [fonts] was said once already.
  final bool fontsSaid;

  /// The fields whose missing characters were kept out (Keep), by handle.
  final Set<int> marked;

  /// A copy with the given values.
  FormView copyWith({
    int? Function()? current,
    bool? highlight,
    bool? order,
    bool? bannerHidden,
    bool? attempted,
    List<String>? fonts,
    bool? fontsSaid,
    Set<int>? marked,
  }) => FormView(
    current: current == null ? this.current : current(),
    highlight: highlight ?? this.highlight,
    order: order ?? this.order,
    bannerHidden: bannerHidden ?? this.bannerHidden,
    attempted: attempted ?? this.attempted,
    fonts: fonts ?? this.fonts,
    fontsSaid: fontsSaid ?? this.fontsSaid,
    marked: marked ?? this.marked,
  );
}

/// The open document's [FormView], as `formSessionProvider`; each document
/// keeps its own.
@Riverpod(keepAlive: true)
class FormSession extends _$FormSession {
  @override
  FormView build() {
    final id = ref.watch(openDocumentProvider.select((d) => d?.id));
    if (id == null) return const FormView();
    final memory = ref.read(documentMemoryProvider(id));
    listenSelf((_, next) => memory.remember(next));
    return memory.recall<FormView>() ?? const FormView();
  }

  /// The person is in field [handle], or none.
  void focus(int? handle) {
    if (state.current != handle) state = state.copyWith(current: () => handle);
  }

  /// Moves [by] fields along the tab order of [form], wrapping, and shows the
  /// field's page.
  void move(FormInfo form, int by) {
    final fields = fillableFields(form);
    if (fields.isEmpty) return;
    final at = fields.indexWhere((field) => field.handle == state.current);
    final next = at < 0
        ? (by > 0 ? 0 : fields.length - 1)
        : (at + by) % fields.length;
    show(fields[next]);
  }

  /// Goes to [field]: it becomes the current one and the canvas scrolls the
  /// least that shows its first box.
  void show(FieldInfo field) {
    focus(field.handle);
    final view = ref.read(viewerProvider);
    final widget = field.widgets.firstOrNull;
    if (view == null || widget == null) return;
    final page = view.document.pageIndexOf(widget.page);
    if (page == null) return;
    ref.read(viewerProvider.notifier).reveal(page, widget.rect);
  }

  /// Sets the panel's switches.
  void options({bool? highlight, bool? order}) =>
      state = state.copyWith(highlight: highlight, order: order);

  /// Hides the form's bar.
  void hideBanner() => state = state.copyWith(bannerHidden: true);

  /// Finish was asked for too early.
  void attempt() => state = state.copyWith(attempted: true);

  /// Dismisses the font notice.
  void dismissFonts() => state = state.copyWith(fonts: const []);

  /// What [commit] of field [handle] said: the fonts once (decision 18) and
  /// the marked fields.
  void committed(int handle, FieldCommit commit) {
    final marked = {...state.marked};
    commit.marked ? marked.add(handle) : marked.remove(handle);
    final say = commit.fonts.isNotEmpty && !state.fontsSaid;
    state = state.copyWith(
      marked: marked,
      fonts: say ? commit.fonts : null,
      fontsSaid: state.fontsSaid || say,
    );
  }
}

/// The form's commands, each one step of the history (a5-1, a5-2, G47), as
/// `formCommandsProvider`. A signed document asks first (a3-16a).
@Riverpod(keepAlive: true)
class FormCommands extends _$FormCommands {
  EngineService get _engine => ref.read(engineServiceProvider);

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ref.read(appLocaleProvider));

  @override
  void build() {}

  /// Takes [change] as a step of [on], else the open document, or says why
  /// not.
  Future<void> _commit(
    Future<RevisionInfo> Function(int document) change, {
    VoidCallback? committed,
    int? on,
  }) async {
    final document = on ?? ref.read(openDocumentProvider)?.id;
    if (document == null) return;
    final failure = await ref
        .read(documentEditorProvider.notifier)
        .pageChange(document, () => change(document), committed: committed);
    if (failure == null || !ref.mounted) return;
    showPageChangeFailure(
      ref.read(toastNoticesProvider.notifier),
      failure,
      ref.read(shellDocumentsProvider).active?.name ?? '',
    );
  }

  /// Sets [field] of [on], else of the open document, to [values], on blur,
  /// Tab or a choice, never per keystroke (M4 decision 16). [missing] answers
  /// Ask each time. A field left by its document's view commits to that
  /// document, which says nothing more once another one shows.
  Future<void> setValue(
    FieldInfo field,
    List<String> values, {
    MissingFont? missing,
    int? on,
  }) async {
    if (missing == null && listEquals(field.values, values)) return;
    late FieldCommit made;
    await _commit(
      on: on,
      (document) async {
        made = await _engine.setFieldValue(
          document,
          field.handle,
          values,
          name: _l10n.formStepFill(field.label ?? field.name),
          missing: missing,
        );
        return made.revision;
      },
      committed: () {
        if (on != null && on != ref.read(openDocumentProvider)?.id) return;
        if (made.asksFont) {
          _askFont(
            (choice) => unawaited(setValue(field, values, missing: choice)),
          );
          return;
        }
        ref.read(formSessionProvider.notifier).committed(field.handle, made);
        if (made.xfaRemoved) {
          ref
              .read(toastNoticesProvider.notifier)
              .show(
                title: (l10n) => l10n.formXfaRemovedTitle,
                message: (l10n) => l10n.formXfaRemovedBody,
              );
        }
      },
    );
  }

  /// Ask each time (a11-1c): asks once, then [again] commits with the
  /// choice.
  void _askFont(void Function(MissingFont choice) again) {
    final dialogs = ref.read(organizeDialogProvider.notifier);
    dialogs.show(
      FormFontDialog(
        done: (choice) {
          dialogs.close();
          if (choice != null) again(choice);
        },
      ),
    );
  }

  /// Clear or Finish, [change], as one step of the open document: Ask each
  /// time asks first and goes [again] with the choice, and the fonts it took
  /// are said (M4 decision 18). Whether it was taken.
  Future<bool> _wholeForm(
    Future<FieldCommit> Function(int document) change,
    void Function(MissingFont choice) again,
  ) async {
    FieldCommit? made;
    var taken = false;
    await _commit((document) async {
      final commit = await change(document);
      made = commit;
      return commit.revision;
    }, committed: () => taken = true);
    final commit = made;
    if (!taken || commit == null || !ref.mounted) return false;
    if (commit.asksFont) {
      _askFont(again);
      return false;
    }
    if (commit.fonts.isNotEmpty) {
      final fonts = commit.fonts.join(', ');
      ref
          .read(toastNoticesProvider.notifier)
          .show(
            title: (l10n) => l10n.formFontNoticeTitle,
            message: (l10n) => l10n.formFontNoticeBody(fonts),
          );
    }
    return true;
  }

  /// Clear form…: asks, then empties every field, signatures aside.
  void clear() {
    final dialogs = ref.read(organizeDialogProvider.notifier);
    dialogs.show(
      FormClearDialog(
        done: ({required confirmed}) {
          dialogs.close();
          if (confirmed) unawaited(_clear());
        },
      ),
    );
  }

  Future<void> _clear({MissingFont? missing}) => _wholeForm(
    (document) =>
        _engine.clearForm(document, _l10n.formStepClear, missing: missing),
    (choice) => unawaited(_clear(missing: choice)),
  );

  /// Finish: with required fields empty or values that fail, goes to the
  /// first such field and shows them as errors; otherwise asks how to finish
  /// (G47).
  void finish() {
    final form = ref.read(documentFormProvider).value;
    if (form == null || form.fields.isEmpty) return;
    final session = ref.read(formSessionProvider.notifier);
    final waiting = fillableFields(form).where(
      (field) => field.problem != null || (field.required && !field.filled),
    );
    if (waiting.isNotEmpty) {
      session
        ..attempt()
        ..show(waiting.first);
      return;
    }
    final dialogs = ref.read(organizeDialogProvider.notifier);
    dialogs.show(
      FormFinishDialog(
        done: (choice) {
          dialogs.close();
          if (choice != null) unawaited(_finish(choice));
        },
      ),
    );
  }

  Future<void> _finish(FinishChoice choice, {MissingFont? missing}) async {
    if (choice.flatten) {
      final done = await _wholeForm(
        (document) => _engine.finishForm(
          document,
          _l10n.formStepFinish,
          missing: missing,
        ),
        (answer) => unawaited(_finish(choice, missing: answer)),
      );
      if (!done || !ref.mounted) return;
    }
    final saver = ref.read(documentSaverProvider.notifier);
    choice.saveAs ? saver.openSheet() : await saver.save();
  }

  /// Fill anything (a5-4): [text] on page [page] (an index) of [on], else of
  /// the open document, in [rect], with [cells] one character a cell, in
  /// [ink]; W2's text box with no border.
  Future<void> placeText(
    int page,
    Rect rect,
    String text, {
    required double fontSize,
    required AnnotationColor ink,
    int? cells,
    OpenedDocument? on,
  }) => _place(
    on,
    page,
    (author) => NewAnnotation(
      kind: AnnotationKind.freeText,
      rect: rect,
      color: ink,
      author: author,
      stroke: 0,
      contents: text,
      fontSize: fontSize,
      comb: cells,
    ),
    _l10n.fillStepText,
  );

  /// Fill anything's [tool] mark (check, cross or dot) in [box] of page
  /// [page], an index: strokes in the ink.
  Future<void> placeMark(
    int page,
    Rect box,
    FillTool tool,
    AnnotationColor ink,
  ) => _place(
    null,
    page,
    (author) => NewAnnotation(
      kind: AnnotationKind.ink,
      rect: box,
      color: ink,
      author: author,
      stroke: tool == FillTool.dot ? box.shortestSide * 0.2 : 1.5,
      points: markStrokes(tool, box),
    ),
    _l10n.fillStepMark,
  );

  /// Places [draft] on page [page] of [on], else of the open document.
  Future<void> _place(
    OpenedDocument? on,
    int page,
    NewAnnotation Function(String author) draft,
    String step,
  ) {
    final open = ref.read(openDocumentProvider);
    final comments = ref.read(commentCommandsProvider.notifier);
    // What was typed for a document no longer shown goes to that one.
    if (on != null && on.id != open?.id) {
      return comments.addLeft(on.id, on.pageHandle(page), draft);
    }
    if (open == null) return Future.value();
    // W2's text annotations, with their name, gate and history step.
    return comments.add(open.pageHandle(page), draft, step: step);
  }
}

/// The points of a dot's loop.
const int _dotSteps = 12;

/// The strokes of a check, a cross or a dot in [box] (page points, y down).
List<List<Offset>> markStrokes(FillTool tool, Rect box) {
  final inner = box.deflate(box.shortestSide * 0.2);
  return switch (tool) {
    FillTool.cross => [
      [inner.topLeft, inner.bottomRight],
      [inner.topRight, inner.bottomLeft],
    ],
    // A small loop under a stroke as wide as itself.
    FillTool.dot => [
      [
        for (var i = 0; i <= _dotSteps; i++)
          box.center +
              Offset.fromDirection(
                2 * math.pi * i / _dotSteps,
                box.shortestSide * 0.1,
              ),
      ],
    ],
    _ => [
      [
        Offset(inner.left, inner.center.dy),
        Offset(inner.left + inner.width * 0.38, inner.bottom),
        inner.topRight,
      ],
    ],
  };
}

/// Whether the canvas draws the open document's form widgets (B203), and the
/// render key that says so.
@immutable
final class FormWidgetsVisibility {
  /// Drawn, by default.
  const new({this.visible = true, this.renderKey = 0});

  /// Whether the canvas draws them.
  final bool visible;

  /// Every page's render key after the last change; 0 before one.
  final int renderKey;
}

/// Form widgets on the canvas, as `formWidgetsShownProvider`: drawn in every
/// mode and tool but Fill & Sign's fields, whose overlay draws each field with
/// its value, so no value shows twice. Render-only, never saved; the canvas
/// listens while it shows a document.
@riverpod
class FormWidgetsShown extends _$FormWidgetsShown {
  @override
  FormWidgetsVisibility build() {
    final document = ref.watch(openDocumentProvider.select((d) => d?.id));
    final fields = ref.watch(
      openDocumentProvider.select((d) => d?.formFields ?? 0),
    );
    if (document == null || fields == 0) return const FormWidgetsVisibility();
    final overlay =
        ref.watch(shellModeProvider) == FermanMode.sign &&
        ref
                .watch(fillToolsStateProvider)
                .effective(ref.watch(documentFormProvider).value) ==
            FillTool.fields;
    unawaited(_show(document, visible: !overlay));
    return FormWidgetsVisibility(visible: !overlay);
  }

  Future<void> _show(int document, {required bool visible}) async {
    final int key;
    try {
      key = await ref
          .read(engineServiceProvider)
          .showFormWidgets(document, visible: visible);
    } on EngineException {
      // A repaired document cannot be reloaded so: the canvas keeps what it
      // drew, and the overlay draws on top as before B203.
      return;
    }
    if (!ref.mounted || key == 0) return;
    if (ref.read(openDocumentProvider)?.id == document) {
      state = FormWidgetsVisibility(visible: visible, renderKey: key);
    }
  }
}
