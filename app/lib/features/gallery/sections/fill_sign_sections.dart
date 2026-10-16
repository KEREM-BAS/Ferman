import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/features/gallery/gallery_layout.dart';
import 'package:ferman/features/gallery/gallery_preview.dart';
import 'package:ferman/features/gallery/gallery_samples.dart';
import 'package:ferman/features/shell/shortcuts.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' hide Icon;

/// The copy of a form field of a type: label, value, invalid value, error,
/// placeholder.
typedef _FieldCopy = ({
  String? label,
  String? value,
  String? invalid,
  String error,
  String? placeholder,
});

_FieldCopy _copy(PdfFormFieldType type) => switch (type) {
  PdfFormFieldType.text => (
    label: GallerySamples.idNumber,
    value: GallerySamples.idNumberValue,
    invalid: GallerySamples.idNumberShort,
    error: GallerySamples.idNumberError,
    placeholder: null,
  ),
  PdfFormFieldType.multiline => (
    label: GallerySamples.notes,
    value: GallerySamples.notesValue,
    invalid: null,
    error: GallerySamples.notesError,
    placeholder: null,
  ),
  PdfFormFieldType.date => (
    label: GallerySamples.date,
    value: GallerySamples.dateValue,
    invalid: GallerySamples.dateInvalid,
    error: GallerySamples.dateError,
    placeholder: null,
  ),
  PdfFormFieldType.dropdown => (
    label: GallerySamples.province,
    value: GallerySamples.provinces[1],
    invalid: null,
    error: GallerySamples.provinceError,
    placeholder: GallerySamples.choose,
  ),
  PdfFormFieldType.checkbox || PdfFormFieldType.radio => (
    label: null,
    value: null,
    invalid: null,
    error: GallerySamples.notesError,
    placeholder: null,
  ),
  PdfFormFieldType.signature => (
    label: GallerySamples.signature,
    value: null,
    invalid: null,
    error: GallerySamples.signatureError,
    placeholder: null,
  ),
};

/// `PdfFormField`: every type in every look, required and signed, on the
/// page.
Widget pdfFormFieldSection(BuildContext context) {
  Widget field(
    PdfFormFieldType type, {
    PdfFormFieldState? state,
    bool filled = false,
    bool required = false,
    bool invalid = false,
  }) {
    final copy = _copy(type);
    final choice =
        type == PdfFormFieldType.checkbox || type == PdfFormFieldType.radio;
    return PdfFormField(
      type: type,
      state: state,
      label: copy.label,
      value: invalid
          ? (copy.invalid ?? copy.value)
          : (filled ? copy.value : null),
      placeholder: copy.placeholder,
      required: required,
      error: invalid ? copy.error : null,
      options: type == PdfFormFieldType.dropdown
          ? GallerySamples.provinces
          : const [],
      checked: choice ? filled : null,
      signedAs: type == PdfFormFieldType.signature && filled
          ? GallerySamples.ayse
          : null,
      signHereLabel: GallerySamples.signHere,
      semanticLabel: copy.label ?? GallerySamples.signature,
      onChanged: (_) {},
      onPressed: () {},
    );
  }

  return GalleryBody(
    children: [
      for (final type in PdfFormFieldType.values)
        GalleryRow(
          label: GalleryLabels.named(SpecName.type.name, type.name),
          children: [
            GallerySpecimen(
              label: PdfFormFieldState.empty.name,
              child: GalleryPage(child: field(type)),
            ),
            GallerySpecimen(
              label: GalleryLabels.hover,
              forced: GalleryForced.hover,
              child: GalleryPage(child: field(type)),
            ),
            GallerySpecimen(
              label: GalleryLabels.focusVisible,
              forced: GalleryForced.focusVisible,
              child: GalleryPage(child: field(type, filled: true)),
            ),
            GallerySpecimen(
              label: type == PdfFormFieldType.signature
                  ? SpecName.signed.name
                  : PdfFormFieldState.filled.name,
              child: GalleryPage(child: field(type, filled: true)),
            ),
            GallerySpecimen(
              label: PdfFormFieldState.focus.name,
              child: GalleryPage(
                child: field(
                  type,
                  state: PdfFormFieldState.focus,
                  filled: true,
                ),
              ),
            ),
            GallerySpecimen(
              label: PdfFormFieldState.error.name,
              child: GalleryPage(child: field(type, invalid: true)),
            ),
            GallerySpecimen(
              label: PdfFormFieldState.readonly.name,
              child: GalleryPage(
                child: field(
                  type,
                  state: PdfFormFieldState.readonly,
                  filled: true,
                ),
              ),
            ),
            GallerySpecimen(
              label: SpecName.required.name,
              child: GalleryPage(child: field(type, required: true)),
            ),
          ],
        ),
    ],
  );
}

/// `SignaturePad`: each mode, drawn, typed and in blue ink.
Widget signaturePadSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  final labels = SignaturePadLabels(
    method: GallerySamples.signatureMethod,
    draw: GallerySamples.draw,
    type: GallerySamples.type,
    image: GallerySamples.image,
    drawingArea: GallerySamples.drawingArea,
    typeName: GallerySamples.typeYourName,
    namePlaceholder: GallerySamples.yourName,
    drawHint: GallerySamples.signAboveLine,
    typeHint: GallerySamples.typeAboveLine,
    imageHint: GallerySamples.imageHint,
    chooseImage: GallerySamples.chooseImage,
    inkColor: GallerySamples.inkColor,
    black: l10n.shellColorBlack,
    blue: l10n.shellColorBlue,
    clear: GallerySamples.clear,
    saveOnDevice: GallerySamples.saveOnDevice,
  );
  Widget pad({
    SignatureMode mode = SignatureMode.draw,
    List<List<Offset>> strokes = const [],
    Color ink = SignaturePad.blackInk,
    String name = '',
  }) => GalleryValue<(SignatureMode, Color, bool)>(
    initial: (mode, ink, true),
    builder: (context, value, set) => SignaturePad(
      labels: labels,
      mode: value.$1,
      ink: value.$2,
      saveForLater: value.$3,
      initialStrokes: strokes,
      initialName: name,
      onModeChanged: (mode) => set((mode, value.$2, value.$3)),
      onInkChanged: (ink) => set((value.$1, ink, value.$3)),
      onSaveForLaterChanged: (save) => set((value.$1, value.$2, save)),
    ),
  );
  final width = theme.size.dialogWSm;
  return GalleryBody(
    children: [
      GalleryRow(
        label: SpecName.mode.name,
        children: [
          GallerySpecimen(
            label: SpecName.emptyDraw.name,
            width: width,
            child: pad(),
          ),
          GallerySpecimen(
            label: SpecName.drawing.name,
            width: width,
            child: pad(strokes: GallerySamples.signatureStrokes),
          ),
          GallerySpecimen(
            label: SpecName.typed.name,
            width: width,
            child: ExcludeFocus(
              child: pad(mode: SignatureMode.type, name: GallerySamples.ayse),
            ),
          ),
          GallerySpecimen(
            label: SignatureMode.image.name,
            width: width,
            child: pad(mode: SignatureMode.image),
          ),
        ],
      ),
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          GallerySpecimen(
            label: SpecName.areaFocusVisible.name,
            forced: GalleryForced.focusVisible,
            width: width,
            child: pad(),
          ),
          GallerySpecimen(
            label: SpecName.inkChecked.name,
            width: width,
            child: pad(
              strokes: GallerySamples.signatureStrokes,
              ink: SignaturePad.blueInk,
            ),
          ),
        ],
      ),
      const GalleryNote(GalleryLabels.noFocusNote),
    ],
  );
}

/// `DropZone`: idle with recent files, over, error and disabled.
Widget dropZoneSection(BuildContext context) {
  final theme = context.ferman;
  final l10n = AppLocalizations.of(context);
  final env = GalleryEnvironment.of(context);
  final future = futureVersionReason(context);
  Widget zone(DropZoneState state, {String? disabledReason}) => DropZone(
    state: state,
    title: l10n.startDropTitle,
    subtitle: l10n.startDropSubtitle,
    overTitle: GallerySamples.releaseToOpen,
    overSubtitle: GallerySamples.opensOnDevice,
    errorTitle: GallerySamples.notAPdf,
    errorSubtitle: GallerySamples.notAPdfSubtitle,
    openLabel: l10n.startOpenPdf,
    createLabel: l10n.startNewBlankPdf,
    recentTitle: GallerySamples.recent,
    footnote: l10n.startDropFootnote,
    shortcut: env.caps(ShellCommand.open) ?? const [],
    recent: [
      for (final (name, meta) in GallerySamples.recentFiles)
        RecentFile(name: name, meta: meta),
    ],
    onOpen: () {},
    onCreate: () {},
    onOpenRecent: (_) {},
    disabledReason: disabledReason,
  );
  final width = theme.size.dialogWMd;
  return GalleryBody(
    children: [
      GalleryRow(
        label: GalleryLabels.state,
        children: [
          for (final state in DropZoneState.values)
            GallerySpecimen(
              label: state.name,
              width: width,
              child: zone(state),
            ),
          GallerySpecimen(
            label: GalleryLabels.disabledWithReason,
            width: width,
            child: zone(DropZoneState.idle, disabledReason: future),
          ),
        ],
      ),
      const GalleryNote(GalleryLabels.dropOverNote),
    ],
  );
}
