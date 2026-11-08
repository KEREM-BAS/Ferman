import 'dart:async';

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/stamps/comment_tool_menus.dart';
import 'package:ferman/features/stamps/stamp_clock.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// a4-3b: text, a second line, colour and the language for capitals, beside a
/// live preview. Saved to My stamps and made the stamp a click places.
class CreateStampDialog extends ConsumerStatefulWidget {
  /// The dialog.
  const new({required this.yourName, super.key});

  /// The preview's width (a4-3b's `250px`).
  static const double previewWidth = 250;

  /// The preview's height (`170px`).
  static const double previewHeight = 170;

  /// The preview's turn (`rotation="{{ -4 }}"`).
  static const double previewTilt = -4;

  /// What the name field starts with.
  final String yourName;

  @override
  ConsumerState<CreateStampDialog> createState() => _CreateStampDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('yourName', yourName));
  }
}

class _CreateStampDialogState extends ConsumerState<CreateStampDialog> {
  final TextEditingController _text = TextEditingController();
  late final TextEditingController _name = TextEditingController(
    text: widget.yourName,
  );
  bool _withName = true;
  bool _withDate = true;
  bool _withTime = false;
  StampTone _tone = StampTone.ink;
  StampLanguage? _language;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    _name.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _text.dispose();
    _name.dispose();
    super.dispose();
  }

  /// The UI's language where it is one of the three.
  StampLanguage _defaultLanguage(Locale locale) =>
      StampLanguage.values
          .where((each) => each.locale.languageCode == locale.languageCode)
          .firstOrNull ??
      StampLanguage.english;

  StampDesign _design(StampLanguage language) => StampDesign(
    label: _text.text.trim(),
    tone: _tone,
    language: language,
    name: _name.text.trim(),
    withName: _withName,
    withDate: _withDate,
    withTime: _withTime,
  );

  void _save(StampDesign stamp) {
    final dialog = ref.read(organizeDialogProvider.notifier);
    final toasts = ref.read(toastNoticesProvider.notifier);
    final menus = ref.read(commentToolMenusProvider.notifier);
    dialog.close();
    unawaited(
      ref.read(myStampsProvider.notifier).add(stamp).then((saved) {
        if (saved) {
          menus.chooseStamp(stamp);
        } else {
          toasts.show(tone: ToastTone.danger, title: (l10n) => l10n.stampsFull);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final dialog = ref.read(organizeDialogProvider.notifier);
    final language =
        _language ?? _defaultLanguage(Localizations.localeOf(context));
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final now = ref.watch(stampClockProvider)();
    final stamp = _design(language);
    final empty = stamp.label.isEmpty;
    final fieldLabel = theme.typography.label.copyWith(
      color: theme.colors.textSecondary,
    );
    return Dialog(
      size: DialogSize.lg,
      title: l10n.createStampTitle,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: empty ? null : () => _save(stamp),
          child: Text(l10n.createStampSave),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: theme.space.space5,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space3,
              children: [
                TextField(
                  label: l10n.createStampText,
                  controller: _text,
                  autofocus: true,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(StampDesign.longestLabel),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space.space2,
                  children: [
                    Text(l10n.createStampSecondLine, style: fieldLabel),
                    Wrap(
                      spacing: theme.space.space4,
                      children: [
                        Checkbox(
                          label: l10n.createStampMyName,
                          checked: _withName,
                          onChanged: (value) =>
                              setState(() => _withName = value),
                        ),
                        Checkbox(
                          label: l10n.createStampDate,
                          checked: _withDate,
                          onChanged: (value) =>
                              setState(() => _withDate = value),
                        ),
                        Checkbox(
                          label: l10n.createStampTime,
                          checked: _withTime,
                          onChanged: (value) =>
                              setState(() => _withTime = value),
                        ),
                      ],
                    ),
                    TextField(
                      size: FieldSize.sm,
                      semanticLabel: l10n.createStampName,
                      controller: _name,
                      disabled: !_withName,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          StampDesign.longestName,
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: theme.space.space1_5,
                  children: [
                    Text(l10n.createStampColour, style: fieldLabel),
                    SegmentedControl<StampTone>(
                      semanticLabel: l10n.createStampColour,
                      fullWidth: true,
                      value: _tone,
                      options: [
                        SegmentOption(
                          value: StampTone.seal,
                          label: l10n.stampToneSeal,
                        ),
                        SegmentOption(
                          value: StampTone.ink,
                          label: l10n.stampToneInk,
                        ),
                        SegmentOption(
                          value: StampTone.green,
                          label: l10n.stampToneGreen,
                        ),
                        SegmentOption(
                          value: StampTone.neutral,
                          label: l10n.stampToneGrey,
                        ),
                      ],
                      onChanged: (value) => setState(() => _tone = value),
                    ),
                  ],
                ),
                Select<StampLanguage>(
                  label: l10n.createStampCaps,
                  size: FieldSize.sm,
                  value: language,
                  options: [
                    SelectOption(
                      value: StampLanguage.turkish,
                      label: l10n.createStampLanguageTurkish,
                    ),
                    SelectOption(
                      value: StampLanguage.english,
                      label: l10n.createStampLanguageEnglish,
                    ),
                    SelectOption(
                      value: StampLanguage.german,
                      label: l10n.createStampLanguageGerman,
                    ),
                  ],
                  onChanged: (value) => setState(() => _language = value),
                ),
              ],
            ),
          ),
          SizedBox(
            width: CreateStampDialog.previewWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: theme.space.space2,
              children: [
                Text(l10n.createStampPreview, style: fieldLabel),
                Container(
                  height: CreateStampDialog.previewHeight,
                  alignment: Alignment.center,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    // The page's white, in both themes.
                    color: theme.pageColors.pageBg,
                    borderRadius: BorderRadius.circular(theme.radius.radiusMd),
                    border: Border.all(color: theme.colors.borderDefault),
                  ),
                  child: empty
                      ? null
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: EdgeInsets.all(theme.space.space4),
                            child: Stamp(
                              label: stamp.label,
                              tone: _tone,
                              meta: stamp.metaAt(now, format, widget.yourName),
                              rotation: CreateStampDialog.previewTilt,
                              locale: language.locale,
                            ),
                          ),
                        ),
                ),
                Text(
                  l10n.createStampSavedNote,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
