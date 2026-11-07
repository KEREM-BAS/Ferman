import 'package:ferman/app/app.dart';
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/comments/comment_model.dart';
import 'package:ferman/features/comments/comment_state.dart';
import 'package:ferman/features/comments/commenter_name_dialog.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/shell/open_files.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter/widgets.dart' show Offset, Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/window_golden.dart';

const String _path = '/Users/elif/Belgeler/Kira sözleşmesi.pdf';

const OpenedDocument _kira = OpenedDocument(
  id: 1,
  pages: [
    PageInfo(width: 595, height: 842, handle: 100),
    PageInfo(width: 595, height: 842, handle: 101),
    PageInfo(width: 595, height: 842, handle: 102),
  ],
);

const AnnotationColor _red = AnnotationColor(0.851, 0.227, 0.169);
const AnnotationColor _yellow = AnnotationColor(1, 0.878, 0.4);
const AnnotationColor _green = AnnotationColor(0.722, 0.89, 0.655);

/// FmComments's threads, with fixed old dates, so they show as dates.
final DateTime _when = DateTime(2026, 10, 13, 10, 12);

List<AnnotationInfo> _annotations() => [
  AnnotationInfo(
    handle: 1,
    page: 100,
    kind: AnnotationKind.highlight,
    rect: const Rect.fromLTWH(70, 200, 200, 16),
    points: const [
      [Offset(70, 200), Offset(270, 200), Offset(70, 216), Offset(270, 216)],
    ],
    thread: 1,
    color: _yellow,
    author: 'Ayşe Yılmaz',
    created: _when,
    quote: 'her ayın beşinci gününe kadar',
    contents: 'Ödeme günü beşi yerine onu olabilir mi?',
  ),
  AnnotationInfo(
    handle: 2,
    page: 100,
    kind: AnnotationKind.note,
    rect: const Rect.fromLTWH(400, 120, 24, 24),
    thread: 1 + 1,
    color: _yellow,
    author: 'Mert Kaya',
    created: _when,
    contents: 'Artış oranı TÜFE’ye bağlı kalsın, sabit oran istemiyorum.',
  ),
  AnnotationInfo(
    handle: 3,
    page: 100,
    kind: AnnotationKind.square,
    rect: const Rect.fromLTWH(70, 330, 455, 60),
    thread: 3,
    color: _red,
    stroke: 2,
    author: 'Av. Deniz Aksoy',
    created: _when,
    quote: 'Madde 5 — Depozito',
    contents: 'TBK m. 342: depozito üç aylık kira bedelini aşamaz.',
  ),
  AnnotationInfo(
    handle: 4,
    page: 101,
    kind: AnnotationKind.underline,
    rect: const Rect.fromLTWH(70, 200, 200, 16),
    thread: 4,
    color: _green,
    author: 'Ayşe Yılmaz',
    created: _when,
    quote: 'TR12 0006 4000 0011 2345 6789 01',
    contents: 'IBAN’ı bankadan teyit ettim.',
    resolved: true,
    resolvedBy: 'Mert Kaya',
    resolvedAt: _when,
  ),
  AnnotationInfo(
    handle: 5,
    page: 100,
    kind: AnnotationKind.note,
    rect: const Rect.fromLTWH(70, 200, 24, 24),
    thread: 1,
    repliesTo: 1,
    author: 'Mert Kaya',
    created: _when,
    contents: 'Olur, 10’u yazalım.',
  ),
  AnnotationInfo(
    handle: 6,
    page: 100,
    kind: AnnotationKind.note,
    rect: const Rect.fromLTWH(70, 200, 24, 24),
    thread: 1,
    repliesTo: 1,
    author: 'Av. Deniz Aksoy',
    created: _when,
    contents: '@Mert Kaya maddeyi buna göre güncelliyorum.',
    mentions: const ['Mert Kaya'],
  ),
];

FakeEngineService _engine() =>
    FakeEngineService(documents: {_path: _kira})
      ..initialAnnotations[1] = _annotations();

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FermanApp)));

Future<void> _opened(WidgetTester tester) async {
  final container = _container(tester);
  await container.read(documentOpenerProvider.notifier).open([_path]);
  await tester.pumpAndSettle();
  container.read(shellModeProvider.notifier).select(FermanMode.comment);
  await tester.pumpAndSettle();
}

/// Comment mode (a4-1, a4-1d, a4-2, a4-5) and its name dialog (G46) in light
/// and dark × en, tr and ar. Goldens run on Linux CI only.
Future<void> main() async {
  final screens = <String, Future<void> Function(WidgetTester)>{
    'comment_selected': (tester) async {
      await _opened(tester);
      final container = _container(tester);
      container.read(commentToolProvider.notifier).pick(AnnotationTool.shapes);
      container.read(commentSelectionProvider.notifier).select(3);
      await tester.pumpAndSettle();
    },
    'comment_note': (tester) async {
      await _opened(tester);
      final container = _container(tester);
      container.read(commentToolProvider.notifier).pick(AnnotationTool.note);
      container
          .read(commentSelectionProvider.notifier)
          .select(2, noteOpen: true);
      await tester.pumpAndSettle();
    },
    'comment_thread': (tester) async {
      await _opened(tester);
      final container = _container(tester);
      container.read(commentToolProvider.notifier).pick(AnnotationTool.select);
      container
          .read(commentFilterProvider.notifier)
          .set(const CommentFilters(open: true));
      container
          .read(commentSelectionProvider.notifier)
          .select(1, composing: true);
      await tester.pumpAndSettle();
    },
    'comment_hidden': (tester) async {
      await _opened(tester);
      await _container(tester)
          .read(commentsShownProvider.notifier)
          .show(visible: false);
      await tester.pumpAndSettle();
    },
    'comment_name': (tester) async {
      await _opened(tester);
      _container(tester)
          .read(organizeDialogProvider.notifier)
          .show(CommenterNameDialog(done: (_) {}));
      await tester.pumpAndSettle();
    },
  };
  const boards = {
    'comment_selected': 'a4-1',
    'comment_note': 'a4-1d',
    'comment_thread': 'a4-2',
    'comment_hidden': 'a4-5',
  };
  for (final MapEntry(key: screen, value: open) in screens.entries) {
    for (final theme in GoldenTheme.values) {
      for (final language in GoldenLanguage.matrix) {
        await windowGoldenTest(
          screen: screen,
          chrome: GoldenChrome.mac,
          theme: theme,
          language: language,
          board: theme == GoldenTheme.light && language == GoldenLanguage.en
              ? boards[screen]
              : null,
          settings: goldenSettings(
            theme: theme,
            language: language,
            onboardingCompleted: true,
          ).copyWith(commenterName: 'Av. Deniz Aksoy'),
          engine: _engine(),
          // A Dialog hides while tickers are muted.
          muteTickers: screen != 'comment_name',
          open: open,
        );
      }
    }
  }
}
