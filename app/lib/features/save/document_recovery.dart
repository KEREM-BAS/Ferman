import 'dart:async';

import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'document_recovery.g.dart';

/// What crash recovery shows, as `documentRecoveryProvider`.
@immutable
final class RecoveryFlow {
  /// The flow offering [offered] (a1-12) or asking [asking]'s password (a1-8).
  const new({this.offered = const [], this.asking});

  /// The documents a1-12 lists; empty when it does not show.
  final List<RecoverableDocument> offered;

  /// The encrypted document whose password a1-8 asks for, or null.
  final RecoverableDocument? asking;
}

/// Crash recovery at launch, as `documentRecoveryProvider`: [check] asks the
/// engine once what a session that ended without cleaning up left (a1-12).
/// [open] restores the checked documents, each as unsaved in a tab of its own
/// (under a new name when its original changed, a11-7f), and deletes the
/// copies of the others; [discard] deletes them all. An encrypted one asks for
/// its password first. A copy that was not opened, by Cancel or a failure,
/// stays for the next launch.
@Riverpod(keepAlive: true)
class DocumentRecovery extends _$DocumentRecovery {
  List<RecoverableDocument> _queue = const [];

  @override
  RecoveryFlow build() => const RecoveryFlow();

  EngineService get _engine => ref.read(engineServiceProvider);

  /// Shows a1-12 when there is anything to restore.
  Future<void> check() async {
    try {
      final found = await _engine.listRecoverable();
      if (found.isNotEmpty) state = RecoveryFlow(offered: found);
    } on Object {
      // No engine, or no folder: nothing to restore.
    }
  }

  /// a1-12's "Open N documents".
  Future<void> open(Set<RecoverableDocument> checked) async {
    final offered = state.offered;
    state = const RecoveryFlow();
    for (final document in offered) {
      if (!checked.contains(document)) await _discard(document);
    }
    _queue = [
      for (final document in offered)
        if (checked.contains(document)) document,
    ];
    await _next();
  }

  /// a1-12's "Discard": the copies are deleted.
  Future<void> discard() async {
    final offered = state.offered;
    state = const RecoveryFlow();
    for (final document in offered) {
      await _discard(document);
    }
  }

  Future<void> _discard(RecoverableDocument document) => _engine
      .discardRecovery(document.session, document: document.document)
      .catchError((Object _) {});

  Future<void> _next() async {
    while (_queue.isNotEmpty && state.asking == null) {
      final document = _queue.first;
      _queue = _queue.sublist(1);
      await _restore(document);
    }
  }

  /// Opens [document]: false when [password] is wrong.
  Future<bool> _restore(
    RecoverableDocument document, {
    String? password,
  }) async {
    try {
      final restored = await _engine.restoreRecovered(
        document.session,
        document.document,
        password: password,
      );
      state = const RecoveryFlow();
      ref
          .read(documentOpenerProvider.notifier)
          .restored(restored, changes: document.changes);
      return true;
    } on EngineException catch (error) {
      if (error.kind == EngineErrorKind.wrongPassword) return false;
      if (error.kind == EngineErrorKind.passwordRequired) {
        state = RecoveryFlow(asking: document);
      } else {
        state = const RecoveryFlow();
        ref
            .read(documentOpenerProvider.notifier)
            .reportRestoreFailed(document.original, error);
      }
      return true;
    }
  }

  /// a1-8's Open for the document asked about: false when the password is
  /// wrong, so the dialog asks again.
  Future<bool> unlock(String password) async {
    final document = state.asking;
    if (document == null) return true;
    final accepted = await _restore(document, password: password);
    if (accepted) unawaited(_next());
    return accepted;
  }

  /// a1-8's Cancel: its copy stays for the next launch.
  void skip() {
    state = const RecoveryFlow();
    unawaited(_next());
  }
}
