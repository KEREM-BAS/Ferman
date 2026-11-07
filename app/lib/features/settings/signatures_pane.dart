import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart' hide AnnotationColor;
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:ferman/features/signatures/signature_preview.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Signatures and certificates pane of Settings, board a11-1e.
///
/// The saved signatures and initials of `savedSignaturesProvider` (W3's
/// store, decision 22), each on a white card with its kind under it and a
/// button that deletes it (the board draws none; the Sign menu deletes too).
/// The certificates, the e-imza card driver and the timestamp server come
/// with certificate signatures (P3, B053) and the revocation switch with
/// signature checks (P3, B083): drawn and disabled. Nothing is listed under
/// Certificates, and the timestamp server says None, because nothing
/// connects yet.
class SignaturesPane extends ConsumerWidget {
  /// The pane.
  const new({super.key});

  /// The gap between the groups (`gap: 18px`).
  static const double groupGap = 18;

  /// The gap between the cards (`gap: 10px`).
  static const double cardGap = 10;

  /// A card's width (`width: 150px`).
  static const double cardWidth = 150;

  /// A card's padding (`padding: 10px`).
  static const double cardPadding = 10;

  /// The signature's height on a card (`height: 34px`).
  static const double inkHeight = 34;

  /// A typed name's size (`font: 500 26px/1`).
  static const double typedSize = 26;

  /// The gap in a card (`gap: 6px`).
  static const double cardInnerGap = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final colors = theme.colors;
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(savedSignaturesProvider).value ?? const [];

    Widget card(SavedSignature signature) => Container(
      width: cardWidth,
      padding: const EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: theme.ramps.paper0,
        borderRadius: BorderRadius.all(Radius.circular(theme.radius.radiusMd)),
        border: Border.all(
          color: colors.borderDefault,
          width: theme.border.borderWidth,
        ),
      ),
      child: Stack(
        children: [
          Column(
            spacing: cardInnerGap,
            children: [
              SizedBox(
                height: inkHeight,
                child: Center(
                  child: SignaturePreview(
                    signature: signature,
                    height: signature.ink is TypedInk ? typedSize : inkHeight,
                  ),
                ),
              ),
              Text(
                signature.initials
                    ? l10n.signKindInitials
                    : switch (signature.ink) {
                        TypedInk() => l10n.settingsSignatureTyped,
                        DrawnInk() => l10n.signDrawn,
                        ImageInk() => l10n.signPadImage,
                      },
                style: theme.typography.caption.copyWith(
                  color: theme.ramps.paper700,
                ),
              ),
            ],
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton(
              icon: IconName.trash2,
              size: IconButtonSize.xs,
              label: l10n.settingsDeleteSignature,
              onPressed: () => unawaited(
                ref.read(savedSignaturesProvider.notifier).remove(signature),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: groupGap,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space2,
          children: [
            Field.labelOf(context, l10n.settingsSavedSignatures),
            if (saved.isEmpty)
              Text(
                l10n.settingsSavedSignaturesNone,
                style: theme.typography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              )
            else
              Wrap(
                spacing: cardGap,
                runSpacing: cardGap,
                children: [for (final signature in saved) card(signature)],
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space2,
          children: [
            Field.labelOf(context, l10n.settingsCertificates),
            Button(
              size: ButtonSize.sm,
              icon: IconName.plus,
              disabledReason: Feature.certificateSignatures.disabledReason(
                context,
              ),
              child: Text(l10n.settingsAddCertificate),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.space.space3,
          children: [
            Expanded(
              child: Select<String>(
                label: l10n.settingsCardDriver,
                size: FieldSize.sm,
                value: 'auto',
                options: [
                  SelectOption(
                    value: 'auto',
                    label: l10n.settingsCardDriverAuto,
                  ),
                ],
                disabled: true,
                disabledReason: Feature.certificateSignatures.disabledReason(
                  context,
                ),
              ),
            ),
            Expanded(
              child: Select<String>(
                label: l10n.settingsTimestampServer,
                size: FieldSize.sm,
                value: 'none',
                options: [
                  SelectOption(
                    value: 'none',
                    label: l10n.settingsTimestampNone,
                  ),
                ],
                disabled: true,
                disabledReason: Feature.certificateSignatures.disabledReason(
                  context,
                ),
              ),
            ),
          ],
        ),
        Switch(
          value: false,
          label: l10n.settingsCheckRevocation,
          disabled: true,
          disabledReason: Feature.signatureChecks.disabledReason(context),
        ),
      ],
    );
  }
}
