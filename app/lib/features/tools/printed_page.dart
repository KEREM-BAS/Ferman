import 'dart:async';
import 'dart:ui' as ui;

import 'package:ferman/design/theme.dart';
import 'package:ferman/engine/engine_providers.dart';
import 'package:ferman/engine/engine_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One page as the print renders it ([EngineService.printPages]): Print's
/// preview, which is the real output (a9-6), and a version's page (a9-8).
/// A white page of [page]'s shape until the picture arrives.
///
/// shortcut: the page comes at the print's resolution and is scaled down;
/// ask the engine for a preview size if decoding a large page shows lag.
class PrintedPage extends ConsumerStatefulWidget {
  /// Page [handle] of [document], [page] its size.
  const new({
    required this.document,
    required this.handle,
    required this.page,
    this.includeComments = true,
    super.key,
  });

  /// The engine document.
  final int document;

  /// The page's handle.
  final int handle;

  /// The page's size, for the white page that waits.
  final PageInfo page;

  /// Whether comments and stamps show.
  final bool includeComments;

  @override
  ConsumerState<PrintedPage> createState() => _PrintedPageState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('document', document))
      ..add(IntProperty('handle', handle))
      ..add(DiagnosticsProperty<PageInfo>('page', page))
      ..add(
        FlagProperty(
          'includeComments',
          value: includeComments,
          ifFalse: 'no comments',
        ),
      );
  }
}

class _PrintedPageState extends ConsumerState<PrintedPage> {
  ui.Image? _image;
  StreamSubscription<PrintPage>? _rendering;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(PrintedPage old) {
    super.didUpdateWidget(old);
    if (old.document != widget.document ||
        old.handle != widget.handle ||
        old.includeComments != widget.includeComments) {
      _render();
    }
  }

  void _render() {
    unawaited(_rendering?.cancel());
    _rendering = ref
        .read(engineServiceProvider)
        .printPages(
          widget.document,
          pages: [widget.handle],
          includeComments: widget.includeComments,
        )
        .listen(
          (page) => ui.decodeImageFromPixels(
            page.pixels,
            page.width,
            page.height,
            ui.PixelFormat.bgra8888,
            (image) {
              if (!mounted) {
                image.dispose();
                return;
              }
              setState(() {
                _image?.dispose();
                _image = image;
              });
            },
          ),
          // The white page stays: Print says why it cannot print.
          onError: (Object _) {},
        );
  }

  @override
  void dispose() {
    unawaited(_rendering?.cancel());
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ferman;
    final page = widget.page;
    return AspectRatio(
      aspectRatio: page.height > 0 ? page.width / page.height : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.pageColors.pageBg,
          boxShadow: theme.elevation.shadowPage,
        ),
        child: _image == null
            ? const SizedBox.expand()
            : RawImage(image: _image, fit: BoxFit.fill),
      ),
    );
  }
}
