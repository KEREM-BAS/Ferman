import 'package:ferman/design/components/core/button.dart';
import 'package:ferman/design/components/core/icon_button.dart';
import 'package:ferman/design/components/feedback/progress_bar.dart';
import 'package:ferman/design/components/feedback/spinner.dart';
import 'package:ferman/design/components/feedback/task_progress.dart';
import 'package:ferman/design/icons/icon.dart';
import 'package:ferman/design/theme.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/component_host.dart';

void main() {
  const light = FermanColorTokens.light;

  final tile = find.descendant(
    of: find.byType(TaskProgress),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.maxWidth == TaskProgress.tileSize,
    ),
  );

  BoxDecoration tileDecoration(WidgetTester tester) =>
      tester.widget<Container>(tile).decoration! as BoxDecoration;

  Icon tileIcon(WidgetTester tester) => tester.widget<Icon>(
    find.descendant(of: tile, matching: find.byType(Icon)),
  );

  group('TaskProgress card', () {
    testWidgets('running: accent tile, title, detail, Cancel, progress', (
      tester,
    ) async {
      var cancels = 0;
      await tester.pumpWidget(
        componentHost(
          TaskProgress(
            title: 'Recognizing text',
            detail: 'Page 2 of 3',
            value: 0.5,
            onCancel: () => cancels++,
            cancelLabel: 'Cancel',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find
          .descendant(
            of: find.byType(TaskProgress),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(card).width, TaskProgress.width);
      final box = tester.widget<Container>(card).decoration! as BoxDecoration;
      expect(box.color, light.surfaceRaised);
      expect(box.boxShadow, FermanElevationTokens.light.shadowPopover);
      expect(tester.getSize(tile), const Size.square(TaskProgress.tileSize));
      expect(tileDecoration(tester).color, light.accentSubtle);
      expect(tileIcon(tester).name, IconName.scanText);
      expect(tileIcon(tester).color, light.textAccent);
      expect(
        tester.widget<Text>(find.text('Recognizing text')).style!.fontWeight,
        FermanTypeTokens.weightMedium,
      );
      expect(
        tester.widget<Text>(find.text('Page 2 of 3')).style!.color,
        light.textSecondary,
      );
      final bar = tester.widget<ProgressBar>(find.byType(ProgressBar));
      expect(bar.value, 0.5);
      expect(bar.tone, ProgressTone.accent);
      final cancel = tester.widget<IconButton>(find.byType(IconButton));
      expect(cancel.size, IconButtonSize.sm);
      expect(cancel.label, 'Cancel');
      expect(cancel.showTooltip, isTrue);
      await tester.tap(find.byType(IconButton));
      expect(cancels, 1);
      // 14 px start padding.
      expect(
        tester.getTopLeft(tile).dx - tester.getTopLeft(card).dx,
        TaskProgress.paddingStart,
      );
    });

    testWidgets('running with onPause: a ghost Pause button', (tester) async {
      var pauses = 0;
      await tester.pumpWidget(
        componentHost(
          TaskProgress(
            title: 'Recognizing text',
            value: 0.2,
            onPause: () => pauses++,
            pauseLabel: 'Pause',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final pause = tester.widget<Button>(find.byType(Button));
      expect(pause.variant, ButtonVariant.ghost);
      expect(pause.size, ButtonSize.sm);
      expect(pause.icon, IconName.pause);
      await tester.tap(find.text('Pause'));
      expect(pauses, 1);
    });

    testWidgets('paused: sunken tile, paused progress, Resume', (tester) async {
      var resumes = 0;
      await tester.pumpWidget(
        componentHost(
          TaskProgress(
            title: 'Archive',
            icon: IconName.workflow,
            value: 0.43,
            state: TaskState.paused,
            onPause: () {},
            pauseLabel: 'Pause',
            onResume: () => resumes++,
            resumeLabel: 'Resume',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tileDecoration(tester).color, light.surfaceSunken);
      expect(tileIcon(tester).name, IconName.workflow);
      expect(tileIcon(tester).color, light.iconSecondary);
      expect(
        tester.widget<ProgressBar>(find.byType(ProgressBar)).tone,
        ProgressTone.paused,
      );
      expect(find.text('Pause'), findsNothing);
      final resume = tester.widget<Button>(find.byType(Button));
      expect(resume.variant, ButtonVariant.secondary);
      await tester.tap(find.text('Resume'));
      expect(resumes, 1);
    });

    testWidgets('done: success tile with circle-check, no progress, no '
        'Cancel, the actions', (tester) async {
      var shows = 0;
      var undos = 0;
      await tester.pumpWidget(
        componentHost(
          TaskProgress(
            title: 'Compressed',
            detail: '24,6 MB → 6,9 MB',
            state: TaskState.done,
            onCancel: () {},
            cancelLabel: 'Cancel',
            primaryAction: (label: 'Show', onPressed: () => shows++),
            secondaryAction: (label: 'Undo', onPressed: () => undos++),
          ),
        ),
      );
      expect(tileDecoration(tester).color, light.successBg);
      expect(tileIcon(tester).name, IconName.circleCheck);
      expect(tileIcon(tester).color, light.success);
      expect(find.byType(ProgressBar), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      final buttons = tester.widgetList<Button>(find.byType(Button)).toList();
      expect(buttons.map((button) => button.variant), [
        ButtonVariant.ghost,
        ButtonVariant.secondary,
      ]);
      expect(
        tester.getCenter(find.text('Undo')).dx,
        lessThan(tester.getCenter(find.text('Show')).dx),
      );
      await tester.tap(find.text('Show'));
      await tester.tap(find.text('Undo'));
      expect(shows, 1);
      expect(undos, 1);
    });

    testWidgets('error: danger tile with circle-alert', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const TaskProgress(title: 'Couldn’t convert', state: TaskState.error),
        ),
      );
      expect(tileDecoration(tester).color, light.dangerBg);
      expect(tileIcon(tester).name, IconName.circleAlert);
      expect(tileIcon(tester).color, light.danger);
      expect(find.byType(ProgressBar), findsNothing);
    });

    testWidgets('right to left mirrors the card', (tester) async {
      await tester.pumpWidget(
        componentHost(
          TaskProgress(
            title: 'التعرف على النص',
            value: 0.5,
            onCancel: () {},
            cancelLabel: 'إلغاء',
          ),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(tile).dx,
        greaterThan(tester.getCenter(find.text('التعرف على النص')).dx),
      );
      expect(
        tester.getCenter(find.byType(IconButton)).dx,
        lessThan(tester.getCenter(find.text('التعرف على النص')).dx),
      );
    });

    testWidgets('dark theme', (tester) async {
      await tester.pumpWidget(
        componentHost(
          const TaskProgress(title: 'Done', state: TaskState.done),
          brightness: Brightness.dark,
        ),
      );
      expect(tileDecoration(tester).color, FermanColorTokens.dark.successBg);
    });

    testWidgets('a polite live region labelled by title and detail', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        componentHost(
          const TaskProgress(
            title: 'Compressed',
            detail: 'Smaller',
            state: TaskState.done,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Compressed')),
        isSemantics(label: 'Compressed\nSmaller', isLiveRegion: true),
      );
      handle.dispose();
    });

    test('the progress tone follows the state', () {
      expect(TaskProgress.toneFor(TaskState.running), ProgressTone.accent);
      expect(TaskProgress.toneFor(TaskState.paused), ProgressTone.paused);
      expect(TaskProgress.toneFor(TaskState.done), ProgressTone.success);
      expect(TaskProgress.toneFor(TaskState.error), ProgressTone.danger);
    });
  });

  group('TaskProgress inline', () {
    testWidgets('a narrow slot ellipsizes the text; a plain row keeps it '
        'whole', (tester) async {
      Widget progress() => TaskProgress(
        variant: TaskProgressVariant.inline,
        title: 'Recognizing text',
        detail: 'Page 14 of 64 · about 2 minutes left',
        value: 0.22,
        onCancel: () {},
        cancelLabel: 'Cancel',
      );
      const label = 'Recognizing text · Page 14 of 64 · about 2 minutes left';
      await tester.pumpWidget(
        componentHost(SizedBox(width: 260, child: progress())),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TaskProgress)).width,
        lessThanOrEqualTo(260),
      );
      final text = tester.widget<Text>(find.text(label));
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
      // The bar keeps its 96 px.
      expect(
        tester.getSize(find.byType(ProgressBar)).width,
        TaskProgress.inlineProgressWidth,
      );

      // A plain Row child gets unbounded width: the text keeps its width.
      await tester.pumpWidget(
        componentHost(
          Row(mainAxisSize: MainAxisSize.min, children: [progress()]),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TaskProgress)).width, greaterThan(260));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('running: 12 px spinner, title · detail, 96 px bar, Cancel', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          TaskProgress(
            variant: TaskProgressVariant.inline,
            title: 'Indexing',
            detail: 'page 14',
            value: 0.3,
            onCancel: () {},
            cancelLabel: 'Cancel',
          ),
        ),
      );
      await tester.pump();
      final spinner = tester.widget<Spinner>(find.byType(Spinner));
      expect(spinner.size, TaskProgress.inlineSpinnerSize);
      expect(find.text('Indexing · page 14'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ProgressBar)).width,
        TaskProgress.inlineProgressWidth,
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).size,
        IconButtonSize.xs,
      );
      final style = DefaultTextStyle.of(
        tester.element(find.text('Indexing · page 14')),
      ).style;
      expect(style.color, light.textSecondary);
      expect(style.fontSize, FermanTypeTokens.sizeSm);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('done: circle-check, no bar, no Cancel', (tester) async {
      await tester.pumpWidget(
        componentHost(
          TaskProgress(
            variant: TaskProgressVariant.inline,
            title: 'Indexed',
            state: TaskState.done,
            onCancel: () {},
            cancelLabel: 'Cancel',
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.name, IconName.circleCheck);
      expect(icon.size, TaskProgress.inlineIconSize);
      expect(find.byType(ProgressBar), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(Spinner), findsNothing);
    });

    testWidgets('paused shows the pause icon and the paused bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        componentHost(
          const TaskProgress(
            variant: TaskProgressVariant.inline,
            title: 'Indexing',
            value: 0.5,
            state: TaskState.paused,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<Icon>(find.byType(Icon)).map((icon) => icon.name),
        contains(IconName.pause),
      );
      expect(
        tester.widget<ProgressBar>(find.byType(ProgressBar)).tone,
        ProgressTone.paused,
      );
    });
  });
}
