import 'dart:async';

import 'package:ferman/app/router.dart';
import 'package:ferman/design/components/additions/save_indicator.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/jobs/background_jobs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'combine.g.dart';

/// Word and Excel files, which wait for conversion (B175).
final RegExp _officeName = RegExp(
  r'\.(docx?|odt|xlsx?|ods)$',
  caseSensitive: false,
);

final RegExp _pdfName = RegExp(r'\.pdf$', caseSensitive: false);

/// The most pages a typed range may name: past any document's limit, and it
/// keeps "1-999999999" from filling the memory.
const int _maxRangePages = 100000;

/// The pages typed as "1–3, 5", as indices in the order typed; null when it
/// cannot be read. The engine says whether the file has them.
List<int>? parsePageRange(String text) {
  final digits = text.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (match) {
    final unit = match[0]!.codeUnitAt(0);
    return '${unit >= 0x06f0 ? unit - 0x06f0 : unit - 0x0660}';
  });
  final pages = <int>[];
  for (final part in digits.split(RegExp('[,;،]'))) {
    final match = RegExp(r'^\s*(\d+)\s*(?:[-–—]\s*(\d+)\s*)?$')
        .firstMatch(part);
    if (match == null) return null;
    final first = int.tryParse(match[1]!);
    final last = match[2] == null ? first : int.tryParse(match[2]!);
    if (first == null || last == null || first < 1 || last < first) return null;
    if (pages.length + last - first >= _maxRangePages) return null;
    for (var page = first; page <= last; page++) {
      pages.add(page - 1);
    }
  }
  return pages;
}

/// One file of a6-3's list.
@immutable
final class CombineRow {
  /// The file at [path], with its own [id] since a file may come twice.
  const new({
    required this.id,
    required this.path,
    this.range,
    this.password,
    this.info,
  });

  /// The row's own number.
  final int id;

  /// Where the file is.
  final String path;

  /// The pages as typed; null for all.
  final String? range;

  /// What opens it (G45).
  final String? password;

  /// What the engine says of it; null before it answered, and for a row it
  /// is not asked about ([office], [badRange]).
  final CombineFileInfo? info;

  /// The file's name, untrusted text from the outside.
  String get name => fileName(path);

  /// Its name without the extension: its bookmark.
  String get stem {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  /// Whether it is a Word or Excel file, which waits for conversion (B175).
  bool get office => _officeName.hasMatch(name);

  /// Whether the range typed cannot be read, or the engine refused it.
  bool get badRange =>
      info?.status == CombineInputStatus.badRange ||
      (range != null && parsePageRange(range!) == null);

  /// Whether Combine can use it.
  bool get ready => !office && info?.status == CombineInputStatus.ready;

  /// This row with [info], [range] or [password]; [range] null keeps all
  /// pages.
  CombineRow copyWith({
    required CombineFileInfo? info,
    required String? range,
    String? password,
  }) => CombineRow(
    id: id,
    path: path,
    range: range,
    password: password ?? this.password,
    info: info,
  );
}

/// What `combineFilesProvider` holds: a6-3's tab.
@immutable
final class CombineFiles {
  /// The state.
  const new({
    this.rows = const [],
    this.bookmarks = true,
    this.keepForms = true,
    this.opensResult = false,
    this.pages = 0,
    this.bytes = 0,
  });

  /// The files, in order.
  final List<CombineRow> rows;

  /// Whether each file gets a bookmark.
  final bool bookmarks;

  /// Whether form fields travel (G159).
  final bool keepForms;

  /// Whether the new file opens once written: Create PDF from files (B019).
  final bool opensResult;

  /// The pages of the output.
  final int pages;

  /// About how large it comes out, in bytes.
  final int bytes;

  /// Whether the output can be written: every row must be usable, so nothing
  /// is left out silently.
  bool get canCombine => rows.isNotEmpty && rows.every((row) => row.ready);

  /// This state with the fields given.
  CombineFiles copyWith({
    List<CombineRow>? rows,
    bool? bookmarks,
    bool? keepForms,
    bool? opensResult,
    int? pages,
    int? bytes,
  }) => CombineFiles(
    rows: rows ?? this.rows,
    bookmarks: bookmarks ?? this.bookmarks,
    keepForms: keepForms ?? this.keepForms,
    opensResult: opensResult ?? this.opensResult,
    pages: pages ?? this.pages,
    bytes: bytes ?? this.bytes,
  );
}

/// The Combine tab's list, as `combineFilesProvider` (a6-3, G45): a preview of
/// the rows after each change, and the job. It empties when the tab closes.
@Riverpod(keepAlive: true)
class CombineFilesNotifier extends _$CombineFilesNotifier {
  int _next = 0;
  int _generation = 0;

  @override
  CombineFiles build() {
    ref.listen(
      shellDocumentsProvider.select(
        (list) => list.documents.any((document) => document.combine),
      ),
      (_, open) {
        if (!open) state = const CombineFiles();
      },
    );
    return const CombineFiles();
  }

  /// Shows the tab named [title], with its row of tools (a6-3's "Combine
  /// files"), the one tab there is, after any files of [add].
  void showTab(
    String title, {
    List<String> add = const [],
    bool opensResult = false,
  }) {
    final documents = ref.read(shellDocumentsProvider.notifier);
    if (!documents.focus(ShellDocument.combinePath)) {
      documents.add(
        ShellDocument(
          name: title,
          icon: IconName.merge,
          path: ShellDocument.combinePath,
          saveState: SaveState.saved,
        ),
      );
    }
    if (opensResult) state = state.copyWith(opensResult: true);
    this.add(add);
    final router = ref.read(routerProvider);
    if (router.state.uri.path == Routes.start) router.go(Routes.editor);
  }

  /// Shows the open panel, its filter named [filterLabel], and adds the
  /// chosen files.
  Future<void> pick({required String filterLabel}) async => add(
    await ref
        .read(filePickerServiceProvider)
        .openFilesToCombine(filterLabel: filterLabel),
  );

  /// Adds [paths] at the end of the list.
  void add(List<String> paths) {
    if (paths.isEmpty) return;
    state = state.copyWith(
      rows: [
        ...state.rows,
        for (final path in paths) CombineRow(id: _next++, path: path),
      ],
    );
    unawaited(_refresh());
  }

  /// Takes the row [id] away.
  void remove(int id) {
    state = state.copyWith(
      rows: [
        for (final row in state.rows)
          if (row.id != id) row,
      ],
    );
    unawaited(_refresh());
  }

  /// Moves the row [id] to before the row now at [index], or to the end at
  /// the list's length.
  void move(int id, int index) {
    final rows = [...state.rows];
    final from = rows.indexWhere((row) => row.id == id);
    if (from < 0) return;
    final row = rows.removeAt(from);
    rows.insert((from < index ? index - 1 : index).clamp(0, rows.length), row);
    state = state.copyWith(rows: rows);
    unawaited(_refresh());
  }

  /// Sets the row [id]'s pages as typed; null for all.
  void setRange(int id, String? range) {
    _change(id, (row) => row.copyWith(info: row.info, range: range));
    unawaited(_refresh());
  }

  /// Tries [password] on the row [id].
  void setPassword(int id, String password) {
    _change(
      id,
      (row) => row.copyWith(info: null, range: row.range, password: password),
    );
    unawaited(_refresh());
  }

  /// Whether each file gets a bookmark.
  void setBookmarks({required bool on}) =>
      state = state.copyWith(bookmarks: on);

  /// Whether form fields travel.
  void setKeepForms({required bool on}) {
    state = state.copyWith(keepForms: on);
    unawaited(_refresh());
  }

  void _change(int id, CombineRow Function(CombineRow) change) =>
      state = state.copyWith(
        rows: [
          for (final row in state.rows)
            if (row.id == id) change(row) else row,
        ],
      );

  /// The rows the engine can be asked about.
  Iterable<CombineRow> get _asked =>
      state.rows.where((row) => !row.office && !_unreadable(row));

  bool _unreadable(CombineRow row) =>
      row.range != null && parsePageRange(row.range!) == null;

  CombineInput _input(CombineRow row) => CombineInput.file(
    row.path,
    password: row.password,
    pages: row.range == null ? null : parsePageRange(row.range!),
    bookmark: state.bookmarks ? row.stem : null,
  );

  Future<void> _refresh() async {
    final generation = ++_generation;
    final asked = _asked.toList();
    var preview = const CombinePreview();
    if (asked.isNotEmpty) {
      try {
        preview = await ref.read(engineServiceProvider).combinePreview([
          for (final row in asked) _input(row),
        ], keepForms: state.keepForms);
      } on EngineException {
        // Each row stays unconfirmed, so Combine stays disabled.
      }
    }
    if (generation != _generation) return;
    final info = <int, CombineFileInfo>{
      for (final (index, row) in asked.indexed)
        if (index < preview.files.length) row.id: preview.files[index],
    };
    state = state.copyWith(
      rows: [
        for (final row in state.rows)
          row.copyWith(info: info[row.id], range: row.range),
      ],
      pages: preview.pages,
      bytes: preview.bytes,
    );
  }

  /// Asks where to write, with [name] suggested, and starts the job.
  Future<void> combine({required String name}) async {
    final files = state;
    if (!files.canCombine) return;
    final output = await ref
        .read(filePickerServiceProvider)
        .saveFile(suggestedName: _pdfName.hasMatch(name) ? name : '$name.pdf');
    if (output == null) return;
    await ref
        .read(backgroundJobsProvider.notifier)
        .combine(
          [for (final row in files.rows) _input(row)],
          keepForms: files.keepForms,
          output: output,
          kind: files.opensResult
              ? BackgroundJobKind.create
              : BackgroundJobKind.combine,
        );
  }
}
