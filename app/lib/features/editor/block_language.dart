import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/editor/block_editor.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/language_tag.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/l10n/region_names.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The name of the language [tag] ("en-GB", a PDF's `/Lang`) in the UI
/// language, with its region: "English (United Kingdom)". A language the
/// app has no name for shows its tag.
String blockLanguageName(BuildContext context, String tag) {
  final l10n = AppLocalizations.of(context);
  final parts = tag.split('-');
  final name = _languageName(l10n, languageTagCode(tag));
  if (name == null) return tag;
  final region = parts
      .skip(1)
      .where((part) => part.length == 2 && hasRegionName(part))
      .firstOrNull;
  if (region == null) return name;
  // The picker's form adds the region's own name in parentheses; a language
  // names only the region.
  final place = regionDisplayName(
    region,
    Localizations.localeOf(context).languageCode,
  ).split(' (').first;
  return l10n.languageWithRegion(name, place);
}

String? _languageName(AppLocalizations l10n, String code) => switch (code) {
  'tr' => l10n.languageNameTurkish,
  'en' => l10n.languageNameEnglish,
  'de' => l10n.languageNameGerman,
  'ar' => l10n.languageNameArabic,
  'ja' => l10n.languageNameJapanese,
  _ => null,
};

/// FmEditPanel's Language section (a3-14): the language of the block being
/// edited, which a choice writes in the block's transaction, over Check
/// spelling and Hyphenate, disabled until M4 (B150).
///
/// The block's editor stays open while the focus is here; when the focus
/// goes anywhere else but back to the editor, the typing commits as a blur
/// of the editor would.
class BlockLanguageSection extends ConsumerWidget {
  /// The section.
  const new({super.key});

  /// The languages FmEditPanel's select lists (`codes`).
  static const List<String> codes = ['tr', 'en', 'de', 'ar', 'ja'];

  static bool _inside<T extends Widget>() =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<T>() !=
      null;

  /// Whether the focus is in this section.
  static bool get hasFocus => _inside<BlockLanguageSection>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tag = ref.watch(documentEditorProvider.select((s) => s.language));
    final page = ref.watch(
      documentEditorProvider.select((s) => s.active?.page ?? 0),
    );
    final code = tag == null ? null : languageTagCode(tag);
    final editor = ref.read(documentEditorProvider.notifier);
    final reason = Feature.spellCheck.disabledReason(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (!focused &&
            !_inside<BlockEditor>() &&
            !editor.panelFocus.hasFocus) {
          unawaited(editor.finish());
        }
      },
      child: PanelSection(
        title: l10n.editLanguage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PanelSection.bodyGap,
          children: [
            Select<String>(
              size: FieldSize.sm,
              icon: IconName.languages,
              semanticLabel: l10n.editLanguage,
              value: code,
              options: [
                for (final option in {...codes, ?code})
                  SelectOption(
                    value: option,
                    label: _languageName(l10n, option) ?? tag ?? option,
                  ),
              ],
              onChanged: (next) {
                if (next == code) return;
                final format = RegionFormat.forRegion(
                  ref.read(regionProvider).region,
                );
                unawaited(
                  editor.setLanguage(
                    next,
                    name: l10n.editStepLanguage(format.integer(page + 1)),
                  ),
                );
              },
            ),
            Switch(
              value: false,
              disabled: true,
              label: l10n.editCheckSpelling,
              disabledReason: reason,
            ),
            Switch(
              value: false,
              disabled: true,
              label: l10n.editHyphenate,
              disabledReason: reason,
            ),
          ],
        ),
      ),
    );
  }
}
