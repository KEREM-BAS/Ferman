// GENERATED — do not edit; run (cd tools/tokens && dart run)
//
// Design tokens from the CSS custom properties in design/ (ADR 0012):
// design/_ds/<design system>/tokens/*.css, then
// design/ds-additions/fm-additions.css, which loads last and wins.
// Hatch patterns come from tools/tokens/supplement.yaml.
// Widgets read these through the ThemeExtensions in theme.dart and never
// hard-code colours, sizes, radii or durations.

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Colour ramps and the annotation palette (colors.css).
///
/// They are the same in the light and dark themes; the semantic colour tokens
/// alias them.
abstract final class FermanRampTokens {
  /// `--amber-50`. Source: `#FDF3E1` (colors.css:61).
  static const Color amber50 = Color(0xFFFDF3E1);

  /// `--amber-200`. Source: `#F0CD8F` (colors.css:62).
  static const Color amber200 = Color(0xFFF0CD8F);

  /// `--amber-300`. Source: `#F0B04A` (colors.css:65).
  static const Color amber300 = Color(0xFFF0B04A);

  /// `--amber-500`. Source: `#D98A0B` (colors.css:63).
  static const Color amber500 = Color(0xFFD98A0B);

  /// `--amber-700`. Source: `#9A5B00` (colors.css:64).
  static const Color amber700 = Color(0xFF9A5B00);

  /// `--annot-blue`. Source: `#A8D1FF` (colors.css:75).
  static const Color annotBlue = Color(0xFFA8D1FF);

  /// `--annot-blue-ink`. Source: `#2A4DAF` (colors.css:80).
  static const Color annotBlueInk = Color(0xFF2A4DAF);

  /// `--annot-green`. Source: `#A8E6A1` (colors.css:74).
  static const Color annotGreen = Color(0xFFA8E6A1);

  /// `--annot-ink`. Source: `#1F1D1A` (colors.css:78).
  static const Color annotInk = Color(0xFF1F1D1A);

  /// `--annot-orange`. Source: `#FFC58A` (colors.css:77).
  static const Color annotOrange = Color(0xFFFFC58A);

  /// `--annot-pink`. Source: `#FFB3C7` (colors.css:76).
  static const Color annotPink = Color(0xFFFFB3C7);

  /// `--annot-red`. Source: `#D93A2B` (colors.css:79).
  static const Color annotRed = Color(0xFFD93A2B);

  /// `--annot-yellow`. Source: `#FFE066` (colors.css:73).
  static const Color annotYellow = Color(0xFFFFE066);

  /// `--green-50`. Source: `#E7F4EC` (colors.css:56).
  static const Color green50 = Color(0xFFE7F4EC);

  /// `--green-200`. Source: `#A9D8BC` (colors.css:57).
  static const Color green200 = Color(0xFFA9D8BC);

  /// `--green-300`. Source: `#4CC07E` (colors.css:60).
  static const Color green300 = Color(0xFF4CC07E);

  /// `--green-500`. Source: `#2E9A5C` (colors.css:58).
  static const Color green500 = Color(0xFF2E9A5C);

  /// `--green-600`. Source: `#1E7A46` (colors.css:59).
  static const Color green600 = Color(0xFF1E7A46);

  /// `--ink-50`. Source: `#EEF2FC` (colors.css:8).
  static const Color ink50 = Color(0xFFEEF2FC);

  /// `--ink-100`. Source: `#DCE4F8` (colors.css:9).
  static const Color ink100 = Color(0xFFDCE4F8);

  /// `--ink-200`. Source: `#B8C8F0` (colors.css:10).
  static const Color ink200 = Color(0xFFB8C8F0);

  /// `--ink-300`. Source: `#8BA4E4` (colors.css:11).
  static const Color ink300 = Color(0xFF8BA4E4);

  /// `--ink-400`. Source: `#5D7FD6` (colors.css:12).
  static const Color ink400 = Color(0xFF5D7FD6);

  /// `--ink-500`. Source: `#3A60C6` (colors.css:13).
  static const Color ink500 = Color(0xFF3A60C6);

  /// `--ink-600`. Source: `#2A4DAF` (colors.css:14).
  static const Color ink600 = Color(0xFF2A4DAF);

  /// `--ink-700`. Source: `#213E8E` (colors.css:15).
  static const Color ink700 = Color(0xFF213E8E);

  /// `--ink-800`. Source: `#1A3170` (colors.css:16).
  static const Color ink800 = Color(0xFF1A3170);

  /// `--ink-900`. Source: `#142553` (colors.css:17).
  static const Color ink900 = Color(0xFF142553);

  /// `--paper-0`. Source: `#FFFFFF` (colors.css:26).
  static const Color paper0 = Color(0xFFFFFFFF);

  /// `--paper-25`. Source: `#FCFBF9` (colors.css:27).
  static const Color paper25 = Color(0xFFFCFBF9);

  /// `--paper-50`. Source: `#F7F6F3` (colors.css:28).
  static const Color paper50 = Color(0xFFF7F6F3);

  /// `--paper-100`. Source: `#F0EEEA` (colors.css:29).
  static const Color paper100 = Color(0xFFF0EEEA);

  /// `--paper-150`. Source: `#E8E5DF` (colors.css:30).
  static const Color paper150 = Color(0xFFE8E5DF);

  /// `--paper-200`. Source: `#DEDAD2` (colors.css:31).
  static const Color paper200 = Color(0xFFDEDAD2);

  /// `--paper-300`. Source: `#C9C4BA` (colors.css:32).
  static const Color paper300 = Color(0xFFC9C4BA);

  /// `--paper-400`. Source: `#A39E94` (colors.css:33).
  static const Color paper400 = Color(0xFFA39E94);

  /// `--paper-500`. Source: `#8A857C` (colors.css:34).
  static const Color paper500 = Color(0xFF8A857C);

  /// `--paper-600`. Source: `#6F6A62` (colors.css:35).
  static const Color paper600 = Color(0xFF6F6A62);

  /// `--paper-700`. Source: `#57534C` (colors.css:36).
  static const Color paper700 = Color(0xFF57534C);

  /// `--paper-800`. Source: `#3A3732` (colors.css:37).
  static const Color paper800 = Color(0xFF3A3732);

  /// `--paper-900`. Source: `#1F1D1A` (colors.css:38).
  static const Color paper900 = Color(0xFF1F1D1A);

  /// `--paper-950`. Source: `#141311` (colors.css:39).
  static const Color paper950 = Color(0xFF141311);

  /// `--red-50`. Source: `#FCEBE9` (colors.css:66).
  static const Color red50 = Color(0xFFFCEBE9);

  /// `--red-200`. Source: `#F2B8B1` (colors.css:67).
  static const Color red200 = Color(0xFFF2B8B1);

  /// `--red-300`. Source: `#F07A6E` (colors.css:70).
  static const Color red300 = Color(0xFFF07A6E);

  /// `--red-500`. Source: `#D93A2B` (colors.css:68).
  static const Color red500 = Color(0xFFD93A2B);

  /// `--red-600`. Source: `#B42318` (colors.css:69).
  static const Color red600 = Color(0xFFB42318);

  /// `--seal-100`. Source: `#F8E3DF` (colors.css:20).
  static const Color seal100 = Color(0xFFF8E3DF);

  /// `--seal-300`. Source: `#E0675A` (colors.css:23).
  static const Color seal300 = Color(0xFFE0675A);

  /// `--seal-500`. Source: `#B5372A` (colors.css:21).
  static const Color seal500 = Color(0xFFB5372A);

  /// `--seal-600`. Source: `#962C21` (colors.css:22).
  static const Color seal600 = Color(0xFF962C21);

  /// `--soot-0`. Source: `#0E0E0D` (colors.css:42).
  static const Color soot0 = Color(0xFF0E0E0D);

  /// `--soot-50`. Source: `#161615` (colors.css:43).
  static const Color soot50 = Color(0xFF161615);

  /// `--soot-100`. Source: `#1D1C1B` (colors.css:44).
  static const Color soot100 = Color(0xFF1D1C1B);

  /// `--soot-150`. Source: `#252422` (colors.css:45).
  static const Color soot150 = Color(0xFF252422);

  /// `--soot-200`. Source: `#2E2D2A` (colors.css:46).
  static const Color soot200 = Color(0xFF2E2D2A);

  /// `--soot-300`. Source: `#3B3936` (colors.css:47).
  static const Color soot300 = Color(0xFF3B3936);

  /// `--soot-400`. Source: `#57544F` (colors.css:48).
  static const Color soot400 = Color(0xFF57544F);

  /// `--soot-500`. Source: `#7A766F` (colors.css:49).
  static const Color soot500 = Color(0xFF7A766F);

  /// `--soot-600`. Source: `#9A958D` (colors.css:50).
  static const Color soot600 = Color(0xFF9A958D);

  /// `--soot-700`. Source: `#BDB8AF` (colors.css:51).
  static const Color soot700 = Color(0xFFBDB8AF);

  /// `--soot-800`. Source: `#E3DFD8` (colors.css:52).
  static const Color soot800 = Color(0xFFE3DFD8);

  /// `--soot-900`. Source: `#F2EFEA` (colors.css:53).
  static const Color soot900 = Color(0xFFF2EFEA);
}

/// Semantic UI colours with a light and a dark instance: surfaces, text, icons,
/// borders, accent and status colours, the page border and the Windows
/// close-button hover.
///
/// Translucent values such as `surfaceHover`, `surfacePressed` and the dark
/// selected colours are overlays: paint them over the surface beneath (for
/// example with `Color.alphaBlend`), not as opaque fills.
final class FermanColorTokens {
  /// Creates a set of tokens. The design defines [light] and [dark].
  const new({
    required this.accent,
    required this.accentBorder,
    required this.accentHover,
    required this.accentPressed,
    required this.accentSubtle,
    required this.accentSubtleHover,
    required this.borderDefault,
    required this.borderFocus,
    required this.borderStrong,
    required this.borderSubtle,
    required this.danger,
    required this.dangerBg,
    required this.dangerBorder,
    required this.dangerHover,
    required this.dangerSolid,
    required this.iconDisabled,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.info,
    required this.infoBg,
    required this.infoBorder,
    required this.pageBorder,
    required this.success,
    required this.successBg,
    required this.successBorder,
    required this.successSolid,
    required this.surfaceCanvas,
    required this.surfaceHover,
    required this.surfaceInverse,
    required this.surfacePanel,
    required this.surfacePressed,
    required this.surfaceRaised,
    required this.surfaceScrim,
    required this.surfaceSelected,
    required this.surfaceSelectedStrong,
    required this.surfaceSunken,
    required this.textAccent,
    required this.textDisabled,
    required this.textInverse,
    required this.textLink,
    required this.textOnAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.warning,
    required this.warningBg,
    required this.warningBorder,
    required this.warningSolid,
    required this.winCloseHover,
  });

  /// The light theme (`:root`), the default.
  static const FermanColorTokens light = FermanColorTokens(
    accent: Color(0xFF2A4DAF),
    accentBorder: Color(0xFF8BA4E4),
    accentHover: Color(0xFF213E8E),
    accentPressed: Color(0xFF1A3170),
    accentSubtle: Color(0xFFEEF2FC),
    accentSubtleHover: Color(0xFFDCE4F8),
    borderDefault: Color(0xFFDEDAD2),
    borderFocus: Color(0xFF3A60C6),
    borderStrong: Color(0xFFC9C4BA),
    borderSubtle: Color(0xFFE6E2DB),
    danger: Color(0xFFB42318),
    dangerBg: Color(0xFFFCEBE9),
    dangerBorder: Color(0xFFF2B8B1),
    dangerHover: Color(0xFF961C13),
    dangerSolid: Color(0xFFB42318),
    iconDisabled: Color(0xFFA39E94),
    iconPrimary: Color(0xFF3A3732),
    iconSecondary: Color(0xFF6F6A62),
    info: Color(0xFF2A4DAF),
    infoBg: Color(0xFFEEF2FC),
    infoBorder: Color(0xFFB8C8F0),
    pageBorder: Color(0x14141311),
    success: Color(0xFF1E7A46),
    successBg: Color(0xFFE7F4EC),
    successBorder: Color(0xFFA9D8BC),
    successSolid: Color(0xFF2E9A5C),
    surfaceCanvas: Color(0xFFE8E5DF),
    surfaceHover: Color(0x0F1F1D1A),
    surfaceInverse: Color(0xFF1F1D1A),
    surfacePanel: Color(0xFFF7F6F3),
    surfacePressed: Color(0x1A1F1D1A),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceScrim: Color(0x61141311),
    surfaceSelected: Color(0xFFEEF2FC),
    surfaceSelectedStrong: Color(0xFFDCE4F8),
    surfaceSunken: Color(0xFFF0EEEA),
    textAccent: Color(0xFF2A4DAF),
    textDisabled: Color(0xFFA39E94),
    textInverse: Color(0xFFFCFBF9),
    textLink: Color(0xFF2A4DAF),
    textOnAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F1D1A),
    textSecondary: Color(0xFF57534C),
    textTertiary: Color(0xFF6F6A62),
    warning: Color(0xFF9A5B00),
    warningBg: Color(0xFFFDF3E1),
    warningBorder: Color(0xFFF0CD8F),
    warningSolid: Color(0xFFD98A0B),
    winCloseHover: Color(0xFFC42B1C),
  );

  /// The dark theme (`[data-theme="dark"]`).
  static const FermanColorTokens dark = FermanColorTokens(
    accent: Color(0xFF3A60C6),
    accentBorder: Color(0xFF5D7FD6),
    accentHover: Color(0xFF4A6DD0),
    accentPressed: Color(0xFF2A4DAF),
    accentSubtle: Color(0x295D7FD6),
    accentSubtleHover: Color(0x3D5D7FD6),
    borderDefault: Color(0xFF3B3936),
    borderFocus: Color(0xFF5D7FD6),
    borderStrong: Color(0xFF57544F),
    borderSubtle: Color(0xFF2E2D2A),
    danger: Color(0xFFF07A6E),
    dangerBg: Color(0xFF331816),
    dangerBorder: Color(0xFF632C27),
    dangerHover: Color(0xFFD94A3E),
    dangerSolid: Color(0xFFC8352A),
    iconDisabled: Color(0xFF7A766F),
    iconPrimary: Color(0xFFE3DFD8),
    iconSecondary: Color(0xFF9A958D),
    info: Color(0xFF8BA4E4),
    infoBg: Color(0x245D7FD6),
    infoBorder: Color(0x5C5D7FD6),
    pageBorder: Color(0x80000000),
    success: Color(0xFF4CC07E),
    successBg: Color(0xFF13291C),
    successBorder: Color(0xFF22503A),
    successSolid: Color(0xFF2E9A5C),
    surfaceCanvas: Color(0xFF0E0E0D),
    surfaceHover: Color(0x12F2EFEA),
    surfaceInverse: Color(0xFFF2EFEA),
    surfacePanel: Color(0xFF161615),
    surfacePressed: Color(0x1CF2EFEA),
    surfaceRaised: Color(0xFF1D1C1B),
    surfaceScrim: Color(0x8F000000),
    surfaceSelected: Color(0x2E5D7FD6),
    surfaceSelectedStrong: Color(0x475D7FD6),
    surfaceSunken: Color(0xFF121211),
    textAccent: Color(0xFF8BA4E4),
    textDisabled: Color(0xFF7A766F),
    textInverse: Color(0xFF1F1D1A),
    textLink: Color(0xFF8BA4E4),
    textOnAccent: Color(0xFFFFFFFF),
    textPrimary: Color(0xFFF2EFEA),
    textSecondary: Color(0xFFBDB8AF),
    textTertiary: Color(0xFF9A958D),
    warning: Color(0xFFF0B04A),
    warningBg: Color(0xFF2E2212),
    warningBorder: Color(0xFF5A4220),
    warningSolid: Color(0xFFD98A0B),
    winCloseHover: Color(0xFFC42B1C),
  );

  /// `--accent`. Light: `var(--ink-600)` (colors.css:112). Dark:
  /// `var(--ink-500)` (colors.css:195).
  final Color accent;

  /// `--accent-border`. Light: `var(--ink-300)` (colors.css:117). Dark:
  /// `var(--ink-400)` (colors.css:200).
  final Color accentBorder;

  /// `--accent-hover`. Light: `var(--ink-700)` (colors.css:113). Dark:
  /// `#4A6DD0` (colors.css:196).
  final Color accentHover;

  /// `--accent-pressed`. Light: `var(--ink-800)` (colors.css:114). Dark:
  /// `var(--ink-600)` (colors.css:197).
  final Color accentPressed;

  /// `--accent-subtle`. Light: `var(--ink-50)` (colors.css:115). Dark:
  /// `rgba(93, 127, 214, 0.16)` (colors.css:198).
  final Color accentSubtle;

  /// `--accent-subtle-hover`. Light: `var(--ink-100)` (colors.css:116). Dark:
  /// `rgba(93, 127, 214, 0.24)` (colors.css:199).
  final Color accentSubtleHover;

  /// `--border-default`. Light: `var(--paper-200)` (colors.css:108). Dark:
  /// `var(--soot-300)` (colors.css:191).
  final Color borderDefault;

  /// `--border-focus`. Light: `var(--ink-500)` (colors.css:110). Dark:
  /// `var(--ink-400)` (colors.css:193).
  final Color borderFocus;

  /// `--border-strong`. Light: `var(--paper-300)` (colors.css:109). Dark:
  /// `var(--soot-400)` (colors.css:192).
  final Color borderStrong;

  /// `--border-subtle`. Light: `#E6E2DB` (colors.css:107). Dark:
  /// `var(--soot-200)` (colors.css:190).
  final Color borderSubtle;

  /// `--danger`. Light: `var(--red-600)` (colors.css:127). Dark:
  /// `var(--red-300)` (colors.css:210).
  final Color danger;

  /// `--danger-bg`. Light: `var(--red-50)` (colors.css:130). Dark: `#331816`
  /// (colors.css:213).
  final Color dangerBg;

  /// `--danger-border`. Light: `var(--red-200)` (colors.css:131). Dark:
  /// `#632C27` (colors.css:214).
  final Color dangerBorder;

  /// `--danger-hover`. Light: `#961C13` (colors.css:129). Dark: `#D94A3E`
  /// (colors.css:212).
  final Color dangerHover;

  /// `--danger-solid`. Light: `var(--red-600)` (colors.css:128). Dark:
  /// `#C8352A` (colors.css:211).
  final Color dangerSolid;

  /// `--icon-disabled`. Light: `var(--paper-400)` (colors.css:105). Dark:
  /// `var(--soot-500)` (colors.css:188).
  final Color iconDisabled;

  /// `--icon-primary`. Light: `var(--paper-800)` (colors.css:103). Dark:
  /// `var(--soot-800)` (colors.css:186).
  final Color iconPrimary;

  /// `--icon-secondary`. Light: `var(--paper-600)` (colors.css:104). Dark:
  /// `var(--soot-600)` (colors.css:187).
  final Color iconSecondary;

  /// `--info`. Light: `var(--ink-600)` (colors.css:132). Dark: `var(--ink-300)`
  /// (colors.css:215).
  final Color info;

  /// `--info-bg`. Light: `var(--ink-50)` (colors.css:133). Dark: `rgba(93, 127,
  /// 214, 0.14)` (colors.css:216).
  final Color infoBg;

  /// `--info-border`. Light: `var(--ink-200)` (colors.css:134). Dark: `rgba(93,
  /// 127, 214, 0.36)` (colors.css:217).
  final Color infoBorder;

  /// `--page-border`. Light: `rgba(20, 19, 17, 0.08)` (colors.css:160). Dark:
  /// `rgba(0, 0, 0, 0.5)` (colors.css:220).
  final Color pageBorder;

  /// `--success`. Light: `var(--green-600)` (colors.css:119). Dark:
  /// `var(--green-300)` (colors.css:202).
  final Color success;

  /// `--success-bg`. Light: `var(--green-50)` (colors.css:121). Dark: `#13291C`
  /// (colors.css:204).
  final Color successBg;

  /// `--success-border`. Light: `var(--green-200)` (colors.css:122). Dark:
  /// `#22503A` (colors.css:205).
  final Color successBorder;

  /// `--success-solid`. Light: `var(--green-500)` (colors.css:120). Dark:
  /// `var(--green-500)` (colors.css:203).
  final Color successSolid;

  /// `--surface-canvas`: behind the PDF page.
  ///
  /// Light: `var(--paper-150)` (colors.css:83). Dark: `var(--soot-0)`
  /// (colors.css:166).
  final Color surfaceCanvas;

  /// `--surface-hover`. Light: `rgba(31, 29, 26, 0.06)` (colors.css:87). Dark:
  /// `rgba(242, 239, 234, 0.07)` (colors.css:170).
  final Color surfaceHover;

  /// `--surface-inverse`. Light: `var(--paper-900)` (colors.css:91). Dark:
  /// `var(--soot-900)` (colors.css:174).
  final Color surfaceInverse;

  /// `--surface-panel`: toolbars, sidebars, properties.
  ///
  /// Light: `var(--paper-50)` (colors.css:84). Dark: `var(--soot-50)`
  /// (colors.css:167).
  final Color surfacePanel;

  /// `--surface-pressed`. Light: `rgba(31, 29, 26, 0.10)` (colors.css:88).
  /// Dark: `rgba(242, 239, 234, 0.11)` (colors.css:171).
  final Color surfacePressed;

  /// `--surface-raised`: menus, popovers, dialogs, inputs.
  ///
  /// Light: `var(--paper-0)` (colors.css:85). Dark: `var(--soot-100)`
  /// (colors.css:168).
  final Color surfaceRaised;

  /// `--surface-scrim`. Light: `rgba(20, 19, 17, 0.38)` (colors.css:92). Dark:
  /// `rgba(0, 0, 0, 0.56)` (colors.css:175).
  final Color surfaceScrim;

  /// `--surface-selected`. Light: `var(--ink-50)` (colors.css:89). Dark:
  /// `rgba(93, 127, 214, 0.18)` (colors.css:172).
  final Color surfaceSelected;

  /// `--surface-selected-strong`. Light: `var(--ink-100)` (colors.css:90).
  /// Dark: `rgba(93, 127, 214, 0.28)` (colors.css:173).
  final Color surfaceSelectedStrong;

  /// `--surface-sunken`: segmented tracks, wells.
  ///
  /// Light: `var(--paper-100)` (colors.css:86). Dark: `#121211`
  /// (colors.css:169).
  final Color surfaceSunken;

  /// `--text-accent`. Light: `var(--ink-600)` (colors.css:100). Dark:
  /// `var(--ink-300)` (colors.css:183).
  final Color textAccent;

  /// `--text-disabled`. Light: `var(--paper-400)` (colors.css:97). Dark:
  /// `var(--soot-500)` (colors.css:180).
  final Color textDisabled;

  /// `--text-inverse`. Light: `var(--paper-25)` (colors.css:99). Dark:
  /// `var(--paper-900)` (colors.css:182).
  final Color textInverse;

  /// `--text-link`. Light: `var(--ink-600)` (colors.css:101). Dark:
  /// `var(--ink-300)` (colors.css:184).
  final Color textLink;

  /// `--text-on-accent`. Light: `#FFFFFF` (colors.css:98). Dark: `#FFFFFF`
  /// (colors.css:181).
  final Color textOnAccent;

  /// `--text-primary`. Light: `var(--paper-900)` (colors.css:94). Dark:
  /// `var(--soot-900)` (colors.css:177).
  final Color textPrimary;

  /// `--text-secondary`. Light: `var(--paper-700)` (colors.css:95). Dark:
  /// `var(--soot-700)` (colors.css:178).
  final Color textSecondary;

  /// `--text-tertiary`. Light: `var(--paper-600)` (colors.css:96). Dark:
  /// `var(--soot-600)` (colors.css:179).
  final Color textTertiary;

  /// `--warning`. Light: `var(--amber-700)` (colors.css:123). Dark:
  /// `var(--amber-300)` (colors.css:206).
  final Color warning;

  /// `--warning-bg`. Light: `var(--amber-50)` (colors.css:125). Dark: `#2E2212`
  /// (colors.css:208).
  final Color warningBg;

  /// `--warning-border`. Light: `var(--amber-200)` (colors.css:126). Dark:
  /// `#5A4220` (colors.css:209).
  final Color warningBorder;

  /// `--warning-solid`. Light: `var(--amber-500)` (colors.css:124). Dark:
  /// `var(--amber-500)` (colors.css:207).
  final Color warningSolid;

  /// `--win-close-hover`. Light: `#C42B1C` (fm-additions.css:24). Dark:
  /// `#C42B1C` (fm-additions.css:69).
  final Color winCloseHover;

  /// Interpolates between this set and [other] by [t], for animated theme
  /// changes. Values that cannot be interpolated switch at t = 0.5.
  FermanColorTokens lerp(FermanColorTokens other, double t) {
    return FermanColorTokens(
      accent: Color.lerp(accent, other.accent, t)!,
      accentBorder: Color.lerp(accentBorder, other.accentBorder, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentPressed: Color.lerp(accentPressed, other.accentPressed, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      accentSubtleHover: Color.lerp(
        accentSubtleHover,
        other.accentSubtleHover,
        t,
      )!,
      borderDefault: Color.lerp(borderDefault, other.borderDefault, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      dangerHover: Color.lerp(dangerHover, other.dangerHover, t)!,
      dangerSolid: Color.lerp(dangerSolid, other.dangerSolid, t)!,
      iconDisabled: Color.lerp(iconDisabled, other.iconDisabled, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
      pageBorder: Color.lerp(pageBorder, other.pageBorder, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      successSolid: Color.lerp(successSolid, other.successSolid, t)!,
      surfaceCanvas: Color.lerp(surfaceCanvas, other.surfaceCanvas, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      surfaceInverse: Color.lerp(surfaceInverse, other.surfaceInverse, t)!,
      surfacePanel: Color.lerp(surfacePanel, other.surfacePanel, t)!,
      surfacePressed: Color.lerp(surfacePressed, other.surfacePressed, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceScrim: Color.lerp(surfaceScrim, other.surfaceScrim, t)!,
      surfaceSelected: Color.lerp(surfaceSelected, other.surfaceSelected, t)!,
      surfaceSelectedStrong: Color.lerp(
        surfaceSelectedStrong,
        other.surfaceSelectedStrong,
        t,
      )!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      textAccent: Color.lerp(textAccent, other.textAccent, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      textInverse: Color.lerp(textInverse, other.textInverse, t)!,
      textLink: Color.lerp(textLink, other.textLink, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      warningSolid: Color.lerp(warningSolid, other.warningSolid, t)!,
      winCloseHover: Color.lerp(winCloseHover, other.winCloseHover, t)!,
    );
  }
}

/// Marks drawn on the PDF page, tuned against white paper: editing states,
/// missing glyphs, redaction, search, form fields, compare, OCR, translation,
/// overflow and the page background.
///
/// The page stays paper-white in both themes, so these do not change in dark
/// mode.
abstract final class FermanPageColorTokens {
  /// `--diff-added`. Source: `rgba(46, 154, 92, 0.22)` (fm-additions.css:31).
  static const Color diffAdded = Color(0x382E9A5C);

  /// `--diff-added-line`. Source: `var(--green-500)` (fm-additions.css:32).
  static const Color diffAddedLine = Color(0xFF2E9A5C);

  /// `--diff-changed`. Source: `rgba(217, 138, 11, 0.22)`
  /// (fm-additions.css:35).
  static const Color diffChanged = Color(0x38D98A0B);

  /// `--diff-changed-line`. Source: `var(--amber-500)` (fm-additions.css:36).
  static const Color diffChangedLine = Color(0xFFD98A0B);

  /// `--diff-removed`. Source: `rgba(217, 58, 43, 0.18)` (fm-additions.css:33).
  static const Color diffRemoved = Color(0x2ED93A2B);

  /// `--diff-removed-line`. Source: `var(--red-500)` (fm-additions.css:34).
  static const Color diffRemovedLine = Color(0xFFD93A2B);

  /// `--edit-box`: active text-block frame.
  ///
  /// Source: `var(--ink-500)` (colors.css:138).
  static const Color editBox = Color(0xFF3A60C6);

  /// `--edit-box-hover`: hover affordance on editable text.
  ///
  /// Source: `rgba(58, 96, 198, 0.45)` (colors.css:139).
  static const Color editBoxHover = Color(0x733A60C6);

  /// `--edit-caret`. Source: `var(--ink-700)` (colors.css:141).
  static const Color editCaret = Color(0xFF213E8E);

  /// `--edit-changed`: edited since open.
  ///
  /// Source: `var(--ink-600)` (fm-additions.css:9). Overrides `#0F7F72`
  /// (colors.css:142).
  static const Color editChanged = Color(0xFF2A4DAF);

  /// `--edit-changed-bg`. Source: `rgba(42, 77, 175, 0.08)`
  /// (fm-additions.css:10). Overrides `rgba(15, 127, 114, 0.10)`
  /// (colors.css:143).
  static const Color editChangedBg = Color(0x142A4DAF);

  /// `--edit-handle-fill`. Source: `#FFFFFF` (colors.css:140).
  static const Color editHandleFill = Color(0xFFFFFFFF);

  /// `--edit-mark`. Source: `var(--ink-600)` (fm-additions.css:11).
  static const Color editMark = Color(0xFF2A4DAF);

  /// `--edit-selection`: selected text run.
  ///
  /// Source: `rgba(58, 96, 198, 0.26)` (colors.css:137).
  static const Color editSelection = Color(0x423A60C6);

  /// `--form-field-bg`. Source: `rgba(58, 96, 198, 0.07)` (colors.css:152).
  static const Color formFieldBg = Color(0x123A60C6);

  /// `--form-field-border`. Source: `var(--ink-300)` (colors.css:153).
  static const Color formFieldBorder = Color(0xFF8BA4E4);

  /// `--form-field-focus`. Source: `var(--ink-500)` (colors.css:154).
  static const Color formFieldFocus = Color(0xFF3A60C6);

  /// `--form-field-required`. Source: `var(--red-600)` (colors.css:155).
  static const Color formFieldRequired = Color(0xFFB42318);

  /// `--glyph-missing`: substituted / missing glyph.
  ///
  /// Source: `var(--amber-500)` (colors.css:144).
  static const Color glyphMissing = Color(0xFFD98A0B);

  /// `--glyph-missing-bg`. Source: `rgba(217, 138, 11, 0.20)` (colors.css:145).
  static const Color glyphMissingBg = Color(0x33D98A0B);

  /// `--ocr-low`. Source: `var(--amber-500)` (fm-additions.css:28).
  static const Color ocrLow = Color(0xFFD98A0B);

  /// `--ocr-low-bg`. Source: `rgba(217, 138, 11, 0.16)` (fm-additions.css:29).
  static const Color ocrLowBg = Color(0x29D98A0B);

  /// `--overflow-mark`. Source: `var(--amber-500)` (fm-additions.css:26).
  static const Color overflowMark = Color(0xFFD98A0B);

  /// `--page-bg`. Source: `#FFFFFF` (colors.css:158).
  static const Color pageBg = Color(0xFFFFFFFF);

  /// `--redact-applied`: burned in — always true black.
  ///
  /// Source: `#000000` (colors.css:148).
  static const Color redactApplied = Color(0xFF000000);

  /// `--redact-pending`: marked, not yet applied.
  ///
  /// Source: `var(--red-600)` (colors.css:146).
  static const Color redactPending = Color(0xFFB42318);

  /// `--redact-pending-bg`. Source: `rgba(180, 35, 24, 0.12)` (colors.css:147).
  static const Color redactPendingBg = Color(0x1FB42318);

  /// `--search-current`. Source: `rgba(255, 159, 28, 0.70)` (colors.css:150).
  static const Color searchCurrent = Color(0xB3FF9F1C);

  /// `--search-current-border`. Source: `#C46A00` (colors.css:151).
  static const Color searchCurrentBorder = Color(0xFFC46A00);

  /// `--search-match`. Source: `rgba(255, 216, 77, 0.55)` (colors.css:149).
  static const Color searchMatch = Color(0x8CFFD84D);

  /// `--translated-mark`. Source: `rgba(58, 96, 198, 0.10)`
  /// (fm-additions.css:38).
  static const Color translatedMark = Color(0x1A3A60C6);
}

/// The type scale, line heights, weights, tracking, numeral features and font
/// stacks (typography.css; fm-additions.css extends `--font-ui` and adds the
/// CJK document and handwriting stacks).
///
/// Sizes are named `size<Step>` so they never share a name with the `--text-*`
/// colours. Heights are `leading / size`, ready for `TextStyle.height`.
/// Tracking values are `em` factors: `letterSpacing = tracking × fontSize`.
///
/// Font stacks keep only the bundled families (IBM Plex Sans, Sans Arabic, Sans
/// Hebrew, Sans Devanagari, Mono and Serif). CSS generic and system keywords,
/// the CJK families (system fonts cover CJK, ADR 0013) and the handwriting
/// faces (waiting for Q08) are dropped; each stack lists what was dropped.
abstract final class FermanTypeTokens {
  /// `--features-ui`. Source: `'kern' 1, 'liga' 1` (typography.css:33).
  static const List<FontFeature> featuresUi = <FontFeature>[
    FontFeature.enable('kern'),
    FontFeature.enable('liga'),
  ];

  /// `--font-arabic`. Source: `'IBM Plex Sans Arabic', 'IBM Plex Sans',
  /// system-ui, sans-serif` (typography.css:7).
  ///
  /// Dropped (not bundled): `system-ui`, `sans-serif`.
  static const FermanFontStack fontArabic = FermanFontStack(
    family: 'IBM Plex Sans Arabic',
    fallback: <String>['IBM Plex Sans'],
  );

  /// `--font-brand`. Source: `'IBM Plex Serif', Georgia, 'Times New Roman',
  /// serif` (typography.css:9).
  ///
  /// Dropped (not bundled): `Georgia`, `Times New Roman`, `serif`.
  static const FermanFontStack fontBrand = FermanFontStack(
    family: 'IBM Plex Serif',
    fallback: <String>[],
  );

  /// `--font-doc-cjk`. Source: `'Noto Serif JP', 'IBM Plex Sans JP', serif`
  /// (fm-additions.css:49).
  ///
  /// Dropped (not bundled): `Noto Serif JP`, `IBM Plex Sans JP`, `serif`.
  static const FermanFontStack fontDocCjk = FermanFontStack(
    family: null,
    fallback: <String>[],
  );

  /// `--font-doc-sample`: stand-in for PDF content in mocks only.
  ///
  /// Source: `'IBM Plex Serif', Georgia, serif` (typography.css:10).
  ///
  /// Dropped (not bundled): `Georgia`, `serif`.
  static const FermanFontStack fontDocSample = FermanFontStack(
    family: 'IBM Plex Serif',
    fallback: <String>[],
  );

  /// `--font-hand-1`. Source: `'Caveat', cursive` (fm-additions.css:50).
  ///
  /// Dropped (not bundled): `Caveat`, `cursive`.
  static const FermanFontStack fontHand1 = FermanFontStack(
    family: null,
    fallback: <String>[],
  );

  /// `--font-hand-2`. Source: `'Homemade Apple', cursive`
  /// (fm-additions.css:51).
  ///
  /// Dropped (not bundled): `Homemade Apple`, `cursive`.
  static const FermanFontStack fontHand2 = FermanFontStack(
    family: null,
    fallback: <String>[],
  );

  /// `--font-hand-3`. Source: `'Dancing Script', cursive`
  /// (fm-additions.css:52).
  ///
  /// Dropped (not bundled): `Dancing Script`, `cursive`.
  static const FermanFontStack fontHand3 = FermanFontStack(
    family: null,
    fallback: <String>[],
  );

  /// `--font-mono`. Source: `'IBM Plex Mono', ui-monospace, 'SF Mono', Menlo,
  /// Consolas, monospace` (typography.css:8).
  ///
  /// Dropped (not bundled): `ui-monospace`, `SF Mono`, `Menlo`, `Consolas`,
  /// `monospace`.
  static const FermanFontStack fontMono = FermanFontStack(
    family: 'IBM Plex Mono',
    fallback: <String>[],
  );

  /// `--font-ui`. Source: `'IBM Plex Sans', 'IBM Plex Sans Arabic', 'IBM Plex
  /// Sans Hebrew', 'IBM Plex Sans Devanagari', 'IBM Plex Sans JP', 'IBM Plex
  /// Sans KR', 'Noto Sans SC', system-ui, -apple-system, 'Segoe UI',
  /// sans-serif` (fm-additions.css:48). Overrides `'IBM Plex Sans', 'IBM Plex
  /// Sans Arabic', system-ui, -apple-system, 'Segoe UI', sans-serif`
  /// (typography.css:6).
  ///
  /// Dropped (not bundled): `IBM Plex Sans JP`, `IBM Plex Sans KR`, `Noto Sans
  /// SC`, `system-ui`, `-apple-system`, `Segoe UI`, `sans-serif`.
  static const FermanFontStack fontUi = FermanFontStack(
    family: 'IBM Plex Sans',
    fallback: <String>[
      'IBM Plex Sans Arabic',
      'IBM Plex Sans Hebrew',
      'IBM Plex Sans Devanagari',
    ],
  );

  /// `--leading-2xl` / `--text-2xl`: the line height as a `TextStyle.height`
  /// ratio (26 / 20).
  static const double height2xl = 26 / 20;

  /// `--leading-2xs` / `--text-2xs`: the line height as a `TextStyle.height`
  /// ratio (12 / 10).
  static const double height2xs = 12 / 10;

  /// `--leading-3xl` / `--text-3xl`: the line height as a `TextStyle.height`
  /// ratio (34 / 28).
  static const double height3xl = 34 / 28;

  /// `--leading-4xl` / `--text-4xl`: the line height as a `TextStyle.height`
  /// ratio (46 / 40).
  static const double height4xl = 46 / 40;

  /// `--leading-lg` / `--text-lg`: the line height as a `TextStyle.height`
  /// ratio (20 / 14).
  static const double heightLg = 20 / 14;

  /// `--leading-md` / `--text-md`: the line height as a `TextStyle.height`
  /// ratio (18 / 13).
  static const double heightMd = 18 / 13;

  /// `--leading-sm` / `--text-sm`: the line height as a `TextStyle.height`
  /// ratio (16 / 12).
  static const double heightSm = 16 / 12;

  /// `--leading-xl` / `--text-xl`: the line height as a `TextStyle.height`
  /// ratio (22 / 16).
  static const double heightXl = 22 / 16;

  /// `--leading-xs` / `--text-xs`: the line height as a `TextStyle.height`
  /// ratio (14 / 11).
  static const double heightXs = 14 / 11;

  /// `--leading-2xl`: dialog titles.
  ///
  /// Source: `26px` (typography.css:23).
  static const double leading2xl = 26;

  /// `--leading-2xs`: status-bar counters, thumbnail page numbers.
  ///
  /// Source: `12px` (typography.css:17).
  static const double leading2xs = 12;

  /// `--leading-3xl`: empty-state headline.
  ///
  /// Source: `34px` (typography.css:24).
  static const double leading3xl = 34;

  /// `--leading-4xl`: onboarding / brand.
  ///
  /// Source: `46px` (typography.css:25).
  static const double leading4xl = 46;

  /// `--leading-lg`: dialog body, readable prose.
  ///
  /// Source: `20px` (typography.css:21).
  static const double leadingLg = 20;

  /// `--leading-md`: default UI text, buttons, inputs.
  ///
  /// Source: `18px` (typography.css:20).
  static const double leadingMd = 18;

  /// `--leading-sm`: secondary text, tooltips, captions.
  ///
  /// Source: `16px` (typography.css:19).
  static const double leadingSm = 16;

  /// `--leading-xl`: panel titles, palette input.
  ///
  /// Source: `22px` (typography.css:22).
  static const double leadingXl = 22;

  /// `--leading-xs`: section labels, badges, shortcut hints.
  ///
  /// Source: `14px` (typography.css:18).
  static const double leadingXs = 14;

  /// `--numeric-tabular`. Source: `tabular-nums` (typography.css:32).
  static const List<FontFeature> numericTabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// `--text-2xl`: dialog titles.
  ///
  /// Source: `20px` (typography.css:23).
  static const double size2xl = 20;

  /// `--text-2xs`: status-bar counters, thumbnail page numbers.
  ///
  /// Source: `10px` (typography.css:17).
  static const double size2xs = 10;

  /// `--text-3xl`: empty-state headline.
  ///
  /// Source: `28px` (typography.css:24).
  static const double size3xl = 28;

  /// `--text-4xl`: onboarding / brand.
  ///
  /// Source: `40px` (typography.css:25).
  static const double size4xl = 40;

  /// `--text-lg`: dialog body, readable prose.
  ///
  /// Source: `14px` (typography.css:21).
  static const double sizeLg = 14;

  /// `--text-md`: default UI text, buttons, inputs.
  ///
  /// Source: `13px` (typography.css:20).
  static const double sizeMd = 13;

  /// `--text-sm`: secondary text, tooltips, captions.
  ///
  /// Source: `12px` (typography.css:19).
  static const double sizeSm = 12;

  /// `--text-xl`: panel titles, palette input.
  ///
  /// Source: `16px` (typography.css:22).
  static const double sizeXl = 16;

  /// `--text-xs`: section labels, badges, shortcut hints.
  ///
  /// Source: `11px` (typography.css:18).
  static const double sizeXs = 11;

  /// `--tracking-label`: small caps-like section labels.
  ///
  /// Source: `0.02em` (typography.css:29).
  static const double trackingLabel = 0.02;

  /// `--tracking-normal`. Source: `0` (typography.css:28).
  static const double trackingNormal = 0;

  /// `--tracking-tight`. Source: `-0.01em` (typography.css:27).
  static const double trackingTight = -0.01;

  /// `--weight-medium`. Source: `500` (typography.css:13).
  static const FontWeight weightMedium = FontWeight.w500;

  /// `--weight-regular`. Source: `400` (typography.css:12).
  static const FontWeight weightRegular = FontWeight.w400;

  /// `--weight-semibold`. Source: `600` (typography.css:14).
  static const FontWeight weightSemibold = FontWeight.w600;
}

/// The semantic text styles, from the `--type-*` font shorthands.
///
/// `height` is the CSS line height divided by the size, with even leading
/// distribution to match CSS half-leading. A shorthand without a line height
/// leaves `height` null, so the font metrics set the line height, as CSS
/// `normal` does. Font stacks keep only the bundled families, as in
/// [FermanTypeTokens]. Colour is not part of a role; take it from
/// [FermanColorTokens].
final class FermanTypeRoleTokens {
  /// Creates a set of tokens. The design defines [standard] and [cjk].
  const new({
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.dialogTitle,
    required this.headline,
    required this.label,
    required this.mono,
    required this.panelTitle,
    required this.prose,
    required this.wordmark,
  });

  /// The default type roles (`:root`).
  static const FermanTypeRoleTokens standard = FermanTypeRoleTokens(
    body: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 18 / 13,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyStrong: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 18 / 13,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    caption: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    dialogTitle: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 22 / 16,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    headline: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 34 / 28,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    label: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 14 / 11,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    mono: TextStyle(
      fontFamily: 'IBM Plex Mono',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    panelTitle: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 18 / 13,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    prose: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    wordmark: TextStyle(
      fontFamily: 'IBM Plex Serif',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
    ),
  );

  /// Japanese, Chinese and Korean text (`[lang|="ja"]`, `zh`, `ko`): taller
  /// leading on five roles. The design also sets `font-synthesis: none` here,
  /// so never synthesise bold or italic for CJK text.
  static const FermanTypeRoleTokens cjk = FermanTypeRoleTokens(
    body: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 20 / 13,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyStrong: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 20 / 13,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    caption: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 18 / 12,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    dialogTitle: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 22 / 16,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    headline: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 34 / 28,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    label: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 16 / 11,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    mono: TextStyle(
      fontFamily: 'IBM Plex Mono',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    panelTitle: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 20 / 13,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    prose: TextStyle(
      fontFamily: 'IBM Plex Sans',
      fontFamilyFallback: <String>[
        'IBM Plex Sans Arabic',
        'IBM Plex Sans Hebrew',
        'IBM Plex Sans Devanagari',
      ],
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    wordmark: TextStyle(
      fontFamily: 'IBM Plex Serif',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
    ),
  );

  /// `--type-body`. Standard: `var(--weight-regular)
  /// var(--text-md)/var(--leading-md) var(--font-ui)` (typography.css:36). CJK:
  /// `var(--weight-regular) var(--text-md)/20px var(--font-ui)`
  /// (fm-additions.css:57).
  final TextStyle body;

  /// `--type-body-strong`. Standard: `var(--weight-medium)
  /// var(--text-md)/var(--leading-md) var(--font-ui)` (typography.css:37). CJK:
  /// `var(--weight-medium) var(--text-md)/20px var(--font-ui)`
  /// (fm-additions.css:58).
  final TextStyle bodyStrong;

  /// `--type-caption`. Standard: `var(--weight-regular)
  /// var(--text-sm)/var(--leading-sm) var(--font-ui)` (typography.css:39). CJK:
  /// `var(--weight-regular) var(--text-sm)/18px var(--font-ui)`
  /// (fm-additions.css:59).
  final TextStyle caption;

  /// `--type-dialog-title`. Source: `var(--weight-semibold)
  /// var(--text-xl)/var(--leading-xl) var(--font-ui)` (typography.css:42).
  final TextStyle dialogTitle;

  /// `--type-headline`. Source: `var(--weight-semibold)
  /// var(--text-3xl)/var(--leading-3xl) var(--font-ui)` (typography.css:43).
  final TextStyle headline;

  /// `--type-label`. Standard: `var(--weight-medium)
  /// var(--text-xs)/var(--leading-xs) var(--font-ui)` (typography.css:38). CJK:
  /// `var(--weight-medium) var(--text-xs)/16px var(--font-ui)`
  /// (fm-additions.css:60).
  final TextStyle label;

  /// `--type-mono`. Source: `var(--weight-regular)
  /// var(--text-sm)/var(--leading-sm) var(--font-mono)` (typography.css:44).
  final TextStyle mono;

  /// `--type-panel-title`. Standard: `var(--weight-semibold)
  /// var(--text-md)/var(--leading-md) var(--font-ui)` (typography.css:41). CJK:
  /// `var(--weight-semibold) var(--text-md)/20px var(--font-ui)`
  /// (fm-additions.css:61).
  final TextStyle panelTitle;

  /// `--type-prose`. Source: `var(--weight-regular)
  /// var(--text-lg)/var(--leading-lg) var(--font-ui)` (typography.css:40).
  final TextStyle prose;

  /// `--type-wordmark`. Source: `var(--weight-semibold) var(--text-xl)/1
  /// var(--font-brand)` (typography.css:45).
  final TextStyle wordmark;

  /// Interpolates between this set and [other] by [t], for animated theme
  /// changes. Values that cannot be interpolated switch at t = 0.5.
  FermanTypeRoleTokens lerp(FermanTypeRoleTokens other, double t) {
    return FermanTypeRoleTokens(
      body: TextStyle.lerp(body, other.body, t)!,
      bodyStrong: TextStyle.lerp(bodyStrong, other.bodyStrong, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      dialogTitle: TextStyle.lerp(dialogTitle, other.dialogTitle, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
      panelTitle: TextStyle.lerp(panelTitle, other.panelTitle, t)!,
      prose: TextStyle.lerp(prose, other.prose, t)!,
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
    );
  }
}

/// The spacing scale (spacing.css): a 4 px base with 2 px and 6 px half steps.
/// `space1_5` is `--space-1-5`.
abstract final class FermanSpaceTokens {
  /// `--space-0`. Source: `0` (spacing.css:5).
  static const double space0 = 0;

  /// `--space-0-5`. Source: `2px` (spacing.css:7).
  static const double space0_5 = 2;

  /// `--space-1`. Source: `4px` (spacing.css:8).
  static const double space1 = 4;

  /// `--space-1-5`. Source: `6px` (spacing.css:9).
  static const double space1_5 = 6;

  /// `--space-2`. Source: `8px` (spacing.css:10).
  static const double space2 = 8;

  /// `--space-2-5`. Source: `10px` (spacing.css:11).
  static const double space2_5 = 10;

  /// `--space-3`. Source: `12px` (spacing.css:12).
  static const double space3 = 12;

  /// `--space-4`. Source: `16px` (spacing.css:13).
  static const double space4 = 16;

  /// `--space-5`. Source: `20px` (spacing.css:14).
  static const double space5 = 20;

  /// `--space-6`. Source: `24px` (spacing.css:15).
  static const double space6 = 24;

  /// `--space-8`. Source: `32px` (spacing.css:16).
  static const double space8 = 32;

  /// `--space-10`. Source: `40px` (spacing.css:17).
  static const double space10 = 40;

  /// `--space-12`. Source: `48px` (spacing.css:18).
  static const double space12 = 48;

  /// `--space-16`. Source: `64px` (spacing.css:19).
  static const double space16 = 64;

  /// `--space-px`. Source: `1px` (spacing.css:6).
  static const double spacePx = 1;
}

/// Control, icon and bar sizes that change with density (spacing.css).
///
/// Choose the instance by platform (desktop or touch), not by `VisualDensity`.
final class FermanDensityTokens {
  /// Creates a set of tokens. The design defines [desktop] and [touch].
  const new({
    required this.controlHLg,
    required this.controlHMd,
    required this.controlHSm,
    required this.controlHXs,
    required this.controlPadX,
    required this.hitMin,
    required this.iconLg,
    required this.iconMd,
    required this.iconSm,
    required this.modebarH,
    required this.statusbarH,
    required this.titlebarH,
    required this.toolbarH,
  });

  /// Compact desktop density (`:root`), the default.
  static const FermanDensityTokens desktop = FermanDensityTokens(
    controlHLg: 36,
    controlHMd: 30,
    controlHSm: 26,
    controlHXs: 22,
    controlPadX: 10,
    hitMin: 24,
    iconLg: 20,
    iconMd: 16,
    iconSm: 14,
    modebarH: 40,
    statusbarH: 26,
    titlebarH: 38,
    toolbarH: 44,
  );

  /// Touch density (`[data-density="touch"]`) for tablets and phones: every
  /// target is at least 44 px.
  static const FermanDensityTokens touch = FermanDensityTokens(
    controlHLg: 48,
    controlHMd: 44,
    controlHSm: 44,
    controlHXs: 32,
    controlPadX: 14,
    hitMin: 44,
    iconLg: 24,
    iconMd: 20,
    iconSm: 14,
    modebarH: 48,
    statusbarH: 40,
    titlebarH: 56,
    toolbarH: 56,
  );

  /// `--control-h-lg`: dialog primary actions, palette rows.
  ///
  /// Desktop: `36px` (spacing.css:25). Touch: `48px` (spacing.css:50).
  final double controlHLg;

  /// `--control-h-md`: default buttons, fields.
  ///
  /// Desktop: `30px` (spacing.css:24). Touch: `44px` (spacing.css:49).
  final double controlHMd;

  /// `--control-h-sm`: toolbar buttons, panel inputs.
  ///
  /// Desktop: `26px` (spacing.css:23). Touch: `44px` (spacing.css:48).
  final double controlHSm;

  /// `--control-h-xs`: inline chips, stepper arrows.
  ///
  /// Desktop: `22px` (spacing.css:22). Touch: `32px` (spacing.css:47).
  final double controlHXs;

  /// `--control-pad-x`. Desktop: `10px` (spacing.css:26). Touch: `14px`
  /// (spacing.css:51).
  final double controlPadX;

  /// `--hit-min`: smallest clickable target on desktop.
  ///
  /// Desktop: `24px` (spacing.css:30). Touch: `44px` (spacing.css:54).
  final double hitMin;

  /// `--icon-lg`. Desktop: `20px` (spacing.css:29). Touch: `24px`
  /// (spacing.css:53).
  final double iconLg;

  /// `--icon-md`. Desktop: `16px` (spacing.css:28). Touch: `20px`
  /// (spacing.css:52).
  final double iconMd;

  /// `--icon-sm`. Source: `14px` (spacing.css:27).
  final double iconSm;

  /// `--modebar-h`. Desktop: `40px` (spacing.css:34). Touch: `48px`
  /// (spacing.css:56).
  final double modebarH;

  /// `--statusbar-h`. Desktop: `26px` (spacing.css:36). Touch: `40px`
  /// (spacing.css:58).
  final double statusbarH;

  /// `--titlebar-h`. Desktop: `38px` (spacing.css:33). Touch: `56px`
  /// (spacing.css:57).
  final double titlebarH;

  /// `--toolbar-h`. Desktop: `44px` (spacing.css:35). Touch: `56px`
  /// (spacing.css:55).
  final double toolbarH;

  /// Interpolates between this set and [other] by [t], for animated theme
  /// changes. Values that cannot be interpolated switch at t = 0.5.
  FermanDensityTokens lerp(FermanDensityTokens other, double t) {
    return FermanDensityTokens(
      controlHLg: _lerpDouble(controlHLg, other.controlHLg, t),
      controlHMd: _lerpDouble(controlHMd, other.controlHMd, t),
      controlHSm: _lerpDouble(controlHSm, other.controlHSm, t),
      controlHXs: _lerpDouble(controlHXs, other.controlHXs, t),
      controlPadX: _lerpDouble(controlPadX, other.controlPadX, t),
      hitMin: _lerpDouble(hitMin, other.hitMin, t),
      iconLg: _lerpDouble(iconLg, other.iconLg, t),
      iconMd: _lerpDouble(iconMd, other.iconMd, t),
      iconSm: _lerpDouble(iconSm, other.iconSm, t),
      modebarH: _lerpDouble(modebarH, other.modebarH, t),
      statusbarH: _lerpDouble(statusbarH, other.statusbarH, t),
      titlebarH: _lerpDouble(titlebarH, other.titlebarH, t),
      toolbarH: _lerpDouble(toolbarH, other.toolbarH, t),
    );
  }
}

/// Fixed sizes that do not change with density: app layout widths, dialog and
/// palette widths, document tabs, the Windows caption button, edit-mark
/// geometry and the mobile bars.
abstract final class FermanSizeTokens {
  /// `--android-appbar-h`. Source: `64px` (fm-additions.css:42).
  static const double androidAppbarH = 64;

  /// `--android-navbar-h`. Source: `80px` (fm-additions.css:43).
  static const double androidNavbarH = 80;

  /// `--dialog-w-md`. Source: `520px` (spacing.css:41).
  static const double dialogWMd = 520;

  /// `--dialog-w-sm`. Source: `400px` (spacing.css:40).
  static const double dialogWSm = 400;

  /// `--doctab-h`. Source: `28px` (fm-additions.css:19).
  static const double doctabH = 28;

  /// `--doctab-w`. Source: `188px` (fm-additions.css:20).
  static const double doctabW = 188;

  /// `--doctab-w-min`. Source: `112px` (fm-additions.css:21).
  static const double doctabWMin = 112;

  /// `--edit-mark-bar-gap`. Source: `12px` (fm-additions.css:13).
  static const double editMarkBarGap = 12;

  /// `--edit-mark-bar-w`. Source: `2px` (fm-additions.css:12).
  static const double editMarkBarW = 2;

  /// `--editbox-meta-h`. Source: `18px` (fm-additions.css:15).
  static const double editboxMetaH = 18;

  /// `--fab-size`. Source: `56px` (fm-additions.css:44).
  static const double fabSize = 56;

  /// `--grabber-w`. Source: `36px` (fm-additions.css:46).
  static const double grabberW = 36;

  /// `--ios-navbar-h`. Source: `44px` (fm-additions.css:40).
  static const double iosNavbarH = 44;

  /// `--ios-tabbar-h`. Source: `83px` (fm-additions.css:41).
  static const double iosTabbarH = 83;

  /// `--palette-w`. Source: `600px` (spacing.css:42).
  static const double paletteW = 600;

  /// `--panel-w`. Source: `264px` (spacing.css:38).
  static const double panelW = 264;

  /// `--sidebar-w`. Source: `216px` (spacing.css:37).
  static const double sidebarW = 216;

  /// `--thumb-badge`. Source: `16px` (fm-additions.css:17).
  static const double thumbBadge = 16;

  /// `--thumb-w`. Source: `112px` (spacing.css:39).
  static const double thumbW = 112;

  /// `--win-caption-w`. Source: `46px` (fm-additions.css:23).
  static const double winCaptionW = 46;
}

/// Corner radii (effects.css; `sheetRadius` from fm-additions.css).
/// `radiusFull` (999 px) draws a pill.
abstract final class FermanRadiusTokens {
  /// `--radius-full`: status dots, switch track.
  ///
  /// Source: `999px` (effects.css:11).
  static const double radiusFull = 999;

  /// `--radius-lg`: dialogs, command palette, floating bars.
  ///
  /// Source: `8px` (effects.css:9).
  static const double radiusLg = 8;

  /// `--radius-md`: menus, thumbnails, cards, toasts.
  ///
  /// Source: `6px` (effects.css:8).
  static const double radiusMd = 6;

  /// `--radius-sm`: buttons, inputs, toolbar items.
  ///
  /// Source: `4px` (effects.css:7).
  static const double radiusSm = 4;

  /// `--radius-xl`: drop zone, onboarding surfaces.
  ///
  /// Source: `12px` (effects.css:10).
  static const double radiusXl = 12;

  /// `--radius-xs`: selection handles, checkbox inner, color chips.
  ///
  /// Source: `2px` (effects.css:6).
  static const double radiusXs = 2;

  /// `--sheet-radius`. Source: `var(--radius-xl)` (fm-additions.css:45).
  static const double sheetRadius = 12;
}

/// Border widths (effects.css).
abstract final class FermanBorderTokens {
  /// `--border-width`. Source: `1px` (effects.css:13).
  static const double borderWidth = 1;

  /// `--border-width-strong`: active text-edit frame.
  ///
  /// Source: `1.5px` (effects.css:14).
  static const double borderWidthStrong = 1.5;
}

/// Shadows for things that float above the document, with light and dark
/// instances.
///
/// Converted for Flutter: the layers are reversed (CSS paints the first layer
/// on top, Flutter the last), a `0 0 0 1px` ring becomes a 1 px spread with no
/// blur, negative spreads are kept, and the CSS blur becomes `blurRadius =
/// (blur / 2 - 0.5) / 0.57735` so that the Gaussian sigma matches.
final class FermanElevationTokens {
  /// Creates a set of tokens. The design defines [light] and [dark].
  const new({
    required this.shadowDialog,
    required this.shadowDrag,
    required this.shadowPage,
    required this.shadowPopover,
    required this.shadowSm,
  });

  /// The light theme (`:root`), the default.
  static const FermanElevationTokens light = FermanElevationTokens(
    shadowDialog: <BoxShadow>[
      BoxShadow(
        color: Color(0x3D141311),
        offset: Offset(0, 24),
        blurRadius: 47.6314,
        spreadRadius: -12,
      ),
      BoxShadow(
        color: Color(0x1A141311),
        offset: Offset(0, 8),
        blurRadius: 19.9186,
      ),
      BoxShadow(color: Color(0x14141311), spreadRadius: 1),
    ],
    shadowDrag: <BoxShadow>[
      BoxShadow(
        color: Color(0x47141311),
        offset: Offset(0, 14),
        blurRadius: 26.8468,
        spreadRadius: -8,
      ),
      BoxShadow(
        color: Color(0x1F141311),
        offset: Offset(0, 2),
        blurRadius: 4.3301,
      ),
    ],
    shadowPage: <BoxShadow>[
      BoxShadow(
        color: Color(0x29141311),
        offset: Offset(0, 6),
        blurRadius: 16.4545,
        spreadRadius: -8,
      ),
      BoxShadow(
        color: Color(0x0F141311),
        offset: Offset(0, 1),
        blurRadius: 0.866,
      ),
      BoxShadow(color: Color(0x14141311), spreadRadius: 1),
    ],
    shadowPopover: <BoxShadow>[
      BoxShadow(
        color: Color(0x24141311),
        offset: Offset(0, 12),
        blurRadius: 23.3827,
        spreadRadius: -6,
      ),
      BoxShadow(
        color: Color(0x14141311),
        offset: Offset(0, 4),
        blurRadius: 9.5263,
      ),
      BoxShadow(color: Color(0x14141311), spreadRadius: 1),
    ],
    shadowSm: <BoxShadow>[
      BoxShadow(
        color: Color(0x14141311),
        offset: Offset(0, 1),
        blurRadius: 0.866,
      ),
    ],
  );

  /// The dark theme (`[data-theme="dark"]`).
  static const FermanElevationTokens dark = FermanElevationTokens(
    shadowDialog: <BoxShadow>[
      BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0, 24),
        blurRadius: 47.6314,
        spreadRadius: -12,
      ),
      BoxShadow(
        color: Color(0x66000000),
        offset: Offset(0, 8),
        blurRadius: 19.9186,
      ),
      BoxShadow(color: Color(0x14FFFFFF), spreadRadius: 1),
    ],
    shadowDrag: <BoxShadow>[
      BoxShadow(
        color: Color(0xB3000000),
        offset: Offset(0, 14),
        blurRadius: 26.8468,
        spreadRadius: -8,
      ),
      BoxShadow(
        color: Color(0x66000000),
        offset: Offset(0, 2),
        blurRadius: 4.3301,
      ),
    ],
    shadowPage: <BoxShadow>[
      BoxShadow(
        color: Color(0x99000000),
        offset: Offset(0, 10),
        blurRadius: 23.3827,
        spreadRadius: -8,
      ),
      BoxShadow(
        color: Color(0x66000000),
        offset: Offset(0, 2),
        blurRadius: 2.5981,
      ),
      BoxShadow(color: Color(0x80000000), spreadRadius: 1),
    ],
    shadowPopover: <BoxShadow>[
      BoxShadow(
        color: Color(0x80000000),
        offset: Offset(0, 12),
        blurRadius: 23.3827,
        spreadRadius: -6,
      ),
      BoxShadow(
        color: Color(0x5C000000),
        offset: Offset(0, 4),
        blurRadius: 9.5263,
      ),
      BoxShadow(color: Color(0x12FFFFFF), spreadRadius: 1),
    ],
    shadowSm: <BoxShadow>[
      BoxShadow(
        color: Color(0x66000000),
        offset: Offset(0, 1),
        blurRadius: 0.866,
      ),
    ],
  );

  /// `--shadow-dialog`. Light: `0 0 0 1px rgba(20, 19, 17, 0.08), 0 8px 24px
  /// rgba(20, 19, 17, 0.10), 0 24px 56px -12px rgba(20, 19, 17, 0.24)`
  /// (effects.css:20). Dark: `0 0 0 1px rgba(255, 255, 255, 0.08), 0 8px 24px
  /// rgba(0, 0, 0, 0.4), 0 24px 56px -12px rgba(0, 0, 0, 0.6)`
  /// (effects.css:51).
  final List<BoxShadow> shadowDialog;

  /// `--shadow-drag`. Light: `0 2px 6px rgba(20, 19, 17, 0.12), 0 14px 32px
  /// -8px rgba(20, 19, 17, 0.28)` (effects.css:21). Dark: `0 2px 6px rgba(0, 0,
  /// 0, 0.4), 0 14px 32px -8px rgba(0, 0, 0, 0.7)` (effects.css:52).
  final List<BoxShadow> shadowDrag;

  /// `--shadow-page`. Light: `0 0 0 1px var(--page-border), 0 1px 2px rgba(20,
  /// 19, 17, 0.06), 0 6px 20px -8px rgba(20, 19, 17, 0.16)` (effects.css:17).
  /// Dark: `0 0 0 1px var(--page-border), 0 2px 4px rgba(0, 0, 0, 0.4), 0 10px
  /// 28px -8px rgba(0, 0, 0, 0.6)` (effects.css:48).
  final List<BoxShadow> shadowPage;

  /// `--shadow-popover`. Light: `0 0 0 1px rgba(20, 19, 17, 0.08), 0 4px 12px
  /// rgba(20, 19, 17, 0.08), 0 12px 28px -6px rgba(20, 19, 17, 0.14)`
  /// (effects.css:19). Dark: `0 0 0 1px rgba(255, 255, 255, 0.07), 0 4px 12px
  /// rgba(0, 0, 0, 0.36), 0 12px 28px -6px rgba(0, 0, 0, 0.5)`
  /// (effects.css:50).
  final List<BoxShadow> shadowPopover;

  /// `--shadow-sm`. Light: `0 1px 2px rgba(20, 19, 17, 0.08)` (effects.css:18).
  /// Dark: `0 1px 2px rgba(0, 0, 0, 0.4)` (effects.css:49).
  final List<BoxShadow> shadowSm;

  /// Interpolates between this set and [other] by [t], for animated theme
  /// changes. Values that cannot be interpolated switch at t = 0.5.
  FermanElevationTokens lerp(FermanElevationTokens other, double t) {
    return FermanElevationTokens(
      shadowDialog: BoxShadow.lerpList(shadowDialog, other.shadowDialog, t)!,
      shadowDrag: BoxShadow.lerpList(shadowDrag, other.shadowDrag, t)!,
      shadowPage: BoxShadow.lerpList(shadowPage, other.shadowPage, t)!,
      shadowPopover: BoxShadow.lerpList(shadowPopover, other.shadowPopover, t)!,
      shadowSm: BoxShadow.lerpList(shadowSm, other.shadowSm, t)!,
    );
  }
}

/// Keyboard focus indicators, with light and dark instances (their colours come
/// from `--surface-raised` and `--border-focus`).
///
/// `focusRing` is a 2 px gap in the raised-surface colour inside a 4 px ring,
/// as shadow layers. `focusRingInset` cannot be a `BoxShadow`, so it is a 2 px
/// inside border. `focusOutline` is drawn outside the box, `focusOffset` away
/// from it.
final class FermanFocusTokens {
  /// Creates a set of tokens. The design defines [light] and [dark].
  const new({
    required this.focusOffset,
    required this.focusOutline,
    required this.focusRing,
    required this.focusRingInset,
  });

  /// The light theme (`:root`), the default.
  static const FermanFocusTokens light = FermanFocusTokens(
    focusOffset: 2,
    focusOutline: BorderSide(
      color: Color(0xFF3A60C6),
      width: 2,
      strokeAlign: BorderSide.strokeAlignOutside,
    ),
    focusRing: <BoxShadow>[
      BoxShadow(color: Color(0xFF3A60C6), spreadRadius: 4),
      BoxShadow(color: Color(0xFFFFFFFF), spreadRadius: 2),
    ],
    focusRingInset: BorderSide(color: Color(0xFF3A60C6), width: 2),
  );

  /// The dark theme (`[data-theme="dark"]`).
  static const FermanFocusTokens dark = FermanFocusTokens(
    focusOffset: 2,
    focusOutline: BorderSide(
      color: Color(0xFF5D7FD6),
      width: 2,
      strokeAlign: BorderSide.strokeAlignOutside,
    ),
    focusRing: <BoxShadow>[
      BoxShadow(color: Color(0xFF5D7FD6), spreadRadius: 4),
      BoxShadow(color: Color(0xFF1D1C1B), spreadRadius: 2),
    ],
    focusRingInset: BorderSide(color: Color(0xFF5D7FD6), width: 2),
  );

  /// `--focus-offset`. Source: `2px` (effects.css:27).
  final double focusOffset;

  /// `--focus-outline`. Source: `2px solid var(--border-focus)`
  /// (effects.css:26). Resolved separately for each instance.
  final BorderSide focusOutline;

  /// `--focus-ring`. Source: `0 0 0 2px var(--surface-raised), 0 0 0 4px
  /// var(--border-focus)` (effects.css:24). Resolved separately for each
  /// instance.
  final List<BoxShadow> focusRing;

  /// `--focus-ring-inset`. Source: `inset 0 0 0 2px var(--border-focus)`
  /// (effects.css:25). Resolved separately for each instance.
  final BorderSide focusRingInset;

  /// Interpolates between this set and [other] by [t], for animated theme
  /// changes. Values that cannot be interpolated switch at t = 0.5.
  FermanFocusTokens lerp(FermanFocusTokens other, double t) {
    return FermanFocusTokens(
      focusOffset: _lerpDouble(focusOffset, other.focusOffset, t),
      focusOutline: BorderSide.lerp(focusOutline, other.focusOutline, t),
      focusRing: BoxShadow.lerpList(focusRing, other.focusRing, t)!,
      focusRingInset: BorderSide.lerp(focusRingInset, other.focusRingInset, t),
    );
  }
}

/// Durations and easing curves (effects.css). Motion is short and eases out,
/// never bouncy.
final class FermanMotionTokens {
  /// Creates a set of tokens. The design defines [standard] and [reduced].
  const new({
    required this.durBase,
    required this.durFast,
    required this.durInstant,
    required this.durSlow,
    required this.easeExit,
    required this.easeInOut,
    required this.easeOut,
  });

  /// Standard motion (`:root`).
  static const FermanMotionTokens standard = FermanMotionTokens(
    durBase: Duration(milliseconds: 180),
    durFast: Duration(milliseconds: 120),
    durInstant: Duration(milliseconds: 60),
    durSlow: Duration(milliseconds: 260),
    easeExit: Cubic(0.4, 0, 1, 1),
    easeInOut: Cubic(0.4, 0, 0.2, 1),
    easeOut: Cubic(0.2, 0, 0, 1),
  );

  /// Reduced motion (`@media (prefers-reduced-motion: reduce)`): every duration
  /// is zero. Use it when `MediaQuery.disableAnimationsOf` is true.
  static const FermanMotionTokens reduced = FermanMotionTokens(
    durBase: Duration.zero,
    durFast: Duration.zero,
    durInstant: Duration.zero,
    durSlow: Duration.zero,
    easeExit: Cubic(0.4, 0, 1, 1),
    easeInOut: Cubic(0.4, 0, 0.2, 1),
    easeOut: Cubic(0.2, 0, 0, 1),
  );

  /// `--dur-base`. Standard: `180ms` (effects.css:32). Reduced motion: `0ms`
  /// (effects.css:59).
  final Duration durBase;

  /// `--dur-fast`. Standard: `120ms` (effects.css:31). Reduced motion: `0ms`
  /// (effects.css:58).
  final Duration durFast;

  /// `--dur-instant`. Standard: `60ms` (effects.css:30). Reduced motion: `0ms`
  /// (effects.css:57).
  final Duration durInstant;

  /// `--dur-slow`. Standard: `260ms` (effects.css:33). Reduced motion: `0ms`
  /// (effects.css:60).
  final Duration durSlow;

  /// `--ease-exit`. Source: `cubic-bezier(0.4, 0, 1, 1)` (effects.css:36).
  final Cubic easeExit;

  /// `--ease-in-out`. Source: `cubic-bezier(0.4, 0, 0.2, 1)` (effects.css:35).
  final Cubic easeInOut;

  /// `--ease-out`. Source: `cubic-bezier(0.2, 0, 0, 1)` (effects.css:34).
  final Cubic easeOut;

  /// Interpolates between this set and [other] by [t], for animated theme
  /// changes. Values that cannot be interpolated switch at t = 0.5.
  FermanMotionTokens lerp(FermanMotionTokens other, double t) {
    return FermanMotionTokens(
      durBase: t < 0.5 ? durBase : other.durBase,
      durFast: t < 0.5 ? durFast : other.durFast,
      durInstant: t < 0.5 ? durInstant : other.durInstant,
      durSlow: t < 0.5 ? durSlow : other.durSlow,
      easeExit: t < 0.5 ? easeExit : other.easeExit,
      easeInOut: t < 0.5 ? easeInOut : other.easeInOut,
      easeOut: t < 0.5 ? easeOut : other.easeOut,
    );
  }
}

/// Stacking order (effects.css). Flutter has no z-index: use these to order
/// overlays and stack children.
abstract final class FermanZTokens {
  /// `--z-canvas`. Source: `0` (effects.css:38).
  static const int zCanvas = 0;

  /// `--z-dialog`. Source: `200` (effects.css:42).
  static const int zDialog = 200;

  /// `--z-edit`. Source: `10` (effects.css:39).
  static const int zEdit = 10;

  /// `--z-popover`. Source: `100` (effects.css:41).
  static const int zPopover = 100;

  /// `--z-sticky`. Source: `20` (effects.css:40).
  static const int zSticky = 20;

  /// `--z-toast`. Source: `300` (effects.css:43).
  static const int zToast = 300;

  /// `--z-tooltip`. Source: `400` (effects.css:44).
  static const int zTooltip = 400;
}

/// The reading-comfort page filter.
///
/// Apply `ColorFilter.matrix(pageFilter)` to the rendered page only, never to
/// chrome, and never when printing or saving.
final class FermanPageFilterTokens {
  /// Creates a set of tokens. The design defines [standard] and [dim].
  const new({required this.pageFilter});

  /// No page filter (`--page-filter: none`), the default.
  static const FermanPageFilterTokens standard = FermanPageFilterTokens(
    pageFilter: null,
  );

  /// The dimmed page (`[data-page="dim"]`), a per-user reading-comfort option
  /// meant for the dark theme.
  static const FermanPageFilterTokens dim = FermanPageFilterTokens(
    pageFilter: <double>[
      0.8618,
      0.0413,
      0.0101,
      0,
      -5.2074,
      0.0187,
      0.8775,
      0.009,
      0,
      -5.1621,
      0.0146,
      0.0287,
      0.8478,
      0,
      -5.0807,
      0,
      0,
      0,
      1,
      0,
    ],
  );

  /// `--page-filter`. Standard: `none` (colors.css:159). Dim: `brightness(0.86)
  /// contrast(1.04) sepia(0.06)` (colors.css:227).
  final List<double>? pageFilter;

  /// Interpolates between this set and [other] by [t], for animated theme
  /// changes. Values that cannot be interpolated switch at t = 0.5.
  FermanPageFilterTokens lerp(FermanPageFilterTokens other, double t) {
    return FermanPageFilterTokens(
      pageFilter: t < 0.5 ? pageFilter : other.pageFilter,
    );
  }
}

/// Stripe patterns that the design draws in component CSS rather than as
/// tokens.
///
/// They come from `tools/tokens/supplement.yaml`, where each entry cites the
/// design file and line it was copied from.
abstract final class FermanHatchTokens {
  /// Stripes on text marked for redaction but not yet applied
  /// (.fm-mark--redact-pending).
  ///
  /// Source: `repeating-linear-gradient(-45deg, var(--redact-pending-bg) 0 4px,
  /// rgba(180, 35, 24, 0.22) 4px 6px)` (components/editing/editing.css:33).
  static const FermanHatch redactPending = FermanHatch(
    angle: -45,
    stripes: <FermanHatchStripe>[
      FermanHatchStripe(color: Color(0x1FB42318), width: 4),
      FermanHatchStripe(color: Color(0x38B42318), width: 2),
    ],
  );

  /// Placeholder text lines drawn on page thumbnails (.fm-thumb__lines).
  ///
  /// Source: `repeating-linear-gradient(to bottom, #D6D2CB 0 2px, transparent
  /// 2px 6px)` (components/pages/pages.css:16).
  static const FermanHatch thumbLines = FermanHatch(
    angle: 180,
    stripes: <FermanHatchStripe>[
      FermanHatchStripe(color: Color(0xFFD6D2CB), width: 2),
      FermanHatchStripe(color: Color(0x00000000), width: 4),
    ],
  );
}

/// A CSS font stack reduced to the families the app bundles.
final class FermanFontStack {
  /// Creates a font stack.
  const new({required this.family, required this.fallback});

  /// The first bundled family, for `TextStyle.fontFamily`, or null when the
  /// stack names no bundled family and the platform default applies.
  final String? family;

  /// The other bundled families in CSS order, for
  /// `TextStyle.fontFamilyFallback`.
  final List<String> fallback;
}

/// A repeating stripe pattern: a CSS `repeating-linear-gradient` with hard
/// stops.
final class FermanHatch {
  /// Creates a stripe pattern.
  const new({required this.angle, required this.stripes});

  /// The CSS gradient angle in degrees: 0 points up, 90 right, 180 down;
  /// negative angles turn anticlockwise.
  final double angle;

  /// The stripes in order along the gradient line, repeated to fill.
  final List<FermanHatchStripe> stripes;
}

/// One stripe of a [FermanHatch].
final class FermanHatchStripe {
  /// Creates a stripe.
  const new({required this.color, required this.width});

  /// The stripe colour.
  final Color color;

  /// The stripe width in logical pixels, measured along the gradient line.
  final double width;
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
