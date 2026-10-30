import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'recent_files.g.dart';

/// A file Ferman opened, as the recent files keep it (a1-4, ADR 0021): no
/// document text, only what the start screen shows about it.
@immutable
final class RecentEntry {
  /// A file at [path], last opened at [opened].
  const new({
    required this.path,
    required this.name,
    required this.opened,
    this.pages,
    this.pinned = false,
    this.signed = false,
    this.bookmark,
  });

  /// Reads an entry of the stored list; null when it is not one.
  static RecentEntry? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final path = json['path'];
    final name = json['name'];
    final opened = json['opened'];
    final pages = json['pages'];
    if (path is! String || path.isEmpty || name is! String) return null;
    final when = opened is String ? DateTime.tryParse(opened) : null;
    if (when == null) return null;
    return RecentEntry(
      path: path,
      name: name,
      opened: when,
      pages: pages is int && pages > 0 ? pages : null,
      pinned: json['pinned'] == true,
      signed: json['signed'] == true,
      bookmark: switch (json['bookmark']) {
        final String bookmark when bookmark.isNotEmpty => bookmark,
        _ => null,
      },
    );
  }

  /// Where the file is.
  final String path;

  /// Its file name.
  final String name;

  /// When it was last opened.
  final DateTime opened;

  /// How many pages it had; null when not known.
  final int? pages;

  /// Whether it is pinned above the recent files.
  final bool pinned;

  /// Whether it carried signatures (the neutral "Signed" badge of a1-4-m2).
  final bool signed;

  /// A security-scoped bookmark of the file (macOS, base64), which reaches
  /// it again after a restart under the App Sandbox (Q18); null elsewhere.
  final String? bookmark;

  /// The entry as the stored list holds it.
  Map<String, Object?> toJson() => {
    'path': path,
    'name': name,
    'opened': opened.toUtc().toIso8601String(),
    if (pages != null) 'pages': pages,
    if (pinned) 'pinned': true,
    if (signed) 'signed': true,
    if (bookmark != null) 'bookmark': bookmark,
  };

  /// This entry with the fields given replaced.
  RecentEntry copyWith({
    String? path,
    String? name,
    DateTime? opened,
    int? pages,
    bool? pinned,
    bool? signed,
    String? bookmark,
  }) => RecentEntry(
    path: path ?? this.path,
    name: name ?? this.name,
    opened: opened ?? this.opened,
    pages: pages ?? this.pages,
    pinned: pinned ?? this.pinned,
    signed: signed ?? this.signed,
    bookmark: bookmark ?? this.bookmark,
  );

  @override
  bool operator ==(Object other) =>
      other is RecentEntry &&
      other.path == path &&
      other.name == name &&
      other.opened == opened &&
      other.pages == pages &&
      other.pinned == pinned &&
      other.signed == signed &&
      other.bookmark == bookmark;

  @override
  int get hashCode =>
      Object.hash(path, name, opened, pages, pinned, signed, bookmark);

  @override
  String toString() => 'RecentEntry($name, $opened, pinned: $pinned)';
}

/// Loads and saves the recent files. The desktop store
/// (`FileRecentFilesStore`) writes `recent_files.json` beside
/// `settings.json`; the list never leaves the device. Tests and the web
/// build use [MemoryRecentFilesStore].
abstract interface class RecentFilesStore {
  /// The stored files, most recent first; none when nothing is stored yet
  /// or the stored file cannot be read.
  Future<List<RecentEntry>> load();

  /// Stores [files], replacing what was stored. A failure throws and leaves
  /// the previous list in place.
  Future<void> save(List<RecentEntry> files);
}

/// A [RecentFilesStore] in memory: tests, and the web build, which cannot
/// open files yet (B116).
final class MemoryRecentFilesStore implements RecentFilesStore {
  /// A store holding [initial].
  new([List<RecentEntry> initial = const []]) : _files = initial;

  List<RecentEntry> _files;

  @override
  Future<List<RecentEntry>> load() async => _files;

  @override
  Future<void> save(List<RecentEntry> files) async => _files = files;
}

/// The user's home directory on macOS and Linux, which the recent files
/// show as "~" (a1-4: "~/Belgeler/Ev"); null on Windows and the web.
/// `bootstrap()` overrides it.
@Riverpod(keepAlive: true)
String? homeDirectory(Ref ref) => null;

/// How the start screen orders the recent files (a1-4's sort menu).
enum RecentSort {
  /// Most recently opened first.
  opened,

  /// By file name, in the UI language's order (the engine's collator).
  name,

  /// By folder, in the UI language's order; within a folder, most recent
  /// first.
  location,
}

/// How the start screen shows the recent files: cards (a1-4) or a table
/// (a1-4c).
enum RecentView {
  /// Five cards a row with the first page.
  grid,

  /// A table with the location, pages and time.
  list,
}

/// The recent files' sort and view, as `recentLayoutProvider`: kept for the
/// session, so leaving the start screen and coming back keeps them (G118).
@Riverpod(keepAlive: true)
class RecentLayout extends _$RecentLayout {
  @override
  (RecentSort, RecentView) build() => (RecentSort.opened, RecentView.grid);

  /// Orders the files by [sort].
  void sortBy(RecentSort sort) => state = (sort, state.$2);

  /// Shows the files as [view].
  void show(RecentView view) => state = (state.$1, view);
}

/// Where the recent files are stored. `bootstrap()` overrides it with the
/// platform's store.
@Riverpod(keepAlive: true)
RecentFilesStore recentFilesStore(Ref ref) => MemoryRecentFilesStore();

/// The recent files loaded at start-up, which `bootstrap()` overrides, so
/// the first frame of the start screen already lists them.
@Riverpod(keepAlive: true)
List<RecentEntry> initialRecentFiles(Ref ref) => const [];

/// The recent files, most recent first, as `recentFilesProvider`: every
/// file opened, at most [limit] of them besides the pinned ones. Each
/// change is stored at once; a failed save keeps the list for this session.
@Riverpod(keepAlive: true)
class RecentFiles extends _$RecentFiles {
  /// How many files that are not pinned the list keeps.
  static const int limit = 50;

  @override
  List<RecentEntry> build() => ref.watch(initialRecentFilesProvider);

  /// Puts the file at [path] first, opened at [now]: a new entry, or the
  /// old one with its pin and anything not given kept.
  Future<void> opened(
    String path, {
    required String name,
    required DateTime now,
    int? pages,
    bool? signed,
    String? bookmark,
  }) {
    RecentEntry? old;
    for (final file in state) {
      if (file.path == path) old = file;
    }
    final entry =
        old?.copyWith(
          name: name,
          opened: now,
          pages: pages,
          signed: signed,
          bookmark: bookmark,
        ) ??
        RecentEntry(
          path: path,
          name: name,
          opened: now,
          pages: pages,
          signed: signed ?? false,
          bookmark: bookmark,
        );
    final rest = [
      for (final file in state)
        if (file.path != path) file,
    ];
    var unpinned = entry.pinned ? 0 : 1;
    return _save([
      entry,
      for (final file in rest)
        if (file.pinned || unpinned++ < limit) file,
    ]);
  }

  /// Pins the file at [path], or unpins it when [pinned] is false.
  Future<void> pin(String path, {required bool pinned}) => _save([
    for (final file in state)
      if (file.path == path) file.copyWith(pinned: pinned) else file,
  ]);

  /// Points the entry of the file at [from] to where it is now, [to] named
  /// [name], with [bookmark] when given: a bookmark that found the file
  /// moved ([sameFile]: its pages and badges stay), or "Locate…" of a1-9e
  /// (another file, whose pages and badges are not known yet). An entry
  /// already at [to] merges into it, so a pin of either stays.
  Future<void> relocate(
    String from, {
    required String to,
    required String name,
    String? bookmark,
    bool sameFile = true,
  }) {
    RecentEntry? at;
    for (final file in state) {
      if (file.path == to && to != from) at = file;
    }
    return _save([
      for (final file in state)
        if (file.path == from)
          RecentEntry(
            path: to,
            name: name,
            opened: file.opened,
            pages: sameFile ? file.pages : null,
            pinned: file.pinned || (at?.pinned ?? false),
            signed: sameFile && file.signed,
            bookmark: bookmark ?? (sameFile ? file.bookmark : null),
          )
        else if (file.path != to)
          file,
    ]);
  }

  /// Takes the file at [path] off the list.
  Future<void> remove(String path) => _save([
    for (final file in state)
      if (file.path != path) file,
  ]);

  /// Empties the list but for the pinned files ("Clear list").
  Future<void> clear() => _save([
    for (final file in state)
      if (file.pinned) file,
  ]);

  Future<void> _save(List<RecentEntry> files) async {
    state = List.unmodifiable(files);
    await ref.read(recentFilesStoreProvider).save(state);
  }
}
