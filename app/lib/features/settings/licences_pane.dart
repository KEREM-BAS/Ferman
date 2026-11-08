import 'package:ferman/app/licenses.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'licences_pane.g.dart';

/// A component of Settings › Licences and its licence texts.
typedef Licensed = ({String name, List<String> texts});

/// Every licence the app ships, by component, sorted by name, as
/// `licencesProvider`: what Flutter's build collects (the engine and the
/// Dart packages), the texts `registerLicenses()` adds (PDFium and its
/// packager, the fonts, the icons, the Rust crates), less the Dart packages
/// that only build and test the app ([ships]).
@riverpod
Future<List<Licensed>> licences(Ref ref) async {
  final byName = <String, List<String>>{};
  await for (final entry in LicenseRegistry.licenses) {
    if (!ships(entry)) continue;
    final text = entry.paragraphs.map((p) => p.text).join('\n\n');
    for (final name in entry.packages) {
      (byName[name] ??= []).add(text);
    }
  }
  // The names are English or package names: root casing.
  String key(String name) => LocaleCasing.root.lower(name);
  return [
    for (final name
        in byName.keys.toList()..sort((a, b) => key(a).compareTo(key(b))))
      (name: name, texts: byName[name]!),
  ];
}

/// Settings › Licences, the third-party notices (question 7 of the M4 plan,
/// G14): no board draws it, so it takes the Fonts pane's list. Ferman's own
/// licence in one line (G13), a search over the components' names, and
/// each component in a row that opens its licence texts under it.
class LicencesPane extends ConsumerStatefulWidget {
  /// The pane.
  const new({super.key});

  /// A row's padding, as the Fonts pane's (`padding: 10px 14px`):
  /// vertical …
  static const double rowPaddingY = 10;

  /// … and horizontal.
  static const double rowPaddingX = 14;

  @override
  ConsumerState<LicencesPane> createState() => _LicencesPaneState();
}

class _LicencesPaneState extends ConsumerState<LicencesPane> {
  String _query = '';
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final colors = theme.colors;
    final typography = theme.typography;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    final licences = ref.watch(licencesProvider);
    final query = casing.lower(_query.trim());
    final shown = [
      for (final licensed in licences.value ?? const <Licensed>[])
        if (casing.lower(licensed.name).contains(query)) licensed,
    ];
    final border = BorderSide(
      color: colors.borderSubtle,
      width: theme.border.borderWidth,
    );
    final radius = BorderRadius.all(Radius.circular(theme.radius.radiusMd));

    Widget row(Licensed licensed) {
      final open = _open.contains(licensed.name);
      return DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FermanInteractive(
              selected: open,
              semanticLabel: licensed.name,
              onPressed: () => setState(
                () => open
                    ? _open.remove(licensed.name)
                    : _open.add(licensed.name),
              ),
              builder: (context, states, _) => FocusRing(
                visible: states.contains(WidgetState.focused),
                style: FocusRingStyle.inset,
                child: Container(
                  color: states.contains(WidgetState.hovered)
                      ? colors.surfaceHover
                      : null,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: LicencesPane.rowPaddingX,
                    vertical: LicencesPane.rowPaddingY,
                  ),
                  child: Row(
                    spacing: theme.space.space2,
                    children: [
                      Expanded(
                        child: Text(
                          licensed.name,
                          style: typography.bodyStrong,
                        ),
                      ),
                      Icon(
                        open ? IconName.chevronUp : IconName.chevronDown,
                        color: colors.iconSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  LicencesPane.rowPaddingX,
                  0,
                  LicencesPane.rowPaddingX,
                  LicencesPane.rowPaddingY,
                ),
                // Licence texts are English, whatever the UI's direction.
                child: Text(
                  licensed.texts.join('\n\n'),
                  textDirection: TextDirection.ltr,
                  style: typography.mono.copyWith(color: colors.textSecondary),
                ),
              ),
          ],
        ),
      );
    }

    final Widget list;
    if (licences.isLoading) {
      list = Padding(
        padding: EdgeInsets.all(theme.space.space6),
        child: Center(child: Spinner(semanticLabel: l10n.licencesLoading)),
      );
    } else if (shown.isEmpty) {
      list = Padding(
        padding: EdgeInsets.all(theme.space.space6),
        child: EmptyState(
          icon: IconName.search,
          title: l10n.licencesNoMatch,
          body: l10n.settingsSearchNoMatchBody,
        ),
      );
    } else {
      list = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final licensed in shown) row(licensed)],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space3,
      children: [
        Text(
          l10n.licencesIntro,
          style: typography.body.copyWith(color: colors.textSecondary),
        ),
        TextField(
          size: FieldSize.sm,
          icon: IconName.search,
          placeholder: l10n.licencesSearch,
          semanticLabel: l10n.licencesSearch,
          onChanged: (query) => setState(() => _query = query),
        ),
        ClipRRect(
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(border),
              borderRadius: radius,
            ),
            child: list,
          ),
        ),
      ],
    );
  }
}
