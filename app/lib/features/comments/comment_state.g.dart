// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The open document's annotations as its committed steps leave them, read
/// again after each step, undo and redo.

@ProviderFor(documentAnnotations)
final documentAnnotationsProvider = DocumentAnnotationsProvider._();

/// The open document's annotations as its committed steps leave them, read
/// again after each step, undo and redo.

final class DocumentAnnotationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<AnnotationList>,
          AnnotationList,
          FutureOr<AnnotationList>
        >
    with $FutureModifier<AnnotationList>, $FutureProvider<AnnotationList> {
  /// The open document's annotations as its committed steps leave them, read
  /// again after each step, undo and redo.
  DocumentAnnotationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentAnnotationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentAnnotationsHash();

  @$internal
  @override
  $FutureProviderElement<AnnotationList> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AnnotationList> create(Ref ref) {
    return documentAnnotations(ref);
  }
}

String _$documentAnnotationsHash() =>
    r'6d6a01d9f9468d61d26bb04f8f46642b8ab23315';

/// The open document's threads, empty until the engine answers.

@ProviderFor(documentThreads)
final documentThreadsProvider = DocumentThreadsProvider._();

/// The open document's threads, empty until the engine answers.

final class DocumentThreadsProvider
    extends
        $FunctionalProvider<
          List<CommentThread>,
          List<CommentThread>,
          List<CommentThread>
        >
    with $Provider<List<CommentThread>> {
  /// The open document's threads, empty until the engine answers.
  DocumentThreadsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'documentThreadsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$documentThreadsHash();

  @$internal
  @override
  $ProviderElement<List<CommentThread>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<CommentThread> create(Ref ref) {
    return documentThreads(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<CommentThread> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<CommentThread>>(value),
    );
  }
}

String _$documentThreadsHash() => r'92ccba12ada90db7eb82f1099d5b88d80c088d96';

/// What the open document's permissions say about comments; null until the
/// engine answers.

@ProviderFor(commentGate)
final commentGateProvider = CommentGateProvider._();

/// What the open document's permissions say about comments; null until the
/// engine answers.

final class CommentGateProvider
    extends $FunctionalProvider<AsyncValue<OpGate?>, OpGate?, FutureOr<OpGate?>>
    with $FutureModifier<OpGate?>, $FutureProvider<OpGate?> {
  /// What the open document's permissions say about comments; null until the
  /// engine answers.
  CommentGateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentGateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentGateHash();

  @$internal
  @override
  $FutureProviderElement<OpGate?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<OpGate?> create(Ref ref) {
    return commentGate(ref);
  }
}

String _$commentGateHash() => r'd97739fb1df81aff47ebb5d920c8ca269c1d6b75';

/// Why the open document takes no comments, in the language given, or null
/// when it does (G27, G46).

@ProviderFor(commentRefusal)
final commentRefusalProvider = CommentRefusalProvider._();

/// Why the open document takes no comments, in the language given, or null
/// when it does (G27, G46).

final class CommentRefusalProvider
    extends
        $FunctionalProvider<
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?,
          String Function(AppLocalizations)?
        >
    with $Provider<String Function(AppLocalizations)?> {
  /// Why the open document takes no comments, in the language given, or null
  /// when it does (G27, G46).
  CommentRefusalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentRefusalProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentRefusalHash();

  @$internal
  @override
  $ProviderElement<String Function(AppLocalizations)?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  String Function(AppLocalizations)? create(Ref ref) {
    return commentRefusal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String Function(AppLocalizations)? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String Function(AppLocalizations)?>(
        value,
      ),
    );
  }
}

String _$commentRefusalHash() => r'8b0a892fabc03eea1946e47f2495c669db7f3062';

/// The Comment row's state, as `commentToolProvider`.

@ProviderFor(CommentTool)
final commentToolProvider = CommentToolProvider._();

/// The Comment row's state, as `commentToolProvider`.
final class CommentToolProvider
    extends $NotifierProvider<CommentTool, CommentTools> {
  /// The Comment row's state, as `commentToolProvider`.
  CommentToolProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentToolProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentToolHash();

  @$internal
  @override
  CommentTool create() => CommentTool();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentTools value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentTools>(value),
    );
  }
}

String _$commentToolHash() => r'796a0c9217be14790fec2c264bb887e44b486a82';

/// The Comment row's state, as `commentToolProvider`.

abstract class _$CommentTool extends $Notifier<CommentTools> {
  CommentTools build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CommentTools, CommentTools>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CommentTools, CommentTools>,
              CommentTools,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The comment selected on the page and in the panel, as
/// `commentSelectionProvider`. It holds through any change around it; one the
/// list no longer has selects nothing.

@ProviderFor(CommentSelection)
final commentSelectionProvider = CommentSelectionProvider._();

/// The comment selected on the page and in the panel, as
/// `commentSelectionProvider`. It holds through any change around it; one the
/// list no longer has selects nothing.
final class CommentSelectionProvider
    extends $NotifierProvider<CommentSelection, CommentSelected?> {
  /// The comment selected on the page and in the panel, as
  /// `commentSelectionProvider`. It holds through any change around it; one the
  /// list no longer has selects nothing.
  CommentSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentSelectionHash();

  @$internal
  @override
  CommentSelection create() => CommentSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentSelected? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentSelected?>(value),
    );
  }
}

String _$commentSelectionHash() => r'1d357c43c4e5bac1da749af29d3a2ebb01b376e3';

/// The comment selected on the page and in the panel, as
/// `commentSelectionProvider`. It holds through any change around it; one the
/// list no longer has selects nothing.

abstract class _$CommentSelection extends $Notifier<CommentSelected?> {
  CommentSelected? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CommentSelected?, CommentSelected?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CommentSelected?, CommentSelected?>,
              CommentSelected?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// FmComments's filters, as `commentFilterProvider`; each document starts
/// with the board's.

@ProviderFor(CommentFilter)
final commentFilterProvider = CommentFilterProvider._();

/// FmComments's filters, as `commentFilterProvider`; each document starts
/// with the board's.
final class CommentFilterProvider
    extends $NotifierProvider<CommentFilter, CommentFilters> {
  /// FmComments's filters, as `commentFilterProvider`; each document starts
  /// with the board's.
  CommentFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentFilterHash();

  @$internal
  @override
  CommentFilter create() => CommentFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentFilters value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentFilters>(value),
    );
  }
}

String _$commentFilterHash() => r'b746a8fd07f66512bd72f385f91660d8ed849aa4';

/// FmComments's filters, as `commentFilterProvider`; each document starts
/// with the board's.

abstract class _$CommentFilter extends $Notifier<CommentFilters> {
  CommentFilters build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CommentFilters, CommentFilters>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CommentFilters, CommentFilters>,
              CommentFilters,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Show comments (⇧⌘H, a4-5), as `commentsShownProvider`: render-only, never
/// saved, and each document keeps its own, as its layers do.

@ProviderFor(CommentsShown)
final commentsShownProvider = CommentsShownProvider._();

/// Show comments (⇧⌘H, a4-5), as `commentsShownProvider`: render-only, never
/// saved, and each document keeps its own, as its layers do.
final class CommentsShownProvider
    extends $NotifierProvider<CommentsShown, CommentsVisibility> {
  /// Show comments (⇧⌘H, a4-5), as `commentsShownProvider`: render-only, never
  /// saved, and each document keeps its own, as its layers do.
  CommentsShownProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentsShownProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentsShownHash();

  @$internal
  @override
  CommentsShown create() => CommentsShown();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CommentsVisibility value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CommentsVisibility>(value),
    );
  }
}

String _$commentsShownHash() => r'88048ceee675ee56c25b6dc30009c1a3d9648cde';

/// Show comments (⇧⌘H, a4-5), as `commentsShownProvider`: render-only, never
/// saved, and each document keeps its own, as its layers do.

abstract class _$CommentsShown extends $Notifier<CommentsVisibility> {
  CommentsVisibility build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CommentsVisibility, CommentsVisibility>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CommentsVisibility, CommentsVisibility>,
              CommentsVisibility,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// What the comment tools do, each one step of the history (a4-1, a4-2), as
/// `commentCommandsProvider`. A signed document asks first (a3-16a).

@ProviderFor(CommentCommands)
final commentCommandsProvider = CommentCommandsProvider._();

/// What the comment tools do, each one step of the history (a4-1, a4-2), as
/// `commentCommandsProvider`. A signed document asks first (a3-16a).
final class CommentCommandsProvider
    extends $NotifierProvider<CommentCommands, void> {
  /// What the comment tools do, each one step of the history (a4-1, a4-2), as
  /// `commentCommandsProvider`. A signed document asks first (a3-16a).
  CommentCommandsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentCommandsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentCommandsHash();

  @$internal
  @override
  CommentCommands create() => CommentCommands();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$commentCommandsHash() => r'31a3606d4816354f3635b7015fdcbfb1e427cf45';

/// What the comment tools do, each one step of the history (a4-1, a4-2), as
/// `commentCommandsProvider`. A signed document asks first (a3-16a).

abstract class _$CommentCommands extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
