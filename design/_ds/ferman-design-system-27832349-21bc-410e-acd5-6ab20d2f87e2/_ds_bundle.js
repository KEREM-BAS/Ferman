/* @ds-bundle: {"format":4,"namespace":"FermanDesignSystem_278323","components":[{"name":"ANNOTATION_TOOLS","sourcePath":"components/annotations/AnnotationTools.jsx"},{"name":"AnnotationTools","sourcePath":"components/annotations/AnnotationTools.jsx"},{"name":"Highlight","sourcePath":"components/annotations/Highlight.jsx"},{"name":"Stamp","sourcePath":"components/annotations/Stamp.jsx"},{"name":"StickyNote","sourcePath":"components/annotations/StickyNote.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"ICON_PATHS","sourcePath":"components/core/Icon.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"Kbd","sourcePath":"components/core/Kbd.jsx"},{"name":"Tooltip","sourcePath":"components/core/Tooltip.jsx"},{"name":"PageMark","sourcePath":"components/editing/PageMark.jsx"},{"name":"SearchReplaceBar","sourcePath":"components/editing/SearchReplaceBar.jsx"},{"name":"TextEditBox","sourcePath":"components/editing/TextEditBox.jsx"},{"name":"TextCaret","sourcePath":"components/editing/TextEditBox.jsx"},{"name":"DropZone","sourcePath":"components/empty/DropZone.jsx"},{"name":"Banner","sourcePath":"components/feedback/Banner.jsx"},{"name":"ProgressBar","sourcePath":"components/feedback/ProgressBar.jsx"},{"name":"Spinner","sourcePath":"components/feedback/Spinner.jsx"},{"name":"TaskProgress","sourcePath":"components/feedback/TaskProgress.jsx"},{"name":"Toast","sourcePath":"components/feedback/Toast.jsx"},{"name":"PdfFormField","sourcePath":"components/fill-sign/PdfFormField.jsx"},{"name":"SignaturePad","sourcePath":"components/fill-sign/SignaturePad.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"ColorPicker","sourcePath":"components/forms/ColorPicker.jsx"},{"name":"FontPicker","sourcePath":"components/forms/FontPicker.jsx"},{"name":"NumberStepper","sourcePath":"components/forms/NumberStepper.jsx"},{"name":"Radio","sourcePath":"components/forms/Radio.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"TextField","sourcePath":"components/forms/TextField.jsx"},{"name":"FERMAN_MODES","sourcePath":"components/navigation/ModeTabs.jsx"},{"name":"ModeTabs","sourcePath":"components/navigation/ModeTabs.jsx"},{"name":"SegmentedControl","sourcePath":"components/navigation/SegmentedControl.jsx"},{"name":"ToolButton","sourcePath":"components/navigation/ToolButton.jsx"},{"name":"Toolbar","sourcePath":"components/navigation/Toolbar.jsx"},{"name":"ToolbarSeparator","sourcePath":"components/navigation/Toolbar.jsx"},{"name":"ToolbarSpacer","sourcePath":"components/navigation/Toolbar.jsx"},{"name":"ToolbarGroup","sourcePath":"components/navigation/Toolbar.jsx"},{"name":"CommandPalette","sourcePath":"components/overlays/CommandPalette.jsx"},{"name":"Dialog","sourcePath":"components/overlays/Dialog.jsx"},{"name":"Menu","sourcePath":"components/overlays/Menu.jsx"},{"name":"PageThumbnail","sourcePath":"components/pages/PageThumbnail.jsx"},{"name":"PanelSection","sourcePath":"components/panels/PanelSection.jsx"}],"sourceHashes":{"components/annotations/AnnotationTools.jsx":"0cf9e235ae52","components/annotations/Highlight.jsx":"04be3f1da750","components/annotations/Stamp.jsx":"dc38ee955f5c","components/annotations/StickyNote.jsx":"c49b69836300","components/core/Badge.jsx":"2f2a32dbe545","components/core/Button.jsx":"40818b437bfc","components/core/Icon.jsx":"5b7e9edfb1ca","components/core/IconButton.jsx":"bc47ef0b6020","components/core/Kbd.jsx":"5976431582f6","components/core/Tooltip.jsx":"31eac08e8624","components/editing/PageMark.jsx":"bfaf0227a737","components/editing/SearchReplaceBar.jsx":"5402eccf7deb","components/editing/TextEditBox.jsx":"1949e7bc82dc","components/empty/DropZone.jsx":"60d1d767bddd","components/feedback/Banner.jsx":"9cbcff091754","components/feedback/ProgressBar.jsx":"8118a772e9ff","components/feedback/Spinner.jsx":"f66e11c6e461","components/feedback/TaskProgress.jsx":"6caca3133234","components/feedback/Toast.jsx":"656f1ae0e8c8","components/fill-sign/PdfFormField.jsx":"d777b32b0c54","components/fill-sign/SignaturePad.jsx":"5b271a734214","components/forms/Checkbox.jsx":"8682ad8b3e4b","components/forms/ColorPicker.jsx":"753047690593","components/forms/FontPicker.jsx":"b0a7fcbbdbf2","components/forms/NumberStepper.jsx":"fd158acbf2aa","components/forms/Radio.jsx":"94c5d88ee152","components/forms/Select.jsx":"91ebc6a8f71e","components/forms/Switch.jsx":"6a3814a4c30f","components/forms/TextField.jsx":"dfaaeec8bf0a","components/navigation/ModeTabs.jsx":"b25e2fa5712b","components/navigation/SegmentedControl.jsx":"e483bbf8c9f5","components/navigation/ToolButton.jsx":"c80b42795b86","components/navigation/Toolbar.jsx":"56bba27d54cf","components/overlays/CommandPalette.jsx":"a38f10582cc4","components/overlays/Dialog.jsx":"546578995918","components/overlays/Menu.jsx":"0f1c22f35c3b","components/pages/PageThumbnail.jsx":"52d1ea923882","components/panels/PanelSection.jsx":"5a17e352107c","ui_kits/desktop/App.jsx":"1d5f015eaa3f","ui_kits/desktop/Chrome.jsx":"beb4e2135bf2","ui_kits/desktop/OrganizeGrid.jsx":"82dcbd176450","ui_kits/desktop/Page.jsx":"919fb6dba0b4","ui_kits/desktop/Panels.jsx":"6f50c15d817b","ui_kits/desktop/data.js":"2916872a80d8"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.FermanDesignSystem_278323 = window.FermanDesignSystem_278323 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/annotations/Highlight.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const COLORS = {
  yellow: 'var(--annot-yellow)',
  green: 'var(--annot-green)',
  blue: 'var(--annot-blue)',
  pink: 'var(--annot-pink)',
  orange: 'var(--annot-orange)',
  red: 'var(--annot-red)',
  ink: 'var(--annot-blue-ink)'
};
function Highlight({
  color = 'yellow',
  variant = 'highlight',
  children,
  ...rest
}) {
  const c = COLORS[color] || color;
  const style = variant === 'highlight' ? {
    background: c
  } : {
    textDecorationColor: c
  };
  return /*#__PURE__*/React.createElement("mark", _extends({
    className: 'fm-hl fm-hl--' + variant,
    style: style
  }, rest), children);
}
Object.assign(__ds_scope, { Highlight });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/annotations/Highlight.jsx", error: String((e && e.message) || e) }); }

// components/annotations/Stamp.jsx
try { (() => {
function Stamp({
  label = 'Approved',
  tone = 'seal',
  meta,
  rotation = -3,
  lang,
  size = 18,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    className: 'fm-stamp fm-stamp--' + tone,
    lang: lang,
    role: "img",
    "aria-label": 'Stamp: ' + label + (meta ? ', ' + meta : ''),
    style: Object.assign({
      transform: rotation ? 'rotate(' + rotation + 'deg)' : undefined,
      fontSize: size
    }, style)
  }, /*#__PURE__*/React.createElement("span", null, label), meta ? /*#__PURE__*/React.createElement("span", {
    className: "fm-stamp__meta"
  }, meta) : null);
}
Object.assign(__ds_scope, { Stamp });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/annotations/Stamp.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
// Lucide icon set (ISC license, lucide-static v0.460.0), copied programmatically.
// SVG originals live in assets/icons/. Ferman renders them at stroke 1.5.
const ICON_PATHS = {
  "align-center": "<path d=\"M17 12H7\" /><path d=\"M19 18H5\" /><path d=\"M21 6H3\" />",
  "align-justify": "<path d=\"M3 12h18\" /><path d=\"M3 18h18\" /><path d=\"M3 6h18\" />",
  "align-left": "<path d=\"M15 12H3\" /><path d=\"M17 18H3\" /><path d=\"M21 6H3\" />",
  "align-right": "<path d=\"M21 12H9\" /><path d=\"M21 18H7\" /><path d=\"M21 6H3\" />",
  "arrow-left": "<path d=\"m12 19-7-7 7-7\" /><path d=\"M19 12H5\" />",
  "arrow-left-right": "<path d=\"M8 3 4 7l4 4\" /><path d=\"M4 7h16\" /><path d=\"m16 21 4-4-4-4\" /><path d=\"M20 17H4\" />",
  "arrow-right": "<path d=\"M5 12h14\" /><path d=\"m12 5 7 7-7 7\" />",
  "arrow-up-down": "<path d=\"m21 16-4 4-4-4\" /><path d=\"M17 20V4\" /><path d=\"m3 8 4-4 4 4\" /><path d=\"M7 4v16\" />",
  "arrow-up-right": "<path d=\"M7 7h10v10\" /><path d=\"M7 17 17 7\" />",
  "ban": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"m4.9 4.9 14.2 14.2\" />",
  "baseline": "<path d=\"M4 20h16\" /><path d=\"m6 16 6-12 6 12\" /><path d=\"M8 12h8\" />",
  "bold": "<path d=\"M6 12h9a4 4 0 0 1 0 8H7a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1h7a4 4 0 0 1 0 8\" />",
  "book-open": "<path d=\"M12 7v14\" /><path d=\"M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z\" />",
  "bookmark": "<path d=\"m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z\" />",
  "calendar": "<path d=\"M8 2v4\" /><path d=\"M16 2v4\" /><rect width=\"18\" height=\"18\" x=\"3\" y=\"4\" rx=\"2\" /><path d=\"M3 10h18\" />",
  "case-sensitive": "<path d=\"m3 15 4-8 4 8\" /><path d=\"M4 13h6\" /><circle cx=\"18\" cy=\"12\" r=\"3\" /><path d=\"M21 9v6\" />",
  "check": "<path d=\"M20 6 9 17l-5-5\" />",
  "chevron-down": "<path d=\"m6 9 6 6 6-6\" />",
  "chevron-left": "<path d=\"m15 18-6-6 6-6\" />",
  "chevron-right": "<path d=\"m9 18 6-6-6-6\" />",
  "chevron-up": "<path d=\"m18 15-6-6-6 6\" />",
  "circle": "<circle cx=\"12\" cy=\"12\" r=\"10\" />",
  "circle-alert": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><line x1=\"12\" x2=\"12\" y1=\"8\" y2=\"12\" /><line x1=\"12\" x2=\"12.01\" y1=\"16\" y2=\"16\" />",
  "circle-check": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"m9 12 2 2 4-4\" />",
  "circle-help": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3\" /><path d=\"M12 17h.01\" />",
  "circle-x": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"m15 9-6 6\" /><path d=\"m9 9 6 6\" />",
  "clock": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><polyline points=\"12 6 12 12 16 14\" />",
  "columns-2": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" /><path d=\"M12 3v18\" />",
  "command": "<path d=\"M15 6v12a3 3 0 1 0 3-3H6a3 3 0 1 0 3 3V6a3 3 0 1 0-3 3h12a3 3 0 1 0-3-3\" />",
  "copy": "<rect width=\"14\" height=\"14\" x=\"8\" y=\"8\" rx=\"2\" ry=\"2\" /><path d=\"M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2\" />",
  "corner-down-left": "<polyline points=\"9 10 4 15 9 20\" /><path d=\"M20 4v7a4 4 0 0 1-4 4H4\" />",
  "crop": "<path d=\"M6 2v14a2 2 0 0 0 2 2h14\" /><path d=\"M18 22V8a2 2 0 0 0-2-2H2\" />",
  "download": "<path d=\"M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4\" /><polyline points=\"7 10 12 15 17 10\" /><line x1=\"12\" x2=\"12\" y1=\"15\" y2=\"3\" />",
  "droplet": "<path d=\"M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z\" />",
  "ellipsis": "<circle cx=\"12\" cy=\"12\" r=\"1\" /><circle cx=\"19\" cy=\"12\" r=\"1\" /><circle cx=\"5\" cy=\"12\" r=\"1\" />",
  "ellipsis-vertical": "<circle cx=\"12\" cy=\"12\" r=\"1\" /><circle cx=\"12\" cy=\"5\" r=\"1\" /><circle cx=\"12\" cy=\"19\" r=\"1\" />",
  "eraser": "<path d=\"m7 21-4.3-4.3c-1-1-1-2.5 0-3.4l9.6-9.6c1-1 2.5-1 3.4 0l5.6 5.6c1 1 1 2.5 0 3.4L13 21\" /><path d=\"M22 21H7\" /><path d=\"m5 11 9 9\" />",
  "external-link": "<path d=\"M15 3h6v6\" /><path d=\"M10 14 21 3\" /><path d=\"M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6\" />",
  "eye": "<path d=\"M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0\" /><circle cx=\"12\" cy=\"12\" r=\"3\" />",
  "eye-off": "<path d=\"M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49\" /><path d=\"M14.084 14.158a3 3 0 0 1-4.242-4.242\" /><path d=\"M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143\" /><path d=\"m2 2 20 20\" />",
  "file-check-2": "<path d=\"M4 22h14a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v4\" /><path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><path d=\"m3 15 2 2 4-4\" />",
  "file-image": "<path d=\"M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z\" /><path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><circle cx=\"10\" cy=\"12\" r=\"2\" /><path d=\"m20 17-1.296-1.296a2.41 2.41 0 0 0-3.408 0L9 22\" />",
  "file-input": "<path d=\"M4 22h14a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v4\" /><path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><path d=\"M2 15h10\" /><path d=\"m9 18 3-3-3-3\" />",
  "file-lock-2": "<path d=\"M4 22h14a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v1\" /><path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><rect width=\"8\" height=\"5\" x=\"2\" y=\"13\" rx=\"1\" /><path d=\"M8 13v-2a2 2 0 1 0-4 0v2\" />",
  "file-output": "<path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><path d=\"M4 7V4a2 2 0 0 1 2-2 2 2 0 0 0-2 2\" /><path d=\"M4.063 20.999a2 2 0 0 0 2 1L18 22a2 2 0 0 0 2-2V7l-5-5H6\" /><path d=\"m5 11-3 3\" /><path d=\"m5 17-3-3h10\" />",
  "file-pen-line": "<path d=\"m18 5-2.414-2.414A2 2 0 0 0 14.172 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2\" /><path d=\"M21.378 12.626a1 1 0 0 0-3.004-3.004l-4.01 4.012a2 2 0 0 0-.506.854l-.837 2.87a.5.5 0 0 0 .62.62l2.87-.837a2 2 0 0 0 .854-.506z\" /><path d=\"M8 18h1\" />",
  "file-plus-2": "<path d=\"M4 22h14a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v4\" /><path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><path d=\"M3 15h6\" /><path d=\"M6 12v6\" />",
  "file-search": "<path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><path d=\"M4.268 21a2 2 0 0 0 1.727 1H18a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v3\" /><path d=\"m9 18-1.5-1.5\" /><circle cx=\"5\" cy=\"14\" r=\"3\" />",
  "file-spreadsheet": "<path d=\"M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z\" /><path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><path d=\"M8 13h2\" /><path d=\"M14 13h2\" /><path d=\"M8 17h2\" /><path d=\"M14 17h2\" />",
  "file-text": "<path d=\"M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z\" /><path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><path d=\"M10 9H8\" /><path d=\"M16 13H8\" /><path d=\"M16 17H8\" />",
  "file-type": "<path d=\"M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z\" /><path d=\"M14 2v4a2 2 0 0 0 2 2h4\" /><path d=\"M9 13v-1h6v1\" /><path d=\"M12 12v6\" /><path d=\"M11 18h2\" />",
  "files": "<path d=\"M20 7h-3a2 2 0 0 1-2-2V2\" /><path d=\"M9 18a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h7l4 4v10a2 2 0 0 1-2 2Z\" /><path d=\"M3 7.6v12.8A1.6 1.6 0 0 0 4.6 22h9.8\" />",
  "folder": "<path d=\"M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z\" />",
  "folder-open": "<path d=\"m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2\" />",
  "globe": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20\" /><path d=\"M2 12h20\" />",
  "grip-vertical": "<circle cx=\"9\" cy=\"12\" r=\"1\" /><circle cx=\"9\" cy=\"5\" r=\"1\" /><circle cx=\"9\" cy=\"19\" r=\"1\" /><circle cx=\"15\" cy=\"12\" r=\"1\" /><circle cx=\"15\" cy=\"5\" r=\"1\" /><circle cx=\"15\" cy=\"19\" r=\"1\" />",
  "hand": "<path d=\"M18 11V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2\" /><path d=\"M14 10V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v2\" /><path d=\"M10 10.5V6a2 2 0 0 0-2-2a2 2 0 0 0-2 2v8\" /><path d=\"M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15\" />",
  "hard-drive": "<line x1=\"22\" x2=\"2\" y1=\"12\" y2=\"12\" /><path d=\"M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z\" /><line x1=\"6\" x2=\"6.01\" y1=\"16\" y2=\"16\" /><line x1=\"10\" x2=\"10.01\" y1=\"16\" y2=\"16\" />",
  "hash": "<line x1=\"4\" x2=\"20\" y1=\"9\" y2=\"9\" /><line x1=\"4\" x2=\"20\" y1=\"15\" y2=\"15\" /><line x1=\"10\" x2=\"8\" y1=\"3\" y2=\"21\" /><line x1=\"16\" x2=\"14\" y1=\"3\" y2=\"21\" />",
  "highlighter": "<path d=\"m9 11-6 6v3h9l3-3\" /><path d=\"m22 12-4.6 4.6a2 2 0 0 1-2.8 0l-5.2-5.2a2 2 0 0 1 0-2.8L14 4\" />",
  "history": "<path d=\"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8\" /><path d=\"M3 3v5h5\" /><path d=\"M12 7v5l4 2\" />",
  "image": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" ry=\"2\" /><circle cx=\"9\" cy=\"9\" r=\"2\" /><path d=\"m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21\" />",
  "indent-increase": "<path d=\"M21 12H11\" /><path d=\"M21 18H11\" /><path d=\"M21 6H11\" /><path d=\"m3 8 4 4-4 4\" />",
  "info": "<circle cx=\"12\" cy=\"12\" r=\"10\" /><path d=\"M12 16v-4\" /><path d=\"M12 8h.01\" />",
  "italic": "<line x1=\"19\" x2=\"10\" y1=\"4\" y2=\"4\" /><line x1=\"14\" x2=\"5\" y1=\"20\" y2=\"20\" /><line x1=\"15\" x2=\"9\" y1=\"4\" y2=\"20\" />",
  "key-round": "<path d=\"M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 1.414-.586l.814-.814a6.5 6.5 0 1 0-4-4z\" /><circle cx=\"16.5\" cy=\"7.5\" r=\".5\" fill=\"currentColor\" />",
  "keyboard": "<path d=\"M10 8h.01\" /><path d=\"M12 12h.01\" /><path d=\"M14 8h.01\" /><path d=\"M16 12h.01\" /><path d=\"M18 8h.01\" /><path d=\"M6 8h.01\" /><path d=\"M7 16h10\" /><path d=\"M8 12h.01\" /><rect width=\"20\" height=\"16\" x=\"2\" y=\"4\" rx=\"2\" />",
  "languages": "<path d=\"m5 8 6 6\" /><path d=\"m4 14 6-6 2-3\" /><path d=\"M2 5h12\" /><path d=\"M7 2h1\" /><path d=\"m22 22-5-10-5 10\" /><path d=\"M14 18h6\" />",
  "layers": "<path d=\"m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z\" /><path d=\"m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65\" /><path d=\"m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65\" />",
  "layout-grid": "<rect width=\"7\" height=\"7\" x=\"3\" y=\"3\" rx=\"1\" /><rect width=\"7\" height=\"7\" x=\"14\" y=\"3\" rx=\"1\" /><rect width=\"7\" height=\"7\" x=\"14\" y=\"14\" rx=\"1\" /><rect width=\"7\" height=\"7\" x=\"3\" y=\"14\" rx=\"1\" />",
  "link": "<path d=\"M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71\" /><path d=\"M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71\" />",
  "list": "<path d=\"M3 12h.01\" /><path d=\"M3 18h.01\" /><path d=\"M3 6h.01\" /><path d=\"M8 12h13\" /><path d=\"M8 18h13\" /><path d=\"M8 6h13\" />",
  "list-ordered": "<path d=\"M10 12h11\" /><path d=\"M10 18h11\" /><path d=\"M10 6h11\" /><path d=\"M4 10h2\" /><path d=\"M4 6h1v4\" /><path d=\"M6 18H4c0-1 2-2 2-3s-1-1.5-2-1\" />",
  "list-tree": "<path d=\"M21 12h-8\" /><path d=\"M21 6H8\" /><path d=\"M21 18h-8\" /><path d=\"M3 6v4c0 1.1.9 2 2 2h3\" /><path d=\"M3 10v6c0 1.1.9 2 2 2h3\" />",
  "loader-circle": "<path d=\"M21 12a9 9 0 1 1-6.219-8.56\" />",
  "lock": "<rect width=\"18\" height=\"11\" x=\"3\" y=\"11\" rx=\"2\" ry=\"2\" /><path d=\"M7 11V7a5 5 0 0 1 10 0v4\" />",
  "lock-open": "<rect width=\"18\" height=\"11\" x=\"3\" y=\"11\" rx=\"2\" ry=\"2\" /><path d=\"M7 11V7a5 5 0 0 1 9.9-1\" />",
  "mail": "<rect width=\"20\" height=\"16\" x=\"2\" y=\"4\" rx=\"2\" /><path d=\"m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7\" />",
  "maximize": "<path d=\"M8 3H5a2 2 0 0 0-2 2v3\" /><path d=\"M21 8V5a2 2 0 0 0-2-2h-3\" /><path d=\"M3 16v3a2 2 0 0 0 2 2h3\" /><path d=\"M16 21h3a2 2 0 0 0 2-2v-3\" />",
  "merge": "<path d=\"m8 6 4-4 4 4\" /><path d=\"M12 2v10.3a4 4 0 0 1-1.172 2.872L4 22\" /><path d=\"m20 22-5-5\" />",
  "message-square": "<path d=\"M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z\" />",
  "minimize-2": "<polyline points=\"4 14 10 14 10 20\" /><polyline points=\"20 10 14 10 14 4\" /><line x1=\"14\" x2=\"21\" y1=\"10\" y2=\"3\" /><line x1=\"3\" x2=\"10\" y1=\"21\" y2=\"14\" />",
  "minus": "<path d=\"M5 12h14\" />",
  "monitor": "<rect width=\"20\" height=\"14\" x=\"2\" y=\"3\" rx=\"2\" /><line x1=\"8\" x2=\"16\" y1=\"21\" y2=\"21\" /><line x1=\"12\" x2=\"12\" y1=\"17\" y2=\"21\" />",
  "moon": "<path d=\"M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z\" />",
  "mouse-pointer-2": "<path d=\"M4.037 4.688a.495.495 0 0 1 .651-.651l16 6.5a.5.5 0 0 1-.063.947l-6.124 1.58a2 2 0 0 0-1.438 1.435l-1.579 6.126a.5.5 0 0 1-.947.063z\" />",
  "move": "<path d=\"M12 2v20\" /><path d=\"m15 19-3 3-3-3\" /><path d=\"m19 9 3 3-3 3\" /><path d=\"M2 12h20\" /><path d=\"m5 9-3 3 3 3\" /><path d=\"m9 5 3-3 3 3\" />",
  "palette": "<circle cx=\"13.5\" cy=\"6.5\" r=\".5\" fill=\"currentColor\" /><circle cx=\"17.5\" cy=\"10.5\" r=\".5\" fill=\"currentColor\" /><circle cx=\"8.5\" cy=\"7.5\" r=\".5\" fill=\"currentColor\" /><circle cx=\"6.5\" cy=\"12.5\" r=\".5\" fill=\"currentColor\" /><path d=\"M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z\" />",
  "panel-left": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" /><path d=\"M9 3v18\" />",
  "panel-left-close": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" /><path d=\"M9 3v18\" /><path d=\"m16 15-3-3 3-3\" />",
  "panel-right": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" /><path d=\"M15 3v18\" />",
  "pause": "<rect x=\"14\" y=\"4\" width=\"4\" height=\"16\" rx=\"1\" /><rect x=\"6\" y=\"4\" width=\"4\" height=\"16\" rx=\"1\" />",
  "pen": "<path d=\"M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z\" />",
  "pen-line": "<path d=\"M12 20h9\" /><path d=\"M16.376 3.622a1 1 0 0 1 3.002 3.002L7.368 18.635a2 2 0 0 1-.855.506l-2.872.838a.5.5 0 0 1-.62-.62l.838-2.872a2 2 0 0 1 .506-.854z\" />",
  "pen-tool": "<path d=\"M15.707 21.293a1 1 0 0 1-1.414 0l-1.586-1.586a1 1 0 0 1 0-1.414l5.586-5.586a1 1 0 0 1 1.414 0l1.586 1.586a1 1 0 0 1 0 1.414z\" /><path d=\"m18 13-1.375-6.874a1 1 0 0 0-.746-.776L3.235 2.028a1 1 0 0 0-1.207 1.207L5.35 15.879a1 1 0 0 0 .776.746L13 18\" /><path d=\"m2.3 2.3 7.286 7.286\" /><circle cx=\"11\" cy=\"11\" r=\"2\" />",
  "pencil": "<path d=\"M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z\" /><path d=\"m15 5 4 4\" />",
  "pilcrow": "<path d=\"M13 4v16\" /><path d=\"M17 4v16\" /><path d=\"M19 4H9.5a4.5 4.5 0 0 0 0 9H13\" />",
  "pipette": "<path d=\"m2 22 1-1h3l9-9\" /><path d=\"M3 21v-3l9-9\" /><path d=\"m15 6 3.4-3.4a2.1 2.1 0 1 1 3 3L18 9l.4.4a2.1 2.1 0 1 1-3 3l-3.8-3.8a2.1 2.1 0 1 1 3-3l.4.4Z\" />",
  "play": "<polygon points=\"6 3 20 12 6 21 6 3\" />",
  "plus": "<path d=\"M5 12h14\" /><path d=\"M12 5v14\" />",
  "pointer": "<path d=\"M22 14a8 8 0 0 1-8 8\" /><path d=\"M18 11v-1a2 2 0 0 0-2-2a2 2 0 0 0-2 2\" /><path d=\"M14 10V9a2 2 0 0 0-2-2a2 2 0 0 0-2 2v1\" /><path d=\"M10 9.5V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v10\" /><path d=\"M18 11a2 2 0 1 1 4 0v3a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15\" />",
  "printer": "<path d=\"M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2\" /><path d=\"M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6\" /><rect x=\"6\" y=\"14\" width=\"12\" height=\"8\" rx=\"1\" />",
  "redo-2": "<path d=\"m15 14 5-5-5-5\" /><path d=\"M20 9H9.5A5.5 5.5 0 0 0 4 14.5A5.5 5.5 0 0 0 9.5 20H13\" />",
  "refresh-cw": "<path d=\"M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8\" /><path d=\"M21 3v5h-5\" /><path d=\"M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16\" /><path d=\"M8 16H3v5\" />",
  "regex": "<path d=\"M17 3v10\" /><path d=\"m12.67 5.5 8.66 5\" /><path d=\"m12.67 10.5 8.66-5\" /><path d=\"M9 17a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v2a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2v-2z\" />",
  "replace": "<path d=\"M14 4a2 2 0 0 1 2-2\" /><path d=\"M16 10a2 2 0 0 1-2-2\" /><path d=\"M20 2a2 2 0 0 1 2 2\" /><path d=\"M22 8a2 2 0 0 1-2 2\" /><path d=\"m3 7 3 3 3-3\" /><path d=\"M6 10V5a3 3 0 0 1 3-3h1\" /><rect x=\"2\" y=\"14\" width=\"8\" height=\"8\" rx=\"2\" />",
  "rotate-ccw": "<path d=\"M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8\" /><path d=\"M3 3v5h5\" />",
  "rotate-cw": "<path d=\"M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8\" /><path d=\"M21 3v5h-5\" />",
  "ruler": "<path d=\"M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z\" /><path d=\"m14.5 12.5 2-2\" /><path d=\"m11.5 9.5 2-2\" /><path d=\"m8.5 6.5 2-2\" /><path d=\"m17.5 15.5 2-2\" />",
  "save": "<path d=\"M15.2 3a2 2 0 0 1 1.4.6l3.8 3.8a2 2 0 0 1 .6 1.4V19a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z\" /><path d=\"M17 21v-7a1 1 0 0 0-1-1H8a1 1 0 0 0-1 1v7\" /><path d=\"M7 3v4a1 1 0 0 0 1 1h7\" />",
  "scan": "<path d=\"M3 7V5a2 2 0 0 1 2-2h2\" /><path d=\"M17 3h2a2 2 0 0 1 2 2v2\" /><path d=\"M21 17v2a2 2 0 0 1-2 2h-2\" /><path d=\"M7 21H5a2 2 0 0 1-2-2v-2\" />",
  "scan-text": "<path d=\"M3 7V5a2 2 0 0 1 2-2h2\" /><path d=\"M17 3h2a2 2 0 0 1 2 2v2\" /><path d=\"M21 17v2a2 2 0 0 1-2 2h-2\" /><path d=\"M7 21H5a2 2 0 0 1-2-2v-2\" /><path d=\"M7 8h8\" /><path d=\"M7 12h10\" /><path d=\"M7 16h6\" />",
  "scissors": "<circle cx=\"6\" cy=\"6\" r=\"3\" /><path d=\"M8.12 8.12 12 12\" /><path d=\"M20 4 8.12 15.88\" /><circle cx=\"6\" cy=\"18\" r=\"3\" /><path d=\"M14.8 14.8 20 20\" />",
  "search": "<circle cx=\"11\" cy=\"11\" r=\"8\" /><path d=\"m21 21-4.3-4.3\" />",
  "settings": "<path d=\"M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z\" /><circle cx=\"12\" cy=\"12\" r=\"3\" />",
  "share": "<path d=\"M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8\" /><polyline points=\"16 6 12 2 8 6\" /><line x1=\"12\" x2=\"12\" y1=\"2\" y2=\"15\" />",
  "shield": "<path d=\"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z\" />",
  "shield-check": "<path d=\"M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z\" /><path d=\"m9 12 2 2 4-4\" />",
  "signature": "<path d=\"m21 17-2.156-1.868A.5.5 0 0 0 18 15.5v.5a1 1 0 0 1-1 1h-2a1 1 0 0 1-1-1c0-2.545-3.991-3.97-8.5-4a1 1 0 0 0 0 5c4.153 0 4.745-11.295 5.708-13.5a2.5 2.5 0 1 1 3.31 3.284\" /><path d=\"M3 21h18\" />",
  "smartphone": "<rect width=\"14\" height=\"20\" x=\"5\" y=\"2\" rx=\"2\" ry=\"2\" /><path d=\"M12 18h.01\" />",
  "spell-check": "<path d=\"m6 16 6-12 6 12\" /><path d=\"M8 12h8\" /><path d=\"m16 20 2 2 4-4\" />",
  "split": "<path d=\"M16 3h5v5\" /><path d=\"M8 3H3v5\" /><path d=\"M12 22v-8.3a4 4 0 0 0-1.172-2.872L3 3\" /><path d=\"m15 9 6-6\" />",
  "square": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" />",
  "square-check": "<rect width=\"18\" height=\"18\" x=\"3\" y=\"3\" rx=\"2\" /><path d=\"m9 12 2 2 4-4\" />",
  "square-dashed": "<path d=\"M5 3a2 2 0 0 0-2 2\" /><path d=\"M19 3a2 2 0 0 1 2 2\" /><path d=\"M21 19a2 2 0 0 1-2 2\" /><path d=\"M5 21a2 2 0 0 1-2-2\" /><path d=\"M9 3h1\" /><path d=\"M9 21h1\" /><path d=\"M14 3h1\" /><path d=\"M14 21h1\" /><path d=\"M3 9v1\" /><path d=\"M21 9v1\" /><path d=\"M3 14v1\" /><path d=\"M21 14v1\" />",
  "square-pen": "<path d=\"M12 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7\" /><path d=\"M18.375 2.625a1 1 0 0 1 3 3l-9.013 9.014a2 2 0 0 1-.853.505l-2.873.84a.5.5 0 0 1-.62-.62l.84-2.873a2 2 0 0 1 .506-.852z\" />",
  "stamp": "<path d=\"M5 22h14\" /><path d=\"M19.27 13.73A2.5 2.5 0 0 0 17.5 13h-11A2.5 2.5 0 0 0 4 15.5V17a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-1.5c0-.66-.26-1.3-.73-1.77Z\" /><path d=\"M14 13V8.5C14 7 15 7 15 5a3 3 0 0 0-3-3c-1.66 0-3 1-3 3s1 2 1 3.5V13\" />",
  "sticky-note": "<path d=\"M16 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8Z\" /><path d=\"M15 3v4a2 2 0 0 0 2 2h4\" />",
  "strikethrough": "<path d=\"M16 4H9a3 3 0 0 0-2.83 4\" /><path d=\"M14 12a4 4 0 0 1 0 8H6\" /><line x1=\"4\" x2=\"20\" y1=\"12\" y2=\"12\" />",
  "sun": "<circle cx=\"12\" cy=\"12\" r=\"4\" /><path d=\"M12 2v2\" /><path d=\"M12 20v2\" /><path d=\"m4.93 4.93 1.41 1.41\" /><path d=\"m17.66 17.66 1.41 1.41\" /><path d=\"M2 12h2\" /><path d=\"M20 12h2\" /><path d=\"m6.34 17.66-1.41 1.41\" /><path d=\"m19.07 4.93-1.41 1.41\" />",
  "table-of-contents": "<path d=\"M16 12H3\" /><path d=\"M16 18H3\" /><path d=\"M16 6H3\" /><path d=\"M21 12h.01\" /><path d=\"M21 18h.01\" /><path d=\"M21 6h.01\" />",
  "text-cursor": "<path d=\"M17 22h-1a4 4 0 0 1-4-4V6a4 4 0 0 1 4-4h1\" /><path d=\"M7 22h1a4 4 0 0 0 4-4v-1\" /><path d=\"M7 2h1a4 4 0 0 1 4 4v1\" />",
  "text-cursor-input": "<path d=\"M5 4h1a3 3 0 0 1 3 3 3 3 0 0 1 3-3h1\" /><path d=\"M13 20h-1a3 3 0 0 1-3-3 3 3 0 0 1-3 3H5\" /><path d=\"M5 16H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h1\" /><path d=\"M13 8h7a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-7\" /><path d=\"M9 7v10\" />",
  "text-select": "<path d=\"M5 3a2 2 0 0 0-2 2\" /><path d=\"M19 3a2 2 0 0 1 2 2\" /><path d=\"M21 19a2 2 0 0 1-2 2\" /><path d=\"M5 21a2 2 0 0 1-2-2\" /><path d=\"M9 3h1\" /><path d=\"M9 21h1\" /><path d=\"M14 3h1\" /><path d=\"M14 21h1\" /><path d=\"M3 9v1\" /><path d=\"M21 9v1\" /><path d=\"M3 14v1\" /><path d=\"M21 14v1\" /><line x1=\"7\" x2=\"15\" y1=\"8\" y2=\"8\" /><line x1=\"7\" x2=\"17\" y1=\"12\" y2=\"12\" /><line x1=\"7\" x2=\"13\" y1=\"16\" y2=\"16\" />",
  "trash-2": "<path d=\"M3 6h18\" /><path d=\"M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6\" /><path d=\"M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2\" /><line x1=\"10\" x2=\"10\" y1=\"11\" y2=\"17\" /><line x1=\"14\" x2=\"14\" y1=\"11\" y2=\"17\" />",
  "triangle-alert": "<path d=\"m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3\" /><path d=\"M12 9v4\" /><path d=\"M12 17h.01\" />",
  "type": "<polyline points=\"4 7 4 4 20 4 20 7\" /><line x1=\"9\" x2=\"15\" y1=\"20\" y2=\"20\" /><line x1=\"12\" x2=\"12\" y1=\"4\" y2=\"20\" />",
  "underline": "<path d=\"M6 4v6a6 6 0 0 0 12 0V4\" /><line x1=\"4\" x2=\"20\" y1=\"20\" y2=\"20\" />",
  "undo-2": "<path d=\"M9 14 4 9l5-5\" /><path d=\"M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5a5.5 5.5 0 0 1-5.5 5.5H11\" />",
  "upload": "<path d=\"M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4\" /><polyline points=\"17 8 12 3 7 8\" /><line x1=\"12\" x2=\"12\" y1=\"3\" y2=\"15\" />",
  "whole-word": "<circle cx=\"7\" cy=\"12\" r=\"3\" /><path d=\"M10 9v6\" /><circle cx=\"17\" cy=\"12\" r=\"3\" /><path d=\"M14 7v8\" /><path d=\"M22 17v1c0 .5-.5 1-1 1H3c-.5 0-1-.5-1-1v-1\" />",
  "wifi-off": "<path d=\"M12 20h.01\" /><path d=\"M8.5 16.429a5 5 0 0 1 7 0\" /><path d=\"M5 12.859a10 10 0 0 1 5.17-2.69\" /><path d=\"M19 12.859a10 10 0 0 0-2.007-1.523\" /><path d=\"M2 8.82a15 15 0 0 1 4.177-2.643\" /><path d=\"M22 8.82a15 15 0 0 0-11.288-3.764\" /><path d=\"m2 2 20 20\" />",
  "x": "<path d=\"M18 6 6 18\" /><path d=\"m6 6 12 12\" />",
  "zoom-in": "<circle cx=\"11\" cy=\"11\" r=\"8\" /><line x1=\"21\" x2=\"16.65\" y1=\"21\" y2=\"16.65\" /><line x1=\"11\" x2=\"11\" y1=\"8\" y2=\"14\" /><line x1=\"8\" x2=\"14\" y1=\"11\" y2=\"11\" />",
  "zoom-out": "<circle cx=\"11\" cy=\"11\" r=\"8\" /><line x1=\"21\" x2=\"16.65\" y1=\"21\" y2=\"16.65\" /><line x1=\"8\" x2=\"14\" y1=\"11\" y2=\"11\" />"
};
function Icon({
  name,
  size = 16,
  strokeWidth = 1.5,
  color = 'currentColor',
  label,
  style,
  className,
  flipRtl = false
}) {
  const inner = ICON_PATHS[name];
  if (!inner) {
    if (typeof console !== 'undefined') console.warn('Ferman Icon: unknown icon "' + name + '"');
  }
  return React.createElement('svg', {
    xmlns: 'http://www.w3.org/2000/svg',
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: color,
    strokeWidth,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    role: label ? 'img' : undefined,
    'aria-label': label,
    'aria-hidden': label ? undefined : true,
    className: className,
    'data-flip-rtl': flipRtl ? '' : undefined,
    style: Object.assign({
      flex: 'none',
      display: 'block'
    }, style),
    dangerouslySetInnerHTML: {
      __html: inner || ''
    }
  });
}
Object.assign(__ds_scope, { ICON_PATHS, Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/annotations/StickyNote.jsx
try { (() => {
const COLORS = {
  yellow: 'var(--annot-yellow)',
  green: 'var(--annot-green)',
  blue: 'var(--annot-blue)',
  pink: 'var(--annot-pink)',
  orange: 'var(--annot-orange)'
};
function StickyNote({
  collapsed = false,
  color = 'yellow',
  author,
  time,
  text,
  replies = [],
  onToggle,
  onReply,
  children
}) {
  const bg = COLORS[color] || color;
  if (collapsed) {
    return /*#__PURE__*/React.createElement("button", {
      type: "button",
      className: "fm-note-pin",
      style: {
        background: bg
      },
      "aria-label": 'Note from ' + author,
      onClick: onToggle
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "message-square",
      size: 14
    }));
  }
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-note",
    role: "dialog",
    "aria-label": 'Note from ' + author
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-note__head",
    style: {
      background: bg
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "fm-note__author"
  }, author), /*#__PURE__*/React.createElement("span", {
    className: "fm-note__time"
  }, time), /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "fm-iconbtn fm-iconbtn--xs",
    "aria-label": "More"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "ellipsis",
    size: 14
  })), /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "fm-iconbtn fm-iconbtn--xs",
    "aria-label": "Close note",
    onClick: onToggle
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "x",
    size: 14
  }))), /*#__PURE__*/React.createElement("div", {
    className: "fm-note__body"
  }, text), replies.map((r, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    className: "fm-note__reply"
  }, /*#__PURE__*/React.createElement("b", null, r.author, " ", /*#__PURE__*/React.createElement("span", {
    className: "fm-note__time",
    style: {
      fontWeight: 400
    }
  }, r.time)), /*#__PURE__*/React.createElement("span", null, r.text))), children, onReply !== null ? /*#__PURE__*/React.createElement("div", {
    className: "fm-note__foot"
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-input fm-input--sm"
  }, /*#__PURE__*/React.createElement("input", {
    className: "fm-input__control",
    placeholder: "Reply",
    "aria-label": "Reply",
    onKeyDown: e => {
      if (e.key === 'Enter' && onReply && e.currentTarget.value) {
        onReply(e.currentTarget.value);
        e.currentTarget.value = '';
      }
    }
  }))) : null);
}
Object.assign(__ds_scope, { StickyNote });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/annotations/StickyNote.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Badge({
  tone = 'neutral',
  dot = false,
  icon,
  children,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    className: 'fm-badge' + (tone !== 'neutral' ? ' fm-badge--' + tone : '')
  }, rest), dot ? /*#__PURE__*/React.createElement("span", {
    className: "fm-badge__dot",
    "aria-hidden": "true"
  }) : null, icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 12,
    strokeWidth: 2
  }) : null, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Button({
  variant = 'secondary',
  size = 'md',
  icon,
  iconEnd,
  loading = false,
  disabled = false,
  fullWidth = false,
  type = 'button',
  children,
  className,
  ...rest
}) {
  const cls = ['fm-btn', 'fm-btn--' + variant, size !== 'md' ? 'fm-btn--' + size : '', fullWidth ? 'fm-btn--full' : '', className || ''].filter(Boolean).join(' ');
  const iconSize = size === 'sm' ? 14 : 16;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    className: cls,
    disabled: disabled,
    "aria-busy": loading || undefined
  }, rest), loading ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "loader-circle",
    size: iconSize,
    className: "fm-icon-spin"
  }) : icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: iconSize
  }) : null, children != null && /*#__PURE__*/React.createElement("span", null, children), iconEnd && !loading ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: iconEnd,
    size: iconSize
  }) : null);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Kbd.jsx
try { (() => {
function Kbd({
  keys,
  tone = 'default',
  children
}) {
  const list = keys || (children != null ? [children] : []);
  return /*#__PURE__*/React.createElement("kbd", {
    className: 'fm-kbd' + (tone !== 'default' ? ' fm-kbd--' + tone : '')
  }, list.map((k, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    className: "fm-kbd__key"
  }, k)));
}
Object.assign(__ds_scope, { Kbd });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Kbd.jsx", error: String((e && e.message) || e) }); }

// components/core/Tooltip.jsx
try { (() => {
function Tooltip({
  content,
  shortcut,
  side = 'bottom',
  open,
  delay = 450,
  children
}) {
  const [show, setShow] = React.useState(false);
  const timer = React.useRef(null);
  const id = React.useId();
  const visible = open !== undefined ? open : show;
  const enter = () => {
    clearTimeout(timer.current);
    timer.current = setTimeout(() => setShow(true), delay);
  };
  const leave = () => {
    clearTimeout(timer.current);
    setShow(false);
  };
  React.useEffect(() => () => clearTimeout(timer.current), []);
  const child = React.isValidElement(children) ? React.cloneElement(children, {
    'aria-describedby': visible ? id : undefined
  }) : children;
  return /*#__PURE__*/React.createElement("span", {
    className: "fm-tooltip-anchor",
    onMouseEnter: enter,
    onMouseLeave: leave,
    onFocus: enter,
    onBlur: leave,
    onKeyDown: e => {
      if (e.key === 'Escape') leave();
    }
  }, child, visible && content ? /*#__PURE__*/React.createElement("span", {
    role: "tooltip",
    id: id,
    className: 'fm-tooltip fm-tooltip--' + side
  }, /*#__PURE__*/React.createElement("span", null, content), shortcut ? /*#__PURE__*/React.createElement(__ds_scope.Kbd, {
    keys: shortcut,
    tone: "inverse"
  }) : null) : null);
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Tooltip.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function IconButton({
  icon,
  label,
  size = 'md',
  variant = 'ghost',
  active,
  shortcut,
  tooltip = true,
  tooltipSide = 'bottom',
  disabled = false,
  className,
  ...rest
}) {
  const cls = ['fm-iconbtn', size !== 'md' ? 'fm-iconbtn--' + size : '', variant !== 'ghost' ? 'fm-iconbtn--' + variant : '', className || ''].filter(Boolean).join(' ');
  const iconSize = size === 'lg' ? 20 : size === 'xs' ? 14 : 16;
  const btn = /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: cls,
    "aria-label": label,
    "aria-pressed": active === undefined ? undefined : !!active,
    disabled: disabled
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: iconSize
  }));
  if (!tooltip || disabled) return btn;
  return /*#__PURE__*/React.createElement(__ds_scope.Tooltip, {
    content: label,
    shortcut: shortcut,
    side: tooltipSide
  }, btn);
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/editing/PageMark.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const DEFAULT_TITLES = {
  'edited': 'Edited',
  'redact-pending': 'Marked for redaction. Apply redactions to remove it permanently.',
  'redact-applied': 'Redacted'
};
function PageMark({
  kind = 'selection',
  title,
  char,
  children,
  ...rest
}) {
  let t = title;
  if (!t && kind === 'missing-glyph') t = 'This font has no ‘' + (char || (typeof children === 'string' ? children : '')) + '’. Ferman will use a similar font for this character.';
  if (!t) t = DEFAULT_TITLES[kind];
  return /*#__PURE__*/React.createElement("mark", _extends({
    className: 'fm-mark fm-mark--' + kind,
    title: t,
    "data-kind": kind
  }, rest), children);
}
Object.assign(__ds_scope, { PageMark });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/editing/PageMark.jsx", error: String((e && e.message) || e) }); }

// components/editing/SearchReplaceBar.jsx
try { (() => {
function SearchReplaceBar({
  query = '',
  replaceWith = '',
  showReplace = false,
  current = 0,
  total = 0,
  matchCase = false,
  wholeWord = false,
  regex = false,
  notice,
  onQueryChange,
  onReplaceChange,
  onToggleReplace,
  onToggleOption,
  onPrev,
  onNext,
  onReplace,
  onReplaceAll,
  onClose,
  autoFocus = false
}) {
  const count = !query ? '' : total === 0 ? 'No results' : current + ' of ' + total;
  const opt = (key, icon, label, on) => /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "fm-search__opt",
    "aria-label": label,
    title: label,
    "aria-pressed": on,
    onClick: () => onToggleOption && onToggleOption(key, !on)
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 14
  }));
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-search",
    role: "search",
    "aria-label": "Find and replace",
    onKeyDown: e => {
      if (e.key === 'Escape' && onClose) onClose();
      if (e.key === 'Enter' && e.target.dataset.role === 'find') {
        e.shiftKey ? onPrev && onPrev() : onNext && onNext();
      }
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-search__row"
  }, /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: showReplace ? 'chevron-down' : 'chevron-right',
    label: showReplace ? 'Hide replace' : 'Show replace',
    size: "sm",
    tooltip: false,
    onClick: onToggleReplace
  }), /*#__PURE__*/React.createElement("div", {
    className: "fm-input fm-input--sm"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "search",
    size: 14
  }), /*#__PURE__*/React.createElement("input", {
    className: "fm-input__control",
    "data-role": "find",
    placeholder: "Find",
    "aria-label": "Find",
    value: query,
    autoFocus: autoFocus,
    onChange: e => onQueryChange && onQueryChange(e.target.value)
  }), opt('matchCase', 'case-sensitive', 'Match case', matchCase), opt('wholeWord', 'whole-word', 'Whole word', wholeWord), opt('regex', 'regex', 'Regular expression', regex)), /*#__PURE__*/React.createElement("span", {
    className: 'fm-search__count' + (query && total === 0 ? ' fm-search__count--none' : ''),
    "aria-live": "polite"
  }, count), /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "chevron-up",
    label: "Previous match",
    size: "sm",
    shortcut: ['⇧', '↵'],
    disabled: !total,
    onClick: onPrev
  }), /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "chevron-down",
    label: "Next match",
    size: "sm",
    shortcut: ['↵'],
    disabled: !total,
    onClick: onNext
  }), /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "x",
    label: "Close",
    size: "sm",
    shortcut: ['Esc'],
    onClick: onClose
  })), showReplace ? /*#__PURE__*/React.createElement("div", {
    className: "fm-search__row",
    style: {
      paddingInlineStart: 30
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-input fm-input--sm"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "replace",
    size: 14
  }), /*#__PURE__*/React.createElement("input", {
    className: "fm-input__control",
    placeholder: "Replace with",
    "aria-label": "Replace with",
    value: replaceWith,
    onChange: e => onReplaceChange && onReplaceChange(e.target.value)
  })), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    disabled: !total,
    onClick: onReplace
  }, "Replace"), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    disabled: !total,
    onClick: onReplaceAll
  }, "Replace all")) : null, notice ? /*#__PURE__*/React.createElement("div", {
    className: "fm-search__notice",
    role: "status"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "triangle-alert",
    size: 14
  }), /*#__PURE__*/React.createElement("span", null, notice)) : null);
}
Object.assign(__ds_scope, { SearchReplaceBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/editing/SearchReplaceBar.jsx", error: String((e && e.message) || e) }); }

// components/editing/TextEditBox.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const HANDLES = ['nw', 'n', 'ne', 'e', 'se', 's', 'sw', 'w'];
function TextEditBox({
  state = 'editing',
  meta,
  metaWarning = false,
  showHandles,
  width,
  style,
  children,
  onClick,
  ...rest
}) {
  const handles = showHandles !== undefined ? showHandles : state === 'selected' || state === 'editing';
  const showMeta = meta && (state === 'selected' || state === 'editing');
  return /*#__PURE__*/React.createElement("div", _extends({
    className: 'fm-editbox fm-editbox--' + state,
    style: Object.assign({
      width
    }, style),
    onClick: onClick,
    role: state === 'editing' ? 'textbox' : undefined,
    "aria-multiline": state === 'editing' ? true : undefined
  }, rest), showMeta ? /*#__PURE__*/React.createElement("span", {
    className: 'fm-editbox__meta' + (metaWarning ? ' fm-editbox__meta--warning' : '')
  }, metaWarning ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "triangle-alert",
    size: 10,
    strokeWidth: 2
  }) : null, meta) : null, children, handles ? HANDLES.map(h => /*#__PURE__*/React.createElement("span", {
    key: h,
    className: "fm-editbox__handle",
    "data-h": h,
    "aria-hidden": "true"
  })) : null);
}
function TextCaret() {
  return /*#__PURE__*/React.createElement("span", {
    className: "fm-caret",
    "aria-hidden": "true"
  });
}
Object.assign(__ds_scope, { TextEditBox, TextCaret });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/editing/TextEditBox.jsx", error: String((e && e.message) || e) }); }

// components/empty/DropZone.jsx
try { (() => {
const COPY = {
  idle: {
    icon: 'file-text',
    title: 'Drop a PDF here',
    sub: 'Or open one from your computer. You can edit any text, sign, and organize pages.'
  },
  over: {
    icon: 'download',
    title: 'Release to open',
    sub: 'Ferman opens the file on this device.'
  },
  error: {
    icon: 'circle-alert',
    title: 'That file isn’t a PDF',
    sub: 'Ferman opens PDF files. To edit a Word or image file, convert it first.'
  }
};
function DropZone({
  state = 'idle',
  title,
  subtitle,
  onOpen,
  onCreate,
  shortcut = ['⌘', 'O'],
  recent = [],
  onOpenRecent,
  footnote = 'Files stay on this device. Ferman never uploads your documents.',
  onFiles,
  minHeight
}) {
  const [over, setOver] = React.useState(false);
  const st = over ? 'over' : state;
  const c = COPY[st];
  return /*#__PURE__*/React.createElement("div", {
    className: 'fm-drop' + (st !== 'idle' ? ' fm-drop--' + st : ''),
    style: minHeight ? {
      minHeight
    } : undefined,
    onDragOver: e => {
      e.preventDefault();
      setOver(true);
    },
    onDragLeave: () => setOver(false),
    onDrop: e => {
      e.preventDefault();
      setOver(false);
      if (onFiles) onFiles(Array.from(e.dataTransfer.files || []));
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "fm-drop__icon"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: c.icon,
    size: 24
  })), /*#__PURE__*/React.createElement("div", {
    className: "fm-drop__text"
  }, /*#__PURE__*/React.createElement("h2", {
    className: "fm-drop__title"
  }, st === 'idle' && title ? title : c.title), /*#__PURE__*/React.createElement("p", {
    className: "fm-drop__sub"
  }, st === 'idle' && subtitle ? subtitle : c.sub)), st !== 'over' ? /*#__PURE__*/React.createElement("div", {
    className: "fm-drop__actions"
  }, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "primary",
    size: "lg",
    icon: "folder-open",
    onClick: onOpen
  }, "Open a PDF", /*#__PURE__*/React.createElement("span", {
    style: {
      marginInlineStart: 4,
      opacity: 0.75,
      fontWeight: 400
    }
  }, shortcut.join(''))), onCreate ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "lg",
    icon: "file-plus-2",
    onClick: onCreate
  }, "New blank PDF") : null) : null, recent.length && st === 'idle' ? /*#__PURE__*/React.createElement("div", {
    className: "fm-drop__recent"
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-drop__recent-title"
  }, "Recent"), recent.map(f => /*#__PURE__*/React.createElement("button", {
    key: f.name,
    type: "button",
    className: "fm-drop__file",
    onClick: () => onOpenRecent && onOpenRecent(f)
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "file-text",
    size: 16,
    color: "var(--icon-secondary)"
  }), /*#__PURE__*/React.createElement("span", {
    className: "fm-drop__file-name"
  }, f.name), /*#__PURE__*/React.createElement("span", {
    className: "fm-drop__file-meta"
  }, f.meta)))) : null, footnote && st === 'idle' ? /*#__PURE__*/React.createElement("div", {
    className: "fm-drop__foot"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "hard-drive",
    size: 14
  }), /*#__PURE__*/React.createElement("span", null, footnote)) : null);
}
Object.assign(__ds_scope, { DropZone });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/empty/DropZone.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Banner.jsx
try { (() => {
const ICONS = {
  info: 'info',
  success: 'circle-check',
  warning: 'triangle-alert',
  danger: 'circle-alert',
  neutral: 'info'
};
function Banner({
  tone = 'info',
  variant = 'box',
  title,
  icon,
  actions,
  onDismiss,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: 'fm-banner fm-banner--' + tone + (variant === 'bar' ? ' fm-banner--bar' : ''),
    role: tone === 'danger' || tone === 'warning' ? 'alert' : 'status'
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon || ICONS[tone],
    size: 14,
    className: "fm-banner__icon"
  }), /*#__PURE__*/React.createElement("div", {
    className: "fm-banner__body"
  }, title ? /*#__PURE__*/React.createElement("div", {
    className: "fm-banner__title"
  }, title) : null, children ? /*#__PURE__*/React.createElement("div", null, children) : null), actions || onDismiss ? /*#__PURE__*/React.createElement("div", {
    className: "fm-banner__actions"
  }, actions, onDismiss ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "x",
    label: "Dismiss",
    size: "xs",
    tooltip: false,
    onClick: onDismiss
  }) : null) : null);
}
Object.assign(__ds_scope, { Banner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Banner.jsx", error: String((e && e.message) || e) }); }

// components/feedback/ProgressBar.jsx
try { (() => {
function ProgressBar({
  value,
  indeterminate = false,
  tone = 'accent',
  size = 'sm',
  label,
  showValue = false
}) {
  const pct = Math.round(Math.max(0, Math.min(1, value || 0)) * 100);
  const cls = ['fm-progress', size === 'md' ? 'fm-progress--md' : '', tone !== 'accent' ? 'fm-progress--' + tone : '', indeterminate ? 'fm-progress--indeterminate' : ''].filter(Boolean).join(' ');
  return /*#__PURE__*/React.createElement("div", {
    className: cls
  }, label || showValue ? /*#__PURE__*/React.createElement("div", {
    className: "fm-progress__head"
  }, /*#__PURE__*/React.createElement("span", null, label), showValue && !indeterminate ? /*#__PURE__*/React.createElement("span", {
    className: "fm-progress__value"
  }, pct, "%") : null) : null, /*#__PURE__*/React.createElement("div", {
    className: "fm-progress__track",
    role: "progressbar",
    "aria-label": typeof label === 'string' ? label : undefined,
    "aria-valuemin": 0,
    "aria-valuemax": 100,
    "aria-valuenow": indeterminate ? undefined : pct
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-progress__fill",
    style: indeterminate ? undefined : {
      width: pct + '%'
    }
  })));
}
Object.assign(__ds_scope, { ProgressBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/ProgressBar.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Spinner.jsx
try { (() => {
function Spinner({
  size = 16,
  onAccent = false,
  label = 'Loading'
}) {
  const bw = size <= 12 ? 1.5 : size >= 32 ? 3 : 2;
  return /*#__PURE__*/React.createElement("span", {
    className: 'fm-spinner' + (onAccent ? ' fm-spinner--on-accent' : ''),
    role: "status",
    "aria-label": label,
    style: {
      width: size,
      height: size,
      borderWidth: bw
    }
  });
}
Object.assign(__ds_scope, { Spinner });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Spinner.jsx", error: String((e && e.message) || e) }); }

// components/feedback/TaskProgress.jsx
try { (() => {
function TaskProgress({
  title,
  detail,
  value,
  indeterminate = false,
  state = 'running',
  icon = 'scan-text',
  variant = 'card',
  onCancel,
  onPause,
  onResume,
  primaryAction,
  secondaryAction
}) {
  const tone = state === 'done' ? 'success' : state === 'error' ? 'danger' : state === 'paused' ? 'paused' : 'accent';
  if (variant === 'inline') {
    return /*#__PURE__*/React.createElement("div", {
      className: "fm-task fm-task--inline",
      role: "status"
    }, state === 'running' ? /*#__PURE__*/React.createElement(__ds_scope.Spinner, {
      size: 12,
      label: typeof title === 'string' ? title : 'Working'
    }) : /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: state === 'done' ? 'circle-check' : state === 'error' ? 'circle-alert' : 'pause',
      size: 14
    }), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("span", {
      style: {
        color: 'var(--text-primary)'
      }
    }, title), detail ? ' · ' : '', detail), state !== 'done' ? /*#__PURE__*/React.createElement(__ds_scope.ProgressBar, {
      value: value,
      indeterminate: indeterminate,
      tone: tone
    }) : null, onCancel && state !== 'done' ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
      icon: "x",
      label: "Cancel",
      size: "xs",
      onClick: onCancel
    }) : null);
  }
  const stateIcon = state === 'done' ? 'circle-check' : state === 'error' ? 'circle-alert' : icon;
  return /*#__PURE__*/React.createElement("div", {
    className: 'fm-task fm-task--' + state,
    role: "status",
    "aria-live": "polite"
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-task__row"
  }, /*#__PURE__*/React.createElement("span", {
    className: "fm-task__icon"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: stateIcon,
    size: 16
  })), /*#__PURE__*/React.createElement("div", {
    className: "fm-task__text"
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-task__title"
  }, title), detail ? /*#__PURE__*/React.createElement("div", {
    className: "fm-task__detail"
  }, detail) : null), onCancel && (state === 'running' || state === 'paused') ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "x",
    label: "Cancel",
    size: "sm",
    onClick: onCancel
  }) : null), state === 'running' || state === 'paused' ? /*#__PURE__*/React.createElement(__ds_scope.ProgressBar, {
    value: value,
    indeterminate: indeterminate,
    tone: tone
  }) : null, onPause || onResume || primaryAction || secondaryAction ? /*#__PURE__*/React.createElement("div", {
    className: "fm-task__actions"
  }, state === 'running' && onPause ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    variant: "ghost",
    icon: "pause",
    onClick: onPause
  }, "Pause") : null, state === 'paused' && onResume ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    onClick: onResume
  }, "Resume") : null, secondaryAction ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    variant: "ghost",
    onClick: secondaryAction.onClick
  }, secondaryAction.label) : null, primaryAction ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    variant: state === 'done' ? 'secondary' : 'secondary',
    onClick: primaryAction.onClick
  }, primaryAction.label) : null) : null);
}
Object.assign(__ds_scope, { TaskProgress });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/TaskProgress.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Toast.jsx
try { (() => {
const ICONS = {
  neutral: 'info',
  success: 'circle-check',
  warning: 'triangle-alert',
  danger: 'circle-alert'
};
function Toast({
  tone = 'neutral',
  title,
  message,
  icon,
  action,
  onClose
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: 'fm-toast fm-toast--' + tone,
    role: tone === 'danger' ? 'alert' : 'status',
    "aria-live": tone === 'danger' ? 'assertive' : 'polite'
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon || ICONS[tone],
    size: 16,
    className: "fm-toast__icon"
  }), /*#__PURE__*/React.createElement("div", {
    className: "fm-toast__body"
  }, title ? /*#__PURE__*/React.createElement("div", {
    className: "fm-toast__title"
  }, title) : null, message ? /*#__PURE__*/React.createElement("div", {
    className: "fm-toast__msg"
  }, message) : null), /*#__PURE__*/React.createElement("div", {
    className: "fm-toast__actions"
  }, action ? /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    variant: "ghost",
    onClick: action.onClick,
    style: {
      color: 'var(--text-accent)'
    }
  }, action.label) : null, onClose ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "x",
    label: "Dismiss",
    size: "sm",
    tooltip: false,
    onClick: onClose
  }) : null));
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Toast.jsx", error: String((e && e.message) || e) }); }

// components/fill-sign/PdfFormField.jsx
try { (() => {
function PdfFormField({
  type = 'text',
  state,
  value,
  placeholder,
  label,
  required = false,
  error,
  options = [],
  width = 160,
  checked,
  signedAs,
  onChange,
  onClick
}) {
  const st = state || (error ? 'error' : value || checked || signedAs ? 'filled' : 'empty');
  const wrap = 'fm-pff fm-pff--' + st;
  const req = required ? /*#__PURE__*/React.createElement("span", {
    className: "fm-pff__req",
    "aria-hidden": "true"
  }, "*") : null;
  const msg = st === 'error' && error ? /*#__PURE__*/React.createElement("span", {
    className: "fm-pff__msg"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "circle-alert",
    size: 12
  }), error) : null;
  const lab = label ? /*#__PURE__*/React.createElement("span", {
    className: "fm-pff__label"
  }, label) : null;
  if (type === 'checkbox' || type === 'radio') {
    return /*#__PURE__*/React.createElement("span", {
      className: wrap
    }, /*#__PURE__*/React.createElement("span", {
      role: type,
      "aria-checked": !!checked,
      "aria-label": label,
      "aria-required": required || undefined,
      tabIndex: 0,
      className: 'fm-pff__box fm-pff__box--' + (type === 'checkbox' ? 'check' : 'radio'),
      onClick: onClick
    }, checked ? type === 'checkbox' ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "check",
      size: 12,
      strokeWidth: 2.5,
      color: "var(--paper-900)"
    }) : /*#__PURE__*/React.createElement("span", {
      className: "fm-pff__dot"
    }) : null, req));
  }
  if (type === 'signature') {
    return /*#__PURE__*/React.createElement("span", {
      className: wrap,
      style: {
        width
      }
    }, lab, /*#__PURE__*/React.createElement("span", {
      role: "button",
      tabIndex: 0,
      "aria-label": signedAs ? 'Signed by ' + signedAs : 'Sign here',
      className: 'fm-pff__box fm-pff__box--signature' + (signedAs ? ' is-signed' : ''),
      onClick: onClick
    }, signedAs ? signedAs : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "signature",
      size: 16
    }), /*#__PURE__*/React.createElement("span", null, "Sign here")), req), msg);
  }
  const icon = type === 'date' ? 'calendar' : type === 'dropdown' ? 'chevron-down' : null;
  return /*#__PURE__*/React.createElement("span", {
    className: wrap,
    style: {
      width
    }
  }, lab, /*#__PURE__*/React.createElement("span", {
    className: 'fm-pff__box' + (type === 'multiline' ? ' fm-pff__box--multiline' : '')
  }, type === 'dropdown' ? /*#__PURE__*/React.createElement("select", {
    className: "fm-pff__input",
    "aria-label": label,
    value: value || '',
    onChange: onChange ? e => onChange(e.target.value) : undefined,
    style: {
      appearance: 'none',
      cursor: 'pointer'
    }
  }, /*#__PURE__*/React.createElement("option", {
    value: "",
    disabled: true
  }, placeholder || 'Choose'), options.map(o => /*#__PURE__*/React.createElement("option", {
    key: o,
    value: o
  }, o))) : type === 'multiline' ? /*#__PURE__*/React.createElement("textarea", {
    className: "fm-pff__input",
    "aria-label": label,
    rows: 3,
    placeholder: placeholder,
    value: value,
    onChange: onChange ? e => onChange(e.target.value) : undefined,
    readOnly: st === 'readonly' || !onChange,
    style: {
      resize: 'none',
      lineHeight: '16px'
    }
  }) : /*#__PURE__*/React.createElement("input", {
    className: "fm-pff__input",
    "aria-label": label,
    "aria-invalid": st === 'error' || undefined,
    "aria-required": required || undefined,
    placeholder: placeholder,
    value: value || '',
    readOnly: st === 'readonly' || !onChange,
    onChange: onChange ? e => onChange(e.target.value) : undefined
  }), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 12,
    color: "#6F6A62"
  }) : null, req), msg);
}
Object.assign(__ds_scope, { PdfFormField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/fill-sign/PdfFormField.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Checkbox({
  label,
  description,
  checked,
  defaultChecked,
  indeterminate = false,
  disabled = false,
  onChange,
  id,
  ...rest
}) {
  const ref = React.useRef(null);
  React.useEffect(() => {
    if (ref.current) ref.current.indeterminate = !!indeterminate;
  }, [indeterminate]);
  return /*#__PURE__*/React.createElement("label", {
    className: 'fm-check' + (disabled ? ' fm-check--disabled' : '')
  }, /*#__PURE__*/React.createElement("span", {
    className: "fm-check__box"
  }, /*#__PURE__*/React.createElement("input", _extends({
    ref: ref,
    id: id,
    type: "checkbox",
    className: 'fm-check__input' + (indeterminate ? ' is-indeterminate' : ''),
    checked: checked,
    defaultChecked: defaultChecked,
    disabled: disabled,
    onChange: onChange ? e => onChange(e.target.checked, e) : undefined
  }, rest)), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: indeterminate ? 'minus' : 'check',
    size: 12,
    strokeWidth: 2.75,
    className: "fm-check__mark"
  })), label || description ? /*#__PURE__*/React.createElement("span", {
    className: "fm-check__text"
  }, label ? /*#__PURE__*/React.createElement("span", null, label) : null, description ? /*#__PURE__*/React.createElement("span", {
    className: "fm-check__desc"
  }, description) : null) : null);
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/ColorPicker.jsx
try { (() => {
const STANDARD = ['#1F1D1A', '#57534C', '#8A857C', '#C9C4BA', '#FFFFFF', '#2A4DAF', '#0F7F72', '#1E7A46', '#D98A0B', '#B42318', '#962C21', '#6B3FA0', '#FFE066', '#A8E6A1', '#A8D1FF', '#FFB3C7'];
function useOutside(ref, onOut, active) {
  React.useEffect(() => {
    if (!active) return undefined;
    const h = e => {
      if (ref.current && !ref.current.contains(e.target)) onOut();
    };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, [active]);
}
function ColorPicker({
  label,
  value,
  defaultValue = '#1F1D1A',
  documentColors = [],
  swatches = STANDARD,
  allowNone = false,
  open,
  defaultOpen = false,
  onOpenChange,
  onChange,
  size = 'sm',
  disabled = false
}) {
  const [inner, setInner] = React.useState(defaultValue);
  const [innerOpen, setInnerOpen] = React.useState(defaultOpen);
  const color = value !== undefined ? value : inner;
  const isOpen = open !== undefined ? open : innerOpen;
  const [hex, setHex] = React.useState(null);
  const ref = React.useRef(null);
  const setOpen = o => {
    if (open === undefined) setInnerOpen(o);
    if (onOpenChange) onOpenChange(o);
  };
  useOutside(ref, () => setOpen(false), isOpen && open === undefined);
  const pick = c => {
    if (value === undefined) setInner(c);
    if (onChange) onChange(c);
  };
  const sw = c => /*#__PURE__*/React.createElement("button", {
    key: c,
    type: "button",
    className: "fm-swatch",
    "aria-label": c,
    "aria-pressed": String(c).toLowerCase() === String(color).toLowerCase(),
    style: {
      background: c
    },
    onClick: () => pick(c)
  });
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-popover-anchor",
    ref: ref
  }, label ? /*#__PURE__*/React.createElement("span", {
    className: "fm-field__label"
  }, label) : null, /*#__PURE__*/React.createElement("div", {
    className: "fm-popover-host"
  }, /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: 'fm-input fm-colortrigger' + (size === 'sm' ? ' fm-input--sm' : '') + (disabled ? ' fm-input--disabled' : ''),
    "aria-haspopup": "dialog",
    "aria-expanded": isOpen,
    disabled: disabled,
    onClick: () => setOpen(!isOpen),
    onKeyDown: e => {
      if (e.key === 'Escape') setOpen(false);
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: 'fm-chip' + (color === 'none' ? ' fm-chip--none' : ''),
    style: color === 'none' ? undefined : {
      background: color
    }
  }), /*#__PURE__*/React.createElement("span", {
    className: "fm-colortrigger__value"
  }, color === 'none' ? 'None' : color), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 14
  })), isOpen ? /*#__PURE__*/React.createElement("div", {
    className: "fm-popover fm-colorpop",
    role: "dialog",
    "aria-label": "Choose color"
  }, documentColors.length ? /*#__PURE__*/React.createElement("div", {
    className: "fm-popover__section"
  }, "In this document") : null, documentColors.length ? /*#__PURE__*/React.createElement("div", {
    className: "fm-swatches"
  }, documentColors.map(sw)) : null, /*#__PURE__*/React.createElement("div", {
    className: "fm-popover__section"
  }, "Standard"), /*#__PURE__*/React.createElement("div", {
    className: "fm-swatches"
  }, allowNone ? /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "fm-swatch fm-chip--none",
    "aria-label": "No color",
    "aria-pressed": color === 'none',
    onClick: () => pick('none')
  }) : null, swatches.map(sw)), /*#__PURE__*/React.createElement("div", {
    className: "fm-colorpop__hex"
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-input fm-input--sm",
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-tertiary)',
      font: 'var(--type-caption)'
    }
  }, "Hex"), /*#__PURE__*/React.createElement("input", {
    className: "fm-input__control",
    "aria-label": "Hex color",
    value: hex !== null ? hex : color === 'none' ? '' : color,
    onChange: e => setHex(e.target.value),
    onBlur: () => {
      if (hex && /^#?[0-9a-f]{6}$/i.test(hex)) pick((hex[0] === '#' ? hex : '#' + hex).toUpperCase());
      setHex(null);
    },
    onKeyDown: e => {
      if (e.key === 'Enter') e.currentTarget.blur();
    },
    style: {
      textTransform: 'uppercase'
    }
  })), /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: "fm-iconbtn fm-iconbtn--sm fm-iconbtn--secondary",
    "aria-label": "Pick a color from the page"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "pipette",
    size: 14
  })))) : null));
}
Object.assign(__ds_scope, { ColorPicker });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/ColorPicker.jsx", error: String((e && e.message) || e) }); }

// components/forms/FontPicker.jsx
try { (() => {
function FontPicker({
  label,
  value,
  fonts = [],
  warning,
  open,
  defaultOpen = false,
  onOpenChange,
  onChange,
  size = 'sm',
  disabled = false
}) {
  const [innerOpen, setInnerOpen] = React.useState(defaultOpen);
  const [q, setQ] = React.useState('');
  const isOpen = open !== undefined ? open : innerOpen;
  const ref = React.useRef(null);
  const setOpen = o => {
    if (open === undefined) setInnerOpen(o);
    if (onOpenChange) onOpenChange(o);
  };
  React.useEffect(() => {
    if (!isOpen || open !== undefined) return undefined;
    const h = e => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener('mousedown', h);
    return () => document.removeEventListener('mousedown', h);
  }, [isOpen]);
  const current = fonts.find(f => f.name === value) || {
    name: value,
    available: true
  };
  const missing = current.available === false;
  const filtered = fonts.filter(f => f.name.toLowerCase().includes(q.toLowerCase()));
  const groups = [['document', 'In this document'], ['system', 'On this device']];
  const row = f => /*#__PURE__*/React.createElement("button", {
    key: f.name,
    type: "button",
    role: "option",
    "aria-selected": f.name === value,
    className: 'fm-fontrow' + (f.available === false ? ' fm-fontrow--missing' : ''),
    onClick: () => {
      if (onChange) onChange(f.name);
      setOpen(false);
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "fm-fontrow__check"
  }, f.name === value ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "check",
    size: 14,
    strokeWidth: 2
  }) : null), /*#__PURE__*/React.createElement("span", {
    className: "fm-fontrow__name",
    style: {
      fontFamily: f.available === false ? 'var(--font-ui)' : f.family || "'" + f.name + "'"
    }
  }, f.name), f.available === false ? /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    tone: "warning"
  }, "Not installed") : null);
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-popover-anchor",
    ref: ref
  }, label ? /*#__PURE__*/React.createElement("span", {
    className: "fm-field__label"
  }, label) : null, /*#__PURE__*/React.createElement("div", {
    className: "fm-popover-host"
  }, /*#__PURE__*/React.createElement("button", {
    type: "button",
    className: 'fm-input fm-fonttrigger' + (size === 'sm' ? ' fm-input--sm' : '') + (missing ? ' fm-input--warning fm-fonttrigger--missing' : '') + (disabled ? ' fm-input--disabled' : ''),
    "aria-haspopup": "listbox",
    "aria-expanded": isOpen,
    disabled: disabled,
    onClick: () => setOpen(!isOpen),
    onKeyDown: e => {
      if (e.key === 'Escape') setOpen(false);
    }
  }, missing ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "triangle-alert",
    size: 14,
    style: {
      color: 'var(--warning-solid)'
    }
  }) : null, /*#__PURE__*/React.createElement("span", {
    className: "fm-fonttrigger__name",
    style: {
      fontFamily: missing ? 'var(--font-ui)' : current.family || "'" + current.name + "'"
    }
  }, current.name), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 14
  })), isOpen ? /*#__PURE__*/React.createElement("div", {
    className: "fm-popover fm-fontpop",
    role: "listbox",
    "aria-label": "Fonts"
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-fontpop__search"
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-input fm-input--sm"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "search",
    size: 14
  }), /*#__PURE__*/React.createElement("input", {
    className: "fm-input__control",
    placeholder: "Search fonts",
    "aria-label": "Search fonts",
    value: q,
    onChange: e => setQ(e.target.value),
    autoFocus: open === undefined
  }))), groups.map(([g, title]) => {
    const items = filtered.filter(f => (f.group || 'system') === g);
    if (!items.length) return null;
    return /*#__PURE__*/React.createElement("div", {
      key: g
    }, /*#__PURE__*/React.createElement("div", {
      className: "fm-popover__section"
    }, title), items.map(row));
  }), !filtered.length ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '10px 12px',
      font: 'var(--type-caption)',
      color: 'var(--text-tertiary)'
    }
  }, "No fonts match \u201C", q, "\u201D.") : null) : null), warning || missing ? /*#__PURE__*/React.createElement("div", {
    className: "fm-fontnote",
    role: "status"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "triangle-alert",
    size: 14
  }), /*#__PURE__*/React.createElement("span", null, warning || current.name + ' isn’t installed. Ferman is showing ' + (current.substitute || 'a similar font') + ' instead.')) : null);
}
Object.assign(__ds_scope, { FontPicker });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/FontPicker.jsx", error: String((e && e.message) || e) }); }

// components/forms/NumberStepper.jsx
try { (() => {
function clamp(v, min, max) {
  return Math.min(max, Math.max(min, v));
}
function NumberStepper({
  label,
  value,
  defaultValue = 0,
  min = -Infinity,
  max = Infinity,
  step = 1,
  unit,
  precision = 0,
  size = 'sm',
  width = 84,
  disabled = false,
  onChange,
  id
}) {
  const autoId = React.useId();
  const fid = id || autoId;
  const [inner, setInner] = React.useState(defaultValue);
  const current = value !== undefined ? value : inner;
  const [draft, setDraft] = React.useState(null);
  const commit = v => {
    const n = clamp(Math.round(v / step) * step, min, max);
    const fixed = Number(n.toFixed(precision));
    if (value === undefined) setInner(fixed);
    if (onChange) onChange(fixed);
  };
  const onKey = e => {
    if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
      e.preventDefault();
      commit(current + (e.key === 'ArrowUp' ? 1 : -1) * step * (e.shiftKey ? 10 : 1));
      setDraft(null);
    } else if (e.key === 'Enter') {
      e.currentTarget.blur();
    }
  };
  const cls = ['fm-input', 'fm-stepper', size === 'sm' ? 'fm-input--sm' : '', disabled ? 'fm-input--disabled' : ''].filter(Boolean).join(' ');
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-field",
    style: {
      width
    }
  }, label ? /*#__PURE__*/React.createElement("label", {
    className: "fm-field__label",
    htmlFor: fid
  }, label) : null, /*#__PURE__*/React.createElement("div", {
    className: cls
  }, /*#__PURE__*/React.createElement("input", {
    id: fid,
    className: "fm-input__control",
    inputMode: "decimal",
    role: "spinbutton",
    "aria-valuenow": current,
    "aria-valuemin": isFinite(min) ? min : undefined,
    "aria-valuemax": isFinite(max) ? max : undefined,
    disabled: disabled,
    value: draft !== null ? draft : current.toFixed(precision),
    onChange: e => setDraft(e.target.value),
    onKeyDown: onKey,
    onBlur: () => {
      if (draft !== null) {
        const n = parseFloat(String(draft).replace(',', '.'));
        if (!isNaN(n)) commit(n);
        setDraft(null);
      }
    }
  }), unit ? /*#__PURE__*/React.createElement("span", {
    className: "fm-input__suffix"
  }, unit) : null, /*#__PURE__*/React.createElement("span", {
    className: "fm-stepper__arrows"
  }, /*#__PURE__*/React.createElement("button", {
    type: "button",
    tabIndex: -1,
    className: "fm-stepper__arrow",
    "aria-label": "Increase",
    disabled: disabled || current >= max,
    onClick: () => commit(current + step)
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-up",
    size: 11,
    strokeWidth: 2
  })), /*#__PURE__*/React.createElement("button", {
    type: "button",
    tabIndex: -1,
    className: "fm-stepper__arrow",
    "aria-label": "Decrease",
    disabled: disabled || current <= min,
    onClick: () => commit(current - step)
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 11,
    strokeWidth: 2
  })))));
}
Object.assign(__ds_scope, { NumberStepper });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/NumberStepper.jsx", error: String((e && e.message) || e) }); }

// components/forms/Radio.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Radio({
  label,
  description,
  checked,
  defaultChecked,
  disabled = false,
  name,
  value,
  onChange,
  id,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    className: 'fm-check fm-radio' + (disabled ? ' fm-check--disabled' : '')
  }, /*#__PURE__*/React.createElement("span", {
    className: "fm-check__box"
  }, /*#__PURE__*/React.createElement("input", _extends({
    id: id,
    type: "radio",
    className: "fm-check__input",
    name: name,
    value: value,
    checked: checked,
    defaultChecked: defaultChecked,
    disabled: disabled,
    onChange: onChange ? e => onChange(e.target.value, e) : undefined
  }, rest))), label || description ? /*#__PURE__*/React.createElement("span", {
    className: "fm-check__text"
  }, label ? /*#__PURE__*/React.createElement("span", null, label) : null, description ? /*#__PURE__*/React.createElement("span", {
    className: "fm-check__desc"
  }, description) : null) : null);
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Radio.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Select({
  label,
  options = [],
  value,
  defaultValue,
  onChange,
  size = 'md',
  icon,
  disabled = false,
  id,
  className,
  ...rest
}) {
  const autoId = React.useId();
  const fid = id || autoId;
  const cls = ['fm-input', 'fm-select', size === 'sm' ? 'fm-input--sm' : '', disabled ? 'fm-input--disabled' : ''].filter(Boolean).join(' ');
  return /*#__PURE__*/React.createElement("div", {
    className: 'fm-field ' + (className || '')
  }, label ? /*#__PURE__*/React.createElement("label", {
    className: "fm-field__label",
    htmlFor: fid
  }, label) : null, /*#__PURE__*/React.createElement("div", {
    className: cls
  }, icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: size === 'sm' ? 14 : 16
  }) : null, /*#__PURE__*/React.createElement("select", _extends({
    id: fid,
    className: "fm-input__control",
    value: value,
    defaultValue: defaultValue,
    disabled: disabled,
    onChange: onChange ? e => onChange(e.target.value, e) : undefined
  }, rest), options.map(o => {
    const opt = typeof o === 'string' ? {
      value: o,
      label: o
    } : o;
    return /*#__PURE__*/React.createElement("option", {
      key: opt.value,
      value: opt.value,
      disabled: opt.disabled
    }, opt.label);
  })), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 14
  })));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Switch({
  label,
  checked,
  defaultChecked,
  disabled = false,
  onChange,
  id,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    className: "fm-switch",
    style: disabled ? {
      color: 'var(--text-disabled)',
      cursor: 'not-allowed'
    } : undefined
  }, /*#__PURE__*/React.createElement("span", {
    className: "fm-switch__track"
  }, /*#__PURE__*/React.createElement("input", _extends({
    id: id,
    type: "checkbox",
    role: "switch",
    className: "fm-switch__input",
    checked: checked,
    defaultChecked: defaultChecked,
    disabled: disabled,
    onChange: onChange ? e => onChange(e.target.checked, e) : undefined
  }, rest)), /*#__PURE__*/React.createElement("span", {
    className: "fm-switch__thumb"
  })), label ? /*#__PURE__*/React.createElement("span", null, label) : null);
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/forms/TextField.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function TextField({
  label,
  hint,
  error,
  icon,
  suffix,
  size = 'md',
  disabled = false,
  id,
  className,
  inputRef,
  ...rest
}) {
  const autoId = React.useId();
  const fid = id || autoId;
  const cls = ['fm-input', size === 'sm' ? 'fm-input--sm' : '', error ? 'fm-input--error' : '', disabled ? 'fm-input--disabled' : ''].filter(Boolean).join(' ');
  return /*#__PURE__*/React.createElement("div", {
    className: 'fm-field ' + (className || '')
  }, label ? /*#__PURE__*/React.createElement("label", {
    className: "fm-field__label",
    htmlFor: fid
  }, label) : null, /*#__PURE__*/React.createElement("div", {
    className: cls
  }, icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: size === 'sm' ? 14 : 16
  }) : null, /*#__PURE__*/React.createElement("input", _extends({
    id: fid,
    ref: inputRef,
    className: "fm-input__control",
    disabled: disabled,
    "aria-invalid": error ? true : undefined,
    "aria-describedby": error || hint ? fid + '-msg' : undefined
  }, rest)), suffix ? /*#__PURE__*/React.createElement("span", {
    className: "fm-input__suffix"
  }, suffix) : null), error ? /*#__PURE__*/React.createElement("div", {
    id: fid + '-msg',
    className: "fm-field__error"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "circle-alert",
    size: 14
  }), /*#__PURE__*/React.createElement("span", null, error)) : hint ? /*#__PURE__*/React.createElement("div", {
    id: fid + '-msg',
    className: "fm-field__hint"
  }, hint) : null);
}
Object.assign(__ds_scope, { TextField });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/TextField.jsx", error: String((e && e.message) || e) }); }

// components/navigation/ModeTabs.jsx
try { (() => {
const FERMAN_MODES = [{
  id: 'view',
  label: 'View',
  icon: 'book-open'
}, {
  id: 'edit',
  label: 'Edit',
  icon: 'file-pen-line'
}, {
  id: 'comment',
  label: 'Comment',
  icon: 'message-square'
}, {
  id: 'sign',
  label: 'Fill & Sign',
  icon: 'signature'
}, {
  id: 'organize',
  label: 'Organize',
  icon: 'layout-grid'
}, {
  id: 'convert',
  label: 'Convert',
  icon: 'refresh-cw'
}, {
  id: 'protect',
  label: 'Protect',
  icon: 'shield'
}];
function ModeTabs({
  modes = FERMAN_MODES,
  value,
  defaultValue,
  onChange,
  variant = 'segmented',
  showIcons = false,
  label = 'Mode'
}) {
  const [inner, setInner] = React.useState(defaultValue || modes[0] && modes[0].id);
  const current = value !== undefined ? value : inner;
  const listRef = React.useRef(null);
  const select = id => {
    if (value === undefined) setInner(id);
    if (onChange) onChange(id);
  };
  const onKey = e => {
    const keys = ['ArrowLeft', 'ArrowRight', 'Home', 'End'];
    if (!keys.includes(e.key)) return;
    e.preventDefault();
    const rtl = listRef.current && getComputedStyle(listRef.current).direction === 'rtl';
    const i = modes.findIndex(m => m.id === current);
    let n = i;
    if (e.key === 'Home') n = 0;else if (e.key === 'End') n = modes.length - 1;else n = (i + (e.key === 'ArrowRight' !== rtl ? 1 : -1) + modes.length) % modes.length;
    select(modes[n].id);
    const btn = listRef.current && listRef.current.querySelectorAll('[role="tab"]')[n];
    if (btn) btn.focus();
  };
  return /*#__PURE__*/React.createElement("div", {
    ref: listRef,
    role: "tablist",
    "aria-label": label,
    className: 'fm-modetabs' + (variant === 'underline' ? ' fm-modetabs--underline' : ''),
    onKeyDown: onKey
  }, modes.map(m => /*#__PURE__*/React.createElement("button", {
    key: m.id,
    type: "button",
    role: "tab",
    "aria-selected": m.id === current,
    tabIndex: m.id === current ? 0 : -1,
    className: "fm-modetab",
    onClick: () => select(m.id)
  }, showIcons && m.icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: m.icon,
    size: 16
  }) : null, /*#__PURE__*/React.createElement("span", null, m.label))));
}
Object.assign(__ds_scope, { FERMAN_MODES, ModeTabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/ModeTabs.jsx", error: String((e && e.message) || e) }); }

// components/navigation/SegmentedControl.jsx
try { (() => {
function SegmentedControl({
  options = [],
  value,
  defaultValue,
  onChange,
  label,
  fullWidth = false,
  disabled = false
}) {
  const [inner, setInner] = React.useState(defaultValue !== undefined ? defaultValue : options[0] && options[0].value);
  const current = value !== undefined ? value : inner;
  const ref = React.useRef(null);
  const select = v => {
    if (value === undefined) setInner(v);
    if (onChange) onChange(v);
  };
  const onKey = e => {
    if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
    e.preventDefault();
    const rtl = ref.current && getComputedStyle(ref.current).direction === 'rtl';
    const i = options.findIndex(o => o.value === current);
    const n = (i + (e.key === 'ArrowRight' !== rtl ? 1 : -1) + options.length) % options.length;
    select(options[n].value);
    const b = ref.current && ref.current.querySelectorAll('[role="radio"]')[n];
    if (b) b.focus();
  };
  return /*#__PURE__*/React.createElement("div", {
    ref: ref,
    role: "radiogroup",
    "aria-label": label,
    className: 'fm-segmented' + (fullWidth ? ' fm-segmented--full' : ''),
    onKeyDown: onKey
  }, options.map(o => {
    const iconOnly = o.icon && !o.label;
    const btn = /*#__PURE__*/React.createElement("button", {
      key: o.value,
      type: "button",
      role: "radio",
      "aria-checked": o.value === current,
      "aria-label": iconOnly ? o.title : undefined,
      tabIndex: o.value === current ? 0 : -1,
      disabled: disabled || o.disabled,
      className: 'fm-segment' + (iconOnly ? ' fm-segment--icon' : ''),
      onClick: () => select(o.value)
    }, o.icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: o.icon,
      size: 14,
      flipRtl: o.flipRtl
    }) : null, o.label ? /*#__PURE__*/React.createElement("span", null, o.label) : null);
    return iconOnly ? /*#__PURE__*/React.createElement(__ds_scope.Tooltip, {
      key: o.value,
      content: o.title
    }, btn) : btn;
  }));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/fill-sign/SignaturePad.jsx
try { (() => {
const INKS = [{
  id: '#1F1D1A',
  name: 'Black'
}, {
  id: '#1A3170',
  name: 'Blue'
}];
function toPath(pts) {
  if (!pts.length) return '';
  if (pts.length < 3) return 'M' + pts[0][0] + ' ' + pts[0][1] + ' L' + pts[pts.length - 1][0] + ' ' + pts[pts.length - 1][1];
  let d = 'M' + pts[0][0] + ' ' + pts[0][1];
  for (let i = 1; i < pts.length - 1; i++) {
    const mx = (pts[i][0] + pts[i + 1][0]) / 2,
      my = (pts[i][1] + pts[i + 1][1]) / 2;
    d += ' Q' + pts[i][0] + ' ' + pts[i][1] + ' ' + mx.toFixed(1) + ' ' + my.toFixed(1);
  }
  return d;
}
function SignaturePad({
  mode,
  defaultMode = 'draw',
  onModeChange,
  name = '',
  ink,
  defaultInk = '#1F1D1A',
  saveForLater = true,
  onChange,
  initialStrokes = []
}) {
  const [m, setM] = React.useState(defaultMode);
  const curMode = mode !== undefined ? mode : m;
  const [inkC, setInk] = React.useState(defaultInk);
  const curInk = ink !== undefined ? ink : inkC;
  const [strokes, setStrokes] = React.useState(initialStrokes);
  const [typed, setTyped] = React.useState(name);
  const drawing = React.useRef(null);
  const areaRef = React.useRef(null);
  const emit = (s, t) => {
    if (onChange) onChange({
      mode: curMode,
      strokes: s,
      text: t,
      ink: curInk,
      empty: curMode === 'draw' ? !s.length : !t
    });
  };
  const pt = e => {
    const r = areaRef.current.getBoundingClientRect();
    return [Math.round((e.clientX - r.left) * 10) / 10, Math.round((e.clientY - r.top) * 10) / 10];
  };
  const down = e => {
    if (curMode !== 'draw') return;
    e.currentTarget.setPointerCapture(e.pointerId);
    drawing.current = [pt(e)];
    setStrokes(s => s.concat([drawing.current]));
  };
  const move = e => {
    if (!drawing.current) return;
    drawing.current.push(pt(e));
    setStrokes(s => s.slice(0, -1).concat([drawing.current.slice()]));
  };
  const up = () => {
    if (drawing.current) {
      drawing.current = null;
      setStrokes(s => {
        emit(s, typed);
        return s;
      });
    }
  };
  const clear = () => {
    setStrokes([]);
    setTyped('');
    emit([], '');
  };
  const setMode = v => {
    if (mode === undefined) setM(v);
    if (onModeChange) onModeChange(v);
  };
  const empty = curMode === 'draw' ? !strokes.length : curMode === 'type' ? !typed : true;
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-sigpad"
  }, /*#__PURE__*/React.createElement(__ds_scope.SegmentedControl, {
    label: "Signature method",
    value: curMode,
    onChange: setMode,
    options: [{
      value: 'draw',
      label: 'Draw',
      icon: 'pen-line'
    }, {
      value: 'type',
      label: 'Type',
      icon: 'type'
    }, {
      value: 'image',
      label: 'Image',
      icon: 'image'
    }]
  }), /*#__PURE__*/React.createElement("div", {
    ref: areaRef,
    className: "fm-sigpad__area",
    tabIndex: curMode === 'draw' ? 0 : -1,
    "aria-label": curMode === 'draw' ? 'Signature drawing area. Draw with a mouse, trackpad, pen or finger.' : undefined,
    onPointerDown: down,
    onPointerMove: move,
    onPointerUp: up,
    onPointerCancel: up,
    style: curMode !== 'draw' ? {
      cursor: 'default'
    } : undefined
  }, /*#__PURE__*/React.createElement("span", {
    className: "fm-sigpad__line"
  }), /*#__PURE__*/React.createElement("span", {
    className: "fm-sigpad__x"
  }, "\xD7"), curMode === 'draw' ? /*#__PURE__*/React.createElement("svg", {
    className: "fm-sigpad__svg",
    "aria-hidden": "true"
  }, strokes.map((s, i) => /*#__PURE__*/React.createElement("path", {
    key: i,
    d: toPath(s),
    fill: "none",
    stroke: curInk,
    strokeWidth: "2.2",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }))) : null, curMode === 'type' ? /*#__PURE__*/React.createElement("input", {
    className: "fm-sigpad__typed",
    "data-autofocus": "",
    "aria-label": "Type your name",
    placeholder: "Your name",
    value: typed,
    style: {
      color: curInk
    },
    onChange: e => {
      setTyped(e.target.value);
      emit(strokes, e.target.value);
    }
  }) : null, curMode === 'image' ? /*#__PURE__*/React.createElement("div", {
    className: "fm-sigpad__image"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "image",
    size: 20
  }), /*#__PURE__*/React.createElement("span", null, "Drop a photo or scan of your signature. Ferman removes the background."), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    icon: "folder-open"
  }, "Choose image\u2026")) : null, curMode !== 'image' && empty ? /*#__PURE__*/React.createElement("span", {
    className: "fm-sigpad__hint"
  }, curMode === 'draw' ? 'Sign above the line' : 'Type your name above the line') : null), /*#__PURE__*/React.createElement("div", {
    className: "fm-sigpad__bar"
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-sigpad__inks",
    role: "radiogroup",
    "aria-label": "Ink color"
  }, INKS.map(k => /*#__PURE__*/React.createElement("button", {
    key: k.id,
    type: "button",
    role: "radio",
    "aria-checked": curInk === k.id,
    "aria-label": k.name,
    className: "fm-annot-color",
    style: {
      background: k.id
    },
    onClick: () => setInk(k.id)
  }))), /*#__PURE__*/React.createElement(__ds_scope.Button, {
    size: "sm",
    variant: "ghost",
    icon: "eraser",
    disabled: empty,
    onClick: clear
  }, "Clear"), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement(__ds_scope.Checkbox, {
    label: "Save on this device",
    defaultChecked: saveForLater
  })));
}
Object.assign(__ds_scope, { SignaturePad });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/fill-sign/SignaturePad.jsx", error: String((e && e.message) || e) }); }

// components/navigation/ToolButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function ToolButton({
  icon,
  label,
  showLabel = true,
  layout = 'inline',
  active,
  hasMenu = false,
  swatch,
  shortcut,
  disabled = false,
  onClick,
  ...rest
}) {
  const iconOnly = !showLabel;
  const cls = ['fm-toolbtn', iconOnly ? 'fm-toolbtn--icon' : '', layout === 'stacked' ? 'fm-toolbtn--stacked' : ''].filter(Boolean).join(' ');
  const btn = /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: cls,
    "aria-pressed": active === undefined ? undefined : !!active,
    "aria-label": iconOnly ? label : undefined,
    "aria-haspopup": hasMenu ? 'menu' : undefined,
    disabled: disabled,
    onClick: onClick,
    style: swatch ? {
      position: 'relative'
    } : undefined
  }, rest), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: layout === 'stacked' ? 20 : 16
  }) : null, showLabel ? /*#__PURE__*/React.createElement("span", null, label) : null, hasMenu ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 12,
    className: "fm-toolbtn__caret"
  }) : null, swatch ? /*#__PURE__*/React.createElement("span", {
    className: "fm-toolbtn__swatch",
    style: {
      background: swatch
    }
  }) : null);
  if (disabled || !iconOnly && !shortcut) return btn;
  return /*#__PURE__*/React.createElement(__ds_scope.Tooltip, {
    content: label,
    shortcut: shortcut
  }, btn);
}
Object.assign(__ds_scope, { ToolButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/ToolButton.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Toolbar.jsx
try { (() => {
function Toolbar({
  variant = 'bar',
  label,
  children,
  className,
  style
}) {
  const ref = React.useRef(null);
  const onKey = e => {
    if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT')) return;
    const items = Array.from(ref.current.querySelectorAll('button:not([disabled]), select, input')).filter(el => !el.closest('[role="tablist"], [role="radiogroup"]') || el.getAttribute('tabindex') === '0');
    const i = items.indexOf(document.activeElement);
    if (i < 0) return;
    e.preventDefault();
    const rtl = getComputedStyle(ref.current).direction === 'rtl';
    const n = (i + (e.key === 'ArrowRight' !== rtl ? 1 : -1) + items.length) % items.length;
    items[n].focus();
  };
  return /*#__PURE__*/React.createElement("div", {
    ref: ref,
    role: "toolbar",
    "aria-label": label,
    className: 'fm-toolbar fm-toolbar--' + variant + (className ? ' ' + className : ''),
    style: style,
    onKeyDown: onKey
  }, children);
}
function ToolbarSeparator() {
  return /*#__PURE__*/React.createElement("span", {
    className: "fm-toolbar__sep",
    role: "separator",
    "aria-orientation": "vertical"
  });
}
function ToolbarSpacer() {
  return /*#__PURE__*/React.createElement("span", {
    className: "fm-toolbar__spacer"
  });
}
function ToolbarGroup({
  label,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-toolbar__group",
    role: "group",
    "aria-label": label
  }, children);
}
Object.assign(__ds_scope, { Toolbar, ToolbarSeparator, ToolbarSpacer, ToolbarGroup });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Toolbar.jsx", error: String((e && e.message) || e) }); }

// components/annotations/AnnotationTools.jsx
try { (() => {
const ANNOTATION_TOOLS = [{
  id: 'select',
  icon: 'mouse-pointer-2',
  label: 'Select',
  key: 'V'
}, {
  id: 'highlight',
  icon: 'highlighter',
  label: 'Highlight',
  key: 'H',
  colored: true
}, {
  id: 'underline',
  icon: 'underline',
  label: 'Underline',
  key: 'U',
  colored: true
}, {
  id: 'strikethrough',
  icon: 'strikethrough',
  label: 'Strikethrough',
  key: 'S',
  colored: true
}, {
  id: 'note',
  icon: 'sticky-note',
  label: 'Note',
  key: 'N',
  colored: true
}, {
  id: 'text',
  icon: 'type',
  label: 'Text box',
  key: 'X'
}, {
  id: 'pen',
  icon: 'pen-tool',
  label: 'Draw',
  key: 'P',
  colored: true
}, {
  id: 'shapes',
  icon: 'square',
  label: 'Shapes',
  key: 'R',
  menu: true,
  colored: true
}, {
  id: 'stamp',
  icon: 'stamp',
  label: 'Stamp',
  menu: true
}];
const PALETTE = [{
  id: 'yellow',
  css: 'var(--annot-yellow)',
  name: 'Yellow'
}, {
  id: 'green',
  css: 'var(--annot-green)',
  name: 'Green'
}, {
  id: 'blue',
  css: 'var(--annot-blue)',
  name: 'Blue'
}, {
  id: 'pink',
  css: 'var(--annot-pink)',
  name: 'Pink'
}, {
  id: 'red',
  css: 'var(--annot-red)',
  name: 'Red'
}, {
  id: 'ink',
  css: 'var(--annot-ink)',
  name: 'Black'
}];
function AnnotationTools({
  tool,
  defaultTool = 'highlight',
  onToolChange,
  color,
  defaultColor = 'yellow',
  onColorChange,
  showLabels = false,
  variant = 'bar',
  tools = ANNOTATION_TOOLS
}) {
  const [t, setT] = React.useState(defaultTool);
  const [c, setC] = React.useState(defaultColor);
  const curT = tool !== undefined ? tool : t;
  const curC = color !== undefined ? color : c;
  const pickT = id => {
    if (tool === undefined) setT(id);
    if (onToolChange) onToolChange(id);
  };
  const pickC = id => {
    if (color === undefined) setC(id);
    if (onColorChange) onColorChange(id);
  };
  const cur = tools.find(x => x.id === curT);
  const swatch = (PALETTE.find(p => p.id === curC) || PALETTE[0]).css;
  return /*#__PURE__*/React.createElement(__ds_scope.Toolbar, {
    variant: variant,
    label: "Comment tools"
  }, tools.map(x => /*#__PURE__*/React.createElement(__ds_scope.ToolButton, {
    key: x.id,
    icon: x.icon,
    label: x.label,
    showLabel: showLabels,
    active: x.id === curT,
    hasMenu: x.menu,
    swatch: x.colored && x.id === curT ? swatch : undefined,
    shortcut: x.key ? [x.key] : undefined,
    onClick: () => pickT(x.id)
  })), /*#__PURE__*/React.createElement(__ds_scope.ToolbarSeparator, null), /*#__PURE__*/React.createElement("div", {
    className: "fm-annot-colors",
    role: "radiogroup",
    "aria-label": "Color",
    "aria-disabled": cur && !cur.colored ? true : undefined,
    style: cur && !cur.colored ? {
      opacity: 0.4
    } : undefined
  }, PALETTE.map(p => /*#__PURE__*/React.createElement("button", {
    key: p.id,
    type: "button",
    role: "radio",
    "aria-checked": p.id === curC,
    "aria-label": p.name,
    className: "fm-annot-color",
    style: {
      background: p.css
    },
    onClick: () => pickC(p.id)
  }))));
}
Object.assign(__ds_scope, { ANNOTATION_TOOLS, AnnotationTools });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/annotations/AnnotationTools.jsx", error: String((e && e.message) || e) }); }

// components/overlays/CommandPalette.jsx
try { (() => {
function mark(label, q) {
  if (!q) return label;
  const i = label.toLocaleLowerCase('tr').indexOf(q.toLocaleLowerCase('tr'));
  if (i < 0) return label;
  return /*#__PURE__*/React.createElement(React.Fragment, null, label.slice(0, i), /*#__PURE__*/React.createElement("b", null, label.slice(i, i + q.length)), label.slice(i + q.length));
}
function CommandPalette({
  open = true,
  inline = false,
  groups = [],
  query,
  defaultQuery = '',
  onQueryChange,
  onSelect,
  onClose,
  placeholder = 'Search commands, pages and text',
  emptyText
}) {
  const [q, setQ] = React.useState(defaultQuery);
  const cur = query !== undefined ? query : q;
  const [active, setActive] = React.useState(0);
  const listRef = React.useRef(null);
  const filtered = groups.map(g => ({
    label: g.label,
    items: g.items.filter(it => !cur || (it.label + ' ' + (it.keywords || '')).toLocaleLowerCase('tr').includes(cur.toLocaleLowerCase('tr')))
  })).filter(g => g.items.length);
  const flat = filtered.flatMap(g => g.items);
  React.useEffect(() => {
    setActive(0);
  }, [cur]);
  React.useEffect(() => {
    const el = listRef.current && listRef.current.querySelector('[aria-selected="true"]');
    if (el && listRef.current) {
      const top = el.offsetTop,
        bottom = top + el.offsetHeight,
        lt = listRef.current.scrollTop,
        lh = listRef.current.clientHeight;
      if (top < lt) listRef.current.scrollTop = top - 6;else if (bottom > lt + lh) listRef.current.scrollTop = bottom - lh + 6;
    }
  }, [active]);
  if (!open) return null;
  const setQuery = v => {
    if (query === undefined) setQ(v);
    if (onQueryChange) onQueryChange(v);
  };
  const onKey = e => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setActive(a => Math.min(flat.length - 1, a + 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setActive(a => Math.max(0, a - 1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (flat[active] && onSelect) onSelect(flat[active].id, flat[active]);
    } else if (e.key === 'Escape') {
      e.preventDefault();
      if (onClose) onClose();
    }
  };
  let n = -1;
  const box = /*#__PURE__*/React.createElement("div", {
    className: "fm-palette",
    role: "dialog",
    "aria-label": "Command palette",
    onKeyDown: onKey,
    onMouseDown: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-palette__input"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "search",
    size: 18
  }), /*#__PURE__*/React.createElement("input", {
    className: "fm-palette__field",
    role: "combobox",
    "aria-expanded": "true",
    "aria-controls": "fm-palette-list",
    "aria-activedescendant": flat[active] ? 'fm-cmd-' + flat[active].id : undefined,
    placeholder: placeholder,
    value: cur,
    onChange: e => setQuery(e.target.value),
    autoFocus: !inline
  }), /*#__PURE__*/React.createElement(__ds_scope.Kbd, {
    keys: ['Esc']
  })), /*#__PURE__*/React.createElement("div", {
    className: "fm-palette__list",
    id: "fm-palette-list",
    role: "listbox",
    ref: listRef
  }, filtered.map(g => /*#__PURE__*/React.createElement("div", {
    key: g.label,
    role: "group",
    "aria-label": g.label
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-palette__group"
  }, g.label), g.items.map(it => {
    n += 1;
    const idx = n;
    return /*#__PURE__*/React.createElement("div", {
      key: it.id,
      id: 'fm-cmd-' + it.id,
      role: "option",
      "aria-selected": idx === active,
      className: "fm-palette__item",
      onMouseMove: () => setActive(idx),
      onClick: () => onSelect && onSelect(it.id, it)
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: it.icon || 'command',
      size: 16
    }), /*#__PURE__*/React.createElement("span", {
      className: "fm-palette__label"
    }, mark(it.label, cur)), it.hint ? /*#__PURE__*/React.createElement("span", {
      className: "fm-palette__hint"
    }, it.hint) : null, it.shortcut ? /*#__PURE__*/React.createElement(__ds_scope.Kbd, {
      keys: it.shortcut,
      tone: "plain"
    }) : null);
  }))), !flat.length ? /*#__PURE__*/React.createElement("div", {
    className: "fm-palette__empty"
  }, emptyText || 'No commands match “' + cur + '”. Press Enter to search the document instead.') : null), /*#__PURE__*/React.createElement("div", {
    className: "fm-palette__foot"
  }, /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement(__ds_scope.Kbd, {
    keys: ['↑', '↓']
  }), "Move"), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement(__ds_scope.Kbd, {
    keys: ['↵']
  }), "Run"), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement(__ds_scope.Kbd, {
    keys: ['Esc']
  }), "Close")));
  if (inline) return box;
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-scrim fm-scrim--top",
    onMouseDown: () => onClose && onClose()
  }, box);
}
Object.assign(__ds_scope, { CommandPalette });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/overlays/CommandPalette.jsx", error: String((e && e.message) || e) }); }

// components/overlays/Dialog.jsx
try { (() => {
const FOCUSABLE = 'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';
function Dialog({
  open = true,
  inline = false,
  title,
  description,
  icon,
  tone = 'default',
  size = 'md',
  children,
  actions,
  footerStart,
  onClose,
  closeLabel = 'Close'
}) {
  const ref = React.useRef(null);
  const id = React.useId();
  React.useEffect(() => {
    if (!open || inline || !ref.current) return undefined;
    const prev = document.activeElement;
    const tabbable = root => Array.from(root.querySelectorAll(FOCUSABLE)).filter(el => el.tabIndex >= 0);
    const body = ref.current.querySelector('.fm-dialog__body');
    const first = ref.current.querySelector('[data-autofocus]') || body && tabbable(body)[0] || ref.current;
    first.focus();
    return () => {
      if (prev && prev.focus) prev.focus();
    };
  }, [open, inline]);
  if (!open) return null;
  const onKey = e => {
    if (e.key === 'Escape' && onClose) {
      e.stopPropagation();
      onClose();
    }
    if (e.key === 'Tab' && !inline) {
      const els = Array.from(ref.current.querySelectorAll(FOCUSABLE)).filter(el => el.tabIndex >= 0);
      if (!els.length) return;
      const a = els[0],
        z = els[els.length - 1];
      if (e.shiftKey && document.activeElement === a) {
        e.preventDefault();
        z.focus();
      } else if (!e.shiftKey && document.activeElement === z) {
        e.preventDefault();
        a.focus();
      }
    }
  };
  const box = /*#__PURE__*/React.createElement("div", {
    ref: ref,
    role: tone === 'danger' ? 'alertdialog' : 'dialog',
    "aria-modal": inline ? undefined : true,
    "aria-labelledby": id + '-t',
    "aria-describedby": description ? id + '-d' : undefined,
    tabIndex: -1,
    className: 'fm-dialog fm-dialog--' + size + (tone !== 'default' ? ' fm-dialog--' + tone : ''),
    onKeyDown: onKey,
    onMouseDown: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-dialog__head"
  }, icon ? /*#__PURE__*/React.createElement("span", {
    className: "fm-dialog__glyph"
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 18
  })) : null, /*#__PURE__*/React.createElement("div", {
    className: "fm-dialog__titles"
  }, /*#__PURE__*/React.createElement("h2", {
    id: id + '-t',
    className: "fm-dialog__title"
  }, title), description ? /*#__PURE__*/React.createElement("p", {
    id: id + '-d',
    className: "fm-dialog__desc"
  }, description) : null), onClose ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "x",
    label: closeLabel,
    size: "sm",
    tooltip: false,
    onClick: onClose
  }) : null), /*#__PURE__*/React.createElement("div", {
    className: "fm-dialog__body"
  }, children), actions || footerStart ? /*#__PURE__*/React.createElement("div", {
    className: "fm-dialog__foot"
  }, footerStart ? /*#__PURE__*/React.createElement("div", {
    className: "fm-dialog__foot-start"
  }, footerStart) : null, actions) : null);
  if (inline) return box;
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-scrim",
    onMouseDown: () => onClose && onClose()
  }, box);
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/overlays/Dialog.jsx", error: String((e && e.message) || e) }); }

// components/overlays/Menu.jsx
try { (() => {
function Menu({
  items = [],
  onSelect,
  onClose,
  label,
  autoFocus = false,
  style
}) {
  const ref = React.useRef(null);
  React.useEffect(() => {
    if (autoFocus && ref.current) {
      const f = ref.current.querySelector('.fm-menu__item:not(:disabled)');
      if (f) f.focus();
    }
  }, [autoFocus]);
  const onKey = e => {
    const els = Array.from(ref.current.querySelectorAll('.fm-menu__item:not(:disabled)'));
    const i = els.indexOf(document.activeElement);
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      els[(i + 1) % els.length].focus();
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      els[(i - 1 + els.length) % els.length].focus();
    } else if (e.key === 'Home') {
      e.preventDefault();
      els[0].focus();
    } else if (e.key === 'End') {
      e.preventDefault();
      els[els.length - 1].focus();
    } else if (e.key === 'Escape' && onClose) {
      e.preventDefault();
      onClose();
    }
  };
  return /*#__PURE__*/React.createElement("div", {
    ref: ref,
    role: "menu",
    "aria-label": label,
    className: "fm-menu",
    style: style,
    onKeyDown: onKey
  }, items.map((it, i) => {
    if (it.separator) return /*#__PURE__*/React.createElement("div", {
      key: 's' + i,
      role: "separator",
      className: "fm-menu__sep"
    });
    if (it.heading) return /*#__PURE__*/React.createElement("div", {
      key: 'h' + i,
      className: "fm-menu__heading",
      role: "presentation"
    }, it.heading);
    const hasCheck = items.some(x => x.checked !== undefined);
    return /*#__PURE__*/React.createElement("button", {
      key: it.id || it.label,
      type: "button",
      role: it.checked !== undefined ? 'menuitemcheckbox' : 'menuitem',
      "aria-checked": it.checked,
      tabIndex: -1,
      disabled: it.disabled,
      className: 'fm-menu__item' + (it.danger ? ' fm-menu__item--danger' : ''),
      onClick: () => {
        if (onSelect) onSelect(it.id || it.label, it);
      }
    }, hasCheck ? /*#__PURE__*/React.createElement("span", {
      className: "fm-menu__check"
    }, it.checked ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "check",
      size: 14,
      strokeWidth: 2
    }) : null) : null, it.icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: it.icon,
      size: 16,
      flipRtl: it.flipRtl
    }) : null, /*#__PURE__*/React.createElement("span", {
      className: "fm-menu__label"
    }, it.label), it.shortcut ? /*#__PURE__*/React.createElement(__ds_scope.Kbd, {
      keys: it.shortcut,
      tone: "plain"
    }) : null, it.submenu ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: "chevron-right",
      size: 14,
      flipRtl: true
    }) : null);
  }));
}
Object.assign(__ds_scope, { Menu });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/overlays/Menu.jsx", error: String((e && e.message) || e) }); }

// components/pages/PageThumbnail.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function PageThumbnail({
  page,
  label,
  selected = false,
  state = 'idle',
  dropIndicator,
  orientation = 'vertical',
  marker,
  width = 112,
  aspect = 1.4142,
  rotation = 0,
  children,
  onClick,
  ...rest
}) {
  const sideways = rotation === 90 || rotation === 270;
  const w = sideways ? Math.round(width * aspect * 0.72) : width;
  const h = sideways ? Math.round(w / aspect) : Math.round(width * aspect);
  const cls = ['fm-thumb', state !== 'idle' ? 'fm-thumb--' + state : ''].filter(Boolean).join(' ');
  const axis = orientation === 'vertical' ? 'v' : 'h';
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    role: "option",
    "aria-selected": selected,
    "aria-label": label || 'Page ' + page,
    className: cls,
    onClick: onClick
  }, rest), /*#__PURE__*/React.createElement("span", {
    className: "fm-thumb__page",
    style: {
      width: w,
      height: h
    }
  }, children || /*#__PURE__*/React.createElement("span", {
    className: "fm-thumb__lines",
    style: rotation ? {
      transform: 'rotate(' + rotation + 'deg)',
      inset: sideways ? '10% 22%' : undefined
    } : undefined
  }), marker ? /*#__PURE__*/React.createElement("span", {
    className: 'fm-thumb__marker fm-thumb__marker--' + marker,
    title: marker === 'edited' ? 'Edited' : 'Has comments'
  }) : null), /*#__PURE__*/React.createElement("span", {
    className: "fm-thumb__num"
  }, rotation ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "rotate-cw",
    size: 10,
    strokeWidth: 2
  }) : null, label || page), dropIndicator ? /*#__PURE__*/React.createElement("span", {
    className: 'fm-thumb__drop fm-thumb__drop--' + axis + '-' + dropIndicator,
    "aria-hidden": "true"
  }) : null);
}
Object.assign(__ds_scope, { PageThumbnail });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/pages/PageThumbnail.jsx", error: String((e && e.message) || e) }); }

// components/panels/PanelSection.jsx
try { (() => {
function PanelSection({
  title,
  collapsible = true,
  defaultOpen = true,
  open,
  onOpenChange,
  actions,
  children
}) {
  const [inner, setInner] = React.useState(defaultOpen);
  const isOpen = open !== undefined ? open : inner;
  const id = React.useId();
  const toggle = () => {
    if (open === undefined) setInner(!isOpen);
    if (onOpenChange) onOpenChange(!isOpen);
  };
  return /*#__PURE__*/React.createElement("section", {
    className: "fm-panelsection",
    "aria-labelledby": id + '-t'
  }, /*#__PURE__*/React.createElement("div", {
    className: "fm-panelsection__head"
  }, collapsible ? /*#__PURE__*/React.createElement("button", {
    type: "button",
    id: id + '-t',
    className: "fm-panelsection__toggle",
    "aria-expanded": isOpen,
    "aria-controls": id,
    onClick: toggle
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 14
  }), /*#__PURE__*/React.createElement("span", null, title)) : /*#__PURE__*/React.createElement("h3", {
    id: id + '-t',
    className: "fm-panelsection__title",
    style: {
      margin: 0
    }
  }, title), actions ? /*#__PURE__*/React.createElement("div", {
    className: "fm-panelsection__actions"
  }, actions) : null), isOpen ? /*#__PURE__*/React.createElement("div", {
    id: id,
    className: "fm-panelsection__body"
  }, children) : null);
}
Object.assign(__ds_scope, { PanelSection });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/panels/PanelSection.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/App.jsx
try { (() => {
/* Ferman desktop — app state, keyboard, overlays. */
const DSA = window.FermanDesignSystem_278323;
const DOC = window.FERMAN_DOC;
const ALL_BLOCKS = DOC.pages.flatMap((p, pi) => p.blocks.map(b => Object.assign({
  page: pi
}, b)));
const DEFAULT_TOOL = {
  view: 'select',
  edit: 'edit-text',
  comment: 'highlight',
  sign: 'fill',
  organize: null,
  convert: null,
  protect: 'redact'
};
const DATE_RE = /^\d{2}\.\d{2}\.\d{4}$/;
function replaceTr(text, q, r, onlyStart) {
  const hits = window.findAllTr(text, q).filter(([s]) => onlyStart === undefined || s === onlyStart);
  let out = '',
    last = 0;
  hits.forEach(([s, e]) => {
    out += text.slice(last, s) + r;
    last = e;
  });
  return {
    text: out + text.slice(last),
    count: hits.length
  };
}
function App() {
  const {
    CommandPalette,
    SearchReplaceBar,
    Dialog,
    Button,
    SignaturePad,
    Toast,
    TaskProgress,
    DropZone
  } = DSA;
  const S = v => React.useState(v);
  const [docOpen, setDocOpen] = S(true);
  const [mode, setModeRaw] = S('edit');
  const [tool, setTool] = S('edit-text');
  const [annotColor, setAnnotColor] = S('yellow');
  const [theme, setTheme] = S('light');
  const [dim, setDim] = S(false);
  const [rtl, setRtl] = S(false);
  const [touch, setTouch] = S(false);
  const [sidebarOpen, setSidebarOpen] = S(true);
  const [sideTab, setSideTab] = S('pages');
  const [order, setOrderRaw] = S([0, 1, 2]);
  const [rotations, setRotations] = S({});
  const [organizeSel, setOrganizeSel] = S([]);
  const [currentPage, setCurrentPage] = S(0);
  const [zoom, setZoom] = S(100);
  const [selectedId, setSelectedId] = S('b12');
  const [editingId, setEditingId] = S(null);
  const [clickPoint, setClickPoint] = S(null);
  const [blockState, setBlockState] = S({});
  const [showEdits, setShowEdits] = S(true);
  const [search, setSearch] = S({
    open: false,
    q: '',
    r: '',
    showReplace: false,
    current: 1,
    matchCase: false,
    wholeWord: false,
    regex: false
  });
  const [palette, setPalette] = S(false);
  const [toasts, setToasts] = S([]);
  const [noteOpen, setNoteOpen] = S(false);
  const [replies, setReplies] = S([]);
  const [redactions, setRedactions] = S({});
  const [fields, setFields] = S({
    name: 'Ayşe Yılmaz',
    date: '',
    sig: null
  });
  const [signOpen, setSignOpen] = S(false);
  const [sigValue, setSigValue] = S(null);
  const [redactOpen, setRedactOpen] = S(false);
  const [task, setTask] = S(null);
  const [dirty, setDirty] = S(false);
  const canvasRef = React.useRef(null);
  const toast = t => {
    const id = Math.random();
    setToasts(x => x.concat([Object.assign({
      id
    }, t)]));
    setTimeout(() => setToasts(x => x.filter(y => y.id !== id)), t.action ? 8000 : 5000);
  };
  const textOf = b => blockState[b.id] && blockState[b.id].text !== undefined ? blockState[b.id].text : b.text;
  const isBlockEdited = id => {
    const st = blockState[id];
    const b = ALL_BLOCKS.find(x => x.id === id);
    return !!st && (st.text !== undefined && st.text !== b.text || st.props && Object.keys(st.props).length > 0);
  };
  const pageEdited = pi => DOC.pages[pi].blocks.some(b => isBlockEdited(b.id));
  const setMode = m => {
    setModeRaw(m);
    setTool(DEFAULT_TOOL[m]);
    setEditingId(null);
    if (m !== 'edit') setSelectedId(null);
  };
  const setOrder = o => {
    setOrderRaw(o);
    setDirty(true);
  };
  const goToPage = i => {
    setCurrentPage(i);
    const el = canvasRef.current && canvasRef.current.querySelector('[data-page-pos="' + i + '"]');
    if (el) canvasRef.current.scrollTop = el.offsetTop * (zoom / 100) - 16;
  };
  const onScroll = () => {
    const c = canvasRef.current;
    if (!c) return;
    const els = Array.from(c.querySelectorAll('[data-page-pos]'));
    const mid = c.scrollTop + c.clientHeight / 3;
    let cur = 0;
    els.forEach((el, i) => {
      if (el.offsetTop * (zoom / 100) <= mid) cur = i;
    });
    setCurrentPage(cur);
  };
  const save = () => {
    if (!dirty) return;
    setDirty(false);
    toast({
      tone: 'success',
      title: 'Saved',
      message: DOC.name + ' · ' + DOC.size
    });
  };
  const openSearch = withReplace => setSearch(s => Object.assign({}, s, {
    open: true,
    showReplace: withReplace || s.showReplace
  }));

  // search
  const matches = [];
  const matchIndex = {};
  if (search.open && search.q) order.forEach(pi => DOC.pages[pi].blocks.forEach(b => {
    if (!b.text) return;
    window.findAllTr(textOf(b), search.q).forEach(([s]) => {
      matchIndex[b.id + ':' + s] = matches.length + 1;
      matches.push({
        b,
        s
      });
    });
  }));
  const current = Math.min(search.current, matches.length || 1);
  let notice;
  if (search.showReplace && search.r && matches.length) {
    for (const ch of search.r) {
      const n = matches.filter(m => m.b.missing && m.b.missing.includes(ch)).length;
      if (n) {
        notice = n + (n === 1 ? ' match uses' : ' matches use') + ' a font without ‘' + ch + '’. Ferman will use a similar font for ' + (n === 1 ? 'that character.' : 'those characters.');
        break;
      }
    }
  }
  const doReplace = all => {
    const targets = all ? matches : [matches[current - 1]];
    const next = Object.assign({}, blockState);
    let count = 0;
    targets.forEach(m => {
      if (!m) return;
      const cur = next[m.b.id] && next[m.b.id].text !== undefined ? next[m.b.id].text : m.b.text;
      const r = replaceTr(cur, search.q, search.r, all ? undefined : m.s);
      count += r.count;
      next[m.b.id] = Object.assign({}, next[m.b.id], {
        text: r.text
      });
    });
    if (!count) return;
    setBlockState(next);
    setDirty(true);
    if (all) toast({
      title: 'Replaced ' + count + (count === 1 ? ' match' : ' matches'),
      action: {
        label: 'Undo',
        onClick: () => setBlockState(blockState)
      }
    });
  };

  // redaction, signing, tasks
  const pendingRedactions = Object.values(redactions).filter(v => v === 'pending').length;
  const onRedact = id => setRedactions(r => {
    const n = Object.assign({}, r);
    if (n[id] === 'pending') delete n[id];else if (!n[id]) n[id] = 'pending';
    return n;
  });
  const applyRedactions = () => {
    const n = {};
    Object.keys(redactions).forEach(k => {
      n[k] = 'applied';
    });
    setRedactions(n);
    setRedactOpen(false);
    setDirty(true);
    toast({
      tone: 'success',
      title: pendingRedactions + (pendingRedactions === 1 ? ' redaction applied' : ' redactions applied'),
      message: 'Save to write them to the file.'
    });
  };
  const requiredFilled = [!!fields.name, DATE_RE.test(fields.date), !!fields.sig].filter(Boolean).length;
  const addSignature = () => {
    setFields(f => Object.assign({}, f, {
      sig: sigValue && sigValue.mode === 'type' && sigValue.text ? sigValue.text : 'A. Yılmaz'
    }));
    setSignOpen(false);
    setDirty(true);
    toast({
      tone: 'success',
      title: 'Signature added',
      message: 'Saved on this device for next time.'
    });
  };
  const startTask = kind => setTask({
    kind,
    state: 'running',
    value: 0
  });
  React.useEffect(() => {
    if (!task || task.state !== 'running') return undefined;
    const t = setInterval(() => setTask(x => x && x.state === 'running' ? x.value + 0.05 >= 1 ? Object.assign({}, x, {
      value: 1,
      state: 'done'
    }) : Object.assign({}, x, {
      value: x.value + 0.05
    }) : x), 260);
    return () => clearInterval(t);
  }, [task && task.state]);
  const rotateSelected = () => {
    const sel = organizeSel.length ? organizeSel : [order[currentPage]];
    setRotations(r => {
      const n = Object.assign({}, r);
      sel.forEach(pi => {
        n[pi] = ((n[pi] || 0) + 90) % 360;
      });
      return n;
    });
    setDirty(true);
  };
  const deleteSelected = () => {
    if (!organizeSel.length) return;
    if (organizeSel.length >= order.length) {
      toast({
        tone: 'warning',
        title: 'A PDF needs at least one page',
        message: 'Keep one page or close the file instead.'
      });
      return;
    }
    const prev = order;
    const n = organizeSel.length;
    setOrder(order.filter(pi => !organizeSel.includes(pi)));
    setOrganizeSel([]);
    toast({
      title: n + (n === 1 ? ' page deleted' : ' pages deleted'),
      action: {
        label: 'Undo',
        onClick: () => setOrderRaw(prev)
      }
    });
  };
  const openDoc = () => {
    setDocOpen(true);
    setModeRaw('edit');
    setTool('edit-text');
    setSelectedId(null);
    setBlockState({});
    setRedactions({});
    setDirty(false);
    setOrderRaw([0, 1, 2]);
    setRotations({});
  };

  // keyboard
  React.useEffect(() => {
    const h = e => {
      const mod = e.metaKey || e.ctrlKey;
      const k = e.key.toLowerCase();
      if (mod && k === 'k') {
        e.preventDefault();
        setPalette(p => !p);
      } else if (mod && k === 'f' && docOpen) {
        e.preventDefault();
        openSearch(e.altKey);
      } else if (mod && k === 's') {
        e.preventDefault();
        save();
      } else if (e.key === 'Escape' && !palette && !signOpen && !redactOpen) {
        if (search.open) setSearch(s => Object.assign({}, s, {
          open: false
        }));else if (!editingId) setSelectedId(null);
      }
    };
    window.addEventListener('keydown', h);
    return () => window.removeEventListener('keydown', h);
  });
  const runCommand = id => {
    setPalette(false);
    const modes = {
      'mode-view': 'view',
      'mode-edit': 'edit',
      'mode-comment': 'comment',
      'mode-sign': 'sign',
      'mode-organize': 'organize',
      'mode-convert': 'convert',
      'mode-protect': 'protect'
    };
    if (modes[id]) {
      if (!docOpen) openDoc();
      setMode(modes[id]);
      return;
    }
    if (id === 'find') openSearch(false);
    if (id === 'replace') {
      setMode('edit');
      openSearch(true);
    }
    if (id === 'ocr') {
      setMode('convert');
      startTask('ocr');
    }
    if (id === 'sign') {
      setMode('sign');
      setSignOpen(true);
    }
    if (id === 'redact') setMode('protect');
    if (id === 'theme') setTheme(t => t === 'dark' ? 'light' : 'dark');
    if (id === 'dim') setDim(d => !d);
    if (id === 'rtl') setRtl(r => !r);
    if (id === 'touch') setTouch(t => !t);
    if (id === 'save') save();
    if (id === 'close') setDocOpen(false);
    if (id === 'open') openDoc();
    if (id.indexOf('page-') === 0) goToPage(Number(id.slice(5)));
  };
  const groups = [{
    label: 'Suggested',
    items: [{
      id: 'replace',
      label: 'Find and replace',
      icon: 'replace',
      hint: 'Edit',
      shortcut: ['⌥', '⌘', 'F'],
      keywords: 'bul değiştir'
    }, {
      id: 'ocr',
      label: 'Recognize text (OCR)',
      icon: 'scan-text',
      hint: 'Convert',
      keywords: 'metin tanıma scan'
    }, {
      id: 'sign',
      label: 'Add signature',
      icon: 'signature',
      hint: 'Fill & Sign',
      keywords: 'imza'
    }, {
      id: 'redact',
      label: 'Redact text and images',
      icon: 'eye-off',
      hint: 'Protect',
      keywords: 'karart gizle'
    }]
  }, {
    label: 'Modes',
    items: [['view', 'View', 'book-open'], ['edit', 'Edit', 'file-pen-line'], ['comment', 'Comment', 'message-square'], ['sign', 'Fill & Sign', 'signature'], ['organize', 'Organize', 'layout-grid'], ['convert', 'Convert', 'refresh-cw'], ['protect', 'Protect', 'shield']].map(([id, l, ic]) => ({
      id: 'mode-' + id,
      label: 'Go to ' + l,
      icon: ic
    }))
  }, {
    label: 'Pages',
    items: order.map((pi, i) => ({
      id: 'page-' + i,
      label: 'Go to page ' + (i + 1),
      icon: 'file-text',
      hint: DOC.pages[pi].blocks[0].text ? DOC.pages[pi].blocks[0].text.slice(0, 32) : ''
    }))
  }, {
    label: 'Settings',
    items: [{
      id: 'theme',
      label: theme === 'dark' ? 'Use light theme' : 'Use dark theme',
      icon: theme === 'dark' ? 'sun' : 'moon',
      keywords: 'karanlık tema'
    }, {
      id: 'dim',
      label: dim ? 'Show pages at full brightness' : 'Dim pages',
      icon: 'eye'
    }, {
      id: 'rtl',
      label: rtl ? 'Use left-to-right layout' : 'Use right-to-left layout',
      icon: 'arrow-left-right',
      keywords: 'arabic rtl'
    }, {
      id: 'touch',
      label: touch ? 'Use compact density' : 'Use touch density',
      icon: 'smartphone'
    }]
  }, {
    label: 'File',
    items: [{
      id: 'save',
      label: 'Save',
      icon: 'save',
      shortcut: ['⌘', 'S']
    }, docOpen ? {
      id: 'close',
      label: 'Close document',
      icon: 'x',
      shortcut: ['⌘', 'W']
    } : {
      id: 'open',
      label: 'Open ' + DOC.name,
      icon: 'folder-open',
      shortcut: ['⌘', 'O']
    }]
  }];
  const ctx = {
    mode,
    selectedId: mode === 'edit' ? selectedId : null,
    editingId,
    clickPoint,
    blockState,
    showEdits,
    onSelect: id => {
      setSelectedId(id);
      setEditingId(null);
    },
    onEdit: (id, pt) => {
      setSelectedId(id);
      setClickPoint(pt);
      setEditingId(id);
    },
    onCommit: (id, text) => {
      setEditingId(null);
      const b = ALL_BLOCKS.find(x => x.id === id);
      if (text !== textOf(b)) {
        setBlockState(s => Object.assign({}, s, {
          [id]: Object.assign({}, s[id], {
            text
          })
        }));
        setDirty(true);
      }
    },
    onDirty: () => {
      if (!dirty) setDirty(true);
    },
    onBackground: () => {
      if (mode === 'edit') {
        setSelectedId(null);
        setEditingId(null);
      }
    },
    searchQ: search.open ? search.q : '',
    matchIndex,
    currentMatch: current,
    redactions,
    onRedact,
    noteOpen,
    onToggleNote: () => setNoteOpen(n => !n),
    replies,
    onReply: t => setReplies(r => r.concat([{
      author: 'Ayşe Yılmaz',
      time: 'Now',
      text: t
    }])),
    fields,
    onField: (k, v) => {
      setFields(f => Object.assign({}, f, {
        [k]: v
      }));
      setDirty(true);
    },
    onSign: () => setSignOpen(true)
  };
  const app = {
    mode,
    tool,
    setTool,
    annotColor,
    setAnnotColor,
    zoom,
    setZoom,
    dim,
    setDim,
    showEdits,
    setShowEdits,
    openSearch,
    openSign: () => setSignOpen(true),
    requiredFilled,
    fields,
    pendingRedactions,
    confirmRedact: () => setRedactOpen(true),
    startTask,
    cancelTask: () => {
      setTask(null);
      toast({
        title: 'Canceled',
        message: 'No changes were made to the file.'
      });
    },
    task,
    order,
    setOrder,
    rotations,
    organizeSel,
    setOrganizeSel,
    rotateSelected,
    deleteSelected,
    toast,
    sideTab,
    setSideTab,
    currentPage,
    goToPage,
    pageEdited,
    isBlockEdited,
    edited: dirty,
    selectedBlock: ALL_BLOCKS.find(b => b.id === selectedId),
    blockState,
    setBlockProps: (id, p) => {
      setBlockState(s => Object.assign({}, s, {
        [id]: Object.assign({}, s[id], {
          props: p ? Object.assign({}, (s[id] || {}).props, p) : {}
        })
      }));
      setDirty(true);
    },
    replies,
    toggleNote: () => setNoteOpen(n => !n)
  };
  return /*#__PURE__*/React.createElement("div", {
    className: "fm-root",
    "data-theme": theme,
    "data-page": dim ? 'dim' : undefined,
    dir: rtl ? 'rtl' : 'ltr',
    "data-density": touch ? 'touch' : undefined,
    style: {
      height: '100vh',
      display: 'flex',
      flexDirection: 'column',
      background: 'var(--surface-panel)',
      overflow: 'hidden'
    }
  }, /*#__PURE__*/React.createElement(TitleBar, {
    docOpen: docOpen,
    docName: DOC.name,
    edited: dirty,
    mode: mode,
    onMode: setMode,
    onPalette: () => setPalette(true),
    theme: theme,
    onTheme: () => setTheme(t => t === 'dark' ? 'light' : 'dark'),
    onSave: save,
    onClose: () => setDocOpen(false),
    sidebarOpen: sidebarOpen,
    onToggleSidebar: () => setSidebarOpen(o => !o)
  }), docOpen ? /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 'none',
      borderBottom: '1px solid var(--border-subtle)'
    }
  }, /*#__PURE__*/React.createElement(ToolRow, {
    mode: mode,
    app: app
  })) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      minHeight: 0
    }
  }, docOpen && sidebarOpen && mode !== 'organize' ? /*#__PURE__*/React.createElement(Sidebar, {
    app: app
  }) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      position: 'relative',
      display: 'flex',
      minWidth: 0
    }
  }, !docOpen ? /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      background: 'var(--surface-canvas)',
      padding: 24,
      display: 'grid',
      overflow: 'auto'
    }
  }, /*#__PURE__*/React.createElement(DropZone, {
    onOpen: openDoc,
    onCreate: () => {},
    recent: DOC.recent,
    onOpenRecent: openDoc,
    onFiles: openDoc
  })) : mode === 'organize' ? /*#__PURE__*/React.createElement(OrganizeGrid, {
    app: app
  }) : /*#__PURE__*/React.createElement("main", {
    ref: canvasRef,
    onScroll: onScroll,
    onClick: () => ctx.onBackground(),
    style: {
      flex: 1,
      overflow: 'auto',
      background: 'var(--surface-canvas)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      zoom: zoom / 100,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 24,
      padding: '28px 72px 64px',
      minWidth: 'min-content'
    }
  }, order.map((pi, i) => /*#__PURE__*/React.createElement("div", {
    key: pi,
    "data-page-pos": i
  }, /*#__PURE__*/React.createElement(Page, {
    page: DOC.pages[pi],
    index: i,
    total: order.length,
    ctx: ctx
  }))))), docOpen && search.open && mode !== 'organize' ? /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 12,
      insetInlineEnd: 20,
      width: 460,
      zIndex: 20
    }
  }, /*#__PURE__*/React.createElement(SearchReplaceBar, {
    autoFocus: true,
    query: search.q,
    replaceWith: search.r,
    showReplace: search.showReplace,
    current: matches.length ? current : 0,
    total: matches.length,
    matchCase: search.matchCase,
    wholeWord: search.wholeWord,
    regex: search.regex,
    notice: notice,
    onQueryChange: q => setSearch(s => Object.assign({}, s, {
      q,
      current: 1
    })),
    onReplaceChange: r => setSearch(s => Object.assign({}, s, {
      r
    })),
    onToggleReplace: () => setSearch(s => Object.assign({}, s, {
      showReplace: !s.showReplace
    })),
    onToggleOption: (k, v) => setSearch(s => Object.assign({}, s, {
      [k]: v
    })),
    onNext: () => setSearch(s => Object.assign({}, s, {
      current: current >= matches.length ? 1 : current + 1
    })),
    onPrev: () => setSearch(s => Object.assign({}, s, {
      current: current <= 1 ? matches.length : current - 1
    })),
    onReplace: () => doReplace(false),
    onReplaceAll: () => doReplace(true),
    onClose: () => setSearch(s => Object.assign({}, s, {
      open: false
    }))
  })) : null, task ? /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 16,
      insetInlineEnd: 20,
      zIndex: 20
    }
  }, /*#__PURE__*/React.createElement(TaskProgress, {
    icon: task.kind === 'ocr' ? 'scan-text' : 'file-output',
    state: task.state,
    value: task.value,
    title: task.state === 'done' ? task.kind === 'ocr' ? 'Text recognized' : 'Converted to Word' : task.kind === 'ocr' ? 'Recognizing text' : 'Converting to Word',
    detail: task.state === 'done' ? task.kind === 'ocr' ? order.length + ' pages are now searchable.' : 'Kira sözleşmesi.docx is in the same folder.' : 'Page ' + Math.min(order.length, Math.floor(task.value * order.length) + 1) + ' of ' + order.length + ' · a few seconds left',
    onCancel: app.cancelTask,
    onPause: () => setTask(t => Object.assign({}, t, {
      state: 'paused'
    })),
    onResume: () => setTask(t => Object.assign({}, t, {
      state: 'running'
    })),
    primaryAction: task.state === 'done' ? {
      label: task.kind === 'ocr' ? 'Done' : 'Show in folder',
      onClick: () => setTask(null)
    } : undefined
  })) : null), docOpen && mode !== 'view' ? /*#__PURE__*/React.createElement(PropertiesPanel, {
    app: app
  }) : null), docOpen ? /*#__PURE__*/React.createElement(StatusBar, {
    app: app
  }) : null, /*#__PURE__*/React.createElement("div", {
    className: "fm-toast-region"
  }, toasts.map(t => /*#__PURE__*/React.createElement(Toast, {
    key: t.id,
    tone: t.tone,
    title: t.title,
    message: t.message,
    action: t.action ? {
      label: t.action.label,
      onClick: () => {
        t.action.onClick();
        setToasts(x => x.filter(y => y.id !== t.id));
      }
    } : undefined,
    onClose: () => setToasts(x => x.filter(y => y.id !== t.id))
  }))), palette ? /*#__PURE__*/React.createElement(CommandPalette, {
    groups: groups,
    onSelect: runCommand,
    onClose: () => setPalette(false)
  }) : null, /*#__PURE__*/React.createElement(Dialog, {
    open: signOpen,
    title: "Add your signature",
    description: "Draw, type or import an image. Ferman keeps it only on this device.",
    onClose: () => setSignOpen(false),
    actions: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
      onClick: () => setSignOpen(false)
    }, "Cancel"), /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      onClick: addSignature
    }, "Add signature"))
  }, /*#__PURE__*/React.createElement(SignaturePad, {
    defaultMode: "type",
    name: fields.name,
    onChange: setSigValue
  })), /*#__PURE__*/React.createElement(Dialog, {
    open: redactOpen,
    tone: "danger",
    size: "sm",
    icon: "eye-off",
    title: 'Apply ' + pendingRedactions + (pendingRedactions === 1 ? ' redaction?' : ' redactions?'),
    description: "The marked text will be permanently removed from this file. You can\u2019t undo this after saving.",
    onClose: () => setRedactOpen(false),
    actions: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
      onClick: () => setRedactOpen(false),
      "data-autofocus": true
    }, "Cancel"), /*#__PURE__*/React.createElement(Button, {
      variant: "danger",
      onClick: applyRedactions
    }, "Apply redactions"))
  }));
}
ReactDOM.createRoot(document.getElementById('root')).render(/*#__PURE__*/React.createElement(App, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/App.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/Chrome.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/* Title bar (window chrome + mode tabs) and the mode-specific tool row. */
const DS = window.FermanDesignSystem_278323;
function TitleBar({
  docOpen,
  docName,
  edited,
  mode,
  onMode,
  onPalette,
  theme,
  onTheme,
  onSave,
  onClose,
  sidebarOpen,
  onToggleSidebar
}) {
  const {
    IconButton,
    Icon,
    Badge,
    ModeTabs,
    Button,
    Kbd
  } = DS;
  return /*#__PURE__*/React.createElement("header", {
    style: {
      height: 'var(--titlebar-h)',
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      padding: '0 8px 0 14px',
      background: 'var(--surface-panel)',
      borderBottom: '1px solid var(--border-subtle)',
      flex: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      marginInlineEnd: 10
    },
    "aria-hidden": "true"
  }, ['#FF5F57', '#FEBC2E', '#28C840'].map(c => /*#__PURE__*/React.createElement("span", {
    key: c,
    style: {
      width: 12,
      height: 12,
      borderRadius: '50%',
      background: c,
      boxShadow: 'inset 0 0 0 0.5px rgba(0,0,0,.25)'
    }
  }))), docOpen ? /*#__PURE__*/React.createElement(IconButton, {
    icon: "panel-left",
    label: sidebarOpen ? 'Hide pages' : 'Show pages',
    size: "sm",
    active: sidebarOpen,
    onClick: onToggleSidebar
  }) : null, docOpen ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      minWidth: 0,
      flex: '0 1 auto'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "file-text",
    size: 14,
    color: "var(--icon-secondary)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-body-strong)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      maxWidth: 200
    }
  }, docName), edited ? /*#__PURE__*/React.createElement(Badge, {
    tone: "edited",
    dot: true
  }, "Edited") : null, /*#__PURE__*/React.createElement(IconButton, {
    icon: "x",
    label: "Close document",
    size: "xs",
    shortcut: ['⌘', 'W'],
    onClick: onClose
  })) : /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-wordmark)',
      color: 'var(--text-primary)'
    }
  }, "Ferman"), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      justifyContent: 'center',
      minWidth: 0
    }
  }, docOpen ? /*#__PURE__*/React.createElement(ModeTabs, {
    value: mode,
    onChange: onMode
  }) : null), /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    size: "sm",
    icon: "search",
    onClick: onPalette
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      gap: 8,
      alignItems: 'center'
    }
  }, "Search", /*#__PURE__*/React.createElement(Kbd, {
    keys: ['⌘', 'K'],
    tone: "plain"
  }))), /*#__PURE__*/React.createElement(IconButton, {
    icon: theme === 'dark' ? 'sun' : 'moon',
    label: theme === 'dark' ? 'Light theme' : 'Dark theme',
    size: "sm",
    onClick: onTheme
  }), docOpen ? /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "sm",
    icon: "save",
    disabled: !edited,
    onClick: onSave
  }, "Save") : null);
}
function ToolRow({
  mode,
  app
}) {
  const {
    Toolbar,
    ToolbarSeparator,
    ToolbarSpacer,
    ToolButton,
    IconButton,
    Select,
    SegmentedControl,
    Switch,
    Button,
    AnnotationTools
  } = DS;
  const t = app.tool;
  const tb = (id, icon, label, extra) => /*#__PURE__*/React.createElement(ToolButton, _extends({
    key: id,
    icon: icon,
    label: label,
    active: t === id,
    onClick: () => app.setTool(id)
  }, extra || {}));
  if (mode === 'comment') return /*#__PURE__*/React.createElement(AnnotationTools, {
    tool: t,
    onToolChange: app.setTool,
    color: app.annotColor,
    onColorChange: app.setAnnotColor,
    showLabels: false
  });
  let content = null;
  if (mode === 'view') content = /*#__PURE__*/React.createElement(React.Fragment, null, tb('select', 'mouse-pointer-2', 'Select'), tb('hand', 'hand', 'Hand'), /*#__PURE__*/React.createElement(ToolbarSeparator, null), /*#__PURE__*/React.createElement(IconButton, {
    icon: "zoom-out",
    label: "Zoom out",
    shortcut: ['⌘', '−'],
    onClick: () => app.setZoom(Math.max(50, app.zoom - 10))
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 96
    }
  }, /*#__PURE__*/React.createElement(Select, {
    size: "sm",
    value: String(app.zoom),
    onChange: v => app.setZoom(Number(v)),
    options: ['50', '75', '90', '100', '110', '125', '150', '200'].map(z => ({
      value: z,
      label: z + '%'
    })).concat(String(app.zoom).match(/^(50|75|90|100|110|125|150|200)$/) ? [] : [{
      value: String(app.zoom),
      label: app.zoom + '%'
    }])
  })), /*#__PURE__*/React.createElement(IconButton, {
    icon: "zoom-in",
    label: "Zoom in",
    shortcut: ['⌘', '+'],
    onClick: () => app.setZoom(Math.min(400, app.zoom + 10))
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "maximize",
    label: "Fit width",
    onClick: () => app.setZoom(110)
  }), /*#__PURE__*/React.createElement(ToolbarSeparator, null), /*#__PURE__*/React.createElement(SegmentedControl, {
    label: "Page layout",
    defaultValue: "scroll",
    options: [{
      value: 'one',
      icon: 'file-text',
      title: 'Single page'
    }, {
      value: 'two',
      icon: 'columns-2',
      title: 'Two pages'
    }, {
      value: 'scroll',
      icon: 'arrow-up-down',
      title: 'Continuous'
    }]
  }), /*#__PURE__*/React.createElement(ToolbarSpacer, null), /*#__PURE__*/React.createElement(Switch, {
    label: "Dim pages",
    checked: app.dim,
    onChange: app.setDim
  }));
  if (mode === 'edit') content = /*#__PURE__*/React.createElement(React.Fragment, null, tb('edit-text', 'text-cursor', 'Edit text', {
    shortcut: ['T']
  }), tb('add-text', 'type', 'Add text'), tb('add-image', 'image', 'Add image'), tb('link', 'link', 'Link'), /*#__PURE__*/React.createElement(ToolbarSeparator, null), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "replace",
    label: "Find & replace",
    onClick: () => app.openSearch(true)
  }), /*#__PURE__*/React.createElement(ToolbarSeparator, null), /*#__PURE__*/React.createElement(IconButton, {
    icon: "undo-2",
    label: "Undo",
    shortcut: ['⌘', 'Z']
  }), /*#__PURE__*/React.createElement(IconButton, {
    icon: "redo-2",
    label: "Redo",
    shortcut: ['⇧', '⌘', 'Z']
  }), /*#__PURE__*/React.createElement(ToolbarSpacer, null), /*#__PURE__*/React.createElement(Switch, {
    label: "Mark edited text",
    checked: app.showEdits,
    onChange: app.setShowEdits
  }));
  if (mode === 'sign') content = /*#__PURE__*/React.createElement(React.Fragment, null, tb('fill', 'text-cursor-input', 'Fill fields'), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "signature",
    label: "Add signature",
    onClick: app.openSign
  }), tb('initials', 'pen-line', 'Initials'), tb('date', 'calendar', 'Date'), tb('check', 'square-check', 'Checkmark'), /*#__PURE__*/React.createElement(ToolbarSpacer, null), /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-caption)',
      color: 'var(--text-secondary)',
      fontVariantNumeric: 'tabular-nums',
      paddingInline: 8
    }
  }, app.requiredFilled, " of 3 required fields filled"));
  if (mode === 'organize') content = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(ToolButton, {
    icon: "file-plus-2",
    label: "Insert pages"
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "rotate-cw",
    label: "Rotate",
    onClick: app.rotateSelected
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "file-output",
    label: "Extract"
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "split",
    label: "Split"
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "merge",
    label: "Merge files"
  }), /*#__PURE__*/React.createElement(ToolbarSeparator, null), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "trash-2",
    label: "Delete",
    onClick: app.deleteSelected
  }), /*#__PURE__*/React.createElement(ToolbarSpacer, null), /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-caption)',
      color: 'var(--text-tertiary)',
      paddingInline: 8
    }
  }, "Drag pages to reorder. Right-click for more."));
  if (mode === 'convert') content = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(ToolButton, {
    icon: "file-type",
    label: "To Word",
    onClick: () => app.startTask('convert')
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "file-spreadsheet",
    label: "To Excel",
    onClick: () => app.startTask('convert')
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "file-image",
    label: "To images",
    onClick: () => app.startTask('convert')
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "file-check-2",
    label: "PDF/A"
  }), /*#__PURE__*/React.createElement(ToolbarSeparator, null), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "scan-text",
    label: "Recognize text (OCR)",
    onClick: () => app.startTask('ocr')
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "minimize-2",
    label: "Compress"
  }));
  if (mode === 'protect') content = /*#__PURE__*/React.createElement(React.Fragment, null, tb('redact', 'eye-off', 'Redact'), tb('find-redact', 'file-search', 'Find & redact'), /*#__PURE__*/React.createElement(ToolbarSeparator, null), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "key-round",
    label: "Password"
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "lock",
    label: "Permissions"
  }), /*#__PURE__*/React.createElement(ToolButton, {
    icon: "eraser",
    label: "Remove hidden data"
  }), /*#__PURE__*/React.createElement(ToolbarSpacer, null), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "danger",
    icon: "eye-off",
    disabled: !app.pendingRedactions,
    onClick: app.confirmRedact
  }, "Apply redactions", app.pendingRedactions ? ' (' + app.pendingRedactions + ')' : ''));
  return /*#__PURE__*/React.createElement(Toolbar, {
    label: "Tools"
  }, content);
}
Object.assign(window, {
  TitleBar,
  ToolRow
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/Chrome.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/OrganizeGrid.jsx
try { (() => {
/* Organize mode: draggable page grid with context menu. */
const DSO = window.FermanDesignSystem_278323;
function OrganizeGrid({
  app
}) {
  const {
    PageThumbnail,
    Menu
  } = DSO;
  const [drag, setDrag] = React.useState(null);
  const [menu, setMenu] = React.useState(null);
  React.useEffect(() => {
    if (!menu) return undefined;
    const close = () => setMenu(null);
    window.addEventListener('mousedown', close);
    return () => window.removeEventListener('mousedown', close);
  }, [menu]);
  const onDrop = () => {
    if (!drag || drag.over == null) {
      setDrag(null);
      return;
    }
    const order = app.order.slice();
    const [moved] = order.splice(drag.from, 1);
    let to = drag.over + (drag.side === 'after' ? 1 : 0);
    if (drag.from < to) to -= 1;
    order.splice(to, 0, moved);
    app.setOrder(order);
    setDrag(null);
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'auto',
      background: 'var(--surface-canvas)',
      padding: 32
    },
    onClick: () => app.setOrganizeSel([])
  }, /*#__PURE__*/React.createElement("div", {
    role: "listbox",
    "aria-label": "Pages",
    "aria-multiselectable": "true",
    style: {
      display: 'flex',
      flexWrap: 'wrap',
      gap: 20,
      alignContent: 'flex-start'
    }
  }, app.order.map((pi, i) => {
    const isDragged = drag && drag.from === i;
    const ind = drag && drag.over === i && !isDragged ? drag.side : undefined;
    return /*#__PURE__*/React.createElement("div", {
      key: pi,
      draggable: true,
      onClick: e => e.stopPropagation(),
      onDragStart: e => {
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', String(i));
        setTimeout(() => setDrag({
          from: i,
          over: null
        }), 0);
      },
      onDragOver: e => {
        e.preventDefault();
        const r = e.currentTarget.getBoundingClientRect();
        const rtl = getComputedStyle(e.currentTarget).direction === 'rtl';
        const after = e.clientX > r.left + r.width / 2 !== rtl;
        setDrag(d => d && Object.assign({}, d, {
          over: i,
          side: after ? 'after' : 'before'
        }));
      },
      onDrop: e => {
        e.preventDefault();
        onDrop();
      },
      onDragEnd: () => setDrag(null),
      onContextMenu: e => {
        e.preventDefault();
        app.setOrganizeSel([pi]);
        setMenu({
          x: e.clientX,
          y: e.clientY,
          pi
        });
      }
    }, /*#__PURE__*/React.createElement(PageThumbnail, {
      page: i + 1,
      width: 150,
      orientation: "horizontal",
      rotation: app.rotations[pi] || 0,
      selected: app.organizeSel.includes(pi),
      state: isDragged ? 'placeholder' : 'idle',
      dropIndicator: ind,
      marker: app.pageEdited(pi) ? 'edited' : undefined,
      onClick: e => {
        const s = app.organizeSel;
        app.setOrganizeSel(e.metaKey || e.shiftKey ? s.includes(pi) ? s.filter(x => x !== pi) : s.concat(pi) : [pi]);
      }
    }));
  })), menu ? /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'fixed',
      left: menu.x,
      top: menu.y,
      zIndex: 'var(--z-popover)'
    },
    onMouseDown: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement(Menu, {
    label: "Page",
    autoFocus: true,
    onClose: () => setMenu(null),
    onSelect: id => {
      setMenu(null);
      if (id === 'rotate') app.rotateSelected();
      if (id === 'delete') app.deleteSelected();
      if (id === 'dup') app.toast({
        title: 'Page duplicated'
      });
    },
    items: [{
      id: 'rotate',
      label: 'Rotate right',
      icon: 'rotate-cw',
      shortcut: ['⌘', 'R']
    }, {
      id: 'dup',
      label: 'Duplicate',
      icon: 'copy',
      shortcut: ['⌘', 'D']
    }, {
      id: 'extract',
      label: 'Extract as new PDF…',
      icon: 'file-output'
    }, {
      separator: true
    }, {
      id: 'delete',
      label: 'Delete page',
      icon: 'trash-2',
      shortcut: ['⌫'],
      danger: true
    }]
  })) : null);
}
Object.assign(window, {
  OrganizeGrid
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/OrganizeGrid.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/Page.jsx
try { (() => {
/* Page canvas: renders PDF pages with editable text blocks, marks, annotations and form fields. */
const {
  TextEditBox,
  PageMark,
  Highlight,
  StickyNote,
  PdfFormField
} = window.FermanDesignSystem_278323;
function findAllTr(text, q) {
  if (!q) return [];
  const t = text.toLocaleLowerCase('tr'),
    s = q.toLocaleLowerCase('tr');
  const out = [];
  let i = t.indexOf(s);
  while (i >= 0 && s.length) {
    out.push([i, i + s.length]);
    i = t.indexOf(s, i + s.length);
  }
  return out;
}
function changedRange(a, b) {
  if (a === b) return null;
  let p = 0;
  while (p < a.length && p < b.length && a[p] === b[p]) p++;
  let s = 0;
  while (s < a.length - p && s < b.length - p && a[a.length - 1 - s] === b[b.length - 1 - s]) s++;
  return b.length - s > p ? [p, b.length - s] : null;
}
function renderDecorated(text, ranges) {
  const cuts = new Set([0, text.length]);
  ranges.forEach(r => {
    cuts.add(Math.max(0, r.s));
    cuts.add(Math.min(text.length, r.e));
  });
  const pts = Array.from(cuts).sort((x, y) => x - y);
  const out = [];
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i],
      b = pts[i + 1];
    let node = text.slice(a, b);
    const cover = ranges.filter(r => r.s <= a && r.e >= b);
    for (let j = cover.length - 1; j >= 0; j--) node = cover[j].wrap(node, a + '-' + j);
    out.push(/*#__PURE__*/React.createElement(React.Fragment, {
      key: a
    }, node));
  }
  return out;
}
const KIND_STYLE = {
  title: {
    margin: '0 0 6px',
    letterSpacing: '0.06em'
  },
  meta: {
    margin: '0 0 28px'
  },
  h: {
    margin: '22px 0 6px'
  },
  p: {
    margin: '0 0 8px',
    textAlign: 'justify'
  }
};
function blockStyle(b, props) {
  const p = Object.assign({}, b, props || {});
  return Object.assign({}, KIND_STYLE[b.kind] || {}, {
    fontFamily: 'var(--font-doc-sample)',
    fontSize: (p.size * 1.333).toFixed(1) + 'px',
    lineHeight: 1.5,
    fontWeight: p.bold ? 600 : p.weight || 400,
    fontStyle: p.italic ? 'italic' : 'normal',
    textDecoration: p.underline ? 'underline' : 'none',
    textAlign: p.align || (KIND_STYLE[b.kind] || {}).textAlign || 'start',
    color: p.color || '#1F1D1A'
  });
}
function PageBlock({
  b,
  ctx
}) {
  const st = ctx.blockState[b.id] || {};
  const text = st.text !== undefined ? st.text : b.text;
  const editRef = React.useRef(null);
  const selected = ctx.selectedId === b.id;
  const editing = ctx.editingId === b.id;
  React.useEffect(() => {
    if (!editing || !editRef.current) return;
    const el = editRef.current;
    el.focus();
    const pt = ctx.clickPoint;
    const sel = window.getSelection();
    let r = pt && document.caretRangeFromPoint ? document.caretRangeFromPoint(pt[0], pt[1]) : null;
    if (!r || !el.contains(r.startContainer)) {
      r = document.createRange();
      r.selectNodeContents(el);
      r.collapse(false);
    }
    sel.removeAllRanges();
    sel.addRange(r);
  }, [editing]);
  const ranges = [];
  if (b.redactable) {
    const i = text.indexOf(b.redactable);
    if (i >= 0) {
      const rs = ctx.redactions[b.id];
      if (rs) ranges.push({
        s: i,
        e: i + b.redactable.length,
        wrap: (n, k) => /*#__PURE__*/React.createElement(PageMark, {
          key: k,
          kind: rs === 'applied' ? 'redact-applied' : 'redact-pending'
        }, n)
      });else if (ctx.mode === 'protect') ranges.push({
        s: i,
        e: i + b.redactable.length,
        wrap: (n, k) => /*#__PURE__*/React.createElement("span", {
          key: k,
          className: "kit-redactable",
          onClick: e => {
            e.stopPropagation();
            ctx.onRedact(b.id);
          },
          title: "Click to mark for redaction"
        }, n)
      });
    }
  }
  if (b.highlight) {
    const i = text.indexOf(b.highlight);
    if (i >= 0) ranges.push({
      s: i,
      e: i + b.highlight.length,
      wrap: (n, k) => /*#__PURE__*/React.createElement(Highlight, {
        key: k
      }, n)
    });
  }
  findAllTr(text, ctx.searchQ).forEach(([s, e]) => {
    const idx = ctx.matchIndex[b.id + ':' + s];
    ranges.push({
      s,
      e,
      wrap: (n, k) => /*#__PURE__*/React.createElement(PageMark, {
        key: k,
        kind: idx === ctx.currentMatch ? 'search-current' : 'search'
      }, n)
    });
  });
  const ch = ctx.showEdits ? changedRange(b.text, text) : null;
  if (ch) ranges.push({
    s: ch[0],
    e: ch[1],
    wrap: (n, k) => /*#__PURE__*/React.createElement(PageMark, {
      key: k,
      kind: "edited"
    }, n)
  });
  if (b.missing && ctx.mode === 'edit') b.missing.forEach(c => {
    let i = text.indexOf(c);
    while (i >= 0) {
      ranges.push({
        s: i,
        e: i + 1,
        wrap: (n, k) => /*#__PURE__*/React.createElement(PageMark, {
          key: k,
          kind: "missing-glyph",
          char: c
        }, n)
      });
      i = text.indexOf(c, i + 1);
    }
  });
  const style = blockStyle(b, st.props);
  const content = editing ? /*#__PURE__*/React.createElement("span", {
    key: 'edit-' + b.id,
    ref: editRef,
    contentEditable: true,
    suppressContentEditableWarning: true,
    spellCheck: false,
    style: {
      outline: 'none',
      display: 'block'
    },
    onBlur: e => ctx.onCommit(b.id, e.currentTarget.textContent),
    onInput: () => ctx.onDirty(b.id),
    onKeyDown: e => {
      if (e.key === 'Escape') {
        e.preventDefault();
        e.currentTarget.blur();
      }
    }
  }, text) : /*#__PURE__*/React.createElement("span", {
    key: 'view-' + b.id
  }, renderDecorated(text, ranges));
  const note = b.note ? /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: -2,
      insetInlineEnd: -64,
      zIndex: 3
    },
    onClick: e => e.stopPropagation()
  }, ctx.noteOpen ? /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 0,
      insetInlineEnd: 0
    }
  }, /*#__PURE__*/React.createElement(StickyNote, {
    author: "Mert Kaya",
    time: "14:32",
    text: "Bu madde 2025 tarihli ekle \xE7eli\u015Fiyor. \xD6deme g\xFCn\xFC ekte ay\u0131n onu olarak ge\xE7iyor.",
    replies: ctx.replies,
    onReply: ctx.onReply,
    onToggle: ctx.onToggleNote
  })) : /*#__PURE__*/React.createElement(StickyNote, {
    collapsed: true,
    author: "Mert Kaya",
    onToggle: ctx.onToggleNote
  })) : null;
  if (ctx.mode === 'edit') {
    const font = st.props && st.props.font || b.font;
    const missing = b.missing && b.missing.length;
    const meta = font + ' · ' + (st.props && st.props.size || b.size) + ' pt';
    return /*#__PURE__*/React.createElement("div", {
      style: Object.assign({
        position: 'relative'
      }, {
        margin: style.margin
      })
    }, /*#__PURE__*/React.createElement(TextEditBox, {
      state: editing ? 'editing' : selected ? 'selected' : 'idle',
      meta: meta,
      metaWarning: !!missing,
      style: Object.assign({}, style, {
        margin: '-4px -5px'
      }),
      onClick: e => {
        e.stopPropagation();
        if (selected && !editing) ctx.onEdit(b.id, [e.clientX, e.clientY]);else if (!selected) ctx.onSelect(b.id);
      },
      onDoubleClick: e => {
        e.stopPropagation();
        ctx.onEdit(b.id, [e.clientX, e.clientY]);
      }
    }, content), note);
  }
  return /*#__PURE__*/React.createElement("div", {
    style: Object.assign({
      position: 'relative'
    }, style)
  }, content, note);
}
function SignatureBlock({
  ctx
}) {
  const f = ctx.fields;
  const live = ctx.mode === 'sign';
  const lab = {
    font: '600 11px/1 var(--font-ui)',
    letterSpacing: '0.08em',
    color: '#57534C',
    marginBottom: 12
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '1fr 1fr',
      gap: 48,
      marginTop: 56
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gap: 12,
      alignContent: 'start'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: lab
  }, "K\u0130RAYA VEREN"), /*#__PURE__*/React.createElement(PdfFormField, {
    label: "Ad Soyad",
    value: "Mert Kaya",
    state: live ? undefined : 'readonly',
    width: 240
  }), /*#__PURE__*/React.createElement(PdfFormField, {
    type: "date",
    label: "Tarih",
    value: "13.10.2026",
    state: live ? undefined : 'readonly',
    width: 140
  }), /*#__PURE__*/React.createElement(PdfFormField, {
    type: "signature",
    label: "\u0130mza",
    signedAs: "M. Kaya",
    width: 240
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gap: 12,
      alignContent: 'start'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: lab
  }, "K\u0130RACI"), /*#__PURE__*/React.createElement(PdfFormField, {
    label: "Ad Soyad",
    value: f.name,
    required: true,
    onChange: live ? v => ctx.onField('name', v) : undefined,
    state: live ? undefined : f.name ? 'readonly' : 'empty',
    width: 240
  }), /*#__PURE__*/React.createElement(PdfFormField, {
    type: "date",
    label: "Tarih",
    placeholder: "GG.AA.YYYY",
    value: f.date,
    required: true,
    onChange: live ? v => ctx.onField('date', v) : undefined,
    error: f.date && !/^\d{2}\.\d{2}\.\d{4}$/.test(f.date) ? 'Enter a date like 14.10.2026.' : undefined,
    width: 140
  }), /*#__PURE__*/React.createElement(PdfFormField, {
    type: "signature",
    label: "\u0130mza",
    required: true,
    signedAs: f.sig,
    width: 240,
    onClick: live ? ctx.onSign : undefined
  })));
}
function Page({
  page,
  index,
  total,
  ctx
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "kit-page",
    "data-page": index,
    dir: "ltr",
    onClick: ctx.onBackground,
    style: {
      position: 'relative',
      width: 794,
      minHeight: 1123,
      padding: '88px 96px 96px',
      boxSizing: 'border-box',
      background: 'var(--page-bg)',
      boxShadow: 'var(--shadow-page)',
      filter: 'var(--page-filter)',
      color: '#1F1D1A',
      flex: 'none'
    }
  }, page.blocks.map(b => b.kind === 'signatures' ? /*#__PURE__*/React.createElement(SignatureBlock, {
    key: b.id,
    ctx: ctx
  }) : /*#__PURE__*/React.createElement(PageBlock, {
    key: b.id,
    b: b,
    ctx: ctx
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 44,
      left: 0,
      right: 0,
      textAlign: 'center',
      font: '400 12px/1 var(--font-doc-sample)',
      color: '#8A857C',
      fontVariantNumeric: 'tabular-nums'
    }
  }, index + 1, " / ", total));
}
Object.assign(window, {
  Page,
  findAllTr
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/Page.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/Panels.jsx
try { (() => {
/* Left sidebar (pages / outline), right properties panel, bottom status bar. */
const DSP = window.FermanDesignSystem_278323;
function Sidebar({
  app
}) {
  const {
    SegmentedControl,
    PageThumbnail,
    Icon
  } = DSP;
  return /*#__PURE__*/React.createElement("aside", {
    style: {
      width: 'var(--sidebar-w)',
      flex: 'none',
      display: 'flex',
      flexDirection: 'column',
      background: 'var(--surface-panel)',
      borderInlineEnd: '1px solid var(--border-subtle)',
      minHeight: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 8,
      borderBottom: '1px solid var(--border-subtle)'
    }
  }, /*#__PURE__*/React.createElement(SegmentedControl, {
    fullWidth: true,
    label: "Sidebar",
    value: app.sideTab,
    onChange: app.setSideTab,
    options: [{
      value: 'pages',
      label: 'Pages'
    }, {
      value: 'outline',
      label: 'Outline'
    }]
  })), app.sideTab === 'pages' ? /*#__PURE__*/React.createElement("div", {
    role: "listbox",
    "aria-label": "Pages",
    style: {
      flex: 1,
      overflow: 'auto',
      display: 'grid',
      justifyContent: 'center',
      alignContent: 'start',
      gap: 6,
      padding: '12px 0'
    }
  }, app.order.map((pi, i) => /*#__PURE__*/React.createElement(PageThumbnail, {
    key: pi,
    page: i + 1,
    width: 104,
    selected: app.currentPage === i,
    rotation: app.rotations[pi] || 0,
    marker: app.pageEdited(pi) ? 'edited' : pi === 0 ? 'comment' : undefined,
    onClick: () => app.goToPage(i)
  }))) : /*#__PURE__*/React.createElement("nav", {
    "aria-label": "Outline",
    style: {
      flex: 1,
      overflow: 'auto',
      padding: '6px'
    }
  }, window.FERMAN_DOC.outline.map(o => /*#__PURE__*/React.createElement("button", {
    key: o.label,
    type: "button",
    onClick: () => app.goToPage(app.order.indexOf(o.page)),
    className: "kit-outline"
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "bookmark",
    size: 14,
    color: "var(--icon-secondary)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      minWidth: 0,
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, o.label), /*#__PURE__*/React.createElement("span", {
    style: {
      color: 'var(--text-tertiary)',
      fontVariantNumeric: 'tabular-nums'
    }
  }, app.order.indexOf(o.page) + 1)))));
}
function PanelHeader({
  title,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 8,
      height: 40,
      padding: '0 12px',
      borderBottom: '1px solid var(--border-subtle)',
      font: 'var(--type-panel-title)',
      flex: 'none'
    }
  }, /*#__PURE__*/React.createElement("span", null, title), children);
}
function Row({
  label,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: '84px minmax(0,1fr)',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-caption)',
      color: 'var(--text-secondary)'
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      minWidth: 0
    }
  }, children));
}
function PropertiesPanel({
  app
}) {
  const {
    PanelSection,
    FontPicker,
    NumberStepper,
    ColorPicker,
    SegmentedControl,
    IconButton,
    Badge,
    Banner,
    Button,
    Radio,
    Checkbox,
    TextField,
    Switch,
    Icon
  } = DSP;
  const doc = window.FERMAN_DOC;
  const b = app.selectedBlock;
  let body = null,
    title = 'Document';
  if (app.mode === 'edit' && b) {
    const p = Object.assign({}, b, (app.blockState[b.id] || {}).props || {});
    const missing = b.missing && b.missing.length && p.font === b.font;
    title = 'Text block';
    const fonts = doc.fonts.map(f => f.name === 'Garamond Premier Pro' ? Object.assign({}, f, {
      available: true
    }) : f);
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(PanelSection, {
      title: "Text",
      actions: /*#__PURE__*/React.createElement(IconButton, {
        icon: "rotate-ccw",
        label: "Reset text style",
        size: "xs",
        onClick: () => app.setBlockProps(b.id, null)
      })
    }, /*#__PURE__*/React.createElement(FontPicker, {
      value: p.font,
      fonts: fonts,
      onChange: v => app.setBlockProps(b.id, {
        font: v
      }),
      warning: missing ? 'This font has no ‘ğ’. Ferman will use a similar font for this character.' : undefined
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 8
      }
    }, /*#__PURE__*/React.createElement(NumberStepper, {
      value: p.size,
      step: 0.5,
      precision: 1,
      min: 4,
      max: 96,
      unit: "pt",
      width: 92,
      onChange: v => app.setBlockProps(b.id, {
        size: v
      })
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        minWidth: 0
      }
    }, /*#__PURE__*/React.createElement(ColorPicker, {
      value: p.color || '#1F1D1A',
      documentColors: ['#1F1D1A', '#57534C', '#2A4DAF'],
      onChange: v => app.setBlockProps(b.id, {
        color: v
      })
    }))), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        justifyContent: 'space-between',
        gap: 8
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 2
      }
    }, /*#__PURE__*/React.createElement(IconButton, {
      icon: "bold",
      label: "Bold",
      size: "sm",
      shortcut: ['⌘', 'B'],
      active: !!p.bold || p.weight === 600,
      onClick: () => app.setBlockProps(b.id, {
        bold: !(p.bold || p.weight === 600),
        weight: 400
      })
    }), /*#__PURE__*/React.createElement(IconButton, {
      icon: "italic",
      label: "Italic",
      size: "sm",
      shortcut: ['⌘', 'I'],
      active: !!p.italic,
      onClick: () => app.setBlockProps(b.id, {
        italic: !p.italic
      })
    }), /*#__PURE__*/React.createElement(IconButton, {
      icon: "underline",
      label: "Underline",
      size: "sm",
      shortcut: ['⌘', 'U'],
      active: !!p.underline,
      onClick: () => app.setBlockProps(b.id, {
        underline: !p.underline
      })
    })), /*#__PURE__*/React.createElement(SegmentedControl, {
      label: "Alignment",
      value: p.align || (b.kind === 'p' ? 'justify' : 'left'),
      onChange: v => app.setBlockProps(b.id, {
        align: v
      }),
      options: [{
        value: 'left',
        icon: 'align-left',
        title: 'Align left'
      }, {
        value: 'center',
        icon: 'align-center',
        title: 'Center'
      }, {
        value: 'right',
        icon: 'align-right',
        title: 'Align right'
      }, {
        value: 'justify',
        icon: 'align-justify',
        title: 'Justify'
      }]
    })), missing ? /*#__PURE__*/React.createElement(Banner, {
      tone: "warning"
    }, "Typing \u2018\u011F\u2019 here uses a similar font for that character. To keep one font, pick an installed font with full Turkish support.") : null), /*#__PURE__*/React.createElement(PanelSection, {
      title: "Paragraph"
    }, /*#__PURE__*/React.createElement(Row, {
      label: "Line spacing"
    }, /*#__PURE__*/React.createElement(NumberStepper, {
      defaultValue: 1.5,
      step: 0.05,
      precision: 2,
      min: 0.8,
      max: 3,
      width: 92
    })), /*#__PURE__*/React.createElement(Row, {
      label: "Space after"
    }, /*#__PURE__*/React.createElement(NumberStepper, {
      defaultValue: 6,
      unit: "pt",
      min: 0,
      max: 72,
      width: 92
    }))), /*#__PURE__*/React.createElement(PanelSection, {
      title: "Position",
      defaultOpen: false
    }));
  } else if (app.mode === 'comment') {
    title = 'Comments';
    body = /*#__PURE__*/React.createElement("div", {
      style: {
        padding: 12,
        display: 'grid',
        gap: 10
      }
    }, /*#__PURE__*/React.createElement("button", {
      type: "button",
      className: "kit-card",
      onClick: app.toggleNote
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        display: 'flex',
        justifyContent: 'space-between',
        font: 'var(--type-caption)',
        color: 'var(--text-tertiary)'
      }
    }, /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("span", {
      className: "kit-dot",
      style: {
        background: 'var(--annot-yellow)'
      }
    }), "Note \xB7 Page 1"), /*#__PURE__*/React.createElement("span", {
      className: "fm-num"
    }, "14:32")), /*#__PURE__*/React.createElement("b", {
      style: {
        font: 'var(--type-body-strong)'
      }
    }, "Mert Kaya"), /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-body)'
      }
    }, "Bu madde 2025 tarihli ekle \xE7eli\u015Fiyor."), /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-caption)',
        color: 'var(--text-tertiary)'
      }
    }, app.replies.length ? app.replies.length + ' reply' : 'No replies')), /*#__PURE__*/React.createElement("div", {
      className: "kit-card",
      style: {
        cursor: 'default'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-caption)',
        color: 'var(--text-tertiary)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      className: "kit-dot",
      style: {
        background: 'var(--annot-yellow)'
      }
    }), "Highlight \xB7 Page 1"), /*#__PURE__*/React.createElement("span", {
      style: {
        font: '400 13px/18px var(--font-doc-sample)'
      }
    }, "\u201Cher ay\u0131n be\u015Finci g\xFCn\xFCne kadar\u201D")));
  } else if (app.mode === 'sign') {
    title = 'Fill & Sign';
    body = /*#__PURE__*/React.createElement(PanelSection, {
      title: "Fields",
      collapsible: false
    }, [['Kiracı · Ad Soyad', !!app.fields.name], ['Kiracı · Tarih', /^\d{2}\.\d{2}\.\d{4}$/.test(app.fields.date)], ['Kiracı · İmza', !!app.fields.sig]].map(([l, ok]) => /*#__PURE__*/React.createElement("div", {
      key: l,
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        font: 'var(--type-body)'
      }
    }, /*#__PURE__*/React.createElement(Icon, {
      name: ok ? 'circle-check' : 'circle',
      size: 16,
      color: ok ? 'var(--success-solid)' : 'var(--icon-disabled)'
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        flex: 1
      }
    }, l), ok ? null : /*#__PURE__*/React.createElement(Badge, {
      tone: "danger"
    }, "Required"))), /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      icon: "signature",
      fullWidth: true,
      onClick: app.openSign
    }, app.fields.sig ? 'Change signature' : 'Add signature'), /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-caption)',
        color: 'var(--text-tertiary)'
      }
    }, "Signatures are saved only on this device."));
  } else if (app.mode === 'convert') {
    title = 'Convert';
    body = /*#__PURE__*/React.createElement(PanelSection, {
      title: "Export as",
      collapsible: false
    }, /*#__PURE__*/React.createElement("div", {
      role: "radiogroup",
      "aria-label": "Format",
      style: {
        display: 'grid',
        gap: 8
      }
    }, /*#__PURE__*/React.createElement(Radio, {
      name: "fmt",
      value: "docx",
      label: "Word document (.docx)",
      defaultChecked: true
    }), /*#__PURE__*/React.createElement(Radio, {
      name: "fmt",
      value: "xlsx",
      label: "Excel workbook (.xlsx)"
    }), /*#__PURE__*/React.createElement(Radio, {
      name: "fmt",
      value: "png",
      label: "Images (.png, one per page)"
    }), /*#__PURE__*/React.createElement(Radio, {
      name: "fmt",
      value: "pdfa",
      label: "PDF/A for archiving"
    })), /*#__PURE__*/React.createElement(Checkbox, {
      label: "Recognize text first (OCR)",
      description: "Needed for scanned pages. Runs on this device.",
      defaultChecked: true
    }), /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      icon: "file-output",
      fullWidth: true,
      onClick: () => app.startTask('convert')
    }, "Convert"));
  } else if (app.mode === 'protect') {
    title = 'Protect';
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(PanelSection, {
      title: "Redaction",
      collapsible: false
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-caption)',
        color: 'var(--text-secondary)'
      }
    }, "Click the IBAN on page 1 or the ID number on page 2 to mark it."), app.pendingRedactions ? /*#__PURE__*/React.createElement(Banner, {
      tone: "danger",
      title: app.pendingRedactions + (app.pendingRedactions === 1 ? ' redaction' : ' redactions') + ' not applied'
    }, "Marked text stays in the file until you apply redactions.") : null, /*#__PURE__*/React.createElement(Button, {
      variant: "danger",
      icon: "eye-off",
      fullWidth: true,
      disabled: !app.pendingRedactions,
      onClick: app.confirmRedact
    }, "Apply redactions")), /*#__PURE__*/React.createElement(PanelSection, {
      title: "Password"
    }, /*#__PURE__*/React.createElement(Switch, {
      label: "Require a password to open"
    }), /*#__PURE__*/React.createElement(TextField, {
      type: "password",
      size: "sm",
      placeholder: "Password",
      hint: "Ferman can\u2019t recover a forgotten password."
    })));
  } else if (app.mode === 'organize') {
    title = 'Pages';
    body = /*#__PURE__*/React.createElement(PanelSection, {
      title: "Selection",
      collapsible: false
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-body)'
      },
      className: "fm-num"
    }, app.organizeSel.length, " of ", app.order.length, " pages selected"), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 6
      }
    }, /*#__PURE__*/React.createElement(Button, {
      size: "sm",
      icon: "rotate-cw",
      onClick: app.rotateSelected
    }, "Rotate"), /*#__PURE__*/React.createElement(Button, {
      size: "sm",
      icon: "trash-2",
      onClick: app.deleteSelected
    }, "Delete")));
  } else {
    body = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(PanelSection, {
      title: "File",
      collapsible: false
    }, /*#__PURE__*/React.createElement(Row, {
      label: "Pages"
    }, /*#__PURE__*/React.createElement("span", {
      className: "fm-num"
    }, app.order.length)), /*#__PURE__*/React.createElement(Row, {
      label: "Page size"
    }, /*#__PURE__*/React.createElement("span", {
      className: "fm-num"
    }, "A4 \xB7 210 \xD7 297 mm")), /*#__PURE__*/React.createElement(Row, {
      label: "Size"
    }, /*#__PURE__*/React.createElement("span", {
      className: "fm-num"
    }, doc.size)), /*#__PURE__*/React.createElement(Row, {
      label: "Location"
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        color: 'var(--text-secondary)',
        wordBreak: 'break-all'
      }
    }, doc.path))), /*#__PURE__*/React.createElement(PanelSection, {
      title: "Fonts in this document"
    }, doc.fonts.filter(f => f.group === 'document').map(f => /*#__PURE__*/React.createElement("div", {
      key: f.name,
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        font: 'var(--type-body)'
      }
    }, /*#__PURE__*/React.createElement(Icon, {
      name: "type",
      size: 14,
      color: "var(--icon-secondary)"
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        flex: 1
      }
    }, f.name), f.subset ? /*#__PURE__*/React.createElement(Badge, {
      tone: "warning"
    }, "Partial") : /*#__PURE__*/React.createElement(Badge, null, "Embedded"))), /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-caption)',
        color: 'var(--text-tertiary)'
      }
    }, "Partial fonts include only the characters already in the file.")), app.mode === 'edit' ? /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '4px 12px',
        font: 'var(--type-caption)',
        color: 'var(--text-tertiary)'
      }
    }, "Click any text on the page to select it. Click again to edit.") : null);
  }
  return /*#__PURE__*/React.createElement("aside", {
    style: {
      width: 'var(--panel-w)',
      flex: 'none',
      display: 'flex',
      flexDirection: 'column',
      background: 'var(--surface-panel)',
      borderInlineStart: '1px solid var(--border-subtle)',
      minHeight: 0
    }
  }, /*#__PURE__*/React.createElement(PanelHeader, {
    title: title
  }, app.mode === 'edit' && b && app.isBlockEdited(b.id) ? /*#__PURE__*/React.createElement(Badge, {
    tone: "edited",
    dot: true
  }, "Edited") : null), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'auto'
    }
  }, body));
}
function StatusBar({
  app
}) {
  const {
    IconButton,
    Icon,
    TaskProgress
  } = DSP;
  return /*#__PURE__*/React.createElement("footer", {
    style: {
      height: 'var(--statusbar-h)',
      flex: 'none',
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '0 8px',
      background: 'var(--surface-panel)',
      borderTop: '1px solid var(--border-subtle)',
      font: 'var(--type-caption)',
      color: 'var(--text-secondary)'
    },
    className: "fm-num"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 2
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    icon: "chevron-up",
    label: "Previous page",
    size: "xs",
    onClick: () => app.goToPage(Math.max(0, app.currentPage - 1))
  }), /*#__PURE__*/React.createElement(IconButton, {
    icon: "chevron-down",
    label: "Next page",
    size: "xs",
    onClick: () => app.goToPage(Math.min(app.order.length - 1, app.currentPage + 1))
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      paddingInline: 4
    }
  }, "Page ", app.currentPage + 1, " of ", app.order.length)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 2
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    icon: "minus",
    label: "Zoom out",
    size: "xs",
    onClick: () => app.setZoom(Math.max(50, app.zoom - 10))
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      minWidth: 40,
      textAlign: 'center'
    }
  }, app.zoom, "%"), /*#__PURE__*/React.createElement(IconButton, {
    icon: "plus",
    label: "Zoom in",
    size: "xs",
    onClick: () => app.setZoom(Math.min(400, app.zoom + 10))
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), app.task && app.task.state === 'running' ? /*#__PURE__*/React.createElement(TaskProgress, {
    variant: "inline",
    title: app.task.kind === 'ocr' ? 'Recognizing text' : 'Converting',
    detail: 'Page ' + Math.min(app.order.length, Math.floor(app.task.value * app.order.length) + 1) + ' of ' + app.order.length,
    value: app.task.value,
    onCancel: app.cancelTask
  }) : null, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "hard-drive",
    size: 12
  }), app.edited ? 'Unsaved changes' : 'Saved on this device'));
}
Object.assign(window, {
  Sidebar,
  PropertiesPanel,
  StatusBar
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/Panels.jsx", error: String((e && e.message) || e) }); }

// ui_kits/desktop/data.js
try { (() => {
/* Sample document for the Ferman desktop UI kit: a 3-page Turkish residential lease. */
window.FERMAN_DOC = {
  name: 'Kira sözleşmesi.pdf',
  path: '~/Belgeler/Ev/Kira sözleşmesi.pdf',
  size: '2.4 MB',
  fonts: [{
    name: 'IBM Plex Serif',
    family: 'var(--font-doc-sample)',
    group: 'document'
  }, {
    name: 'Garamond Premier Pro',
    family: 'var(--font-doc-sample)',
    group: 'document',
    subset: true
  }, {
    name: 'IBM Plex Sans',
    family: 'var(--font-ui)',
    group: 'system'
  }, {
    name: 'Georgia',
    family: 'Georgia, serif',
    group: 'system'
  }, {
    name: 'Times New Roman',
    family: '"Times New Roman", serif',
    group: 'system'
  }],
  pages: [{
    id: 'p1',
    blocks: [{
      id: 'b1',
      kind: 'title',
      text: 'KONUT KİRA SÖZLEŞMESİ',
      font: 'IBM Plex Serif',
      size: 16,
      weight: 600,
      align: 'center'
    }, {
      id: 'b2',
      kind: 'meta',
      text: 'Sözleşme No: 2026/0412 · Düzenleme tarihi: 13.10.2026',
      font: 'IBM Plex Serif',
      size: 9,
      align: 'center',
      color: '#57534C'
    }, {
      id: 'b3',
      kind: 'h',
      text: 'Madde 1 — Taraflar',
      font: 'IBM Plex Serif',
      size: 11,
      weight: 600
    }, {
      id: 'b4',
      kind: 'p',
      text: 'Kiraya veren: Mert Kaya, Moda Cad. No: 18, Kadıköy, İstanbul. Kiracı: Ayşe Yılmaz, Bağdat Cad. No: 241/7, Maltepe, İstanbul. Taraflar bu sözleşmede “kiraya veren” ve “kiracı” olarak anılacaktır.',
      font: 'IBM Plex Serif',
      size: 10.5
    }, {
      id: 'b5',
      kind: 'h',
      text: 'Madde 2 — Kiralanan',
      font: 'IBM Plex Serif',
      size: 11,
      weight: 600
    }, {
      id: 'b6',
      kind: 'p',
      text: 'Kiralanan taşınmaz, Caferağa Mah. Şair Nefi Sok. No: 9 Daire: 4 adresindeki üç oda bir salon konuttur. Konut eşyasız olarak, sayaçları kiracı adına açılmak üzere teslim edilmiştir.',
      font: 'IBM Plex Serif',
      size: 10.5
    }, {
      id: 'b7',
      kind: 'h',
      text: 'Madde 3 — Süre',
      font: 'IBM Plex Serif',
      size: 11,
      weight: 600
    }, {
      id: 'b8',
      kind: 'p',
      text: 'Kira süresi 01.11.2026 tarihinde başlar ve bir yıl sürer. Taraflardan biri süre bitiminden en az on beş gün önce bildirimde bulunmadıkça sözleşme aynı koşullarla bir yıl uzar.',
      font: 'IBM Plex Serif',
      size: 10.5
    }, {
      id: 'b9',
      kind: 'h',
      text: 'Madde 4 — Kira Bedeli ve Ödeme',
      font: 'IBM Plex Serif',
      size: 11,
      weight: 600,
      note: true
    }, {
      id: 'b10',
      kind: 'p',
      text: 'Kiracı, aylık kira bedeli olan 18.500 TL’yi her ayın beşinci gününe kadar kiraya verenin aşağıdaki hesabına ödemekle yükümlüdür.',
      font: 'IBM Plex Serif',
      size: 10.5,
      highlight: 'her ayın beşinci gününe kadar'
    }, {
      id: 'b11',
      kind: 'p',
      text: 'IBAN: TR12 0006 4000 0011 2345 6789 01 · Alıcı: Mert Kaya',
      font: 'IBM Plex Serif',
      size: 10.5,
      redactable: 'TR12 0006 4000 0011 2345 6789 01'
    }, {
      id: 'b12',
      kind: 'p',
      text: 'Ödemenin ağustos ayında gecikmesi hâlinde yasal faiz uygulanır; gecikme otuz günü aşarsa kiraya veren sözleşmeyi feshedebilir.',
      font: 'Garamond Premier Pro',
      size: 10.5,
      missing: ['ğ']
    }]
  }, {
    id: 'p2',
    blocks: [{
      id: 'c1',
      kind: 'h',
      text: 'Madde 5 — Depozito',
      font: 'IBM Plex Serif',
      size: 11,
      weight: 600
    }, {
      id: 'c2',
      kind: 'p',
      text: 'Kiracı, sözleşme imzalanırken iki aylık kira bedeli tutarında, 37.000 TL depozito öder. Depozito, kiralananın hasarsız teslim edilmesinden sonra on gün içinde iade edilir.',
      font: 'IBM Plex Serif',
      size: 10.5
    }, {
      id: 'c3',
      kind: 'h',
      text: 'Madde 6 — Kullanım',
      font: 'IBM Plex Serif',
      size: 11,
      weight: 600
    }, {
      id: 'c4',
      kind: 'p',
      text: 'Kiralanan yalnızca konut olarak kullanılır. Kiracı, kiraya verenin yazılı izni olmadan kiralananı başkasına kiralayamaz, devredemez ve tadilat yapamaz.',
      font: 'IBM Plex Serif',
      size: 10.5
    }, {
      id: 'c5',
      kind: 'h',
      text: 'Madde 7 — Tahliye',
      font: 'IBM Plex Serif',
      size: 11,
      weight: 600
    }, {
      id: 'c6',
      kind: 'p',
      text: 'Kiracı, sözleşme sona erdiğinde kiralananı aldığı gibi, temiz ve boş olarak teslim eder. Anahtar teslimi bir tutanakla belgelenir.',
      font: 'IBM Plex Serif',
      size: 10.5
    }, {
      id: 'c7',
      kind: 'p',
      text: 'Kiracı T.C. Kimlik No: 12345678901',
      font: 'IBM Plex Serif',
      size: 10.5,
      redactable: '12345678901'
    }]
  }, {
    id: 'p3',
    blocks: [{
      id: 'd1',
      kind: 'h',
      text: 'Madde 8 — Uyuşmazlıklar',
      font: 'IBM Plex Serif',
      size: 11,
      weight: 600
    }, {
      id: 'd2',
      kind: 'p',
      text: 'Bu sözleşmeden doğan uyuşmazlıklarda İstanbul Anadolu Mahkemeleri ve İcra Daireleri yetkilidir. Sözleşme iki nüsha olarak düzenlenmiş ve taraflarca okunarak imzalanmıştır.',
      font: 'IBM Plex Serif',
      size: 10.5
    }, {
      id: 'd3',
      kind: 'signatures'
    }]
  }],
  outline: [{
    page: 0,
    label: 'Madde 1 — Taraflar'
  }, {
    page: 0,
    label: 'Madde 2 — Kiralanan'
  }, {
    page: 0,
    label: 'Madde 3 — Süre'
  }, {
    page: 0,
    label: 'Madde 4 — Kira Bedeli ve Ödeme'
  }, {
    page: 1,
    label: 'Madde 5 — Depozito'
  }, {
    page: 1,
    label: 'Madde 6 — Kullanım'
  }, {
    page: 1,
    label: 'Madde 7 — Tahliye'
  }, {
    page: 2,
    label: 'Madde 8 — Uyuşmazlıklar'
  }],
  recent: [{
    name: 'Kira sözleşmesi.pdf',
    meta: 'Today · 3 pages'
  }, {
    name: '2025 Gelir vergisi beyannamesi.pdf',
    meta: '12 Oct · 24 pages'
  }, {
    name: 'Thesis draft — chapter 3.pdf',
    meta: '3 Oct · 41 pages'
  }]
};
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/desktop/data.js", error: String((e && e.message) || e) }); }

__ds_ns.ANNOTATION_TOOLS = __ds_scope.ANNOTATION_TOOLS;

__ds_ns.AnnotationTools = __ds_scope.AnnotationTools;

__ds_ns.Highlight = __ds_scope.Highlight;

__ds_ns.Stamp = __ds_scope.Stamp;

__ds_ns.StickyNote = __ds_scope.StickyNote;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.ICON_PATHS = __ds_scope.ICON_PATHS;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Kbd = __ds_scope.Kbd;

__ds_ns.Tooltip = __ds_scope.Tooltip;

__ds_ns.PageMark = __ds_scope.PageMark;

__ds_ns.SearchReplaceBar = __ds_scope.SearchReplaceBar;

__ds_ns.TextEditBox = __ds_scope.TextEditBox;

__ds_ns.TextCaret = __ds_scope.TextCaret;

__ds_ns.DropZone = __ds_scope.DropZone;

__ds_ns.Banner = __ds_scope.Banner;

__ds_ns.ProgressBar = __ds_scope.ProgressBar;

__ds_ns.Spinner = __ds_scope.Spinner;

__ds_ns.TaskProgress = __ds_scope.TaskProgress;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.PdfFormField = __ds_scope.PdfFormField;

__ds_ns.SignaturePad = __ds_scope.SignaturePad;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.ColorPicker = __ds_scope.ColorPicker;

__ds_ns.FontPicker = __ds_scope.FontPicker;

__ds_ns.NumberStepper = __ds_scope.NumberStepper;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.TextField = __ds_scope.TextField;

__ds_ns.FERMAN_MODES = __ds_scope.FERMAN_MODES;

__ds_ns.ModeTabs = __ds_scope.ModeTabs;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.ToolButton = __ds_scope.ToolButton;

__ds_ns.Toolbar = __ds_scope.Toolbar;

__ds_ns.ToolbarSeparator = __ds_scope.ToolbarSeparator;

__ds_ns.ToolbarSpacer = __ds_scope.ToolbarSpacer;

__ds_ns.ToolbarGroup = __ds_scope.ToolbarGroup;

__ds_ns.CommandPalette = __ds_scope.CommandPalette;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.Menu = __ds_scope.Menu;

__ds_ns.PageThumbnail = __ds_scope.PageThumbnail;

__ds_ns.PanelSection = __ds_scope.PanelSection;

})();
