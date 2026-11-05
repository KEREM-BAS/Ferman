import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';

/// The canvas's tooltip for text that cannot be edited for [reason]
/// (a3-11, a3-19, G39).
String notEditableTip(AppLocalizations l10n, NotEditableReason reason) =>
    switch (reason) {
      NotEditableReason.imageOnly => l10n.editTipImageOnly,
      NotEditableReason.outlinedText => l10n.editTipOutlinedText,
      NotEditableReason.unknownText => l10n.editTipUnknownText,
      NotEditableReason.invisibleText => l10n.editTipInvisibleText,
      NotEditableReason.restricted => l10n.editTipRestricted,
      NotEditableReason.readOnly => l10n.editTipReadOnly,
      NotEditableReason.damaged => l10n.editTipDamaged,
      NotEditableReason.signatureAppearance => l10n.editTipSignature,
      NotEditableReason.annotationOrField => l10n.editTipAnnotation,
      NotEditableReason.tooComplexLimits ||
      NotEditableReason.tooComplexSplitOperator ||
      NotEditableReason.tooComplexSkewed => l10n.editTipTooComplex,
    };

/// The Edit panel callout's message for [reason] (a3-19, G39).
String notEditableBody(AppLocalizations l10n, NotEditableReason reason) =>
    switch (reason) {
      NotEditableReason.imageOnly => l10n.editBodyImageOnly,
      NotEditableReason.outlinedText => l10n.editBodyOutlinedText,
      NotEditableReason.unknownText => l10n.editBodyUnknownText,
      NotEditableReason.invisibleText => l10n.editBodyInvisibleText,
      NotEditableReason.restricted => l10n.editBodyRestricted,
      NotEditableReason.readOnly => l10n.editBodyReadOnly,
      NotEditableReason.damaged => l10n.editBodyDamaged,
      NotEditableReason.signatureAppearance => l10n.editBodySignature,
      NotEditableReason.annotationOrField => l10n.editBodyAnnotation,
      NotEditableReason.tooComplexLimits => l10n.editBodyLimits,
      NotEditableReason.tooComplexSplitOperator => l10n.editBodySplit,
      NotEditableReason.tooComplexSkewed => l10n.editBodySkewed,
    };
