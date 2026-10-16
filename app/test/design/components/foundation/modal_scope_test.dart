import 'package:ferman/design/components/foundation/modal_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens a modal handle while it is in the tree, as Dialog does: in
/// initState (during the build) and closed in dispose.
class _BuildTimeModal extends StatefulWidget {
  const new();

  @override
  State<_BuildTimeModal> createState() => _BuildTimeModalState();
}

class _BuildTimeModalState extends State<_BuildTimeModal> {
  late final ModalHandle _handle = ModalScope.open(debugLabel: 'test');

  @override
  void initState() {
    super.initState();
    _handle.toString();
  }

  @override
  void dispose() {
    _handle.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Rebuilds with the open count, as the title bar will.
class _Listener extends StatefulWidget {
  const new();

  @override
  State<_Listener> createState() => _ListenerState();
}

class _ListenerState extends State<_Listener> {
  @override
  void initState() {
    super.initState();
    ModalScope.openCount.addListener(_changed);
  }

  @override
  void dispose() {
    ModalScope.openCount.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) =>
      Text('${ModalScope.openCount.value}', textDirection: TextDirection.ltr);
}

void main() {
  tearDown(ModalScope.debugReset);

  group('ModalScope', () {
    test('counts open handles; closing twice counts once', () {
      expect(ModalScope.openCount.value, 0);
      expect(ModalScope.isOpen, isFalse);
      final first = ModalScope.open(debugLabel: 'first');
      final second = ModalScope.open();
      expect(ModalScope.openCount.value, 2);
      expect(ModalScope.isOpen, isTrue);
      first
        ..close()
        ..close();
      expect(first.isClosed, isTrue);
      expect(ModalScope.openCount.value, 1);
      second.close();
      expect(ModalScope.openCount.value, 0);
      expect(ModalScope.isOpen, isFalse);
      expect(first.toString(), 'ModalHandle(first, closed)');
    });

    test('a handle opened before debugReset does not count after it', () {
      final stale = ModalScope.open(debugLabel: 'stale');
      ModalScope.debugReset();
      final open = ModalScope.open(debugLabel: 'open');
      expect(ModalScope.openCount.value, 1);
      stale.close();
      expect(stale.isClosed, isTrue);
      expect(ModalScope.openCount.value, 1);
      expect(ModalScope.isOpen, isTrue);
      open.close();
      expect(ModalScope.openCount.value, 0);
      // Closed after the reset and before any new modal: the next one
      // still counts.
      final early = ModalScope.open();
      ModalScope.debugReset();
      early.close();
      final next = ModalScope.open();
      expect(ModalScope.openCount.value, 1);
      next.close();
    });

    test('notifies listeners of each change', () {
      final seen = <int>[];
      void listener() => seen.add(ModalScope.openCount.value);
      ModalScope.openCount.addListener(listener);
      addTearDown(() => ModalScope.openCount.removeListener(listener));
      ModalScope.open().close();
      expect(seen, [1, 0]);
    });

    testWidgets('changes during a frame reach listeners after it, so they '
        'may rebuild', (tester) async {
      await tester.pumpWidget(const Column(children: [_Listener()]));
      expect(find.text('0'), findsOneWidget);
      // Opened while the frame builds.
      await tester.pumpWidget(
        const Column(children: [_Listener(), _BuildTimeModal()]),
      );
      expect(tester.takeException(), isNull);
      expect(ModalScope.openCount.value, 1);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      // Closed while the frame disposes it.
      await tester.pumpWidget(const Column(children: [_Listener()]));
      expect(tester.takeException(), isNull);
      expect(ModalScope.openCount.value, 0);
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
    });
  });
}
