import 'dart:convert';
import 'dart:io';

import 'package:ferman/features/gallery/gallery_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// The components of the component spec: name and group.
List<({String name, String group})> specComponents() {
  final spec = jsonDecode(
    File('test/design/component_spec.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return [
    for (final component
        in (spec['components']! as List<Object?>).cast<Map<String, Object?>>())
      (
        name: component['name']! as String,
        group: component['group']! as String,
      ),
  ];
}

void main() {
  test('every component of the spec has a section, in its group', () {
    final components = specComponents();
    expect(components, isNotEmpty);
    final byName = {for (final entry in galleryEntries) entry.name: entry};
    final missing = [
      for (final component in components)
        if (!byName.containsKey(component.name)) component.name,
    ];
    expect(missing, isEmpty, reason: 'components without a gallery section');
    for (final component in components) {
      expect(
        byName[component.name]!.group.id,
        component.group,
        reason: '${component.name} sits in the wrong group',
      );
    }
  });

  test('every section but the foundations is a spec component, once', () {
    final names = {for (final component in specComponents()) component.name};
    final sections = [
      for (final entry in galleryEntries)
        if (entry.group != GalleryGroup.foundation) entry.name,
    ];
    expect(sections.toSet(), names);
    expect(sections, hasLength(names.length), reason: 'a duplicate section');
    expect(
      [
        for (final entry in galleryEntries)
          if (entry.group == GalleryGroup.foundation) entry.name,
      ],
      ['FocusRing'],
    );
  });

  test('the sections come in group order', () {
    final order = [for (final entry in galleryEntries) entry.group.index];
    expect(order, [...order]..sort());
  });
}
