import 'dart:async';

import 'package:ferman/app/feature_registry.dart';
import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:ferman/features/editor/links.dart';
import 'package:ferman/features/viewer/viewer_state.dart';
import 'package:ferman/l10n/format.dart';
import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide Icon;
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _LinkType { web, mail, page, file }

/// a3-6's Edit link popover, or Add link's without [link]: where it goes, how
/// it looks, Remove link, Cancel and Save link. A link to a file stays disabled
/// (B200). A link whose target is not offered keeps it until a new one is
/// typed.
class LinkPopover extends ConsumerStatefulWidget {
  /// The popover of [link], or of a new one.
  const new({super.key, this.link});

  /// `width: 400px`.
  static const double width = 400;

  /// The link; null for a new one.
  final LinkInfo? link;

  @override
  ConsumerState<LinkPopover> createState() => _LinkPopoverState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LinkInfo?>('link', link));
  }
}

class _LinkPopoverState extends ConsumerState<LinkPopover> {
  late _LinkType _type;
  late LinkLook _look;
  late final Map<_LinkType, TextEditingController> _fields;
  late final Map<_LinkType, String> _before;
  String? _error;

  /// Whether the link does something Ferman shows but does not offer.
  bool get _refused => switch (widget.link?.kind) {
    LinkKind.script ||
    LinkKind.launch ||
    LinkKind.file ||
    LinkKind.address ||
    LinkKind.action ||
    LinkKind.nothing => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    final link = widget.link;
    _look = link?.look ?? LinkLook.invisible;
    _type = switch (link?.kind) {
      LinkKind.mail => _LinkType.mail,
      LinkKind.page || LinkKind.broken => _LinkType.page,
      _ => _LinkType.web,
    };
    final index = ref
        .read(viewerProvider)
        ?.document
        .pageIndexOf(link?.targetPage ?? -1);
    _before = {
      _LinkType.web: link?.kind == LinkKind.web ? link!.target : '',
      _LinkType.mail: link?.kind == LinkKind.mail
          ? mailAddressOf(link!.target)
          : '',
      _LinkType.page: switch (link?.kind) {
        LinkKind.page when index != null => '${index + 1}',
        LinkKind.broken => link?.wantedPage?.toString() ?? '',
        _ => '',
      },
    };
    _fields = {
      for (final MapEntry(:key, :value) in _before.entries)
        key: TextEditingController(text: value),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  /// What the field says; null when the target stays as it is. Sets [_error]
  /// on what cannot be a target. The engine has the last word on an address.
  LinkDestination? _destination(AppLocalizations l10n) {
    _error = null;
    final text = _fields[_type]?.text.trim() ?? '';
    if (widget.link != null && text.isNotEmpty && text == _before[_type]) {
      return null;
    }
    // Only the look can change on a link no target is offered for.
    if (text.isEmpty && _refused) return null;
    switch (_type) {
      case _LinkType.web:
        final address = text.contains('://') ? text : 'https://$text';
        if (RegExp(
          r'^https?://[^\s/?#\\]+\S*$',
          caseSensitive: false,
        ).hasMatch(address)) {
          return LinkDestination.address(address);
        }
        _error = l10n.linkErrorWeb;
      case _LinkType.mail:
        final address = mailAddressOf(text);
        if (RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(address)) {
          return LinkDestination.address(address, mail: true);
        }
        _error = l10n.linkErrorMail;
      case _LinkType.page:
        final document = ref.read(viewerProvider)?.document;
        final pages = document?.pages.length ?? 0;
        final page = int.tryParse(text);
        if (document != null && page != null && page >= 1 && page <= pages) {
          return LinkDestination.page(document.pageHandle(page - 1));
        }
        _error = l10n.linkErrorPage(pages, bidiIsolate('$pages'));
      case _LinkType.file:
        break;
    }
    return null;
  }

  void _save(AppLocalizations l10n) {
    final destination = _destination(l10n);
    if (_error != null) {
      setState(() {});
      return;
    }
    unawaited(ref.read(linkToolProvider.notifier).save(destination, _look));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final l10n = AppLocalizations.of(context);
    final tool = ref.read(linkToolProvider.notifier);
    void close() => tool.mark(null);
    final link = widget.link;
    final target = bidiIsolate(link?.target ?? '');
    final refused = switch (link?.kind) {
      LinkKind.script => l10n.linkRefusedScript,
      LinkKind.launch => l10n.linkRefusedLaunch(target),
      LinkKind.file => l10n.linkRefusedFile(target),
      LinkKind.address => l10n.linkRefusedAddress(target),
      LinkKind.action => l10n.linkRefusedAction,
      LinkKind.nothing => l10n.linksKindNothing,
      _ => null,
    };
    final title = link == null ? l10n.linkAddTitle : l10n.linkEditTitle;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: title,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
        child: FocusScope(
          autofocus: true,
          child: PopoverSurface(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: theme.space.space4,
                vertical: theme.space.space3 + theme.space.space0_5,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: theme.space.space3,
                children: [
                  Row(
                    spacing: theme.space.space2,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.typography.panelTitle.copyWith(
                            color: theme.colors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: IconName.x,
                        label: l10n.saveAsClose,
                        size: IconButtonSize.xs,
                        onPressed: close,
                      ),
                    ],
                  ),
                  if (refused != null)
                    Text(
                      refused,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(
                        color: theme.colors.warning,
                      ),
                    ),
                  SegmentedControl<_LinkType>(
                    fullWidth: true,
                    semanticLabel: l10n.linkTo,
                    value: _type,
                    onChanged: (type) => setState(() {
                      _type = type;
                      _error = null;
                    }),
                    options: [
                      SegmentOption(
                        value: _LinkType.web,
                        label: l10n.linksKindWeb,
                      ),
                      SegmentOption(
                        value: _LinkType.mail,
                        label: l10n.linksKindMail,
                      ),
                      SegmentOption(
                        value: _LinkType.page,
                        label: l10n.linksKindPage,
                      ),
                      SegmentOption(
                        value: _LinkType.file,
                        label: l10n.linkTypeFile,
                        disabled: true,
                        disabledReason: Feature.linksToFiles.disabledReason(
                          context,
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    key: ValueKey(_type),
                    size: FieldSize.sm,
                    autofocus: true,
                    controller: _fields[_type],
                    error: _error,
                    label: switch (_type) {
                      _LinkType.mail => l10n.linkFieldMail,
                      _LinkType.page => l10n.linkFieldPage,
                      _ => l10n.linkFieldWeb,
                    },
                    onSubmitted: (_) => _save(l10n),
                  ),
                  Select<LinkLook>(
                    size: FieldSize.sm,
                    label: l10n.linkAppearance,
                    value: _look,
                    onChanged: (look) => setState(() => _look = look),
                    options: [
                      SelectOption(
                        value: LinkLook.invisible,
                        label: l10n.linkLookNone,
                      ),
                      SelectOption(
                        value: LinkLook.underline,
                        label: l10n.linkLookUnderline,
                      ),
                      SelectOption(
                        value: LinkLook.box,
                        label: l10n.linkLookBox,
                      ),
                    ],
                  ),
                  Row(
                    spacing: theme.space.space1_5,
                    children: [
                      if (link != null)
                        Button(
                          size: ButtonSize.sm,
                          variant: ButtonVariant.ghost,
                          icon: IconName.trash2,
                          onPressed: () => unawaited(tool.remove()),
                          child: Text(l10n.linkRemove),
                        ),
                      const Spacer(),
                      Button(
                        size: ButtonSize.sm,
                        onPressed: close,
                        child: Text(l10n.findCancel),
                      ),
                      Button(
                        size: ButtonSize.sm,
                        variant: ButtonVariant.primary,
                        onPressed: () => _save(l10n),
                        child: Text(l10n.linkSave),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
