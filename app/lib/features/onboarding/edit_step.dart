import 'package:ferman/design/components/components.dart';
import 'package:ferman/design/theme.dart';
import 'package:ferman/l10n/locale_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The end column of the first-run editing step, board a1-2a: a page of a
/// Turkish contract with the real editing frame on one paragraph, the
/// edited amount's mark and bar and a blinking caret. The board's sample
/// stays Turkish and left to right in every language: right to left never
/// mirrors a page.
class EditSpecimen extends ConsumerWidget {
  /// The specimen.
  const new({super.key});

  /// The page's padding (`padding: 44px 48px 52px`): top …
  static const double paddingTop = 44;

  /// … sides …
  static const double paddingX = 48;

  /// … and bottom.
  static const double paddingBottom = 52;

  /// The text (`font: 400 15px/1.6`).
  static const double textSize = 15;

  /// The text's line height.
  static const double textHeight = 1.6;

  /// The heading (`font: 600 15.5px/1.5`).
  static const double headingSize = 15.5;

  /// The heading's line height.
  static const double headingHeight = 1.5;

  /// The gap under the heading (`margin-bottom: 8px`).
  static const double headingGap = 8;

  /// The gap above the IBAN (`margin-top: 34px`), which the frame's font
  /// label takes part of.
  static const double ibanGap = 34;

  /// The edit bar's place before the paragraph (`left: -14px`).
  static const double barLeft = -14;

  /// The edit bar's distance from the paragraph's top (`top: 2px`).
  static const double barTop = 2;

  /// The edit bar's width.
  static const double barWidth = 2;

  /// The edit bar's height.
  static const double barHeight = 22;

  /// The sample's font size in the font label ("10,5 pt" by region).
  static const double metaPoints = 10.5;

  static const String _font = 'IBM Plex Serif';
  static const String _heading = 'Madde 4 — Kira Bedeli ve Ödeme';
  static const String _before = 'Kiracı, aylık kira bedeli olan ';
  static const String _edited = '19.500 TL';
  static const String _after =
      '’yi her ayın beşinci gününe kadar kiraya verenin aşağıdaki hesabına '
      'ödemekle yükümlüdür.';
  static const String _iban = 'IBAN: TR12 0006 4000 0011 2345 6789 01';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.ferman;
    final sample = theme.typeScale.fontDocSample;
    final format = ref.watch(regionProvider).format;
    const locale = Locale('tr');
    // One text for screen readers: the frame takes no focus here.
    return Semantics(
      container: true,
      localeForSubtree: locale,
      label: '$_heading $_before$_edited$_after $_iban',
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: sample.family,
              fontFamilyFallback: sample.fallback,
              fontSize: textSize,
              height: textHeight,
              color: theme.ramps.paper900,
            ),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(
                paddingX,
                paddingTop,
                paddingX,
                paddingBottom,
              ),
              decoration: BoxDecoration(
                color: theme.ramps.paper0,
                boxShadow: theme.elevation.shadowPage,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.only(bottom: headingGap),
                    child: Text(
                      _heading,
                      locale: locale,
                      style: TextStyle(
                        fontSize: headingSize,
                        height: headingHeight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PositionedDirectional(
                        start: barLeft,
                        top: barTop,
                        child: Container(
                          width: barWidth,
                          height: barHeight,
                          color: theme.pageColors.editMark,
                        ),
                      ),
                      TextEditBox(
                        inert: true,
                        meta: '$_font · ${format.pointSize(metaPoints)}',
                        metaPlacement: MetaPlacement.below,
                        child: const Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: _before),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: PageMark(
                                  kind: PageMarkKind.edited,
                                  child: TextSpan(text: _edited),
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: TextCaret(),
                              ),
                              TextSpan(text: _after),
                            ],
                          ),
                          locale: locale,
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: ibanGap),
                    child: Text(
                      _iban,
                      locale: locale,
                      style: TextStyle(color: theme.ramps.paper700),
                    ),
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
