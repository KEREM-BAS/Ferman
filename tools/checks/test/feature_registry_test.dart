import 'package:checks/checks.dart';
import 'package:test/test.dart';

import 'support/fixture.dart';

const String _registry = FeatureRegistryCheck.registryPath;
const String _backlog = FeatureRegistryCheck.backlogPath;
const String _stickyNote =
    'app/lib/design/components/annotations/sticky_note.dart';
const String _signaturePad =
    'app/lib/design/components/fill_sign/signature_pad.dart';

/// A registry with [values], the text between `enum Feature {` and `;`.
String _registryWith(String values) =>
    '''
import 'package:ferman/design/components/foundation/future_version.dart';
import 'package:flutter/widgets.dart';

/// The registry. Feature.ghost('B999') in a comment does not count.
enum Feature {
$values;

  new(this.backlog);

  final String backlog;

  String disabledReason(BuildContext context) => futureVersionReason(context);
}
''';

/// A backlog with the open rows [open] and the rows [done] under Done, and
/// an example in a fenced block, with a heading, that belongs to neither.
String _backlogWith({
  List<String> open = const [],
  List<String> done = const [],
}) =>
    '''
# Backlog

## Entry format

```markdown
## Open

| B001 | Compare documents | a9-2 | Tools row › Compare | P3 | |
```

## Open

| ID | Feature | Artboards | Where it appears disabled | Target milestone | Notes |
|---|---|---|---|---|---|
${[for (final id in open) '| $id | Something | a1-1 | Somewhere | M2 | |'].join('\n')}

## Done

| ID | Feature | Shipped in | Notes |
|---|---|---|---|
${[for (final id in done) '| $id | Something | M1 | |'].join('\n')}
''';

/// A fixture that passes: `openFiles` and `zoom` with their open rows,
/// used by a screen; the component files on the reviewed list and the
/// gallery use the reason directly.
Fixture _consistent() => Fixture()
  ..write(
    _registry,
    _registryWith('''
  /// Opening files; a comment with , ; ( ) and } in it.
  openFiles('B018'),

  /// Zoom, written over lines
  /// and with a trailing comma.
  zoom(
    "B034",
  ),'''),
  )
  ..write(_backlog, _backlogWith(open: ['B018', 'B034']))
  ..write(FeatureRegistryCheck.reasonPath, '''
String futureVersionReason(BuildContext context) =>
    AppLocalizations.of(context).availableInFutureVersion;
''')
  ..write(_stickyNote, 'Object more(Object c) => futureVersionReason(c);\n')
  ..write(_signaturePad, 'Object image(Object c) => futureVersionReason(c);\n')
  ..write('app/lib/features/start/start_screen.dart', '''
import 'package:ferman/app/feature_registry.dart';

// futureVersionReason(context) in a comment does not count.
const note = 'futureVersionReason(context) in a string does not count';
Object button(Object context) => Feature.openFiles.disabledReason(context);
Object zoom(Object context) => Feature . zoom;
''')
  ..write('app/lib/features/gallery/gallery.dart', '''
Object sample(Object context) => futureVersionReason(context);
''')
  ..write('app/lib/l10n/gen/app_localizations_en.dart', '''
String get availableInFutureVersion => 'Available in a future version';
''')
  ..write('app/lib/l10n/isolated_fallback.g.dart', '''
String get availableInFutureVersion => isolate(super.availableInFutureVersion);
''');

void main() {
  test('skips when app/lib does not exist', () {
    expect(Fixture().run(const FeatureRegistryCheck()), skips);
  });

  test('fails when the registry or the backlog is missing', () {
    final fixture = Fixture()
      ..write('app/lib/main.dart', 'void main() {}\n')
      ..write(_backlog, _backlogWith());
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith(['$_registry does not exist']),
    );
    fixture
      ..write(_registry, _registryWith("  openFiles('B018')"))
      ..delete(_backlog);
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith(['$_backlog does not exist']),
    );
  });

  test('passes when the registry, the backlog and the controls agree', () {
    expect(
      _consistent().run(const FeatureRegistryCheck()),
      hasResult(Status.pass, [
        '2 features, each with an open row in $_backlog and a control',
      ]),
    );
  });

  test('reads only the Open and Done tables, outside fenced blocks', () {
    final rows = BacklogRows.parse(
      _backlogWith(open: ['B002', 'B010'], done: ['B003']),
    );
    expect(rows.open, {'B002', 'B010'});
    expect(rows.done, {'B003'});
  });

  test('fails on a value whose row is under Done: the feature shipped', () {
    final fixture = _consistent()
      ..write(_backlog, _backlogWith(open: ['B034'], done: ['B018']));
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith([
        '$_registry:7: Feature.openFiles names B018, which is under Done',
        'the feature shipped, so remove its value and wire its controls',
      ]),
    );
  });

  test('fails on a value without an open row', () {
    final fixture = _consistent()
      ..write(_backlog, _backlogWith(open: ['B034']));
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith([
        '$_registry:7: Feature.openFiles names B018, but $_backlog',
        'has no open row B018: add the row',
      ]),
    );
  });

  test('fails on a row that is both open and under Done', () {
    final fixture = _consistent()
      ..write(_backlog, _backlogWith(open: ['B018', 'B034'], done: ['B034']));
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith([
        '$_registry:11: Feature.zoom names B034, which $_backlog lists both',
      ]),
    );
  });

  test('fails on a feature that names no control', () {
    final fixture = _consistent()
      ..write(
        'app/lib/features/start/start_screen.dart',
        'Object zoom() => Feature.zoom;\n'
            '// Feature.openFiles\n'
            "const s = 'Feature.openFiles';\n"
            'Object welcome() => WelcomeFeature.openFiles;\n',
      )
      // A gallery sample and a test are not controls.
      ..write(
        'app/lib/features/gallery/sections.dart',
        'Object a() => Feature.openFiles;\n',
      )
      ..write('app/test/start_test.dart', 'Object a() => Feature.openFiles;\n');
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith([
        '$_registry:7: Feature.openFiles names no control in app/lib',
      ]),
    );
  });

  test('fails on values it cannot read', () {
    final fixture = _consistent()
      ..write(
        _registry,
        _registryWith('''
  openFiles('B018'),
  plain,
  noRow(),
  badId('18'),
  twoRows('B018', 'B019'),
  computed(row),
  shipped('B034', available: true),
  zoom('B034')'''),
      );
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith([
        '$_registry:7: cannot read the Feature value "plain"',
        '$_registry:8: cannot read Feature.noRow',
        '$_registry:9: cannot read Feature.badId',
        '$_registry:10: cannot read Feature.twoRows',
        '$_registry:11: cannot read Feature.computed',
        '$_registry:12: cannot read Feature.shipped',
      ]),
    );
  });

  test('fails when the registry has no enum Feature', () {
    final fixture = _consistent()..write(_registry, 'class Feature {}\n');
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith(['$_registry: no enum Feature']),
    );
  });

  test('fails on the reason passed without the registry', () {
    const pane = 'app/lib/features/settings/privacy_pane.dart';
    const button = 'app/lib/design/components/core/button.dart';
    final fixture = _consistent()
      ..write(
        pane,
        'Object a(Object context) => Feature.openFiles;\n'
        'Object b(Object context) => futureVersionReason(context);\n'
        'final c = futureVersionReason;\n',
      )
      ..write(
        'app/lib/app/router.dart',
        'Object d(Object l10n) => l10n.availableInFutureVersion;\n',
      )
      ..write(
        button,
        'Object e(Object context) => futureVersionReason(context);\n'
        'Object f(Object l10n) => l10n.availableInFutureVersion;\n',
      );
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith([
        '$pane:2: uses futureVersionReason; name the control',
        "control's feature in $_registry and pass Feature.<name>",
        '$pane:3: uses futureVersionReason',
        'app/lib/app/router.dart:1: reads availableInFutureVersion',
        '$button:1: uses futureVersionReason',
        '$button:2: reads availableInFutureVersion',
      ]),
    );
  });

  test('fails on a reviewed component file that no longer uses it', () {
    final fixture = _consistent()
      ..write(_stickyNote, 'Object more(Object c) => c;\n');
    expect(
      fixture.run(const FeatureRegistryCheck()),
      failsWith([
        'componentReasons lists $_stickyNote, which no longer uses',
        'no longer uses futureVersionReason: remove the entry',
      ]),
    );
  });
}
