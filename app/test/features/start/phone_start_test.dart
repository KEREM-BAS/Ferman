import 'package:ferman/design/components/components.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/engine/fake_engine_service.dart';
import 'package:ferman/features/phone/fm_phone.dart';
import 'package:ferman/features/settings/settings_screen.dart';
import 'package:ferman/recent/recent_files.dart';
import 'package:ferman/settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_picker.dart';
import '../../helpers/phone_golden.dart';
import '../../helpers/text_fit.dart';
import '../onboarding/ferman_app_harness.dart';

const _reason = 'Available in a future version';

const _webEngine = UnavailableEngineService(
  EngineUnavailableException(EngineUnavailableReason.unsupportedPlatform),
);

final List<RecentEntry> _files = [
  RecentEntry(
    path: '/home/ayse/Belgeler/Kira sözleşmesi.pdf',
    name: 'Kira sözleşmesi.pdf',
    opened: DateTime(2025, 10, 13, 14, 32),
    pages: 3,
    pinned: true,
    signed: true,
  ),
  RecentEntry(
    path: '/home/ayse/Belgeler/Başvuru formu çok uzun bir dosya adı.pdf',
    name: 'Başvuru formu çok uzun bir dosya adı.pdf',
    opened: DateTime(2025, 10, 12, 9, 5),
    pages: 2,
    form: true,
  ),
];

AppSettings _in(String language) => AppSettings(
  languageCode: language,
  regionCode: 'TR',
  onboardingCompleted: true,
);

void main() {
  group('the phone home', () {
    testWidgets('is the empty home of a13-2e in the frame of G129', (
      tester,
    ) async {
      await pumpFermanApp(tester, size: goldenPhoneSize, engine: _webEngine);
      expect(find.byType(FmPhone), findsOneWidget);
      for (final text in [
        'Ferman',
        'Search documents',
        'Scan',
        'Sign',
        'Edit',
        'Convert',
        'Compress',
        'Combine',
        'Protect',
        'OCR',
        'No documents yet',
        'Open a file',
        'Scan a document',
        'OPEN FROM',
        'Downloads',
        'Google Drive',
        'OneDrive',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      // The desktop's cards and drop area are gone.
      expect(find.byType(DropZone), findsNothing);
    });

    testWidgets('Turkish capitals follow the locale', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize, settings: _in('tr'));
      expect(find.text('ŞURADAN AÇ'), findsOneWidget);
    });

    testWidgets('Arabic mirrors it', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize, settings: _in('ar'));
      final view = tester.getSize(find.byType(FmPhone)).width;
      // "Scan" comes first, so it sits at the start edge: the right.
      final first = tester.getCenter(find.text('مسح').first).dx;
      final last = tester.getCenter(find.text('ضغط')).dx;
      expect(first, greaterThan(view / 2));
      expect(last, greaterThan(view / 2));
      expect(
        tester.getCenter(find.text('تحويل')).dx,
        lessThan(view / 2),
        reason: 'the fourth tool sits at the end edge: the left',
      );
    });

    for (final width in const [320.0, 375.0, 393.0, 767.0]) {
      for (final language in const ['en', 'tr', 'ar']) {
        // pumpFermanApp fails the test on an overflow.
        testWidgets('fits $width px in $language', (tester) async {
          await pumpFermanApp(
            tester,
            size: Size(width, 852),
            settings: _in(language),
            recentFiles: _files,
          );
          expect(find.byType(FmPhone), findsOneWidget);
        });
      }
    }

    testWidgets('every control takes at least 44 px', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize, recentFiles: _files);
      final controls = find.byType(FermanInteractive);
      expect(controls, findsWidgets);
      for (final control in controls.evaluate()) {
        final size = tester.getSize(find.byWidget(control.widget));
        expect(size.height, greaterThanOrEqualTo(44), reason: '$control');
        expect(size.width, greaterThanOrEqualTo(44), reason: '$control');
      }
      expect(tester.getSize(find.byType(TextField)).height, 44);
    });

    testWidgets('a touch on a disabled control says why', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize, engine: _webEngine);
      for (final label in [
        'Compress',
        'Scan a document',
        'OneDrive',
        'Search documents',
      ]) {
        final gesture = await tester.startGesture(
          tester.getCenter(find.text(label)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text(_reason), findsOneWidget, reason: label);
        await gesture.up();
        await tester.pump(const Duration(seconds: 3));
        expect(find.text(_reason), findsNothing, reason: label);
      }
    });

    testWidgets('on the web nothing opens', (tester) async {
      final picker = FakeFilePickerService();
      await pumpFermanApp(
        tester,
        size: goldenPhoneSize,
        engine: _webEngine,
        picker: picker,
      );
      await tester.tap(find.text('Open a file'));
      await tester.pump(const Duration(seconds: 3));
      expect(picker.requests, isEmpty);
    });

    testWidgets('with an engine Open a file shows the open panel', (
      tester,
    ) async {
      final picker = FakeFilePickerService();
      await pumpFermanApp(tester, size: goldenPhoneSize, picker: picker);
      await tester.tap(find.text('Open a file'));
      await tester.pumpAndSettle();
      expect(picker.requests, hasLength(1));
    });

    testWidgets('Settings stays one tap away', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize, engine: _webEngine);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(FmSettings), findsOneWidget);
    });
  });

  group('with files', () {
    testWidgets('lists the pinned and recent files of a13-2c', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize, recentFiles: _files);
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('See all'), findsOneWidget);
      expect(find.text('Signed'), findsOneWidget);
      expect(find.text('Form'), findsOneWidget);
      // Pinned files are in Recent too, as the boards list them.
      expect(find.text('Kira sözleşmesi.pdf'), findsNWidgets(2));
      expect(find.text('No documents yet'), findsNothing);
    });

    testWidgets("the heading is the phone board's word in Turkish", (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        size: goldenPhoneSize,
        settings: _in('tr'),
        recentFiles: _files,
      );
      expect(find.text('Son açılanlar'), findsOneWidget);
      expect(find.text('Son kullanılanlar'), findsNothing);
    });

    testWidgets('at 320 px a meta line wraps: only names are cut', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        size: const Size(320, 2000),
        recentFiles: _files,
      );
      final cut = textFitProblems(tester)
          .where((problem) => !problem.text.endsWith('.pdf'));
      expect(cut, isEmpty);
    });

    testWidgets('a recent file on the web says why it does not open', (
      tester,
    ) async {
      await pumpFermanApp(
        tester,
        size: goldenPhoneSize,
        engine: _webEngine,
        recentFiles: _files,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Kira sözleşmesi.pdf').last),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_reason), findsOneWidget);
      await gesture.up();
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('the FAB of a13-2c', () {
    final fab = find.byWidgetPredicate(
      (widget) =>
          widget is FermanInteractive && widget.semanticLabel == 'Open a file',
    );

    testWidgets('is disabled on the web, with its reason', (tester) async {
      await pumpFermanApp(
        tester,
        size: goldenPhoneSize,
        recentFiles: _files,
        engine: _webEngine,
      );
      expect(fab, findsOneWidget);
      final item = tester.widget<FermanInteractive>(fab);
      expect(item.onPressed, isNull);
      expect(item.disabledReason, _reason);
      expect(tester.getSize(fab), const Size.square(56));
    });

    testWidgets('the empty home has the button instead', (tester) async {
      await pumpFermanApp(tester, size: goldenPhoneSize, engine: _webEngine);
      expect(find.text('Open a file'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Open a file'),
          matching: find.byType(Button),
        ),
        findsOneWidget,
      );
    });
  });

  group('when the engine cannot open files (G101)', () {
    final failed = FakeEngineService(
      fakeStatus: const EngineStatus(
        appVersion: '0.1.0',
        apiVersion: kAppApiVersion,
        isDebugBuild: false,
        pdfium: PdfiumState.failed,
        pdfiumReason: 'cannot load the PDFium library: dlopen failed',
      ),
    );

    for (final language in const ['en', 'tr', 'ar']) {
      testWidgets('the notice fits a phone in $language', (tester) async {
        await pumpFermanApp(
          tester,
          size: const Size(320, 852),
          settings: _in(language),
          engine: failed,
        );
        expect(find.byType(Banner), findsOneWidget);
      });
    }

    testWidgets('it keeps Copy technical details, under the text', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpFermanApp(tester, size: goldenPhoneSize, engine: failed);
      final button = find.text('Copy technical details');
      expect(
        tester.getTopLeft(button).dy,
        greaterThan(
          tester.getBottomLeft(find.textContaining('A part of Ferman')).dy,
        ),
      );
      await tester.tap(button);
      await tester.pump();
      expect(copied, contains('dlopen failed'));
    });
  });
}
