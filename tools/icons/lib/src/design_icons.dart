/// Loads the icon geometry from the read-only design export.
library;

import 'dart:io';

import 'package:icons/src/errors.dart';
import 'package:icons/src/js_literal.dart';
import 'package:icons/src/text.dart';
import 'package:path/path.dart' as p;

/// The design-system bundle that holds `ICON_PATHS`, relative to the
/// repository root.
const String bundlePath =
    'design/_ds/ferman-design-system-27832349-21bc-410e-acd5-6ab20d2f87e2/'
    '_ds_bundle.js';

/// The DS additions file whose `ADD` map is merged into `ICON_PATHS` at run
/// time, relative to the repository root.
const String additionsPath = 'design/ds-additions/fm-icons.js';

/// How many icons `ICON_PATHS` holds in the export (G04).
const int bundleIconCount = 145;

/// How many icons `fm-icons.js` adds (G04, G60).
const int additionsIconCount = 84;

/// How many icons ship: every glyph of both sources, none shared.
const int totalIconCount = bundleIconCount + additionsIconCount;

/// Where an icon's path data comes from.
enum IconOrigin {
  /// `ICON_PATHS` in the design-system bundle.
  bundle('ICON_PATHS', 'const ICON_PATHS = {'),

  /// The `ADD` map of `ds-additions/fm-icons.js`.
  additions('fm-icons.js', 'var ADD = {');

  new(this.label, this.marker);

  /// A short name for tables and messages.
  final String label;

  /// The source text that opens the object literal.
  final String marker;

  /// The source file, relative to the repository root.
  String get path => switch (this) {
    IconOrigin.bundle => bundlePath,
    IconOrigin.additions => additionsPath,
  };
}

/// One icon as the design draws it.
class DesignIcon {
  /// Creates an icon named [name] whose SVG child elements are [markup].
  const new(this.name, this.markup, this.origin);

  /// The design-system name, such as `chevron-right`.
  final String name;

  /// The SVG child elements exactly as the design source holds them (the
  /// decoded JavaScript string, byte for byte).
  final String markup;

  /// The file the geometry comes from.
  final IconOrigin origin;
}

final RegExp _iconName = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

/// Reads every icon from the design export under [root], sorted by name.
///
/// Throws [IconsException] when a source cannot be read, a name is not
/// kebab-case, the two sources share a name, or the counts differ from
/// [bundleIconCount] and [additionsIconCount] (a changed export must be
/// reviewed against ADR 0013 before it ships).
List<DesignIcon> loadDesignIcons(String root) {
  final icons = <String, DesignIcon>{};
  for (final origin in IconOrigin.values) {
    final file = File(p.joinAll([root, ...origin.path.split('/')]));
    if (!file.existsSync()) {
      throw IconsException('Missing design source ${origin.path}.');
    }
    final entries = readStringMap(
      readText(file),
      origin.marker,
      sourceName: origin.path,
    );
    final expected = origin == IconOrigin.bundle
        ? bundleIconCount
        : additionsIconCount;
    if (entries.length != expected) {
      throw IconsException(
        '${origin.path} holds ${entries.length} icons; ADR 0013 expects '
        '$expected. Review the design export before changing the count.',
      );
    }
    for (final MapEntry(key: name, value: markup) in entries.entries) {
      if (!_iconName.hasMatch(name)) {
        throw IconsException(
          '${origin.path}: "$name" is not a kebab-case name.',
        );
      }
      if (markup.trim().isEmpty) {
        throw IconsException('${origin.path}: "$name" has no path data.');
      }
      final earlier = icons[name];
      if (earlier != null) {
        throw IconsException(
          '"$name" is in both ${earlier.origin.path} and ${origin.path}.',
        );
      }
      icons[name] = DesignIcon(name, markup, origin);
    }
  }
  return icons.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}
