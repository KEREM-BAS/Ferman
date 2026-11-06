import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/edit_session.dart';
import 'package:ferman/features/editor/font_picker_dialog.dart';
import 'package:ferman/features/editor/review_list.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
// The widgets library has its own Banner (the debug ribbon).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Banner, Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Edit panel's callouts for the text being edited (FmEditPanel):
/// missing-glyph step 3's one warning (a3-3a, a3-17: "Missing character",
/// "No font has this character" or "This font can’t be embedded") with
/// Choose a font…, which opens the a3-3b picker ([FontPickerDialog]), and
/// Keep as is; a11-1c's third choice, which keeps the characters unasked and
/// says so; step 2's "Character added from this computer", said once; a3-4's
/// "Text doesn't fit" with its three choices and the amounts the engine
/// computed, each disabled one with a3-18's reason under it, and a3-9's
/// "Totals don't update" while table cells depend on the edited one.
///
/// The first choice that can apply is the primary button, Keep and warn the
/// quiet one. Picking one goes to `DocumentEditor.resolve`, and the warning
/// goes until text overflows again. "Review the marked cells" opens Review
/// edits (a3-12).
class EditCallouts extends ConsumerWidget {
  /// The callouts of the open document's edit.
  const new({super.key, this.padded = true});

  /// Whether it brings its own inset: not inside a panel section's grid.
  final bool padded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final plan = ref.watch(documentEditorProvider.select((s) => s.asking));
    final glyphs = ref.watch(documentEditorProvider.select((s) => s.glyphs));
    final notice = ref.watch(documentEditorProvider.select((s) => s.notice));
    final marked = ref.watch(
      documentEditorProvider.select((s) => s.markedChars),
    );
    final picking = ref.watch(documentEditorProvider.select((s) => s.picking));
    final dependents = ref.watch(
      documentEditorProvider.select(
        (s) => s.active == null ? 0 : s.preview?.dependents.length ?? 0,
      ),
    );
    if (plan == null &&
        dependents == 0 &&
        glyphs == null &&
        notice == null &&
        marked.isEmpty) {
      return const SizedBox.shrink();
    }
    final editor = ref.read(documentEditorProvider.notifier);
    final gap = theme.space.space2;
    return Padding(
      padding: EdgeInsetsDirectional.all(padded ? theme.space.space3 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          if (glyphs != null) ...[
            _glyphWarning(l10n, glyphs),
            Row(
              spacing: theme.space.space1_5,
              children: [
                Button(
                  size: ButtonSize.sm,
                  onPressed: () => editor.showFontPicker(open: true),
                  child: Text(l10n.editGlyphChoose),
                ),
                Button(
                  size: ButtonSize.sm,
                  variant: ButtonVariant.ghost,
                  onPressed: () => unawaited(editor.keepAsIs()),
                  child: Text(l10n.editGlyphKeep),
                ),
              ],
            ),
            if (picking) FontPickerDialog(glyphs: glyphs),
          ],
          if (marked.isNotEmpty)
            Banner(
              tone: BannerTone.warning,
              title: l10n.editGlyphTitle,
              child: Text(
                l10n.editGlyphMarkedBody(
                  marked.runes
                      .map((c) => quoted(String.fromCharCode(c)))
                      .join(', '),
                ),
              ),
            ),
          if (notice != null)
            Banner(
              title: l10n.editGlyphAddedTitle,
              child: Text(
                l10n.editGlyphAddedBody(
                  notice.chars.runes
                      .map((c) => quoted(String.fromCharCode(c)))
                      .join(', '),
                  bidiIsolate(notice.toFont),
                ),
              ),
            ),
          if (plan != null) ...[
            Banner(
              tone: BannerTone.warning,
              title: l10n.editOverflowTitle,
              child: Text(
                l10n.editOverflowBody(plan.over, format.integer(plan.over)),
              ),
            ),
            for (final choice in OverflowChoice.values)
              _Choice(
                choice: choice,
                label: overflowChoiceLabel(l10n, format, plan, choice),
                variant: choice == OverflowChoice.keep
                    ? ButtonVariant.ghost
                    : OverflowChoice.values.firstWhere(plan.allows) == choice
                    ? ButtonVariant.primary
                    : ButtonVariant.secondary,
                reason: plan.allows(choice)
                    ? null
                    : overflowDisabledReason(l10n, format, plan, choice),
                onPressed: () => unawaited(editor.resolve(choice)),
              ),
          ],
          if (dependents > 0) ...[
            Banner(
              tone: BannerTone.warning,
              title: l10n.editTotalsTitle,
              child: Text(l10n.editTotalsBody),
            ),
            Button(
              size: ButtonSize.sm,
              icon: IconName.filePenLine,
              fullWidth: true,
              onPressed: () => showReviewList(ref),
              child: Text(
                l10n.editTotalsReview(dependents, format.integer(dependents)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('padded', value: padded, ifTrue: 'padded'));
  }
}

/// Step 3's warning for [glyphs]: why the font did not draw them and what
/// Ferman does instead (a3-3a, a3-17).
Widget _glyphWarning(AppLocalizations l10n, MissingGlyphs glyphs) {
  final chars = quotedChars(glyphs);
  final font = bidiIsolate(glyphs.reasonFont ?? glyphs.font);
  final several = {for (final c in glyphs.chars) c.text}.length > 1;
  final (title, body) = glyphs.candidates.isEmpty
      ? (l10n.editGlyphNoneTitle, l10n.editGlyphNoneBody(chars))
      : switch (glyphs.reason) {
          MissingReason.notInstalled => (
            l10n.editGlyphTitle,
            several ? l10n.editGlyphBodyMany(chars) : l10n.editGlyphBody(chars),
          ),
          MissingReason.notEmbeddable => (
            l10n.editGlyphLicenceTitle,
            glyphs.reasonEmbedding == FontEmbedding.previewAndPrint
                ? l10n.editGlyphLicenceBody(font, chars)
                : l10n.editGlyphLicenceBodyRestricted(font, chars),
          ),
          MissingReason.restricted => (
            l10n.editGlyphLicenceTitle,
            l10n.editGlyphOwnFontBody(font, chars),
          ),
        };
  return Banner(tone: BannerTone.warning, title: title, child: Text(body));
}

/// One overflow choice, with the reason it is disabled under it.
class _Choice extends StatelessWidget {
  const new({
    required this.choice,
    required this.label,
    required this.variant,
    required this.reason,
    required this.onPressed,
  });

  final OverflowChoice choice;
  final String label;
  final ButtonVariant variant;
  final String? reason;
  final VoidCallback onPressed;

  /// FmEditPanel's `gap:3px` between a choice and its reason.
  static const double reasonGap = 3;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final reason = this.reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: reasonGap,
      children: [
        Button(
          size: ButtonSize.sm,
          variant: variant,
          icon: switch (choice) {
            OverflowChoice.extend => IconName.arrowUpDown,
            OverflowChoice.tighten => IconName.minimize2,
            OverflowChoice.keep => IconName.triangleAlert,
          },
          fullWidth: true,
          disabled: reason != null,
          onPressed: reason == null ? onPressed : null,
          child: Text(label),
        ),
        if (reason != null)
          Text(
            reason,
            style: theme.typography.caption.copyWith(
              color: theme.colors.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// [choice]'s label with the amount [plan] computed (a3-4): "Extend block
/// by 1 line", "Tighten spacing slightly (−0.6%)", "Keep and warn".
String overflowChoiceLabel(
  AppLocalizations l10n,
  RegionFormat format,
  OverflowPlan plan,
  OverflowChoice choice,
) => switch (choice) {
  OverflowChoice.extend => l10n.editOverflowExtend(
    plan.extendLines ?? plan.over,
    format.integer(plan.extendLines ?? plan.over),
  ),
  OverflowChoice.tighten =>
    plan.tightenPercent == null
        // Disabled: the label names the cap that was not enough.
        ? l10n.editOverflowTighten(format.percent(tightenCapPercent))
        : l10n.editOverflowTighten(
            format.percent(plan.tightenPercent!, maxFractionDigits: 1),
          ),
  OverflowChoice.keep => l10n.editOverflowKeep,
};

/// Why [choice] cannot apply to [plan], worded from the engine's reason
/// (a3-18); null when it can.
String? overflowDisabledReason(
  AppLocalizations l10n,
  RegionFormat format,
  OverflowPlan plan,
  OverflowChoice choice,
) {
  if (plan.allows(choice)) return null;
  switch (choice) {
    case OverflowChoice.extend:
      final blocked = plan.extendBlocked;
      if (blocked == null || blocked.kind == ExtendBlockedKind.pageEdge) {
        return l10n.editOverflowExtendPageEdge;
      }
      final text = blocked.text.trim();
      // A labelled line ("IBAN: TR12 …") is named by its label, as a3-18
      // does; any other by its start.
      final label = RegExp(
        r'^(\p{L}[^\s:]{0,23}):',
        unicode: true,
      ).firstMatch(text)?.group(1);
      if (label != null) {
        return l10n.editOverflowExtendLabelBelow(bidiIsolate(label));
      }
      final runes = text.runes;
      return l10n.editOverflowExtendBelow(
        bidiIsolate(
          runes.length > _snippetChars
              ? '${String.fromCharCodes(runes.take(_snippetChars))}…'
              : text,
        ),
      );
    case OverflowChoice.tighten:
      final short = plan.tightenShort ?? plan.over;
      return l10n.editOverflowTightenShort(short, format.integer(short));
    case OverflowChoice.keep:
      return null;
  }
}

/// The tightest spacing "Tighten spacing slightly" may apply, in percent
/// (ARCHITECTURE §6.8, M3 plan decision 5).
const double tightenCapPercent = 2;

/// The characters of a blocking line its reason quotes.
const int _snippetChars = 24;

/// a3-4's "+1 line hidden": the amber status in the page margin at the end
/// of a block whose last [lines] "Keep and warn" hides, 18 px tall with a
/// 10 px warning triangle. It sits on the white page, so its colours do not
/// change with the theme. Announced as a status.
class HiddenLinesStatus extends ConsumerWidget {
  /// The status for [lines] hidden lines.
  const new({required this.lines, super.key});

  /// How many lines are hidden.
  final int lines;

  /// a3-4's `height:18px`.
  static const double height = 18;

  /// a3-4's `inset-inline-start: calc(100% + 10px)`: its gap from the frame.
  static const double gap = 10;

  /// a3-4's `bottom:-2px`: how far its bottom sits below the frame's.
  static const double drop = 2;

  /// a3-4's `font: … var(--text-2xs)/1`.
  static const double lineHeight = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final text = l10n.editOverflowHidden(lines, format.integer(lines));
    final size = theme.typeScale.size2xs;
    return Semantics(
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Container(
          height: height,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.space.space1_5,
          ),
          decoration: BoxDecoration(
            color: theme.ramps.amber500,
            borderRadius: BorderRadius.all(
              Radius.circular(theme.radius.radiusXs),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: theme.space.space1,
            children: [
              Icon(
                IconName.triangleAlert,
                size: TextEditBox.metaIconSize,
                strokeWidth: TextEditBox.metaIconStroke,
                color: theme.ramps.paper950,
              ),
              Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: theme.typography.label.copyWith(
                  fontSize: size,
                  height: lineHeight,
                  fontWeight: theme.typeScale.weightMedium,
                  color: theme.ramps.paper950,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// a11-6's "Font substituted" warning toast after a commit set characters
/// in a similar font: "This block uses EB Garamond for ‘ğ’.", with
/// Dismiss; it leaves after `DocumentEditor.toastTime`. Review is not
/// offered until the review list can name them (G128).
class FontSubstitutedToast extends ConsumerWidget {
  /// The toast of [substitution].
  const new(this.substitution, {super.key});

  /// The characters and the font they are set in.
  final FontSubstitution substitution;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Toast(
      tone: ToastTone.warning,
      title: l10n.editFontSubstituted,
      message: l10n.editFontSubstitutedBody(
        bidiIsolate(substitution.toFont),
        substitution.chars.runes
            .map((c) => quoted(String.fromCharCode(c)))
            .join(', '),
      ),
      onClose: ref.read(documentEditorProvider.notifier).dismissToast,
      closeLabel: l10n.editFontSubstitutedDismiss,
    );
  }
}
