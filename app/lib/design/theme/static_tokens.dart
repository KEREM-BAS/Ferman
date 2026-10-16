// Hand-written, not generated: a view of each static token class of
// tokens.g.dart, so widgets reach every token through `context.ferman`
// (ADR 0012). Field names are the token names. When tools/tokens adds,
// renames or removes a static token, update this file:
// test/design/theme/static_tokens_test.dart fails until it matches.

import 'package:ferman/design/tokens.g.dart';
import 'package:flutter/painting.dart';

/// The colour ramps and the annotation palette ([FermanRampTokens]).
///
/// They are the same in light and dark.
final class FermanRamps {
  /// The view; use `context.ferman.ramps`.
  const new();

  /// [FermanRampTokens.amber50].
  Color get amber50 => FermanRampTokens.amber50;

  /// [FermanRampTokens.amber200].
  Color get amber200 => FermanRampTokens.amber200;

  /// [FermanRampTokens.amber300].
  Color get amber300 => FermanRampTokens.amber300;

  /// [FermanRampTokens.amber500].
  Color get amber500 => FermanRampTokens.amber500;

  /// [FermanRampTokens.amber700].
  Color get amber700 => FermanRampTokens.amber700;

  /// [FermanRampTokens.annotBlue].
  Color get annotBlue => FermanRampTokens.annotBlue;

  /// [FermanRampTokens.annotBlueInk].
  Color get annotBlueInk => FermanRampTokens.annotBlueInk;

  /// [FermanRampTokens.annotGreen].
  Color get annotGreen => FermanRampTokens.annotGreen;

  /// [FermanRampTokens.annotInk].
  Color get annotInk => FermanRampTokens.annotInk;

  /// [FermanRampTokens.annotOrange].
  Color get annotOrange => FermanRampTokens.annotOrange;

  /// [FermanRampTokens.annotPink].
  Color get annotPink => FermanRampTokens.annotPink;

  /// [FermanRampTokens.annotRed].
  Color get annotRed => FermanRampTokens.annotRed;

  /// [FermanRampTokens.annotYellow].
  Color get annotYellow => FermanRampTokens.annotYellow;

  /// [FermanRampTokens.green50].
  Color get green50 => FermanRampTokens.green50;

  /// [FermanRampTokens.green200].
  Color get green200 => FermanRampTokens.green200;

  /// [FermanRampTokens.green300].
  Color get green300 => FermanRampTokens.green300;

  /// [FermanRampTokens.green500].
  Color get green500 => FermanRampTokens.green500;

  /// [FermanRampTokens.green600].
  Color get green600 => FermanRampTokens.green600;

  /// [FermanRampTokens.ink50].
  Color get ink50 => FermanRampTokens.ink50;

  /// [FermanRampTokens.ink100].
  Color get ink100 => FermanRampTokens.ink100;

  /// [FermanRampTokens.ink200].
  Color get ink200 => FermanRampTokens.ink200;

  /// [FermanRampTokens.ink300].
  Color get ink300 => FermanRampTokens.ink300;

  /// [FermanRampTokens.ink400].
  Color get ink400 => FermanRampTokens.ink400;

  /// [FermanRampTokens.ink500].
  Color get ink500 => FermanRampTokens.ink500;

  /// [FermanRampTokens.ink600].
  Color get ink600 => FermanRampTokens.ink600;

  /// [FermanRampTokens.ink700].
  Color get ink700 => FermanRampTokens.ink700;

  /// [FermanRampTokens.ink800].
  Color get ink800 => FermanRampTokens.ink800;

  /// [FermanRampTokens.ink900].
  Color get ink900 => FermanRampTokens.ink900;

  /// [FermanRampTokens.paper0].
  Color get paper0 => FermanRampTokens.paper0;

  /// [FermanRampTokens.paper25].
  Color get paper25 => FermanRampTokens.paper25;

  /// [FermanRampTokens.paper50].
  Color get paper50 => FermanRampTokens.paper50;

  /// [FermanRampTokens.paper100].
  Color get paper100 => FermanRampTokens.paper100;

  /// [FermanRampTokens.paper150].
  Color get paper150 => FermanRampTokens.paper150;

  /// [FermanRampTokens.paper200].
  Color get paper200 => FermanRampTokens.paper200;

  /// [FermanRampTokens.paper300].
  Color get paper300 => FermanRampTokens.paper300;

  /// [FermanRampTokens.paper400].
  Color get paper400 => FermanRampTokens.paper400;

  /// [FermanRampTokens.paper500].
  Color get paper500 => FermanRampTokens.paper500;

  /// [FermanRampTokens.paper600].
  Color get paper600 => FermanRampTokens.paper600;

  /// [FermanRampTokens.paper700].
  Color get paper700 => FermanRampTokens.paper700;

  /// [FermanRampTokens.paper800].
  Color get paper800 => FermanRampTokens.paper800;

  /// [FermanRampTokens.paper900].
  Color get paper900 => FermanRampTokens.paper900;

  /// [FermanRampTokens.paper950].
  Color get paper950 => FermanRampTokens.paper950;

  /// [FermanRampTokens.red50].
  Color get red50 => FermanRampTokens.red50;

  /// [FermanRampTokens.red200].
  Color get red200 => FermanRampTokens.red200;

  /// [FermanRampTokens.red300].
  Color get red300 => FermanRampTokens.red300;

  /// [FermanRampTokens.red500].
  Color get red500 => FermanRampTokens.red500;

  /// [FermanRampTokens.red600].
  Color get red600 => FermanRampTokens.red600;

  /// [FermanRampTokens.seal100].
  Color get seal100 => FermanRampTokens.seal100;

  /// [FermanRampTokens.seal300].
  Color get seal300 => FermanRampTokens.seal300;

  /// [FermanRampTokens.seal500].
  Color get seal500 => FermanRampTokens.seal500;

  /// [FermanRampTokens.seal600].
  Color get seal600 => FermanRampTokens.seal600;

  /// [FermanRampTokens.soot0].
  Color get soot0 => FermanRampTokens.soot0;

  /// [FermanRampTokens.soot50].
  Color get soot50 => FermanRampTokens.soot50;

  /// [FermanRampTokens.soot100].
  Color get soot100 => FermanRampTokens.soot100;

  /// [FermanRampTokens.soot150].
  Color get soot150 => FermanRampTokens.soot150;

  /// [FermanRampTokens.soot200].
  Color get soot200 => FermanRampTokens.soot200;

  /// [FermanRampTokens.soot300].
  Color get soot300 => FermanRampTokens.soot300;

  /// [FermanRampTokens.soot400].
  Color get soot400 => FermanRampTokens.soot400;

  /// [FermanRampTokens.soot500].
  Color get soot500 => FermanRampTokens.soot500;

  /// [FermanRampTokens.soot600].
  Color get soot600 => FermanRampTokens.soot600;

  /// [FermanRampTokens.soot700].
  Color get soot700 => FermanRampTokens.soot700;

  /// [FermanRampTokens.soot800].
  Color get soot800 => FermanRampTokens.soot800;

  /// [FermanRampTokens.soot900].
  Color get soot900 => FermanRampTokens.soot900;
}

/// The on-page mark colours, tuned for white paper ([FermanPageColorTokens]).
///
/// They do not change in dark mode: the page stays paper-white.
final class FermanPageColors {
  /// The view; use `context.ferman.pageColors`.
  const new();

  /// [FermanPageColorTokens.diffAdded].
  Color get diffAdded => FermanPageColorTokens.diffAdded;

  /// [FermanPageColorTokens.diffAddedLine].
  Color get diffAddedLine => FermanPageColorTokens.diffAddedLine;

  /// [FermanPageColorTokens.diffChanged].
  Color get diffChanged => FermanPageColorTokens.diffChanged;

  /// [FermanPageColorTokens.diffChangedLine].
  Color get diffChangedLine => FermanPageColorTokens.diffChangedLine;

  /// [FermanPageColorTokens.diffRemoved].
  Color get diffRemoved => FermanPageColorTokens.diffRemoved;

  /// [FermanPageColorTokens.diffRemovedLine].
  Color get diffRemovedLine => FermanPageColorTokens.diffRemovedLine;

  /// [FermanPageColorTokens.editBox].
  Color get editBox => FermanPageColorTokens.editBox;

  /// [FermanPageColorTokens.editBoxHover].
  Color get editBoxHover => FermanPageColorTokens.editBoxHover;

  /// [FermanPageColorTokens.editCaret].
  Color get editCaret => FermanPageColorTokens.editCaret;

  /// [FermanPageColorTokens.editChanged].
  Color get editChanged => FermanPageColorTokens.editChanged;

  /// [FermanPageColorTokens.editChangedBg].
  Color get editChangedBg => FermanPageColorTokens.editChangedBg;

  /// [FermanPageColorTokens.editHandleFill].
  Color get editHandleFill => FermanPageColorTokens.editHandleFill;

  /// [FermanPageColorTokens.editMark].
  Color get editMark => FermanPageColorTokens.editMark;

  /// [FermanPageColorTokens.editSelection].
  Color get editSelection => FermanPageColorTokens.editSelection;

  /// [FermanPageColorTokens.formFieldBg].
  Color get formFieldBg => FermanPageColorTokens.formFieldBg;

  /// [FermanPageColorTokens.formFieldBorder].
  Color get formFieldBorder => FermanPageColorTokens.formFieldBorder;

  /// [FermanPageColorTokens.formFieldFocus].
  Color get formFieldFocus => FermanPageColorTokens.formFieldFocus;

  /// [FermanPageColorTokens.formFieldRequired].
  Color get formFieldRequired => FermanPageColorTokens.formFieldRequired;

  /// [FermanPageColorTokens.glyphMissing].
  Color get glyphMissing => FermanPageColorTokens.glyphMissing;

  /// [FermanPageColorTokens.glyphMissingBg].
  Color get glyphMissingBg => FermanPageColorTokens.glyphMissingBg;

  /// [FermanPageColorTokens.ocrLow].
  Color get ocrLow => FermanPageColorTokens.ocrLow;

  /// [FermanPageColorTokens.ocrLowBg].
  Color get ocrLowBg => FermanPageColorTokens.ocrLowBg;

  /// [FermanPageColorTokens.overflowMark].
  Color get overflowMark => FermanPageColorTokens.overflowMark;

  /// [FermanPageColorTokens.pageBg].
  Color get pageBg => FermanPageColorTokens.pageBg;

  /// [FermanPageColorTokens.redactApplied].
  Color get redactApplied => FermanPageColorTokens.redactApplied;

  /// [FermanPageColorTokens.redactPending].
  Color get redactPending => FermanPageColorTokens.redactPending;

  /// [FermanPageColorTokens.redactPendingBg].
  Color get redactPendingBg => FermanPageColorTokens.redactPendingBg;

  /// [FermanPageColorTokens.searchCurrent].
  Color get searchCurrent => FermanPageColorTokens.searchCurrent;

  /// [FermanPageColorTokens.searchCurrentBorder].
  Color get searchCurrentBorder => FermanPageColorTokens.searchCurrentBorder;

  /// [FermanPageColorTokens.searchMatch].
  Color get searchMatch => FermanPageColorTokens.searchMatch;

  /// [FermanPageColorTokens.translatedMark].
  Color get translatedMark => FermanPageColorTokens.translatedMark;
}

/// The type scale: sizes, line heights, weights, tracking, font features and
/// font stacks ([FermanTypeTokens]).
///
/// Prefer the type roles (`context.ferman.typography`) for text styles.
final class FermanTypeScale {
  /// The view; use `context.ferman.typeScale`.
  const new();

  /// [FermanTypeTokens.featuresUi].
  List<FontFeature> get featuresUi => FermanTypeTokens.featuresUi;

  /// [FermanTypeTokens.fontArabic].
  FermanFontStack get fontArabic => FermanTypeTokens.fontArabic;

  /// [FermanTypeTokens.fontBrand].
  FermanFontStack get fontBrand => FermanTypeTokens.fontBrand;

  /// [FermanTypeTokens.fontDocCjk].
  FermanFontStack get fontDocCjk => FermanTypeTokens.fontDocCjk;

  /// [FermanTypeTokens.fontDocSample].
  FermanFontStack get fontDocSample => FermanTypeTokens.fontDocSample;

  /// [FermanTypeTokens.fontHand1].
  FermanFontStack get fontHand1 => FermanTypeTokens.fontHand1;

  /// [FermanTypeTokens.fontHand2].
  FermanFontStack get fontHand2 => FermanTypeTokens.fontHand2;

  /// [FermanTypeTokens.fontHand3].
  FermanFontStack get fontHand3 => FermanTypeTokens.fontHand3;

  /// [FermanTypeTokens.fontMono].
  FermanFontStack get fontMono => FermanTypeTokens.fontMono;

  /// [FermanTypeTokens.fontUi].
  FermanFontStack get fontUi => FermanTypeTokens.fontUi;

  /// [FermanTypeTokens.height2xl].
  double get height2xl => FermanTypeTokens.height2xl;

  /// [FermanTypeTokens.height2xs].
  double get height2xs => FermanTypeTokens.height2xs;

  /// [FermanTypeTokens.height3xl].
  double get height3xl => FermanTypeTokens.height3xl;

  /// [FermanTypeTokens.height4xl].
  double get height4xl => FermanTypeTokens.height4xl;

  /// [FermanTypeTokens.heightLg].
  double get heightLg => FermanTypeTokens.heightLg;

  /// [FermanTypeTokens.heightMd].
  double get heightMd => FermanTypeTokens.heightMd;

  /// [FermanTypeTokens.heightSm].
  double get heightSm => FermanTypeTokens.heightSm;

  /// [FermanTypeTokens.heightXl].
  double get heightXl => FermanTypeTokens.heightXl;

  /// [FermanTypeTokens.heightXs].
  double get heightXs => FermanTypeTokens.heightXs;

  /// [FermanTypeTokens.leading2xl].
  double get leading2xl => FermanTypeTokens.leading2xl;

  /// [FermanTypeTokens.leading2xs].
  double get leading2xs => FermanTypeTokens.leading2xs;

  /// [FermanTypeTokens.leading3xl].
  double get leading3xl => FermanTypeTokens.leading3xl;

  /// [FermanTypeTokens.leading4xl].
  double get leading4xl => FermanTypeTokens.leading4xl;

  /// [FermanTypeTokens.leadingLg].
  double get leadingLg => FermanTypeTokens.leadingLg;

  /// [FermanTypeTokens.leadingMd].
  double get leadingMd => FermanTypeTokens.leadingMd;

  /// [FermanTypeTokens.leadingSm].
  double get leadingSm => FermanTypeTokens.leadingSm;

  /// [FermanTypeTokens.leadingXl].
  double get leadingXl => FermanTypeTokens.leadingXl;

  /// [FermanTypeTokens.leadingXs].
  double get leadingXs => FermanTypeTokens.leadingXs;

  /// [FermanTypeTokens.numericTabular].
  List<FontFeature> get numericTabular => FermanTypeTokens.numericTabular;

  /// [FermanTypeTokens.size2xl].
  double get size2xl => FermanTypeTokens.size2xl;

  /// [FermanTypeTokens.size2xs].
  double get size2xs => FermanTypeTokens.size2xs;

  /// [FermanTypeTokens.size3xl].
  double get size3xl => FermanTypeTokens.size3xl;

  /// [FermanTypeTokens.size4xl].
  double get size4xl => FermanTypeTokens.size4xl;

  /// [FermanTypeTokens.sizeLg].
  double get sizeLg => FermanTypeTokens.sizeLg;

  /// [FermanTypeTokens.sizeMd].
  double get sizeMd => FermanTypeTokens.sizeMd;

  /// [FermanTypeTokens.sizeSm].
  double get sizeSm => FermanTypeTokens.sizeSm;

  /// [FermanTypeTokens.sizeXl].
  double get sizeXl => FermanTypeTokens.sizeXl;

  /// [FermanTypeTokens.sizeXs].
  double get sizeXs => FermanTypeTokens.sizeXs;

  /// [FermanTypeTokens.trackingLabel].
  double get trackingLabel => FermanTypeTokens.trackingLabel;

  /// [FermanTypeTokens.trackingNormal].
  double get trackingNormal => FermanTypeTokens.trackingNormal;

  /// [FermanTypeTokens.trackingTight].
  double get trackingTight => FermanTypeTokens.trackingTight;

  /// [FermanTypeTokens.weightMedium].
  FontWeight get weightMedium => FermanTypeTokens.weightMedium;

  /// [FermanTypeTokens.weightRegular].
  FontWeight get weightRegular => FermanTypeTokens.weightRegular;

  /// [FermanTypeTokens.weightSemibold].
  FontWeight get weightSemibold => FermanTypeTokens.weightSemibold;
}

/// The spacing scale: a 4 px base with 2 px and 6 px half steps
/// ([FermanSpaceTokens]).
final class FermanSpacing {
  /// The view; use `context.ferman.space`.
  const new();

  /// [FermanSpaceTokens.space0].
  double get space0 => FermanSpaceTokens.space0;

  /// [FermanSpaceTokens.space0_5].
  double get space0_5 => FermanSpaceTokens.space0_5;

  /// [FermanSpaceTokens.space1].
  double get space1 => FermanSpaceTokens.space1;

  /// [FermanSpaceTokens.space1_5].
  double get space1_5 => FermanSpaceTokens.space1_5;

  /// [FermanSpaceTokens.space2].
  double get space2 => FermanSpaceTokens.space2;

  /// [FermanSpaceTokens.space2_5].
  double get space2_5 => FermanSpaceTokens.space2_5;

  /// [FermanSpaceTokens.space3].
  double get space3 => FermanSpaceTokens.space3;

  /// [FermanSpaceTokens.space4].
  double get space4 => FermanSpaceTokens.space4;

  /// [FermanSpaceTokens.space5].
  double get space5 => FermanSpaceTokens.space5;

  /// [FermanSpaceTokens.space6].
  double get space6 => FermanSpaceTokens.space6;

  /// [FermanSpaceTokens.space8].
  double get space8 => FermanSpaceTokens.space8;

  /// [FermanSpaceTokens.space10].
  double get space10 => FermanSpaceTokens.space10;

  /// [FermanSpaceTokens.space12].
  double get space12 => FermanSpaceTokens.space12;

  /// [FermanSpaceTokens.space16].
  double get space16 => FermanSpaceTokens.space16;

  /// [FermanSpaceTokens.spacePx].
  double get spacePx => FermanSpaceTokens.spacePx;
}

/// Layout sizes: panel widths, document tabs, Windows caption buttons, edit
/// marks and mobile bars ([FermanSizeTokens]).
///
/// Control heights and icon sizes depend on the density; take them from
/// `context.ferman.density`.
final class FermanSizes {
  /// The view; use `context.ferman.size`.
  const new();

  /// [FermanSizeTokens.androidAppbarH].
  double get androidAppbarH => FermanSizeTokens.androidAppbarH;

  /// [FermanSizeTokens.androidNavbarH].
  double get androidNavbarH => FermanSizeTokens.androidNavbarH;

  /// [FermanSizeTokens.dialogWMd].
  double get dialogWMd => FermanSizeTokens.dialogWMd;

  /// [FermanSizeTokens.dialogWSm].
  double get dialogWSm => FermanSizeTokens.dialogWSm;

  /// [FermanSizeTokens.doctabH].
  double get doctabH => FermanSizeTokens.doctabH;

  /// [FermanSizeTokens.doctabW].
  double get doctabW => FermanSizeTokens.doctabW;

  /// [FermanSizeTokens.doctabWMin].
  double get doctabWMin => FermanSizeTokens.doctabWMin;

  /// [FermanSizeTokens.editMarkBarGap].
  double get editMarkBarGap => FermanSizeTokens.editMarkBarGap;

  /// [FermanSizeTokens.editMarkBarW].
  double get editMarkBarW => FermanSizeTokens.editMarkBarW;

  /// [FermanSizeTokens.editboxMetaH].
  double get editboxMetaH => FermanSizeTokens.editboxMetaH;

  /// [FermanSizeTokens.fabSize].
  double get fabSize => FermanSizeTokens.fabSize;

  /// [FermanSizeTokens.grabberW].
  double get grabberW => FermanSizeTokens.grabberW;

  /// [FermanSizeTokens.iosNavbarH].
  double get iosNavbarH => FermanSizeTokens.iosNavbarH;

  /// [FermanSizeTokens.iosTabbarH].
  double get iosTabbarH => FermanSizeTokens.iosTabbarH;

  /// [FermanSizeTokens.paletteW].
  double get paletteW => FermanSizeTokens.paletteW;

  /// [FermanSizeTokens.panelW].
  double get panelW => FermanSizeTokens.panelW;

  /// [FermanSizeTokens.sidebarW].
  double get sidebarW => FermanSizeTokens.sidebarW;

  /// [FermanSizeTokens.thumbBadge].
  double get thumbBadge => FermanSizeTokens.thumbBadge;

  /// [FermanSizeTokens.thumbW].
  double get thumbW => FermanSizeTokens.thumbW;

  /// [FermanSizeTokens.winCaptionW].
  double get winCaptionW => FermanSizeTokens.winCaptionW;
}

/// Corner radii ([FermanRadiusTokens]).
final class FermanRadii {
  /// The view; use `context.ferman.radius`.
  const new();

  /// [FermanRadiusTokens.radiusFull].
  double get radiusFull => FermanRadiusTokens.radiusFull;

  /// [FermanRadiusTokens.radiusLg].
  double get radiusLg => FermanRadiusTokens.radiusLg;

  /// [FermanRadiusTokens.radiusMd].
  double get radiusMd => FermanRadiusTokens.radiusMd;

  /// [FermanRadiusTokens.radiusSm].
  double get radiusSm => FermanRadiusTokens.radiusSm;

  /// [FermanRadiusTokens.radiusXl].
  double get radiusXl => FermanRadiusTokens.radiusXl;

  /// [FermanRadiusTokens.radiusXs].
  double get radiusXs => FermanRadiusTokens.radiusXs;

  /// [FermanRadiusTokens.sheetRadius].
  double get sheetRadius => FermanRadiusTokens.sheetRadius;
}

/// Border widths ([FermanBorderTokens]).
final class FermanBorders {
  /// The view; use `context.ferman.border`.
  const new();

  /// [FermanBorderTokens.borderWidth].
  double get borderWidth => FermanBorderTokens.borderWidth;

  /// [FermanBorderTokens.borderWidthStrong].
  double get borderWidthStrong => FermanBorderTokens.borderWidthStrong;
}

/// Stacking order of overlays (z-index) ([FermanZTokens]).
final class FermanLayers {
  /// The view; use `context.ferman.z`.
  const new();

  /// [FermanZTokens.zCanvas].
  int get zCanvas => FermanZTokens.zCanvas;

  /// [FermanZTokens.zDialog].
  int get zDialog => FermanZTokens.zDialog;

  /// [FermanZTokens.zEdit].
  int get zEdit => FermanZTokens.zEdit;

  /// [FermanZTokens.zPopover].
  int get zPopover => FermanZTokens.zPopover;

  /// [FermanZTokens.zSticky].
  int get zSticky => FermanZTokens.zSticky;

  /// [FermanZTokens.zToast].
  int get zToast => FermanZTokens.zToast;

  /// [FermanZTokens.zTooltip].
  int get zTooltip => FermanZTokens.zTooltip;
}

/// Hatch patterns: pending redaction stripes and thumbnail text lines
/// ([FermanHatchTokens]).
final class FermanHatches {
  /// The view; use `context.ferman.hatch`.
  const new();

  /// [FermanHatchTokens.redactPending].
  FermanHatch get redactPending => FermanHatchTokens.redactPending;

  /// [FermanHatchTokens.thumbLines].
  FermanHatch get thumbLines => FermanHatchTokens.thumbLines;
}
