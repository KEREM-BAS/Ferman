import 'dart:io';

import 'package:ferman/features/shell/shell_commands.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const linux = ShortcutPlatform.linux;
  const mac = ShortcutPlatform.mac;
  const ctrlShiftS = KeyBinding(
    LogicalKeyboardKey.keyS,
    control: true,
    shift: true,
  );

  group('KeyBinding.parse', () {
    test('reads back every key of the table', () {
      for (final platform in ShortcutPlatform.values) {
        for (final command in ShellCommand.values) {
          for (final binding in command.defaultsFor(platform)) {
            expect(KeyBinding.parse(binding.identity), binding);
          }
        }
      }
    });

    test('refuses what it did not write', () {
      expect(KeyBinding.parse(''), isNull);
      expect(KeyBinding.parse('X+1'), isNull);
      expect(KeyBinding.parse('SC+${LogicalKeyboardKey.keyS.keyId}'), isNull);
      expect(KeyBinding.parse('C+notanumber'), isNull);
      expect(KeyBinding.parse('C+1'), isNull);
    });
  });

  group('ShortcutBindings', () {
    test('is the table until the user changes it', () {
      const keys = ShortcutBindings(mac);
      expect(keys.caps(ShellCommand.save), ['⌘', 'S']);
      expect(keys.changed(ShellCommand.save), isFalse);
      expect(keys.caps(null), isNull);
    });

    test('taking a key leaves the command that had it with none (decision '
        '33)', () {
      // Save as has Ctrl+Shift+S in every mode, Add signature works in
      // Fill & Sign: they meet there.
      const keys = ShortcutBindings(linux);
      expect(keys.holders(ShellCommand.addSignature, ctrlShiftS), [
        ShellCommand.saveAs,
      ]);
      final next = keys.rebind(ShellCommand.addSignature, ctrlShiftS);
      expect(next.of(ShellCommand.addSignature), [ctrlShiftS]);
      expect(next.of(ShellCommand.saveAs), isEmpty);
      expect(next.caps(ShellCommand.saveAs), isNull);
      expect(next.changed(ShellCommand.saveAs), isTrue);
      expect(next.conflicts(), isEmpty);
    });

    test('a key of another mode is free', () {
      // H is the Hand tool in View and Highlight in Comment.
      const h = KeyBinding(LogicalKeyboardKey.keyH);
      const keys = ShortcutBindings(linux);
      expect(keys.holders(ShellCommand.highlight, h), isEmpty);
      expect(keys.holders(ShellCommand.handTool, h), isEmpty);
      expect(keys.holders(ShellCommand.selectTool, h), [ShellCommand.handTool]);
    });

    test('a command of every mode names each command that loses the key', () {
      const h = KeyBinding(LogicalKeyboardKey.keyH);
      const keys = ShortcutBindings(linux);
      final holders = keys.holders(ShellCommand.save, h);
      expect(
        holders,
        containsAll([ShellCommand.handTool, ShellCommand.highlight]),
      );
      final next = keys.rebind(ShellCommand.save, h);
      for (final holder in holders) {
        expect(next.of(holder), isNot(contains(h)), reason: holder.name);
      }
    });

    test('reset gives the table keys back and takes them from whoever has '
        'them', () {
      const keys = ShortcutBindings(linux);
      final moved = keys.rebind(ShellCommand.addSignature, ctrlShiftS);
      const shiftS = KeyBinding(LogicalKeyboardKey.keyS, shift: true);
      final taken = moved.rebind(ShellCommand.todaysDate, shiftS);
      final reset = taken.reset(ShellCommand.addSignature);
      expect(reset.of(ShellCommand.addSignature), [shiftS]);
      expect(reset.of(ShellCommand.todaysDate), isEmpty);
      expect(reset.changed(ShellCommand.addSignature), isFalse);
      expect(reset.conflicts(), isEmpty);
    });

    test('a key matching the table again is no change', () {
      const keys = ShortcutBindings(linux);
      const other = KeyBinding(LogicalKeyboardKey.keyJ, control: true);
      final back = keys
          .rebind(ShellCommand.save, other)
          .rebind(
            ShellCommand.save,
            const KeyBinding(LogicalKeyboardKey.keyS, control: true),
          );
      expect(back.changes, isEmpty);
    });

    test('refuses the system keys, but a command may take its own back', () {
      const keys = ShortcutBindings(linux);
      const altF4 = KeyBinding(LogicalKeyboardKey.f4, alt: true);
      const tab = KeyBinding(LogicalKeyboardKey.tab);
      expect(keys.reserved(ShellCommand.save, altF4), isTrue);
      expect(keys.reserved(ShellCommand.save, tab), isTrue);
      expect(
        keys.reserved(
          ShellCommand.save,
          const KeyBinding(LogicalKeyboardKey.escape),
        ),
        isTrue,
      );
      expect(keys.reserved(ShellCommand.nextField, tab), isFalse);
      expect(
        const ShortcutBindings(mac).reserved(
          ShellCommand.save,
          const KeyBinding(LogicalKeyboardKey.keyQ, meta: true),
        ),
        isTrue,
      );
    });

    test('round-trips through the settings, each system apart', () {
      final keys = const ShortcutBindings(linux)
          .rebind(ShellCommand.addSignature, ctrlShiftS);
      final stored = keys.toSettings({
        'mac.save': ['M+${LogicalKeyboardKey.keyJ.keyId}'],
        'linux.save': ['stale'],
      });
      expect(stored.keys, containsAll(['mac.save', 'linux.addSignature']));
      expect(stored.containsKey('linux.save'), isFalse);
      final read = ShortcutBindings.fromSettings(linux, stored);
      expect(read.of(ShellCommand.addSignature), [ctrlShiftS]);
      expect(read.of(ShellCommand.saveAs), isEmpty);
      expect(
        ShortcutBindings.fromSettings(mac, stored).caps(ShellCommand.save),
        ['⌘', 'J'],
      );
    });

    test('reads settings as untrusted', () {
      final ctrlJ = 'C+${LogicalKeyboardKey.keyJ.keyId}';
      expect(
        ShortcutBindings.fromSettings(linux, {
          'linux.nothing': [ctrlJ],
          'linux.save': const ['garbage'],
          'linux.quit': [ctrlJ],
          'linux.open': ['A+${LogicalKeyboardKey.f4.keyId}'],
        }).changes,
        isEmpty,
      );
      // Two commands on one key: the whole table as it ships.
      expect(
        ShortcutBindings.fromSettings(linux, {
          'linux.save': [ctrlJ],
          'linux.open': [ctrlJ],
        }).changes,
        isEmpty,
      );
    });
  });

  test('every command has a handler or a feature (the registry)', () {
    // The handlers are written as `ShellCommand.<name>:` map keys in the
    // scopes' source; the document jumps through `documentJumps`.
    final file = File('lib/features/shell/shell_commands.dart')
        .readAsStringSync();
    // Without the registry itself, whose keys are written the same way.
    final start = file.indexOf('unfinishedCommands = {');
    final source =
        file.substring(0, start) + file.substring(file.indexOf('};', start));
    final missing = [
      for (final command in ShellCommand.values)
        if (!unfinishedCommands.containsKey(command) &&
            !documentJumps.contains(command) &&
            !source.contains('ShellCommand.${command.name}:'))
          command.name,
    ];
    expect(missing, isEmpty);
    // A command with a handler is not also held back.
    for (final command in unfinishedCommands.keys) {
      expect(
        source.contains('ShellCommand.${command.name}:'),
        isFalse,
        reason: command.name,
      );
    }
  });
}
