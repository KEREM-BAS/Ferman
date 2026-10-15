import 'dart:io';

import 'package:icons/icons.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support.dart';

/// Icon names the design files flip with a literal name: `flip-rtl` on an
/// imported Icon, a `data-fm-flip` wrapper around literal `icon=`/`name=`
/// attributes, or `flipRtl: true` next to a literal name in the bundle.
Set<String> flippedInDesign() {
  final flipped = <String>{};
  final design = Directory(p.join(repoRoot, 'design'));
  final literal = RegExp(r'\b(?:icon|name)="([a-z0-9-]+)"');
  for (final file in design.listSync().whereType<File>()) {
    if (!file.path.endsWith('.dc.html')) continue;
    final text = readText(file);
    for (final tag in RegExp('<x-import[^>]*>').allMatches(text)) {
      final t = tag.group(0)!;
      if (!t.contains('flip-rtl="{{ true }}"')) continue;
      final name = RegExp(r'\bname="([a-z0-9-]+)"').firstMatch(t);
      if (name != null) flipped.add(name.group(1)!);
    }
    for (final marker in 'data-fm-flip'.allMatches(text)) {
      final end = text.indexOf('</span>', marker.end);
      final scope = text.substring(marker.end, end < 0 ? text.length : end);
      flipped.addAll(literal.allMatches(scope).map((m) => m.group(1)!));
    }
  }
  final bundle = readRepoFile(bundlePath).split('\n');
  for (var i = 0; i < bundle.length; i++) {
    if (!bundle[i].contains('flipRtl: true')) continue;
    for (var j = i - 1; j >= 0 && j >= i - 3; j--) {
      final name = RegExp('name: "([a-z0-9-]+)"').firstMatch(bundle[j]);
      if (name != null) flipped.add(name.group(1)!);
    }
  }
  return flipped;
}

void main() {
  test('every icon the design flips with a literal name is directional', () {
    final flipped = flippedInDesign();
    expect(flipped, isNotEmpty);
    expect(
      directionalIcons.keys.toSet().containsAll(flipped),
      isTrue,
      reason: 'flipped in the design: $flipped',
    );
  });

  test('the only directional icon flipped through data is arrow-left', () {
    final rest = directionalIcons.keys.toSet().difference(flippedInDesign());
    expect(rest, {'arrow-left'});
    final phone = readRepoFile('design/FmPhone.dc.html');
    expect(phone, contains('name="{{ navIcon }}"'));
    expect(phone, contains("'arrow-left')"));
  });

  test('every directional icon exists', () {
    final names = {for (final i in loadDesignIcons(repoRoot)) i.name};
    expect(names.containsAll(directionalIcons.keys), isTrue);
  });
}
