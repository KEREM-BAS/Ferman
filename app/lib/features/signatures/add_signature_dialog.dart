import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:ferman/app/toast_host.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/organize/organize_dialogs.dart';
import 'package:ferman/features/signatures/saved_signatures.dart';
import 'package:ferman/features/signatures/signature_preview.dart';
import 'package:ferman/features/stamps/stamp_design.dart';
import 'package:ferman/l10n/casing.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens a5-3's dialog, for [initials] or a signature, with [yourName] typed.
void showAddSignatureDialog(
  WidgetRef ref, {
  required String yourName,
  bool initials = false,
}) => ref
    .read(organizeDialogProvider.notifier)
    .show(AddSignatureDialog(yourName: yourName, initials: initials));

/// The initials of [name]: the first letter of each word, in capitals.
String initialsOf(String name, LocaleCasing casing) => casing.upper(
  name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => String.fromCharCode(word.runes.first))
      .join(),
);

/// a5-3, a5-3b and a5-3c: Signature or Initials, then the pad (Type, Draw or
/// Image) and, for a typed name, the handwriting styles that can write every
/// letter of it (G158); when none can, a line says so and Draw and Image stay
/// (G149). Saved on this device when asked, and made what a click places.
class AddSignatureDialog extends ConsumerStatefulWidget {
  /// The dialog.
  const new({required this.yourName, this.initials = false, super.key});

  /// The gap between its parts (`gap: 14px`), between two space tokens.
  static const double gap = 14;

  /// The kind choice's width (`hint-size="200px"`).
  static const double kindWidth = 200;

  /// A style tile's height (`height: 56px`).
  static const double tileHeight = 56;

  /// The tiles' text sizes, in a5-3's order (`26px`, `17px`, `24px`).
  static const List<double> tileSizes = [26, 17, 24];

  /// The selected tile's ring (`0 0 0 2px var(--accent)`).
  static const double selectedRing = 2;

  /// The name the typed signature starts with.
  final String yourName;

  /// Whether it starts on Initials.
  final bool initials;

  @override
  ConsumerState<AddSignatureDialog> createState() => _AddSignatureDialogState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('yourName', yourName))
      ..add(FlagProperty('initials', value: initials, ifTrue: 'initials'));
  }
}

class _AddSignatureDialogState extends ConsumerState<AddSignatureDialog> {
  late bool _initials = widget.initials;
  SignatureMode _mode = SignatureMode.type;
  Color _ink = SignaturePad.blueInk;
  bool _save = true;
  SignatureValue? _value;
  Uint8List? _image;

  /// The styles that can write [_styledFor], in a5-3's order.
  List<String> _covered = const [];
  String _styledFor = '';
  String? _family;

  String _startName(LocaleCasing casing) =>
      _initials ? initialsOf(widget.yourName, casing) : widget.yourName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_value == null) {
      unawaited(_askStyles(_startName(LocaleCasing.of(context))));
    }
  }

  String get _text =>
      (_value?.text ?? _startName(LocaleCasing.of(context))).trim();

  Future<void> _askStyles(String text) async {
    final name = text.trim();
    if (name == _styledFor && _covered.isNotEmpty) return;
    _styledFor = name;
    List<HandwritingStyle> styles;
    try {
      styles = name.isEmpty
          ? const []
          : await ref.read(engineServiceProvider).handwritingStyles(name);
    } on Exception {
      styles = const [];
    }
    if (!mounted || name != _styledFor) return;
    final covered = {
      for (final style in styles)
        if (style.covered) style.family,
    };
    setState(() {
      _covered = [
        for (final family in handwritingFamilies)
          if (covered.contains(family)) family,
      ];
      if (!_covered.contains(_family)) _family = _covered.firstOrNull;
    });
  }

  void _changed(SignatureValue value) {
    setState(() => _value = value);
    if (value.mode == SignatureMode.type) unawaited(_askStyles(value.text));
  }

  Future<void> _chooseImage(AppLocalizations l10n) async {
    final toasts = ref.read(toastNoticesProvider.notifier);
    final bytes = await ref
        .read(filePickerServiceProvider)
        .openImage(
          filterLabel: l10n.signImageFilter,
          largest: SavedSignature.largestImage,
        );
    if (bytes == null || !mounted) return;
    if (bytes.isEmpty) {
      toasts.show(
        tone: ToastTone.danger,
        title: (l10n) => l10n.signImageTooLarge,
      );
      return;
    }
    setState(() => _image = bytes);
  }

  /// What the dialog makes now, or null while it makes nothing.
  SavedSignature? _signature() {
    final ink = switch (_mode) {
      SignatureMode.type =>
        _text.isEmpty || _family == null || !_covered.contains(_family)
            ? null
            : TypedInk(text: _text, family: _family!),
      SignatureMode.draw =>
        (_value?.strokes ?? const []).isEmpty
            ? null
            : DrawnInk(
                strokes: _value!.strokes,
                width: SignaturePad.strokeWidth,
              ),
      SignatureMode.image => switch (_image) {
        final image? => ImageInk(image),
        null => null,
      },
    };
    if (ink == null) return null;
    return SavedSignature(
      ink: ink,
      color: annotationColorOf(_ink),
      initials: _initials,
    );
  }

  void _add(SavedSignature signature) {
    final dialog = ref.read(organizeDialogProvider.notifier);
    final placement = ref.read(signaturePlacementProvider.notifier);
    final saved = ref.read(savedSignaturesProvider.notifier);
    final toasts = ref.read(toastNoticesProvider.notifier);
    dialog.close();
    placement.choose(signature);
    if (!_save) return;
    unawaited(
      saved.add(signature).then((copy) {
        if (copy == null) {
          toasts.show(
            tone: ToastTone.danger,
            title: (l10n) => l10n.signSaveFailed,
          );
        } else if (ref.read(signaturePlacementProvider) == signature) {
          placement.choose(copy);
        }
      }),
    );
  }

  Widget _styles(BuildContext context, AppLocalizations l10n) {
    final theme = context.ferman;
    if (_covered.isEmpty) {
      if (_text.isEmpty) return const SizedBox.shrink();
      return Text(
        l10n.signNoStyle,
        style: theme.typography.caption.copyWith(
          color: theme.colors.textSecondary,
        ),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.radioGroup,
      label: l10n.signHandwriting,
      child: Row(
        spacing: theme.space.space2,
        children: [
          for (final (index, family) in handwritingFamilies.indexed)
            Expanded(
              child: _covered.contains(family)
                  ? _StyleTile(
                      family: family,
                      text: _text,
                      size: AddSignatureDialog.tileSizes[index],
                      ink: _ink,
                      checked: family == _family,
                      onPressed: () => setState(() => _family = family),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final casing = LocaleCasing.of(context);
    final dialog = ref.read(organizeDialogProvider.notifier);
    final signature = _signature();
    final title = _initials
        ? l10n.signDialogTitleInitials
        : l10n.signDialogTitle;
    return Dialog(
      title: title,
      onClose: dialog.close,
      closeLabel: l10n.organizeCancel,
      footerStart: Text(
        l10n.signSavedNote,
        style: theme.typography.caption.copyWith(
          color: theme.colors.textTertiary,
        ),
      ),
      cancelAction: Button(
        onPressed: dialog.close,
        child: Text(l10n.organizeCancel),
      ),
      actions: [
        Button(
          variant: ButtonVariant.primary,
          onPressed: signature == null ? null : () => _add(signature),
          child: Text(title),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AddSignatureDialog.gap,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: AddSignatureDialog.kindWidth,
              child: SegmentedControl<bool>(
                semanticLabel: l10n.signCreate,
                fullWidth: true,
                value: _initials,
                options: [
                  SegmentOption(value: false, label: l10n.signKindSignature),
                  SegmentOption(value: true, label: l10n.signKindInitials),
                ],
                onChanged: (initials) {
                  setState(() {
                    _initials = initials;
                    _value = null;
                  });
                  unawaited(_askStyles(_startName(casing)));
                },
              ),
            ),
          ),
          SignaturePad(
            // A new kind starts again from its own name.
            key: ValueKey(_initials),
            labels: SignaturePadLabels(
              method: l10n.signPadMethod,
              draw: l10n.signPadDraw,
              type: l10n.signPadType,
              image: l10n.signPadImage,
              drawingArea: l10n.signPadArea,
              typeName: l10n.signPadTypeName,
              namePlaceholder: l10n.signPadNamePlaceholder,
              drawHint: l10n.signPadDrawHint,
              typeHint: l10n.signPadTypeHint,
              imageHint: l10n.signPadImageHint,
              chooseImage: l10n.signPadChooseImage,
              inkColor: l10n.signPadInk,
              black: l10n.signPadBlack,
              blue: l10n.signPadBlue,
              clear: l10n.signPadClear,
              saveOnDevice: l10n.signPadSave,
            ),
            mode: _mode,
            onModeChanged: (mode) => setState(() => _mode = mode),
            initialName: _startName(casing),
            ink: _ink,
            onInkChanged: (ink) => setState(() => _ink = ink),
            saveForLater: _save,
            onSaveForLaterChanged: (save) => setState(() => _save = save),
            onChanged: _changed,
            onChooseImage: () => unawaited(_chooseImage(l10n)),
            image: _image,
          ),
          if (_mode == SignatureMode.type) _styles(context, l10n),
        ],
      ),
    );
  }
}

/// One handwriting style (a5-3's radio tiles): the name in the style on the
/// page's white, ringed in the accent when chosen.
class _StyleTile extends StatelessWidget {
  const new({
    required this.family,
    required this.text,
    required this.size,
    required this.ink,
    required this.checked,
    required this.onPressed,
  });

  final String family;
  final String text;
  final double size;
  final Color ink;
  final bool checked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    return FermanInteractive(
      onPressed: onPressed,
      checked: checked,
      inMutuallyExclusiveGroup: true,
      isButton: false,
      semanticLabel: family,
      builder: (context, states, child) => Container(
        height: AddSignatureDialog.tileHeight,
        alignment: Alignment.center,
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: theme.space.space2,
        ),
        decoration: BoxDecoration(
          color: theme.pageColors.pageBg,
          borderRadius: BorderRadius.circular(theme.radius.radiusMd),
          border: Border.all(
            color: checked || states.contains(WidgetState.focused)
                ? theme.colors.accent
                : theme.colors.borderDefault,
            width: checked
                ? AddSignatureDialog.selectedRing
                : theme.border.borderWidth,
          ),
        ),
        child: child,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          textDirection: TextDirection.ltr,
          style: handwritingStyle(context, family, size, ink),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('family', family))
      ..add(StringProperty('text', text))
      ..add(DoubleProperty('size', size))
      ..add(ColorProperty('ink', ink))
      ..add(FlagProperty('checked', value: checked, ifTrue: 'checked'))
      ..add(ObjectFlagProperty<VoidCallback>.has('onPressed', onPressed));
  }
}
