import 'dart:async';

import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:ferman/platform/file_picker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file pages come from, once it can be read.
@immutable
final class PageSource {
  /// The file at [path], of [pages] pages.
  const new({required this.path, required this.pages, this.password});

  /// Where it is.
  final String path;

  /// What opens it.
  final String? password;

  /// Its pages.
  final int pages;

  /// Its file name, untrusted text.
  String get name => path.split(RegExp(r'[/\\]')).last;
}

/// G45's File row, shared by Insert and Replace: the picker of G26, the file's
/// name and pages, and a locked file's password inline, as the a1-8 field in a
/// Combine row.
///
/// shortcut: the panel offers PDFs; an image comes in by a drop on the grid,
/// and Insert's job takes one once its panel offers them.
class PageSourceField extends ConsumerStatefulWidget {
  /// The field, reporting a usable file or null through [onChanged].
  const new({required this.onChanged, super.key});

  /// Called with the file, or null while there is none it can read.
  final ValueChanged<PageSource?> onChanged;

  @override
  ConsumerState<PageSourceField> createState() => _PageSourceFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      ObjectFlagProperty<ValueChanged<PageSource?>>.has('onChanged', onChanged),
    );
  }
}

class _PageSourceFieldState extends ConsumerState<PageSourceField> {
  final TextEditingController _password = TextEditingController();
  String? _path;
  PageSource? _source;
  CombineInputStatus? _status;
  bool _show = false;
  bool _busy = false;

  @override
  void dispose() {
    _password
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _choose(String filter) async {
    final path = await ref
        .read(filePickerServiceProvider)
        .openPdf(filterLabel: filter);
    if (path == null || !mounted) return;
    _password.clear();
    setState(() {
      _path = path;
      _source = null;
      _status = null;
    });
    widget.onChanged(null);
    await _check();
  }

  Future<void> _check() async {
    final path = _path;
    if (path == null || _busy) return;
    final password = _password.text.isEmpty ? null : _password.text;
    setState(() => _busy = true);
    CombineFileInfo? info;
    try {
      final preview = await ref.read(engineServiceProvider).combinePreview([
        CombineInput.file(path, password: password),
      ], keepForms: false);
      info = preview.files.firstOrNull;
    } on EngineException {
      // Reads as a file it cannot use.
    }
    if (!mounted) return;
    final status = info?.status ?? CombineInputStatus.unreadable;
    final source = status == CombineInputStatus.ready
        ? PageSource(path: path, pages: info!.pages, password: password)
        : null;
    setState(() {
      _busy = false;
      _status = status;
      _source = source;
    });
    widget.onChanged(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = context.ferman;
    final format = RegionFormat.forRegion(ref.watch(regionProvider).region);
    final source = _source;
    final locked = switch (_status) {
      CombineInputStatus.passwordRequired ||
      CombineInputStatus.wrongPassword ||
      CombineInputStatus.ownerPasswordRequired => true,
      _ => false,
    };
    final name = _path?.split(RegExp(r'[/\\]')).last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: theme.space.space2,
      children: [
        Row(
          spacing: theme.space.space2_5,
          children: [
            Button(
              icon: IconName.folderOpen,
              onPressed: _busy
                  ? null
                  : () => unawaited(_choose(l10n.openPdfFilter)),
              child: Text(l10n.sourceChoose),
            ),
            Expanded(
              child: Text(
                source != null
                    ? l10n.sourcePagesInfo(
                        source.pages,
                        bidiIsolate(source.name),
                        format.integer(source.pages),
                      )
                    : name == null
                    ? l10n.sourceNone
                    : bidiIsolate(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        if (locked) ...[
          TextField(
            label: l10n.unlockPassword,
            size: FieldSize.sm,
            controller: _password,
            obscureText: !_show,
            keyboardType: TextInputType.visiblePassword,
            autofocus: true,
            error: switch (_status) {
              CombineInputStatus.wrongPassword => l10n.errorWrongPassword,
              CombineInputStatus.ownerPasswordRequired => l10n.sourceForbidden,
              _ => null,
            },
            onSubmitted: (_) => unawaited(_check()),
          ),
          Row(
            children: [
              Expanded(
                child: Checkbox(
                  checked: _show,
                  label: l10n.unlockShowPassword,
                  onChanged: (value) => setState(() => _show = value),
                ),
              ),
              Button(
                size: ButtonSize.sm,
                onPressed: _busy ? null : () => unawaited(_check()),
                child: Text(l10n.sourceUnlock),
              ),
            ],
          ),
        ] else if (_status == CombineInputStatus.unreadable)
          Text(
            l10n.sourceUnreadable,
            style: theme.typography.caption.copyWith(
              color: theme.colors.danger,
            ),
          ),
      ],
    );
  }
}
