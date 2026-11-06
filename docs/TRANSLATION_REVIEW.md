# Translation review

Every message of the app in English, Turkish and Arabic, side by side, for the native-speaker review
that Milestone 1 waits on: gate S5 in [ROADMAP.md](ROADMAP.md), the
[pending owner check](PROGRESS.md#pending-owner-checks) and [BACKLOG.md](BACKLOG.md) B100.

Related: [progress](PROGRESS.md) · [backlog](BACKLOG.md) · [design gaps](DESIGN_GAPS.md) ·
[contributing: translations](../CONTRIBUTING.md#translations)

## Status

No native speaker has reviewed these strings yet. A few phrases come from the design's Turkish and
Arabic boards; the others were drafted with machine assistance during Milestone 1. Following
[CONTRIBUTING.md](../CONTRIBUTING.md#translations), they are suggestions until a person who speaks
the language has reviewed them. When both languages have been reviewed, the owner ticks the review
in [PROGRESS.md](PROGRESS.md#pending-owner-checks).

## How to review

- Each row is one message: its key, the English source, the Turkish and Arabic translations, and
  the context. The context is the note for translators in `app/lib/l10n/app_en.arb`: where the
  string appears, what it does, and limits such as "keep it short". Codes in parentheses, such as
  "FmWindow t.home", "a11-1b" or "design gap G20", point developers to the design and the docs; a
  reviewer can skip them.
- Keep placeholders in braces as they are (`{formatted}`, `{language}`, `{page}`): the app fills
  them in.
- One message is an ICU plural, `onboardingFeatureLanguages`: `{count, plural, =1{…} other{…}}`.
  Keep `count, plural`, the case names (`=1`, `other`) and the placeholders, and translate the
  words inside each case. Each language has its own cases: Turkish keeps the noun singular after a
  number, and Arabic uses `zero`, `one`, `two`, `few`, `many` and `other`.
- Write Turkish in sentence case, as the design does almost everywhere; where the design's Turkish
  differs, keep it (the mode tab "Doldur ve İmzala"). The app capitalizes with Turkish rules where
  the design shows capitals ("İMZALA"), so write the letters normally.
- The app shows Arabic right to left. A browser may place the punctuation and placeholders of an
  Arabic cell oddly in this table; judge the wording here, and the placement in the app or in the
  goldens (`app/test/goldens/goldens/`).
- A dash (—) means the language has no message for the key yet, so the app shows the English one.

## Sending corrections

- Open an issue that names the key, the current text and the proposed text, or
- open a pull request that changes `app/lib/l10n/app_tr.arb` or `app/lib/l10n/app_ar.arb`. Then run
  `flutter pub get` and `flutter gen-l10n` in `app/`, and `dart run` and `dart run l10n:review_table`
  in `tools/l10n/`. A
  changed string can change the goldens; regenerate them on Linux as
  [CONTRIBUTING.md](../CONTRIBUTING.md) describes.

The table below is generated from the ARB files by `tools/l10n`
([README](../tools/l10n/README.md#review-table)); never edit it by hand. CI fails when it is stale.

## Messages

<!-- BEGIN GENERATED TRANSLATION TABLE: tools/l10n, dart run l10n:review_table -->

904 messages in `app_en.arb`; translated: Turkish 904, Arabic 904.

| Key | English | Turkish | Arabic | Context |
|---|---|---|---|---|
| `shellHome` | Home | Ana sayfa | الرئيسية | Title bar: tooltip and screen-reader name of the house button that shows the start screen, and the name of the home tab when the start screen shows (FmWindow t.home). |
| `shellOpenDocuments` | Open documents | Açık belgeler | المستندات المفتوحة | Title bar: screen-reader name of the strip of document tabs (FmWindow t.docs). "Open" is an adjective: the documents that are open. |
| `shellOpenFile` | Open file | Dosya aç | فتح ملف | Title bar: tooltip and screen-reader name of the "+" button after the document tabs, which opens a file (FmWindow t.open). |
| `shellCloseDocument` | Close document | Belgeyi kapat | إغلاق المستند | Title bar: tooltip and screen-reader name of the small x button on the active document tab (FmWindow t.closeDoc). Closes the document, not the window. |
| `shellUnsavedChanges` | Unsaved changes | Kaydedilmemiş değişiklikler | تغييرات غير محفوظة | Tooltip of the dot on a document tab, read after the file name by screen readers, and the status-bar save state of a document with unsaved changes (FmWindow t.unsaved). |
| `shellOpening` | Opening | Açılıyor | جارٍ الفتح | Screen-reader label of the small spinner on a document tab while the file is still opening (FmWindow Spinner label). |
| `shellMoreDocuments` | {count} more | {count} belge daha | {count} أخرى | Title bar: screen-reader name of the "+N" button that lists the open documents whose tabs do not fit (FmWindow t.more). {count} is the number of those documents, already formatted for the region. |
| `shellMoreDocumentsBadge` | +{count} | +{count} | +{count} | Title bar: the visible label of the button that lists the open documents whose tabs do not fit, a plus sign and their number (FmWindow overflowLabel, for example "+3"). {count} is already formatted for the region. |
| `shellSearch` | Search | Ara | بحث | Title bar: label of the Search button, which opens the command palette (FmWindow t.search). A verb. |
| `shellSettings` | Settings | Ayarlar | الإعدادات | Title bar: tooltip and screen-reader name of the gear button that opens Settings (FmWindow t.settings). |
| `shellModeLabel` | Mode | Mod | الوضع | Mode bar: screen-reader name of the row of mode tabs (FmWindow t.modeLabel). |
| `shellModeView` | View | Görüntüle | عرض | Mode tab: reading, zoom and page layout (FmWindow modes\[0\]). A proper name of the mode; keep it short. |
| `shellModeEdit` | Edit | Düzenle | تحرير | Mode tab: editing text and content (FmWindow modes\[1\]); also the title of the right panel in this mode. Keep it short. |
| `shellModeComment` | Comment | Yorum | تعليق | Mode tab: comments and annotations (FmWindow modes\[2\]). Keep it short. |
| `shellModeSign` | Fill &amp; Sign | Doldur ve İmzala | تعبئة وتوقيع | Mode tab: filling forms and signing (FmWindow modes\[3\]). Keep it short. |
| `shellModeOrganize` | Organize | Sayfalar | تنظيم | Mode tab: organizing pages (FmWindow modes\[4\]). The Turkish design uses "Sayfalar" so it cannot be confused with Düzenle (Edit). |
| `shellModeConvert` | Convert | Dönüştür | تحويل | Mode tab: converting to and from other formats (FmWindow modes\[5\]). Keep it short. |
| `shellModeProtect` | Protect | Koru | حماية | Mode tab: passwords and redaction (FmWindow modes\[6\]). Keep it short. |
| `shellModeTools` | Tools | Araçlar | أدوات | Mode tab: compress, compare and the other tools (FmWindow modes\[7\]); also the screen-reader name of that mode's tool row. Keep it short. |
| `shellToggleSidebar` | Show or hide sidebar | Kenar çubuğunu göster veya gizle | إظهار الشريط الجانبي أو إخفاؤه | Mode bar: tooltip and screen-reader name of the button that shows or hides the sidebar on the start side (FmWindow t.sidebar). |
| `shellTogglePanel` | Show or hide panel | Paneli göster veya gizle | إظهار اللوحة أو إخفاؤها | Mode bar: tooltip and screen-reader name of the button that shows or hides the right panel (FmWindow t.panel). |
| `shellAiAssistant` | AI assistant | Yapay zekâ yardımcısı | المساعد الذكي | Name of the AI assistant: the mode-bar button (shown only when AI is turned on) and the last tool of the Tools row (FmWindow t.ai). |
| `shellSave` | Save | Kaydet | حفظ | Mode bar: label of the primary Save button (FmWindow t.save). A verb. |
| `shellNoChangesToSave` | No changes to save | Kaydedilecek değişiklik yok | لا توجد تغييرات للحفظ | Tooltip of the disabled Save button when the document has no unsaved changes (FmWindow t.saveTipOff). |
| `shellViewTools` | View tools | Görüntüleme araçları | أدوات العرض | Screen-reader name of the View mode's tool row (FmWindow Toolbar label). |
| `shellToolSelect` | Select | Seç | تحديد | Tool button in the View and Comment tool rows: the pointer that selects text and objects (FmWindow, mouse-pointer icon). A verb. |
| `shellToolHand` | Hand | El aracı | أداة اليد | View tool row: the hand tool that drags the page around (FmWindow). |
| `shellToolMarqueeZoom` | Marquee zoom | Alana yakınlaştır | تكبير منطقة | View tool row: the tool that zooms to a rectangle the user drags (FmWindow). |
| `shellZoomOut` | Zoom out | Uzaklaştır | تصغير | Tooltip and screen-reader name of the zoom-out buttons in the View tool row and the status bar (FmWindow t.zoomOut). |
| `shellZoomIn` | Zoom in | Yakınlaştır | تكبير | Tooltip and screen-reader name of the zoom-in buttons in the View tool row and the status bar (FmWindow t.zoomIn). |
| `shellZoom` | Zoom | Yakınlaştırma düzeyi | مستوى التكبير | View tool row: screen-reader name of the zoom percentage menu (FmWindow aria-label). |
| `shellFit` | Fit | Sığdır | ملاءمة | View tool row: screen-reader name of the group of three fit buttons (fit width, fit page, actual size) (FmWindow). |
| `shellFitWidth` | Fit width | Genişliğe sığdır | ملاءمة عرض الصفحة | Zoom choice that fits the page width to the window: a fit button and a zoom-menu entry (FmWindow). |
| `shellFitPage` | Fit page | Sayfaya sığdır | ملاءمة الصفحة | Zoom choice that fits the whole page in the window: a fit button and a zoom-menu entry (FmWindow). |
| `shellActualSize` | Actual size | Gerçek boyut | الحجم الفعلي | Zoom choice that shows the page at its printed size (FmWindow). |
| `shellPageLayout` | Page layout | Sayfa düzeni | تخطيط الصفحة | View tool row: screen-reader name of the group of four page-layout buttons (FmWindow). |
| `shellLayoutSingle` | Single page | Tek sayfa | صفحة واحدة | Page layout button: one page at a time (FmWindow). |
| `shellLayoutContinuous` | Continuous scroll | Sürekli kaydırma | تمرير متواصل | Page layout button: pages one under another, scrolling continuously (FmWindow). |
| `shellLayoutTwoPage` | Two-page spread | İki sayfa yan yana | صفحتان متجاورتان | Page layout button: two pages side by side (FmWindow). |
| `shellLayoutBook` | Book (cover page alone) | Kitap (kapak sayfası ayrı) | كتاب (صفحة الغلاف منفردة) | Page layout button: two pages side by side with the cover page on its own, like a book (FmWindow). |
| `shellToolSplitView` | Split view | Bölünmüş görünüm | عرض مقسّم | View tool row: shows two views of documents side by side (FmWindow). |
| `shellToolReadAloud` | Read aloud | Sesli oku | القراءة بصوت عالٍ | View tool row: reads the document aloud with the system voice (FmWindow). |
| `shellToolPresent` | Present | Sunum yap | عرض تقديمي | View tool row: shows the document full screen as a presentation (FmWindow). A verb. |
| `shellDarkReadingMode` | Dark reading mode | Koyu okuma modu | وضع القراءة الداكن | View tool row: switch that shows pages with dark backgrounds for reading at night (FmWindow). |
| `shellEditTools` | Edit tools | Düzenleme araçları | أدوات التحرير | Screen-reader name of the Edit mode's tool row (FmWindow t.editTools). |
| `shellToolEditText` | Edit text | Metni düzenle | تحرير النص | Edit tool row: the tool that edits existing text in the PDF (FmWindow t.editText). |
| `shellToolAddText` | Add text | Metin ekle | إضافة نص | Tool button in the Edit and Fill &amp; Sign tool rows: adds new text on the page (FmWindow t.addText). |
| `shellToolAddImage` | Add image | Görsel ekle | إضافة صورة | Edit tool row: adds an image on the page (FmWindow t.addImage). |
| `shellToolLink` | Link | Bağlantı | رابط | Edit tool row: adds or edits a link (FmWindow t.link). A noun. |
| `shellToolFindReplace` | Find &amp; replace | Bul ve değiştir | بحث واستبدال | Edit tool row: finds text and replaces it (FmWindow t.findReplace). |
| `shellToolPageMarks` | Page marks | Sayfa işaretleri | علامات الصفحة | Edit tool row: menu of watermarks, headers and footers, Bates numbers and page backgrounds (FmWindow t.pageMarks). |
| `shellUndo` | Undo | Geri al | تراجع | Edit tool row: tooltip and screen-reader name of the undo button (FmWindow t.undo). |
| `shellRedo` | Redo | Yinele | إعادة | Edit tool row: tooltip and screen-reader name of the redo button (FmWindow t.redo). |
| `shellEditHistory` | Edit history | Düzenleme geçmişi | سجل التحرير | Edit tool row: tooltip and screen-reader name of the button that shows the list of edits made in this session (FmWindow t.history). |
| `shellMarkEditedText` | Mark edited text | Düzenlenen metni işaretle | تمييز النص المعدّل | Edit tool row: switch that marks the edited text on the page (FmWindow t.markEdited). |
| `shellReviewEdits` | Review edits | Düzenlemeleri incele | مراجعة التعديلات | Edit tool row: button that opens the list of edits to review, followed by their number (FmWindow t.review). |
| `shellCommentTools` | Comment tools | Yorum araçları | أدوات التعليق | Screen-reader name of the Comment mode's tool row (AnnotationTools). |
| `shellAnnotationHighlight` | Highlight | Vurgula | تمييز | Comment tool: highlights text (FmWindow annotTools). A verb. |
| `shellAnnotationUnderline` | Underline | Altını çiz | تسطير | Comment tool: underlines text as a comment mark (FmWindow annotTools). A verb. |
| `shellAnnotationStrikethrough` | Strikethrough | Üstünü çiz | شطب | Comment tool: strikes through text as a comment mark (FmWindow annotTools). |
| `shellAnnotationNote` | Note | Not | ملاحظة | Comment tool: adds a sticky note (FmWindow annotTools). A noun. |
| `shellAnnotationText` | Text | Metin | نص | Comment tool: adds a text box comment on the page (FmWindow annotTools). A noun. |
| `shellAnnotationCallout` | Callout | Belirtme çizgisi | وسيلة شرح | Comment tool: adds a text box with a pointer line (FmWindow annotTools). A noun. |
| `shellAnnotationDraw` | Draw | Çiz | رسم | Comment tool: freehand drawing with a pen (FmWindow annotTools). A verb. |
| `shellAnnotationShapes` | Shapes | Şekiller | أشكال | Comment tool: menu of rectangles, ellipses, lines and arrows (FmWindow annotTools). |
| `shellAnnotationStamp` | Stamp | Damga | ختم | Comment tool: menu of stamps such as Approved (FmWindow annotTools). A noun. |
| `shellToolMeasure` | Measure | Ölç | قياس | Tool button in the Comment and Tools rows: measures distances and areas on the page (FmWindow). A verb. |
| `shellColor` | Color | Renk | اللون | Comment tool row: screen-reader name of the group of annotation colours (AnnotationTools). |
| `shellColorYellow` | Yellow | Sarı | أصفر | Annotation colour name, read by screen readers (design palette). |
| `shellColorGreen` | Green | Yeşil | أخضر | Annotation colour name, read by screen readers (design palette). |
| `shellColorBlue` | Blue | Mavi | أزرق | Annotation colour name, read by screen readers (design palette). |
| `shellColorPink` | Pink | Pembe | وردي | Annotation colour name, read by screen readers (design palette). |
| `shellColorOrange` | Orange | Turuncu | برتقالي | Annotation colour name, read by screen readers (design palette). |
| `shellColorRed` | Red | Kırmızı | أحمر | Annotation colour name, read by screen readers (design palette). |
| `shellColorBlack` | Black | Siyah | أسود | Annotation colour name (the ink colour), read by screen readers (design palette). |
| `shellShowComments` | Show comments | Yorumları göster | إظهار التعليقات | Comment tool row: switch that shows or hides every comment on the pages (FmWindow). |
| `shellFillSignTools` | Fill and sign tools | Doldurma ve imzalama araçları | أدوات التعبئة والتوقيع | Screen-reader name of the Fill &amp; Sign mode's tool row (FmWindow Toolbar label). |
| `shellToolFillFields` | Fill fields | Alanları doldur | تعبئة الحقول | Fill &amp; Sign tool row: fills in the form fields of the PDF (FmWindow). |
| `shellToolCheckmark` | Checkmark | Onay işareti | علامة اختيار | Fill &amp; Sign tool row: puts a check mark on the page (FmWindow). |
| `shellToolDate` | Date | Tarih | التاريخ | Fill &amp; Sign tool row: puts a date on the page (FmWindow). A noun. |
| `shellToolSign` | Sign | İmzala | توقيع | Fill &amp; Sign tool row: menu that adds a signature (FmWindow; the same word as the Sign tool of the mobile home, FmMHome tools). A verb. |
| `shellToolInitials` | Initials | Paraf | الأحرف الأولى | Fill &amp; Sign tool row: adds the signer's initials (FmWindow). |
| `shellToolDigitalSignature` | Digital signature | Dijital imza | توقيع رقمي | Fill &amp; Sign tool row: signs with a certificate (FmWindow). |
| `shellToolEimza` | e-imza | e-imza | e-imza | Fill &amp; Sign tool row: signs with a Turkish e-imza card (FmWindow). A Turkish product name: keep "e-imza" in every language. |
| `shellToolPrepareForm` | Prepare form | Form hazırla | إعداد نموذج | Fill &amp; Sign tool row: adds form fields to a PDF (FmWindow). |
| `shellOrganizeTools` | Organize tools | Sayfa araçları | أدوات التنظيم | Screen-reader name of the Organize mode's tool row (FmWindow Toolbar label). |
| `shellToolInsert` | Insert | Ekle | إدراج | Organize tool row: menu that inserts blank pages or pages from a file (FmWindow). A verb. |
| `shellToolRotateLeft` | Rotate left | Sola döndür | تدوير لليسار | Organize tool row: tooltip and screen-reader name of the button that rotates the selected pages counterclockwise (FmWindow). |
| `shellToolRotateRight` | Rotate right | Sağa döndür | تدوير لليمين | Organize tool row: tooltip and screen-reader name of the button that rotates the selected pages clockwise (FmWindow). |
| `shellToolDuplicate` | Duplicate | Çoğalt | تكرار | Organize tool row: duplicates the selected pages (FmWindow). A verb. |
| `shellToolExtract` | Extract | Ayıkla | استخراج | Organize tool row: saves the selected pages as a new PDF (FmWindow). A verb. |
| `shellToolReplace` | Replace | Değiştir | استبدال | Organize tool row: replaces the selected pages with pages from another file (FmWindow). A verb. |
| `shellToolDelete` | Delete | Sil | حذف | Organize tool row: deletes the selected pages (FmWindow). A verb. |
| `shellToolSplit` | Split | Böl | تقسيم | Organize tool row: splits the document into several files (FmWindow). A verb. |
| `shellToolCombineFiles` | Combine files | Dosyaları birleştir | دمج الملفات | Organize tool row: combines several files into one PDF (FmWindow; the same words as the start screen's Combine files, FmStart). |
| `shellToolCrop` | Crop | Kırp | اقتصاص | Organize tool row: crops the pages (FmWindow). A verb. |
| `shellToolPageLabels` | Page labels | Sayfa etiketleri | تسميات الصفحات | Organize tool row: sets the page numbering, such as i, ii, iii (FmWindow). |
| `shellOrganizeHint` | Drag pages to reorder. Right-click for more. | Sıralamak için sayfaları sürükleyin. Daha fazlası için sağ tıklayın. | اسحب الصفحات لإعادة ترتيبها. انقر بزر الماوس الأيمن للمزيد. | Organize tool row: hint at the end of the row (FmWindow organizeHint). |
| `shellConvertTools` | Convert tools | Dönüştürme araçları | أدوات التحويل | Screen-reader name of the Convert mode's tool row (FmWindow Toolbar label). |
| `shellConvertWord` | Word | Word | Word | Convert tool row: converts the PDF to a Word document (FmWindow). A product name. |
| `shellConvertExcel` | Excel | Excel | Excel | Convert tool row: converts the PDF to an Excel spreadsheet (FmWindow). A product name. |
| `shellConvertPowerPoint` | PowerPoint | PowerPoint | PowerPoint | Convert tool row: converts the PDF to a PowerPoint presentation (FmWindow). A product name. |
| `shellConvertImage` | Image | Görsel | صورة | Convert tool row: converts the pages to images (FmWindow). A noun. |
| `shellConvertHtml` | HTML | HTML | HTML | Convert tool row: converts the PDF to a web page (FmWindow). A format name. |
| `shellConvertText` | Text | Metin | نص | Convert tool row: converts the PDF to plain text (FmWindow). A noun: the plain-text format. |
| `shellConvertMarkdown` | Markdown | Markdown | Markdown | Convert tool row: converts the PDF to Markdown (FmWindow). A format name. |
| `shellToolCreatePdf` | Create PDF | PDF oluştur | إنشاء PDF | Convert tool row: creates a PDF from other files (FmWindow; the same words as the start screen's Create PDF, FmStart). |
| `shellToolScan` | Scan | Tara | مسح | Convert tool row: scans paper into a PDF (FmWindow; the same word as the Scan tool of the mobile home, FmMHome tools). A verb. |
| `shellToolRecognizeText` | Recognize text (OCR) | Metni tanı (OCR) | التعرّف على النص (OCR) | Convert tool row: recognizes the text of scanned pages (FmWindow). |
| `shellProtectTools` | Protect tools | Koruma araçları | أدوات الحماية | Screen-reader name of the Protect mode's tool row (FmWindow Toolbar label). |
| `shellToolRedact` | Redact | Karart | حجب | Protect tool row: blacks out content for good (FmWindow). A verb. |
| `shellToolFindRedact` | Find &amp; redact | Bul ve karart | بحث وحجب | Protect tool row: finds text and patterns to black out (FmWindow). |
| `shellToolPassword` | Password | Parola | كلمة المرور | Protect tool row: protects the PDF with a password (FmWindow). A noun. |
| `shellToolRemoveHidden` | Remove hidden information | Gizli bilgileri kaldır | إزالة المعلومات المخفية | Protect tool row: removes metadata and other hidden content (FmWindow). |
| `shellToolSecurityReport` | Security report | Güvenlik raporu | تقرير الأمان | Protect tool row: shows what the document contains and allows (FmWindow). |
| `shellApplyRedactions` | Apply redactions | Karartmaları uygula | تطبيق الحجب | Protect tool row: the red button that blacks out the marked content for good (FmWindow applyLabel). |
| `shellToolCompress` | Compress | Sıkıştır | ضغط | Tools row: makes the PDF smaller (FmWindow; the same word as the Compress tool of the mobile home, FmMHome tools). A verb. |
| `shellToolCompare` | Compare | Karşılaştır | مقارنة | Tools row: compares two versions of a document (FmWindow). A verb. |
| `shellToolAccessibility` | Accessibility | Erişilebilirlik | إمكانية الوصول | Tools row: checks and fixes the PDF for screen readers (FmWindow). |
| `shellToolPdfA` | PDF/A &amp; preflight | PDF/A ve ön kontrol | PDF/A والفحص المسبق | Tools row: archiving (PDF/A) and print checks (FmWindow). |
| `shellToolBatch` | Batch actions | Toplu işlemler | إجراءات مجمّعة | Tools row: runs a series of steps on many files (FmWindow). |
| `shellToolPrint` | Print | Yazdır | طباعة | Tools row: prints the document (FmWindow). A verb. |
| `shellToolVersionHistory` | Version history | Sürüm geçmişi | سجل الإصدارات | Tools row: shows the saved versions of the document (FmWindow). |
| `fieldContextMenu` | Text field | Metin alanı | حقل نص | Accessible name of the context menu a right click opens on a text field (B017). |
| `fieldCut` | Cut | Kes | قص | Text field context menu: cut the selected text. |
| `fieldCopy` | Copy | Kopyala | نسخ | Text field context menu: copy the selected text. |
| `fieldPaste` | Paste | Yapıştır | لصق | Text field context menu: paste the clipboard. |
| `fieldSelectAll` | Select all | Tümünü seç | تحديد الكل | Text field context menu: select all the field's text. |
| `shellResizeSidebar` | Resize sidebar | Kenar çubuğunu yeniden boyutlandır | تغيير حجم الشريط الجانبي | Accessible name of the invisible drag handle on the sidebar's edge that changes its width (B094). |
| `shellResizePanel` | Resize panel | Paneli yeniden boyutlandır | تغيير حجم اللوحة | Accessible name of the invisible drag handle on the right panel's edge that changes its width (B094). |
| `shellSidebar` | Sidebar | Kenar çubuğu | الشريط الجانبي | Screen-reader name of the sidebar and of its row of tabs (FmSidebar t.sidebar). |
| `shellSidebarPages` | Pages | Sayfalar | الصفحات | Sidebar tab and heading: page thumbnails (FmSidebar t.pages). |
| `shellSidebarOutline` | Outline | Yer işaretleri | الإشارات المرجعية | Sidebar tab and heading: the document's bookmarks (FmSidebar t.outline). |
| `shellSidebarAttachments` | Attachments | Ekler | المرفقات | Sidebar tab and heading: files embedded in the PDF (FmSidebar t.attachments). |
| `shellSidebarLayers` | Layers | Katmanlar | الطبقات | Sidebar tab and heading: layers that can be shown or hidden (FmSidebar t.layers). |
| `shellSidebarSignatures` | Signatures | İmzalar | التوقيعات | Sidebar tab and heading: the signatures in the document (FmSidebar t.signatures). |
| `shellSidebarSearch` | Search results | Arama sonuçları | نتائج البحث | Sidebar tab and heading: results of a search in the document (FmSidebar t.search). |
| `shellPageBadgesLegend` | What the page badges mean | Sayfa rozetlerinin anlamı | معنى شارات الصفحات | Sidebar: tooltip and screen-reader name of the info button that explains the small badges on page thumbnails (FmSidebar t.legend). |
| `shellAddBookmark` | Add bookmark | Yer işareti ekle | إضافة إشارة مرجعية | Sidebar Outline tab: tooltip and screen-reader name of the + button that adds a bookmark (FmSidebar). |
| `shellMore` | More | Diğer | المزيد | Tooltip and screen-reader name of the "…" buttons that open a menu with more actions, in the sidebar and the right panel (FmSidebar, FmDocPanel; the same word as FmEditPanel t.more). |
| `shellMoreTools` | More tools | Diğer araçlar | مزيد من الأدوات | Tool row: tooltip and screen-reader name of the "…" button that appears when the window is too narrow for every tool, and the name of the menu it opens with the tools that do not fit (G21). |
| `shellReviewEditsCount` | Review edits ({count}) | Düzenlemeleri incele ({count}) | مراجعة التعديلات ({count}) | Tool row: the Review edits button as an entry of the "More tools" menu of a narrow window (G21), with the number of edits waiting for review (the row shows it as a badge). {count} is already formatted for the region. |
| `shellWindowTooNarrow` | Make the window wider to show this panel | Bu paneli göstermek için pencereyi genişletin | وسّع النافذة لعرض هذه اللوحة | Mode bar: tooltip and screen-reader hint of the sidebar or right-panel toggle when the window is too narrow for that panel beside the document, even on its own (G21; reachable on the web and narrow tablets, below the 1024 px desktop minimum). The toggle is disabled while this shows. |
| `shellAttachFile` | Attach a file | Dosya ekle | إرفاق ملف | Sidebar Attachments tab: tooltip and screen-reader name of the + button that embeds a file in the PDF (FmSidebar). |
| `shellPanelDocument` | Document | Belge | المستند | Title of the right panel that shows the document's properties (FmDocPanel title). |
| `shellCanvas` | Document pages | Belge sayfaları | صفحات المستند | Screen-reader name of the large area where the document's pages show (the canvas). |
| `shellPreviousPage` | Previous page | Önceki sayfa | الصفحة السابقة | Status bar: tooltip and screen-reader name of the up-arrow button (FmWindow t.prev). |
| `shellNextPage` | Next page | Sonraki sayfa | الصفحة التالية | Status bar: tooltip and screen-reader name of the down-arrow button (FmWindow t.next). |
| `shellPageOf` | Page {page} of {count} | Sayfa {page} / {count} | الصفحة {page} من {count} | Status bar: the current page and the number of pages (FmWindow t.page). {page} and {count} are already formatted for the region. |
| `shellSavedOnDevice` | Saved on this device · {time} | Bu cihaza kaydedildi · {time} | حُفظ على هذا الجهاز · {time} | Status bar: the document was saved on this computer, and when (FmWindow t.saved). {time} is the time of day, already formatted for the region, for example 14:32. |
| `shellSaving` | Saving… | Kaydediliyor… | جارٍ الحفظ… | Status bar: the document is being saved now (FmWindow t.saving). |
| `shellSaveError` | Couldn’t save | Kaydedilemedi | تعذّر الحفظ | Status bar: the last save failed (FmWindow t.saveError). |
| `shellReadOnly` | Read-only | Salt okunur | للقراءة فقط | Status bar: the document cannot be saved in place (FmWindow t.readonly). |
| `appName` | Ferman | Ferman | Ferman | Product name. A proper noun: do not translate; keep the Latin spelling in every language. |
| `availableInFutureVersion` | Available in a future version | Gelecek bir sürümde sunulacak | متاح في إصدار قادم | Tooltip and screen-reader hint on every control whose feature is not built yet; the control stays visible and disabled (brief, design gap G10). Keep it short: it appears in a small tooltip bubble. |
| `windowMinimize` | Minimize | Simge durumuna küçült | تصغير | Tooltip and screen-reader name of the window's minimize caption button on Windows and Linux (FmWindow t.minimize). Use the operating system's own word for this button. |
| `windowMaximize` | Maximize | Ekranı kapla | تكبير | Tooltip and screen-reader name of the window's maximize caption button on Windows and Linux (FmWindow t.maximize). Use the operating system's own word for this button. |
| `windowRestore` | Restore | Geri yükle | استعادة | Tooltip and screen-reader name of the maximize caption button while the window is maximized: it returns the window to its previous size. Not in the design; use the operating system's own word (Windows: Restore). |
| `windowClose` | Close | Kapat | إغلاق | Tooltip and screen-reader name of the window's close caption button on Windows and Linux (FmWindow t.closeWin). Closes the window, not a document. |
| `languageAppLanguage` | App language | Uygulama dili | لغة التطبيق | Label of the app-language choice: the radio group of the first-run language picker (a1-1, aria-label) and the select in Settings › Language and region (a11-1b, FmSettings t.appLang). |
| `languageSystem` | System language | Sistem dili | لغة النظام | Caption beside the language that is the operating system's language, in the first-run language picker (a1-1, LANGS\[0\]). Short: it sits at the end of a list row. |
| `languageNotTranslated` | Not translated yet | Henüz çevrilmedi | لم تُترجم بعد | Caption on a language that has no translation yet; choosing it shows the interface in English until volunteers translate it (design gap G20). Short: it sits at the end of a list row. |
| `languageOptionNotTranslated` | {language} · Not translated yet | {language} · Henüz çevrilmedi | {language} · لم تُترجم بعد | One option of the app-language list in Settings › Language and region for a language that has no translation yet: the language's own name, then the not-translated caption (design gap G20). Choosing it shows the interface in English until volunteers translate it. You may change the separator or put the caption first. |
| `languageNameEnglish` | English | İngilizce | الإنجليزية | The English language, named in the interface language: a document-language badge in Settings › Language and region (a11-1b, FmSettings t.en). |
| `languageNameTurkish` | Turkish | Türkçe | التركية | The Turkish language, named in the interface language: a document-language badge in Settings › Language and region (a11-1b, FmSettings t.tr). |
| `languageNameArabic` | Arabic | Arapça | العربية | The Arabic language, named in the interface language: a document-language badge in Settings › Language and region (a11-1b). |
| `onboardingLanguageTitle` | Choose a language | Bir dil seçin | اختر لغة | Heading of the first-run language picker (a1-1). |
| `onboardingLanguageSubtitleSystem` | {language} is selected because it’s your system language. You can change it any time in Settings › Language and region. | {language} sistem diliniz olduğu için seçildi. Bunu istediğiniz zaman Ayarlar › Dil ve bölge bölümünden değiştirebilirsiniz. | اختيرت {language} لأنها لغة نظامك. يمكنك تغييرها في أي وقت من الإعدادات › اللغة والمنطقة. | Text under the heading of the first-run language picker (a1-1) while the selected language is the operating system's. {language} is the language's own name, such as English or Türkçe. Settings › Language and region names the settings pane; keep the › separator. |
| `onboardingLanguageSubtitle` | You can change it any time in Settings › Language and region. | Bunu istediğiniz zaman Ayarlar › Dil ve bölge bölümünden değiştirebilirsiniz. | يمكنك تغييرها في أي وقت من الإعدادات › اللغة والمنطقة. | Text under the heading of the first-run language picker (a1-1) once a language other than the system's is selected. Settings › Language and region names the settings pane; keep the › separator. |
| `onboardingLanguageSearchPlaceholder` | Search languages · Dil ara · Sprache suchen · ابحث عن لغة | Dil ara · Search languages · Sprache suchen · ابحث عن لغة | ابحث عن لغة · Search languages · Dil ara · Sprache suchen | Placeholder of the search field of the first-run language picker (a1-1). It asks in several languages on purpose, so people who don't read the interface language can still find theirs: keep the other languages and put this language's phrase first. |
| `onboardingLanguageSearchPlaceholderPhone` | Search · Ara · Suchen · بحث | Ara · Search · Suchen · بحث | بحث · Search · Ara · Suchen | Placeholder of the language search field at phone width (board a13-1b): the shorter form that fits one line. It shows the word in several languages on purpose, this language first. |
| `onboardingLanguageSearchLabel` | Search languages | Dil ara | ابحث عن لغة | Screen-reader name of the search field of the first-run language picker (a1-1). |
| `onboardingLanguageNoMatch` | No language matches “{query}”. | “{query}” ile eşleşen dil yok. | لا توجد لغة تطابق «{query}». | Shown in the first-run language picker (a1-1) when the search finds no language. {query} is what the person typed. |
| `onboardingLanguageNoMatchBody` | Search by the language’s own name, its English name or its code. | Dilin kendi adıyla, İngilizce adıyla ya da koduyla arayın. | ابحث باسم اللغة بلغتها أو باسمها الإنجليزي أو برمزها. | The line under onboardingLanguageNoMatch in the first-run language picker's empty state (a1-1, a2-3m's EmptyState). |
| `onboardingLanguageMissing` | Missing your language? | Dilinizi bulamadınız mı? | لم تجد لغتك؟ | Footer of the first-run language picker (a1-1), before the Help translate Ferman link. |
| `onboardingLanguageHelpTranslate` | Help translate Ferman | Ferman’ı çevirmeye yardım edin | ساعد في ترجمة Ferman | Link in the footer of the first-run language picker (a1-1) to the community translation project. |
| `onboardingContinue` | Continue | Devam | متابعة | Button that leaves the first-run language picker for the welcome steps (a1-1). |
| `onboardingStep` | {step} of {count} | {step} / {count} | {step} من {count} | Step counter above the heading of a first-run welcome step (a1-2b, a1-2c), such as 1 of 2. The numbers come already formatted for the region. |
| `onboardingStepLabel` | Step {step} of {count} | Adım {step}, toplam {count} | الخطوة {step} من {count} | Screen-reader name of the step dots at the bottom of a first-run welcome step (a1-2b, a1-2c). The numbers come already formatted for the region. |
| `onboardingSkip` | Skip | Atla | تخطّي | Button at the bottom start of a first-run welcome step that goes straight to the start screen (a1-2b). |
| `onboardingBack` | Back | Geri | رجوع | Button that returns to the previous first-run step (a1-2b, a1-2c). |
| `onboardingNext` | Next | İleri | التالي | Button that moves to the next first-run welcome step (a1-2b). |
| `onboardingStartUsing` | Start using Ferman | Ferman’ı kullanmaya başla | بدء استخدام Ferman | Button on the last first-run welcome step that ends first run and opens the start screen (a1-2c). |
| `onboardingEditTitle` | Edit any PDF like a document | Her PDF’i bir belge gibi düzenleyin | حرّر أي ملف PDF كما لو كان مستندًا | Heading of the first-run editing step (a1-2a). |
| `onboardingEditBody` | Click any text and type. Ferman keeps the original font, size and spacing, and reflows the paragraph inside its frame. | Herhangi bir metne tıklayıp yazın. Ferman özgün yazı tipini, boyutu ve aralıkları korur, paragrafı çerçevesinin içinde yeniden yerleştirir. | انقر أي نص واكتب. يحافظ Ferman على الخط الأصلي وحجمه وتباعده، ويعيد توزيع الفقرة داخل إطارها. | First paragraph of the first-run editing step (a1-2a). |
| `onboardingEditGlyphs` | When a font is missing a character, Ferman tells you which one and what it will use instead. | Bir yazı tipinde bir karakter eksikse Ferman hangisi olduğunu ve yerine ne kullanacağını söyler. | عندما يفتقد الخط حرفًا ما، يخبرك Ferman بهذا الحرف وبما سيستخدمه بدلًا منه. | Second paragraph of the first-run editing step (a1-2a). |
| `onboardingPrivacyTitle` | Everything stays on your device | Her şey cihazınızda kalır | يبقى كل شيء على جهازك | Heading of the first-run privacy step (a1-2b). |
| `onboardingPrivacyBody` | Ferman opens, edits, signs and recognizes text on this computer. There’s no account to create and nothing to upload. | Ferman belgeleri bu bilgisayarda açar, düzenler, imzalar ve metinlerini tanır. Hesap oluşturmanız ya da internete bir şey yüklemeniz gerekmez. | على هذا الجهاز، يفتح Ferman المستندات ويحرّرها ويوقّعها ويتعرّف على نصوصها. لا حاجة إلى إنشاء حساب أو رفع أي شيء. | Text under the heading of the first-run privacy step (a1-2b). |
| `onboardingPrivacyFilesTitle` | Files stay on this device | Dosyalar bu cihazda kalır | تبقى الملفات على هذا الجهاز | Title of a privacy fact on the first-run privacy step (a1-2b). |
| `onboardingPrivacyFilesBody` | Ferman reads and writes files where they are. Nothing is uploaded. | Ferman dosyaları bulundukları yerde okur ve kaydeder. Hiçbir şey internete yüklenmez. | يقرأ Ferman الملفات ويحفظها في أماكنها. لا يُرفع أي شيء. | Text of the privacy fact Files stay on this device (a1-2b). |
| `onboardingPrivacyOfflineTitle` | Works offline | Çevrimdışı çalışır | يعمل دون اتصال | Title of a privacy fact on the first-run privacy step (a1-2b). |
| `onboardingPrivacyOfflineBody` | Editing, OCR, signing and conversion need no connection. | Düzenleme, OCR, imzalama ve dönüştürme için internet bağlantısı gerekmez. | لا يحتاج التحرير والتعرّف على النص (OCR) والتوقيع والتحويل إلى اتصال بالإنترنت. | Text of the privacy fact Works offline (a1-2b). OCR is optical character recognition. |
| `onboardingPrivacyAccountTitle` | No account | Hesap yok | بلا حساب | Title of a privacy fact on the first-run privacy step (a1-2b). |
| `onboardingPrivacyAccountBody` | There’s nothing to sign up for and nothing to sign in to. | Kaydolmanız ya da oturum açmanız gerekmez. | لا حاجة إلى التسجيل ولا إلى تسجيل الدخول. | Text of the privacy fact No account (a1-2b). |
| `onboardingPrivacyTelemetryTitle` | No telemetry | Telemetri yok | بلا قياس عن بُعد | Title of a privacy fact on the first-run privacy step (a1-2b). |
| `onboardingPrivacyTelemetryBody` | Ferman doesn’t collect usage data or crash reports. | Ferman kullanım verileri veya çökme raporları toplamaz. | لا يجمع Ferman بيانات الاستخدام ولا تقارير الأعطال. | Text of the privacy fact No telemetry (a1-2b). |
| `onboardingPrivacyUpdatesTitle` | One optional check for updates | İsteğe bağlı tek bir güncelleme denetimi | فحص اختياري واحد للتحديثات | Title of the first of the four times Ferman uses the network, on the first-run privacy step (a1-2b, design gap G24). |
| `onboardingPrivacyUpdatesBody` | Once a day, sending only the version number and platform. You can turn it off. | Günde bir kez; yalnızca sürüm numarası ve işletim sistemi gönderilir. Kapatabilirsiniz. | مرة واحدة يوميًا، ولا يُرسَل سوى رقم الإصدار ونظام التشغيل. يمكنك إيقافه. | Text of the update-check row on the first-run privacy step (a1-2b, G24). Platform means the operating system. |
| `onboardingPrivacyPacksTitle` | OCR language packs | OCR dil paketleri | حزم لغات OCR | Title of the network use for downloading text-recognition (OCR) language packs, on the first-run privacy step (a1-2b, G24). Name OCR packs: the interface languages are bundled with the app and never downloaded (G52). |
| `onboardingPrivacyPacksBody` | Downloaded only when you choose to. Off until you use it. | Yalnızca siz istediğinizde indirilir. Kullanmadığınız sürece kapalıdır. | لا تُنزَّل إلا عندما تختار ذلك. معطّلة حتى تستخدمها. | Text of the language-pack row on the first-run privacy step (a1-2b, G24). |
| `onboardingPrivacyAiTitle` | AI assistant | Yapay zekâ yardımcısı | المساعد الذكي | Title of the network use of the optional AI assistant, on the first-run privacy step (a1-2b, G24). Same words as the AI assistant settings pane. |
| `onboardingPrivacyAiBody` | Runs on this computer, or uses your own API key. Off until you use it. | Bu bilgisayarda çalışır ya da kendi API anahtarınızı kullanır. Kullanmadığınız sürece kapalıdır. | يعمل على هذا الجهاز أو يستخدم مفتاح API الخاص بك. معطّل حتى تستخدمه. | Text of the AI row on the first-run privacy step (a1-2b, G24): the assistant runs a local model, or sends questions to a provider with the person's own key. |
| `onboardingPrivacyTimestampsTitle` | Signature timestamps | İmza zaman damgaları | الطوابع الزمنية للتوقيعات | Title of the network use for timestamp servers when signing, on the first-run privacy step (a1-2b, G24). |
| `onboardingPrivacyTimestampsBody` | Contacts the timestamp server you chose when you sign. Off until you use it. | İmzaladığınızda seçtiğiniz zaman damgası sunucusuna bağlanır. Kullanmadığınız sürece kapalıdır. | يتصل بخادم الطوابع الزمنية الذي اخترته عند التوقيع. معطّل حتى تستخدمه. | Text of the timestamp row on the first-run privacy step (a1-2b, G24). |
| `onboardingPrivacySettingsLink` | See every connection in Settings › Privacy | Tüm ağ bağlantılarını Ayarlar › Gizlilik bölümünde görün | عرض كل الاتصالات في الإعدادات › الخصوصية | Link at the bottom of the first-run privacy step that opens Settings › Privacy (a1-2b, G24). Keep the › separator. |
| `onboardingFreeTitle` | Free forever, nothing locked | Sonsuza dek ücretsiz, hiçbir şey kilitli değil | مجاني إلى الأبد، ولا شيء مقفل | Heading of the last first-run welcome step (a1-2c). |
| `onboardingFreeBody` | Every feature is included, with no trial, no subscription and no paid tier. Ferman is open source, so anyone can read, check and improve the code. | Tüm özellikler dâhildir; deneme süresi, abonelik ya da ücretli sürüm yoktur. Ferman açık kaynaklıdır, bu yüzden herkes kodunu okuyabilir, denetleyebilir ve geliştirebilir. | كل الميزات مضمّنة، دون فترة تجريبية أو اشتراك أو باقة مدفوعة. Ferman مفتوح المصدر، لذا يمكن لأي شخص قراءة شيفرته وفحصها وتحسينها. | Text under the heading of the last first-run welcome step (a1-2c). |
| `onboardingFreeLicence` | Licence: Apache-2.0 | Lisans: Apache-2.0 | الترخيص: Apache-2.0 | The software licence on the last first-run welcome step (a1-2c, design gap G13). Apache-2.0 is the licence's name: do not translate it. |
| `onboardingFreeSourceCode` | Source code | Kaynak kodu | الشيفرة المصدرية | Link to Ferman's source code on the last first-run welcome step (a1-2c). |
| `onboardingFreeSupport` | Support the project | Projeyi destekleyin | دعم المشروع | Link to ways of supporting Ferman on the last first-run welcome step (a1-2c). |
| `onboardingFeatureEditing` | Edit text | Metin düzenleme | تحرير النصوص | Feature tile on the last first-run welcome step (a1-2c). |
| `onboardingFeatureOcr` | Text recognition (OCR) | Metin tanıma (OCR) | التعرّف على النص (OCR) | Feature tile on the last first-run welcome step (a1-2c). OCR is optical character recognition. |
| `onboardingFeatureFillSign` | Fill and sign forms | Form doldurma ve imzalama | تعبئة النماذج وتوقيعها | Feature tile on the last first-run welcome step (a1-2c). |
| `onboardingFeatureSignatures` | e-imza and digital signatures | e-imza ve dijital imzalar | e-imza والتوقيعات الرقمية | Feature tile on the last first-run welcome step (a1-2c). e-imza is the Turkish electronic signature: keep the word. |
| `onboardingFeatureRedaction` | Redaction | Karartma | حجب المحتوى | Feature tile on the last first-run welcome step (a1-2c): removing confidential content for good. |
| `onboardingFeatureConvert` | Convert to and from Office | Office’e ve Office’ten dönüştürme | التحويل من Office وإليه | Feature tile on the last first-run welcome step (a1-2c): Word, Excel and PowerPoint files. |
| `onboardingFeatureCompare` | Compare documents | Belge karşılaştırma | مقارنة المستندات | Feature tile on the last first-run welcome step (a1-2c). |
| `onboardingFeatureBatch` | Batch actions | Toplu işlemler | إجراءات مجمّعة | Feature tile on the last first-run welcome step (a1-2c): one action on many files. |
| `onboardingFeatureAccessibility` | Accessibility checker | Erişilebilirlik denetleyicisi | مدقّق إمكانية الوصول | Feature tile on the last first-run welcome step (a1-2c). |
| `onboardingFeatureLanguages` | {count, plural, =1{{formatted} interface language} other{{formatted} interface languages}} | {count, plural, =1{{formatted} arayüz dili} other{{formatted} arayüz dili}} | {count, plural, zero{{formatted} لغة للواجهة} one{لغة واحدة للواجهة} two{لغتان للواجهة} few{{formatted} لغات للواجهة} many{{formatted} لغة للواجهة} other{{formatted} لغة للواجهة}} | Feature tile on the last first-run welcome step (a1-2c) with the number of languages the interface is translated into (design gap G20). {formatted} is the number written for the region; {count} picks the plural form. |
| `onboardingFeatureIncluded` | Included | Dâhil | مضمّنة | Screen-reader name of the green check on a feature tile whose feature this version has (a1-2c). |
| `startOpenFile` | Open file… | Dosya aç… | فتح ملف… | Title of the first action card on the start screen (a1-5, FmStart open). The ellipsis says that a file chooser follows. |
| `startOpenFileDescription` | PDF files | PDF dosyaları | ملفات PDF | Description of the Open file action card on the start screen (a1-5). Speaks of PDFs only until conversion exists (design gap G11). |
| `startCreatePdf` | Create PDF | PDF oluştur | إنشاء PDF | Title of an action card on the start screen (a1-5, FmStart create). |
| `startCreatePdfDescription` | From a blank page, files or the clipboard | Boş bir sayfadan, dosyalardan veya panodan | من صفحة فارغة أو ملفات أو الحافظة | Description of the Create PDF action card on the start screen (a1-5). |
| `startCombineFiles` | Combine files | Dosyaları birleştir | دمج الملفات | Title of an action card on the start screen (a1-5, FmStart combine). |
| `startCombineFilesDescription` | Merge several files into one PDF | Birden çok dosyayı tek bir PDF’de birleştirin | دمج عدة ملفات في ملف PDF واحد | Description of the Combine files action card on the start screen (a1-5). |
| `startScanToPdf` | Scan to PDF | PDF olarak tara | مسح ضوئي إلى PDF | Title of an action card on the start screen (a1-5, FmStart scan). |
| `startScanToPdfDescription` | From a scanner or a phone camera | Tarayıcıdan veya telefon kamerasından | من ماسح ضوئي أو كاميرا الهاتف | Description of the Scan to PDF action card on the start screen (a1-5). |
| `startQuickTools` | Quick tools | Hızlı araçlar | أدوات سريعة | Label before the row of quick-tool buttons on the start screen (a1-5, FmStart quick). |
| `startToolCompress` | Compress | Sıkıştır | ضغط | Quick-tool button on the start screen: make a PDF smaller (a1-5). |
| `startToolConvert` | Convert | Dönüştür | تحويل | Quick-tool button on the start screen: convert to or from PDF (a1-5). |
| `startToolSign` | Sign | İmzala | توقيع | Quick-tool button on the start screen: sign a PDF (a1-5). |
| `startToolOcr` | Recognize text (OCR) | Metni tanı (OCR) | التعرّف على النص (OCR) | Quick-tool button on the start screen: make scanned text selectable (a1-5). OCR is optical character recognition. |
| `startToolProtect` | Protect | Koru | حماية | Quick-tool button on the start screen: passwords and permissions (a1-5). |
| `startToolCompare` | Compare | Karşılaştır | مقارنة | Quick-tool button on the start screen: compare two versions of a document (a1-5). |
| `startDropTitle` | Drop a PDF here | PDF’yi buraya bırakın | أفلت ملف PDF هنا | Headline of the drop area of the empty start screen (a1-5, FmStart emptyTitle). |
| `startDropSubtitle` | or open one from your computer. | veya bilgisayarınızdan bir PDF açın. | أو افتح ملفًا من جهازك. | Text under Drop a PDF here on the empty start screen (a1-5). Speaks of PDFs only until conversion exists (design gap G11). |
| `startDropFootnote` | Files stay on this device. Ferman never uploads them. | Dosyalar bu cihazda kalır. Ferman onları hiçbir yere yüklemez. | تبقى الملفات على هذا الجهاز. | Note at the bottom of the drop area of the empty start screen (a1-5, FmStart emptyFoot). |
| `startOpenPdf` | Open a PDF | PDF aç | فتح ملف PDF | Main button of the drop area of the empty start screen (a1-5, DropZone). |
| `startNewBlankPdf` | New blank PDF | Yeni boş PDF | ملف PDF فارغ جديد | Second button of the drop area of the empty start screen (a1-5, DropZone). |
| `startEngineUnavailableTitle` | Ferman can’t open PDF files right now. | Ferman şu anda PDF dosyalarını açamıyor. | يتعذّر على Ferman فتح ملفات PDF حاليًا. | Title of the warning banner at the top of the start screen when the engine library or PDFium, the page renderer, is missing or broken (G101). Opening files stays off, with this title as the reason. |
| `startEngineUnavailableMessage` | A part of Ferman is missing or doesn’t match this version. Installing Ferman again fixes this. | Ferman’ın bir parçası eksik ya da bu sürümle uyuşmuyor. Ferman’ı yeniden yüklemek bunu düzeltir. | أحد أجزاء Ferman مفقود أو لا يطابق هذا الإصدار. تُصلح إعادة تثبيت Ferman ذلك. | Message of the warning banner at the top of the start screen when Ferman cannot open PDF files because a part of the app is missing or broken (G101). |
| `startCopyTechnicalDetails` | Copy technical details | Teknik ayrıntıları kopyala | نسخ التفاصيل التقنية | Button of the start screen’s warning banner (G101): copies the technical facts about the missing or broken part, in English, for a bug report (as a1-9b’s link). |
| `settingsTitle` | Settings | Ayarlar | الإعدادات | Heading of the settings window and screen-reader name of its pane list (a11-1, FmSettings t.settings). |
| `settingsSearch` | Search settings | Ayarlarda ara | البحث في الإعدادات | Placeholder and screen-reader name of the search field above the settings panes (a11-1). |
| `settingsClose` | Close settings | Ayarları kapat | إغلاق الإعدادات | Tooltip and screen-reader name of the button that closes settings and returns to where the person was. Settings opens inside the main window in this version. |
| `settingsSaveFailedTitle` | Your settings couldn’t be saved. | Ayarlarınız kaydedilemedi. | تعذّر حفظ إعداداتك. | Title of the warning banner at the top of Settings when a change could not be written to the settings file on this device. The change still applies while Ferman runs. |
| `settingsSaveFailedMessage` | This change applies until you close Ferman. | Bu değişiklik, Ferman’ı kapatana kadar geçerli. | يسري هذا التغيير حتى تُغلق Ferman. | Message of the warning banner at the top of Settings when a change could not be saved: the change is kept for this session only and is gone at the next start. |
| `settingsSaveFailedDismiss` | Dismiss | Kapat | تجاهل | Screen-reader name of the button that hides the could-not-save banner in Settings. |
| `settingsPaneGeneral` | General | Genel | عام | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPaneLanguage` | Language and region | Dil ve bölge | اللغة والمنطقة | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPaneEditing` | Editing | Düzenleme | التحرير | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPaneFonts` | Fonts | Yazı tipleri | الخطوط | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPaneSignatures` | Signatures and certificates | İmzalar ve sertifikalar | التوقيعات والشهادات | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPaneOcr` | Text recognition (OCR) | Metin tanıma (OCR) | التعرّف على النص (OCR) | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). OCR is optical character recognition. |
| `settingsPaneAi` | AI assistant | Yapay zekâ yardımcısı | المساعد الذكي | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPhoneGroupDocuments` | Documents | Belgeler | المستندات | Phone Settings: a group of the list (a13-15, shown in capitals) and a heading of Language and region (a13-15b). |
| `settingsPhoneGroupApp` | App | Uygulama | التطبيق | Phone Settings › Language and region: the heading over the app language (a13-15b). |
| `settingsPhoneGroupRegion` | Region | Bölge | المنطقة | Phone Settings › Language and region: the heading over the region formats (a13-15b). |
| `settingsPhonePrivacyValue` | No data collected | Veri toplanmaz | لا تُجمع أي بيانات | Phone Settings: the value of the Privacy row, which states the fact (a13-15). Keep it short. |
| `settingsPhoneAbout` | About and licence | Hakkında ve lisans | حول التطبيق والترخيص | Phone Settings: the row of About and the licences (a13-15). |
| `settingsPanePrivacy` | Privacy | Gizlilik | الخصوصية | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPaneUpdates` | Updates | Güncellemeler | التحديثات | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPaneShortcuts` | Keyboard shortcuts | Klavye kısayolları | اختصارات لوحة المفاتيح | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsPaneAdvanced` | Advanced | Gelişmiş | متقدّم | A settings pane: its row in the pane list and its heading (a11-1, FmSettings t.nav). |
| `settingsTheme` | Theme | Tema | المظهر | Label of the appearance choice in Settings › General (a11-1). |
| `settingsThemeSystem` | Match system | Sistemle aynı | حسب النظام | Theme choice in Settings › General: follow the operating system's light or dark appearance (a11-1). |
| `settingsThemeLight` | Light | Açık | فاتح | Theme choice in Settings › General (a11-1). |
| `settingsThemeDark` | Dark | Koyu | داكن | Theme choice in Settings › General (a11-1). |
| `settingsPageTheme` | PDF pages in dark theme | Koyu temada PDF sayfaları | صفحات PDF في المظهر الداكن | Label of the choice of how PDF pages look while the dark theme is on, in Settings › General (a11-1). |
| `settingsPagePaper` | Paper white | Kâğıt beyazı | أبيض كالورق | Choice under PDF pages in dark theme (a11-1). |
| `settingsPagePaperDescription` | Pages look exactly as printed. | Sayfalar tam olarak basıldığı gibi görünür. | تظهر الصفحات تمامًا كما تُطبع. | Description of the choice Paper white (a11-1). |
| `settingsPageDimmed` | Dimmed | Kısık parlaklık | خافت | Choice under PDF pages in dark theme (a11-1). |
| `settingsPageDimmedDescription` | Slightly darker with a trace of sepia. Colours aren’t inverted. | Hafif sepya tonuyla biraz daha koyu. Renkler ters çevrilmez. | أغمق قليلًا مع مسحة من لون السيبيا. لا تُعكس الألوان. | Description of the choice Dimmed (a11-1). |
| `settingsPageDark` | Dark reading mode | Koyu okuma modu | وضع القراءة الداكن | Choice under PDF pages in dark theme (a11-1). |
| `settingsPageDarkDescription` | Light text on dark pages. Images keep their colours. Never printed. | Koyu sayfalarda açık renkli metin. Görseller renklerini korur. Baskıya yansımaz. | نص فاتح على صفحات داكنة. تحتفظ الصور بألوانها. لا يُطبَّق عند الطباعة. | Description of the choice Dark reading mode (a11-1). |
| `settingsPageLayout` | Page layout for new documents | Yeni belgeler için sayfa düzeni | تخطيط الصفحة للمستندات الجديدة | Label of a select in Settings › General (a11-1). |
| `settingsPageLayoutScroll` | Continuous scroll | Sürekli kaydırma | تمرير متواصل | Option of Page layout for new documents (a11-1). |
| `settingsPageLayoutSingle` | Single page | Tek sayfa | صفحة واحدة | Option of Page layout for new documents (a11-1). |
| `settingsPageLayoutSpread` | Two-page spread | İki sayfa yan yana | صفحتان متجاورتان | Option of Page layout for new documents (a11-1). |
| `settingsZoom` | Zoom | Yakınlaştırma düzeyi | مستوى التكبير | Label of the default-zoom select in Settings › General (a11-1). |
| `settingsZoomFitWidth` | Fit width | Genişliğe sığdır | ملاءمة عرض الصفحة | Option of Zoom: the page fills the window's width (a11-1). |
| `settingsZoomFitPage` | Fit page | Sayfaya sığdır | ملاءمة الصفحة | Option of Zoom: the whole page fits in the window (a11-1). |
| `settingsReopen` | Reopen documents from last time | Son oturumdaki belgeleri yeniden aç | إعادة فتح مستندات الجلسة الأخيرة | Switch in Settings › General (a11-1). |
| `settingsDefaultApp` | Ferman can be the app that opens when you double-click a PDF. | Ferman, bir PDF’ye çift tıkladığınızda açılan uygulama olabilir. | يمكن أن يكون Ferman التطبيق الذي يُفتح عند النقر المزدوج على ملف PDF. | Text beside the Make Ferman the default button in Settings › General (from the default-app dialog, a1-3). |
| `settingsDefaultAppWindows` | Ferman can be the app that opens when you double-click a PDF. Windows lets you choose it in Settings › Default apps. | Ferman, bir PDF’ye çift tıkladığınızda açılan uygulama olabilir. Windows’ta bunu Ayarlar › Varsayılan uygulamalar bölümünden seçebilirsiniz. | يمكن أن يكون Ferman التطبيق الذي يُفتح عند النقر المزدوج على ملف PDF. يتيح لك Windows اختياره من الإعدادات › التطبيقات الافتراضية. | Text beside the Make Ferman the default button in Settings › General on Windows (a11-1w), instead of settingsDefaultApp: Windows does not let apps make themselves the default, so the button opens Windows Settings › Default apps (design gap G16). Use the names of the Windows Settings pages in your language. |
| `settingsMakeDefault` | Make Ferman the default… | Ferman’ı varsayılan yap… | تعيين Ferman كتطبيق افتراضي… | Button in Settings › General that makes Ferman the app that opens PDFs (a11-1). The ellipsis says that the system asks to confirm. |
| `settingsAppLanguageHint` | Ferman switches right away. No restart needed. | Ferman dili hemen değiştirir. Yeniden başlatmanız gerekmez. | يتغيّر Ferman فورًا دون إعادة تشغيل. | Hint under the app-language select in Settings › Language and region (a11-1b, FmSettings t.appLangHint). |
| `settingsDocumentLanguages` | Document languages | Belge dilleri | لغات المستندات | Label of the languages used for documents that don't name theirs, in Settings › Language and region (a11-1b, FmSettings t.docLang). |
| `settingsDocumentLanguagesHint` | Used for text recognition, spell-check and hyphenation when a document doesn’t say its language. | Bir belge dilini belirtmediğinde metin tanıma, yazım denetimi ve tireleme için kullanılır. | تُستخدم للتعرّف على النص والتدقيق الإملائي والوصل بشرطة عندما لا يحدّد المستند لغته. | Hint under Document languages in Settings › Language and region (a11-1b, FmSettings t.docLangHint). |
| `settingsAddDocumentLanguage` | Add | Ekle | إضافة | Button that adds a document language in Settings › Language and region (a11-1b, FmSettings t.add). |
| `settingsPrivacyStatement` | Ferman collects nothing. | Ferman hiçbir şey toplamaz. | لا يجمع Ferman أي شيء. | Statement at the top of Settings › Privacy (a11-1h). |
| `settingsPrivacyStatementBody` | No usage data, no crash reports, no document contents, no account. Files stay on this device. These are the only times Ferman connects to the internet, and each can be turned off: | Kullanım verisi, çökme raporu, belge içeriği ya da hesap yok. Dosyalar bu cihazda kalır. Ferman yalnızca şu durumlarda internete bağlanır ve her birini kapatabilirsiniz: | لا بيانات استخدام، ولا تقارير أعطال، ولا محتوى مستندات، ولا حساب. تبقى الملفات على هذا الجهاز. هذه هي الحالات الوحيدة التي يتصل فيها Ferman بالإنترنت، ويمكن إيقاف كلٍّ منها: | Text under Ferman collects nothing. in Settings › Privacy, before the list of network uses (a11-1h). |
| `settingsNetUpdates` | Check for updates | Güncellemeleri denetle | التحقق من وجود تحديثات | A network use in Settings › Privacy (a11-1h). |
| `settingsNetUpdatesDescription` | Once a day; sends only the version number and platform. | Günde bir kez; yalnızca sürüm numarasını ve işletim sistemini gönderir. | مرة واحدة يوميًا؛ يُرسل رقم الإصدار ونظام التشغيل فقط. | Description of Check for updates in Settings › Privacy (a11-1h). Platform means the operating system. |
| `settingsNetSignatureChecks` | Signature checks | İmza denetimleri | التحقق من التوقيعات | A network use in Settings › Privacy (a11-1h): asking whether a certificate was revoked. Not enabled until the owner decides (design gap G51). |
| `settingsNetSignatureChecksDescription` | Asks the certificate provider whether a certificate was revoked, when you sign or open a signed file. | İmzaladığınızda veya imzalı bir dosya açtığınızda, sertifika sağlayıcısına sertifikanın iptal edilip edilmediğini sorar. | يسأل مزوّد الشهادة عمّا إذا كانت الشهادة قد أُبطلت، عند التوقيع أو فتح ملف موقّع. | Description of Signature checks in Settings › Privacy (a11-1h). |
| `settingsNetTimestamps` | Timestamps | Zaman damgaları | الطوابع الزمنية | A network use in Settings › Privacy (a11-1h). |
| `settingsNetTimestampsDescription` | Contacts the timestamp server you chose when you sign. | İmzaladığınızda seçtiğiniz zaman damgası sunucusuna bağlanır. | يتصل بخادم الطوابع الزمنية الذي اخترته عند التوقيع. | Description of Timestamps in Settings › Privacy (a11-1h). |
| `settingsNetDownloads` | Downloads you start | Başlattığınız indirmeler | التنزيلات التي تبدؤها | A network use in Settings › Privacy (a11-1h). |
| `settingsNetDownloadsDescription` | OCR language packs and the assistant’s model. | OCR dil paketleri ve yapay zekâ yardımcısının modeli. | حزم لغات OCR ونموذج المساعد الذكي. | Description of Downloads you start in Settings › Privacy (a11-1h). OCR is optical character recognition; the assistant is the AI assistant. |
| `settingsNetAiProvider` | Your AI provider | Yapay zekâ sağlayıcınız | مزوّد الذكاء الاصطناعي الخاص بك | A network use in Settings › Privacy (a11-1h). |
| `settingsNetAiProviderDescription` | Only if you add your own API key. Off. | Yalnızca kendi API anahtarınızı eklerseniz. Kapalı. | فقط إذا أضفت مفتاح API الخاص بك. معطّل. | Description of Your AI provider in Settings › Privacy (a11-1h). |
| `settingsNetworkActivity` | Show network activity… | Ağ etkinliğini göster… | عرض نشاط الشبكة… | Button in Settings › Privacy that lists the connections Ferman made (a11-1h). |
| `regionFormats` | Region formats | Bölge biçimleri | تنسيقات المنطقة | Label of the region select in Settings › Language and region: the region drives dates, numbers, paper size, units and the first day of the week (a11-1b, FmSettings t.region). |
| `regionPaperSize` | Paper size | Kâğıt boyutu | حجم الورق | Label in Settings › Language and region (a11-1b, FmSettings t.paper). |
| `regionPaperA4` | A4 | A4 | A4 | The ISO A4 paper size (a11-1b). Usually kept as A4. |
| `regionPaperLetter` | Letter | Letter | Letter | The US Letter paper size (a11-1b). |
| `regionUnits` | Units | Birimler | الوحدات | Label of the length-unit choice in Settings › Language and region (a11-1b, FmSettings t.units). |
| `regionFirstDay` | First day of the week | Haftanın ilk günü | أول أيام الأسبوع | Label in Settings › Language and region (a11-1b, FmSettings t.week). |
| `regionMonday` | Monday | Pazartesi | الاثنين | Option of First day of the week (a11-1b). |
| `regionSunday` | Sunday | Pazar | الأحد | Option of First day of the week (a11-1b). |
| `regionSaturday` | Saturday | Cumartesi | السبت | Option of First day of the week (a11-1b). |
| `regionFriday` | Friday | Cuma | الجمعة | Option of First day of the week, shown for regions whose week starts on Friday (a11-1b, design gap G34). |
| `regionExamples` | Examples | Örnekler | أمثلة | Heading of the box of example values in Settings › Language and region; shown in capitals (a11-1b, FmSettings t.example). |
| `regionExampleDate` | Date | Tarih | التاريخ | Row of the examples box: a date in the region's format (a11-1b). |
| `regionExampleTime` | Time | Saat | الوقت | Row of the examples box: a time in the region's format (a11-1b). |
| `regionExampleNumber` | Number | Sayı | الرقم | Row of the examples box: a number in the region's format (a11-1b). |
| `regionExampleFontSize` | Font size | Yazı tipi boyutu | حجم الخط | Row of the examples box: a font size in the region's format (a11-1b). |
| `viewerPageFailed` | Ferman couldn’t draw page {page}. | Ferman {page}. sayfayı çizemedi. | تعذّر على Ferman عرض الصفحة {page}. | Canvas: the title of the placeholder of a page that failed to render (a2-13, G30). {page} is the page number, already formatted for the region. |
| `viewerPageFailedReason` | Something on this page can’t be read. The rest of the document works as usual. | Bu sayfadaki bir öğe okunamıyor. Belgenin geri kalanı her zamanki gibi çalışır. | تعذّرت قراءة عنصر في هذه الصفحة. يعمل باقي المستند كالمعتاد. | Canvas: the plain reason under the title of a page that failed to render (a2-13). |
| `viewerTryAgain` | Try again | Yeniden dene | إعادة المحاولة | Canvas: the button that renders a failed page again (a2-13). |
| `viewerMarqueeZoom` | Release to zoom to {zoom} | {zoom} yakınlaştırmak için bırakın | أفلِت للتكبير إلى {zoom} | Canvas: the label beside the rectangle of Marquee zoom while it is dragged (a2-2). {zoom} is the zoom it gives, a percentage already formatted for the region, for example 180%. |
| `editHoverTip` | Click to edit · {block} | Düzenlemek için tıklayın · {block} | انقر للتحرير · {block} | Edit mode: the tooltip beside the pointer over an editable text block (a3-1a). {block} is the start of the block's first line, as the document writes it, for example Madde 3. |
| `editNotEditableTitle` | This text can’t be edited | Bu metin düzenlenemez | لا يمكن تحرير هذا النص | Edit mode: the title of the right panel's callout for text that cannot be edited (a3-19, G39). |
| `editTipImageOnly` | No text on this page yet · Recognize text to edit | Bu sayfada henüz metin yok · Düzenlemek için metni tanıyın | لا يوجد نص في هذه الصفحة بعد · تعرّف على النص لتحريره | Edit mode: the tooltip beside the pointer over a scanned page without text (a3-11). |
| `editBodyImageOnly` | This page is an image, such as a scan. Recognize its text to edit it. | Bu sayfa, taranmış bir belge gibi bir görüntü. Düzenlemek için metnini tanıyın. | هذه الصفحة صورة، مثل مستند ممسوح ضوئيًا. تعرّف على نصها لتحريرها. | Edit mode: the panel callout's message for a scanned page without text (a3-11, G39). |
| `editTipOutlinedText` | This text is drawn as shapes, so it can’t be edited | Bu metin şekillerle çizilmiş, düzenlenemez | هذا النص مرسوم كأشكال، فلا يمكن تحريره | Edit mode: the tooltip over text drawn as vector shapes (a3-19). |
| `editBodyOutlinedText` | This text is drawn as vector shapes, not letters. Ferman can’t change it without redrawing it. | Bu metin harflerle değil, vektör şekillerle çizilmiş. Ferman onu yeniden çizmeden değiştiremez. | هذا النص مرسوم كأشكال متجهة لا كحروف. لا يستطيع Ferman تغييره دون إعادة رسمه. | Edit mode: the panel callout's message for text drawn as vector shapes (a3-19). |
| `editTipUnknownText` | Ferman can’t read the letters of this text | Ferman bu metnin harflerini okuyamıyor | لا يستطيع Ferman قراءة حروف هذا النص | Edit mode: the tooltip over text whose glyphs have no Unicode mapping (G39). |
| `editBodyUnknownText` | Its font doesn’t say which letters its shapes stand for, so Ferman can’t change it safely. | Yazı tipi, şekillerinin hangi harfler olduğunu söylemiyor; Ferman onu güvenle değiştiremez. | لا يحدد خطه الحروف التي تمثلها أشكاله، لذا لا يستطيع Ferman تغييره بأمان. | Edit mode: the panel callout's message for text without a Unicode mapping (G39). |
| `editTipInvisibleText` | This text is invisible | Bu metin görünmez | هذا النص غير مرئي | Edit mode: the tooltip over invisible text, such as recognized text over a scan (G39). |
| `editBodyInvisibleText` | It’s hidden text, such as recognized text over a scan. Ferman doesn’t edit it. | Bu, taramanın üzerindeki tanınmış metin gibi gizli bir metin. Ferman onu düzenlemez. | إنه نص مخفي، مثل نص متعرَّف عليه فوق مستند ممسوح ضوئيًا. لا يحرره Ferman. | Edit mode: the panel callout's message for invisible text (G39). |
| `editTipRestricted` | The author’s permissions don’t allow editing | Yazarın izinleri düzenlemeye izin vermiyor | أذونات المؤلف لا تسمح بالتحرير | Edit mode: the tooltip over text of a document whose permissions forbid changes (G27, G39). |
| `editBodyRestricted` | Unlock the document with its owner password to edit it. | Düzenlemek için belgenin kilidini sahip parolasıyla açın. | افتح قفل المستند بكلمة مرور المالك لتحريره. | Edit mode: the panel callout's message for a restricted document (G27, G39). |
| `editTipReadOnly` | This document is read-only | Bu belge salt okunur | هذا المستند للقراءة فقط | Edit mode: the tooltip over text of a document Ferman opened read-only, such as an XFA form (G39). |
| `editBodyReadOnly` | Ferman opened this document for viewing only, so its text can’t be changed. | Ferman bu belgeyi yalnızca görüntülemek için açtı; metni değiştirilemez. | فتح Ferman هذا المستند للعرض فقط، لذا لا يمكن تغيير نصه. | Edit mode: the panel callout's message for a read-only document (G39). |
| `editTipDamaged` | This document was repaired, so it can’t be edited | Bu belge onarıldı, düzenlenemez | تم إصلاح هذا المستند، لذا لا يمكن تحريره | Edit mode: the tooltip over text of a repaired document, or one whose readers disagree (a1-9, G39). |
| `editBodyDamaged` | Ferman found problems in this file and opened it for viewing only. Save a repaired copy to edit it. | Ferman bu dosyada sorunlar buldu ve onu yalnızca görüntülemek için açtı. Düzenlemek için onarılmış bir kopyasını kaydedin. | وجد Ferman مشكلات في هذا الملف وفتحه للعرض فقط. احفظ نسخة مُصلَحة لتحريره. | Edit mode: the panel callout's message for a repaired document (a1-9, G39). |
| `editTipSignature` | This text is part of a signature | Bu metin bir imzanın parçası | هذا النص جزء من توقيع | Edit mode: the tooltip over text inside a signature field (G39). |
| `editBodySignature` | Ferman never edits signatures. | Ferman imzaları hiçbir zaman düzenlemez. | لا يحرر Ferman التوقيعات أبدًا. | Edit mode: the panel callout's message for text inside a signature field (G39). |
| `editTipAnnotation` | This text belongs to a comment or form field | Bu metin bir yoruma veya form alanına ait | هذا النص يتبع تعليقًا أو حقل نموذج | Edit mode: the tooltip over text inside an annotation or form field (G39). |
| `editBodyAnnotation` | Change it in Comment or Fill &amp; Sign mode. | Yorum veya Doldur ve İmzala modunda değiştirin. | غيّره في وضع التعليق أو التعبئة والتوقيع. | Edit mode: the panel callout's message for text inside an annotation or form field (G39). Use the mode names of the mode bar. |
| `editTipTooComplex` | Ferman can’t change this text safely | Ferman bu metni güvenle değiştiremez | لا يستطيع Ferman تغيير هذا النص بأمان | Edit mode: the tooltip over text the engine cannot rewrite safely (G39). |
| `editBodyLimits` | This page is too large or complex for Ferman to rewrite safely. | Bu sayfa, Ferman’ın güvenle yeniden yazması için fazla büyük veya karmaşık. | هذه الصفحة كبيرة أو معقدة جدًا ليعيد Ferman كتابتها بأمان. | Edit mode: the panel callout's message for a page that hit a resource limit (G39). |
| `editBodySplit` | Its drawing instructions are split across two parts of the page, so Ferman can’t rewrite it safely. | Çizim komutları sayfanın iki parçasına bölünmüş; Ferman onu güvenle yeniden yazamaz. | تعليمات رسمه مقسمة بين جزأين من الصفحة، لذا لا يستطيع Ferman إعادة كتابته بأمان. | Edit mode: the panel callout's message for text whose operator is split across two content streams (G39). |
| `editBodySkewed` | This text is slanted, so Ferman can’t rewrite it safely. | Bu metin eğik; Ferman onu güvenle yeniden yazamaz. | هذا النص مائل، لذا لا يستطيع Ferman إعادة كتابته بأمان. | Edit mode: the panel callout's message for sheared text (G39). |
| `viewerTextMenu` | Text | Metin | النص | Canvas: the accessible name of the context menu a right click opens on page text with the Select tool (B106). |
| `viewerPageNumber` | Page number | Sayfa numarası | رقم الصفحة | Status bar: the accessible name of the page field, which takes a page number or a page label (a2-13, ⌘G). |
| `sidebarPage` | Page {page} | Sayfa {page} | الصفحة {page} | Sidebar: a page thumbnail's accessible name and a signature field's page (a2-3p, a2-14). {page} is the page number formatted for the region, or the page's label such as iv. |
| `sidebarNoBookmarks` | No bookmarks | Yer işareti yok | لا توجد إشارات مرجعية | Sidebar › Outline: the title of the empty state when the document has no outline (a2-3m). |
| `sidebarNoBookmarksBody` | This document has no outline. Add a bookmark to mark a place you want to come back to. | Bu belgede yer işareti yok. Geri dönmek istediğiniz bir yeri işaretlemek için yer işareti ekleyin. | لا يحتوي هذا المستند على إشارات مرجعية. أضف إشارة لتعليم موضع تريد العودة إليه. | Sidebar › Outline: the line under the empty state's title (a2-3m). |
| `sidebarNoAttachments` | No attachments | Ek yok | لا توجد مرفقات | Sidebar › Attachments: the title of the empty state (a2-3m). |
| `sidebarNoAttachmentsBody` | Files embedded in this PDF appear here. | Bu PDF’ye gömülü dosyalar burada görünür. | تظهر هنا الملفات المضمّنة في ملف PDF هذا. | Sidebar › Attachments: the line under the empty state's title (a2-3m). |
| `sidebarNoLayers` | No layers | Katman yok | لا توجد طبقات | Sidebar › Layers: the title of the empty state (a2-3m). |
| `sidebarNoLayersBody` | This document has no layers to show or hide. | Bu belgede gösterilip gizlenebilecek katman yok. | لا يحتوي هذا المستند على طبقات يمكن إظهارها أو إخفاؤها. | Sidebar › Layers: the line under the empty state's title (a2-3m). |
| `sidebarNoSignatures` | No signatures | İmza yok | لا توجد توقيعات | Sidebar › Signatures: the title of the empty state (a2-3m). |
| `sidebarNoSignaturesBody` | This document isn’t signed and has no signature fields. | Bu belge imzalı değil ve imza alanı içermiyor. | هذا المستند غير موقّع ولا يحتوي على حقول توقيع. | Sidebar › Signatures: the line under the empty state's title (a2-3m). |
| `sidebarAttachmentsNote` | Attachments open in their own app. Ferman doesn’t run embedded files. | Ekler kendi uygulamalarında açılır. Ferman gömülü dosyaları çalıştırmaz. | تُفتح المرفقات في تطبيقاتها الخاصة. لا يشغّل Ferman الملفات المضمّنة. | Sidebar › Attachments: the note under the list (a2-3b). |
| `sidebarSaveAttachment` | Save attachment as… | Eki farklı kaydet… | حفظ المرفق باسم… | Sidebar › Attachments: the download button of an attachment, which saves it where the user picks (a2-3b). |
| `sidebarLayersNote` | Hidden layers still print unless you turn off “Print hidden layers” in Print. | Gizli katmanlar, Yazdır’da “Gizli katmanları yazdır” kapatılmadıkça yine de yazdırılır. | تُطبع الطبقات المخفية ما لم توقف «طباعة الطبقات المخفية» في نافذة الطباعة. | Sidebar › Layers: the note under the list (a2-3c). |
| `sidebarHideLayer` | Hide layer | Katmanı gizle | إخفاء الطبقة | Sidebar › Layers: the eye button of a shown layer (a2-3c). |
| `sidebarShowLayer` | Show layer | Katmanı göster | إظهار الطبقة | Sidebar › Layers: the eye button of a hidden layer (a2-3c). |
| `sidebarLayerLocked` | Locked | Kilitli | مقفلة | Sidebar › Layers: the accessible name of the lock beside a layer whose visibility the document locks (a2-3c). |
| `sidebarSignatureCheckingLater` | Signature checking is available in a future version. | İmza denetimi gelecek bir sürümde sunulacak. | التحقق من التوقيعات متاح في إصدار قادم. | Sidebar › Signatures: the line under a signer's name until signatures are checked (a2-14, design gap G31). |
| `sidebarEmptySignatureField` | Empty signature field | Boş imza alanı | حقل توقيع فارغ | Sidebar › Signatures: the line under an unsigned signature field's name (a2-14). |
| `findRegion` | Find and replace | Bul ve değiştir | بحث واستبدال | The find bar's accessible name (a2-4a, SearchReplaceBar). |
| `findField` | Find | Bul | بحث | The find field's placeholder and name (a2-4a). |
| `findReplaceWith` | Replace with | Şununla değiştir | استبدال بـ | The replace field's placeholder; replace comes in P2 (B045). |
| `findMatchCase` | Match case | Büyük/küçük harf duyarlı | مطابقة حالة الأحرف | Find option and toggle (a2-4a). |
| `findWholeWords` | Whole words | Tam sözcükler | كلمات كاملة | Find option and toggle (a2-4a). |
| `findRegex` | Regular expression | Düzenli ifade | تعبير نمطي | Find option and toggle (a2-4a); disabled for a future version. |
| `findShowReplace` | Show replace | Değiştirmeyi göster | إظهار الاستبدال | The find bar's disclosure while the replace row is hidden. |
| `findHideReplace` | Hide replace | Değiştirmeyi gizle | إخفاء الاستبدال | The find bar's disclosure while the replace row shows. |
| `findPrevious` | Previous match | Önceki eşleşme | التطابق السابق | The find bar's previous button (⇧↵). |
| `findNext` | Next match | Sonraki eşleşme | التطابق التالي | The find bar's next button (↵). |
| `findReplaceAll` | Replace all | Tümünü değiştir | استبدال الكل | The find bar's Replace all button; P2 (B045). |
| `findNoResults` | No results | Sonuç yok | لا نتائج | The find bar's count when nothing matches (a2-4d), in the danger colour. |
| `findOptions` | Search options | Arama seçenekleri | خيارات البحث | The group of match options under the find bar (a2-4a). |
| `findMatch` | Match | Eşleştirme | المطابقة | The options group's first heading (a2-4a, shown in capitals). |
| `findIgnoreAccents` | Ignore accents and dotted/dotless i | Aksanları ve noktalı/noktasız i’yi yok say | تجاهل علامات التشكيل والفرق بين i المنقوطة وغير المنقوطة | Find option, on by default (a2-4a, G61). |
| `findIgnoreAccentsBody` | “i” finds İ, ı and î; “c” finds ç; “kira” finds KİRA. On by default. | “i”; İ, ı ve î’yi bulur; “c”, ç’yi bulur; “kira”, KİRA’yı bulur. Varsayılan olarak açık. | «i» تجد İ وı وî؛ و«c» تجد ç؛ و«kira» تجد KİRA. مفعّل افتراضيًا. | The description under Ignore accents (a2-4a). |
| `findLookIn` | Look in | Şurada ara | البحث في | The options group's second heading (a2-4a, shown in capitals). |
| `findPageText` | Page text | Sayfa metni | نص الصفحة | Look in: the pages' text (a2-4a). |
| `findComments` | Comments | Yorumlar | التعليقات | Look in: comments already in the file (a2-4a). |
| `findFormFields` | Form fields | Form alanları | حقول النماذج | Look in: form field values (a2-4a). |
| `findBookmarks` | Bookmarks | Yer imleri | الإشارات المرجعية | Look in: bookmark titles (a2-4a). |
| `findSearchingBody` | Matches appear as they’re found. | Eşleşmeler bulundukça görünür. | تظهر النتائج فور العثور عليها. | Under a long search's progress (a2-4c). |
| `findCancel` | Cancel | İptal | إلغاء | Stops a long search (a2-4c), also Esc. |
| `findNoneAction` | Also search comments and fields | Yorumlarda ve alanlarda da ara | البحث في التعليقات والحقول أيضًا | No results: the action that widens the search (a2-4d). |
| `findCount` | {current} of {total} | {current} / {total} | {current} من {total} | The find bar's count, a polite live region (a2-4a); numbers in the region's format. |
| `statusSearching` | Searching | Aranıyor | جارٍ البحث | The status bar's inline task while a search runs (FmWindow task, B124), before "Page N of M". |
| `findSearching` | Searching · page {page} of {pages} | Aranıyor · sayfa {page} / {pages} | جارٍ البحث · الصفحة {page} من {pages} | A long search's progress (a2-4c); numbers in the region's format. |
| `findNoneTitle` | No results for “{query}” | “{query}” için sonuç yok | لا نتائج لـ«{query}» | No results: the title, with the query as typed (a2-4d). |
| `findNoneBody` | Ferman searched {count, plural, =1{the only page} other{all {pages} pages}}, ignoring accents and dotted/dotless i. Comments and form fields weren’t searched. | Ferman {count, plural, =1{tek sayfada} other{{pages} sayfanın tamamında}} aradı; aksanlar ve noktalı/noktasız i yok sayıldı. Yorumlar ve form alanları aranmadı. | بحث Ferman في {count, plural, =1{الصفحة الوحيدة} =2{الصفحتين كلتيهما} other{الصفحات الـ{pages} كلها}}، مع تجاهل علامات التشكيل والفرق بين i المنقوطة وغير المنقوطة. لم يُبحث في التعليقات وحقول النماذج. | No results: what was searched and how, with Ignore accents on (a2-4d). count is the page count, pages the same number in the region's format. |
| `findNoneBodyExact` | Ferman searched {count, plural, =1{the only page} other{all {pages} pages}}. Comments and form fields weren’t searched. | Ferman {count, plural, =1{tek sayfada} other{{pages} sayfanın tamamında}} aradı. Yorumlar ve form alanları aranmadı. | بحث Ferman في {count, plural, =1{الصفحة الوحيدة} =2{الصفحتين كلتيهما} other{الصفحات الـ{pages} كلها}}. لم يُبحث في التعليقات وحقول النماذج. | No results: what was searched, with Ignore accents off (a2-4d). count is the page count, pages the same number in the region's format. |
| `sidebarSearchField` | Search in document | Belgede ara | البحث في المستند | Sidebar › Search results: the field's accessible name (a2-3e). |
| `sidebarSearchBookmark` | Bookmark: {title} | Yer imi: {title} | إشارة مرجعية: {title} | Accessible name of a search result found in a bookmark's title (Look in › Bookmarks). |
| `sidebarSearchNoTextTitle` | No text to search | Aranacak metin yok | لا يوجد نص للبحث فيه | Sidebar › Search results: the title of the empty state when the document has no text layer, such as a scan (a2-3m). |
| `sidebarSearchNoTextBody` | These pages are scanned images. Recognizing text makes them searchable. | Bu sayfalar taranmış görüntülerden oluşuyor. Metin tanıma, sayfaları aranabilir yapar. | هذه الصفحات صور ممسوحة ضوئيًا. التعرّف على النص يجعلها قابلة للبحث. | Sidebar › Search results: the line under the no-text empty state's title (a2-3m); recognizing text is OCR. |
| `sidebarSearchSummary` | {matches, plural, =1{1 match} other{{matchesText} matches}} on {pages, plural, =1{1 page} other{{pagesText} pages}} | {pages, plural, =1{1 sayfada} other{{pagesText} sayfada}} {matches, plural, =1{1 eşleşme} other{{matchesText} eşleşme}} | {matches, plural, =1{تطابق واحد} =2{تطابقان} few{{matchesText} تطابقات} other{{matchesText} تطابقًا}} في {pages, plural, =1{صفحة واحدة} =2{صفحتين} few{{pagesText} صفحات} other{{pagesText} صفحة}} | Sidebar › Search results: the summary under the field (a2-3e). matches and pages are counts, matchesText and pagesText the same numbers in the region's format. |
| `openPdfFilter` | PDF documents | PDF belgeleri | مستندات PDF | Name of the file-type filter in the system open panel (a1-13): the panel lists only PDF files. |
| `openFailedTitle` | Ferman can’t open “{name}” | Ferman “{name}” dosyasını açamıyor | يتعذّر على Ferman فتح «{name}» | Title of the start screen’s danger banner when a file did not open (a1-9b’s title, G116). {name} is the file name. |
| `openFailedDismiss` | Dismiss | Kapat | تجاهل | Accessible name of the close button of the banner of openFailedTitle. |
| `shellSavedOnDeviceUndated` | Saved on this device | Bu cihaza kaydedildi | حُفظ على هذا الجهاز | Status bar: a document just opened, with no save in this session yet (FmWindow t.saved without its time). |
| `shellMoreDocumentsMenu` | More open documents | Diğer açık belgeler | مستندات مفتوحة أخرى | Accessible name of the menu behind “+N” in the title bar (a1-10). |
| `shellMoreDocumentsHeading` | {count, plural, =1{1 more document} other{{countText} more documents}} | {count, plural, =1{1 belge daha} other{{countText} belge daha}} | {count, plural, =1{مستند واحد آخر} =2{مستندان آخران} few{{countText} مستندات أخرى} many{{countText} مستندًا آخر} other{{countText} مستند آخر}} | Heading of the “+N” menu (a1-10): how many documents have no tab in the title bar. {countText} is {count} formatted for the region. |
| `shellMoreDocumentsUnsaved` | {name} · unsaved | {name} · kaydedilmedi | {name} · غير محفوظ | An item of the “+N” menu (a1-10) for a document with unsaved changes: its file name, then the mark. {name} is the file name. |
| `shellShowAllDocuments` | Show all open documents | Tüm açık belgeleri göster | عرض كل المستندات المفتوحة | Item of the “+N” menu (a1-10). |
| `shellCloseOtherDocuments` | Close other documents… | Diğer belgeleri kapat… | إغلاق المستندات الأخرى… | Item of the “+N” menu (a1-10): closes every document but the active one, asking about unsaved ones. |
| `dropOverlayTitle` | Drop to open the files | Açmak için dosyaları bırakın | أفلت لفتح الملفات | Headline of the overlay while files are dragged over the window (a1-6, FmStart dropN without its count: the files are named only once dropped, G117). |
| `dropOverlayHint` | Move over a choice, then let go. | Bir seçeneğin üzerine gelin, sonra bırakın. | مرّر فوق أحد الخيارين ثم أفلت. | Line under dropOverlayTitle (a1-6, FmStart dropHow). |
| `dropOverlayTabs` | Open in tabs | Sekmelerde aç | فتح في علامات تبويب | Title of the drop target that opens each dropped file in its own tab (a1-6, FmStart dropTabs without its count, G117). |
| `dropOverlayTabsDescription` | Each file opens on its own. | Her dosya ayrı açılır. | يُفتح كل ملف على حدة. | Line under dropOverlayTabs (a1-6, FmStart dropTabsSub, the PDF-only line of G11). |
| `dropOverlayCombine` | Combine into one PDF | Tek bir PDF’de birleştir | دمج في ملف PDF واحد | Title of the drop target that would merge the dropped files, disabled until combining ships (a1-6, FmStart dropCombine, B104). |
| `startDropStripTitle` | Drop files anywhere in this window | Dosyaları bu pencerede herhangi bir yere bırakın | أفلت الملفات في أي مكان في هذه النافذة | Title of the drop strip above the recent files (a1-4-m2, FmStart drop). |
| `startDropStripSubtitle` | PDF files open in tabs. | PDF dosyaları sekmelerde açılır. | تُفتح ملفات PDF في علامات تبويب. | Line under startDropStripTitle until conversion ships (a1-4-m2, FmStart dropSubPdf, G11). |
| `startPhoneSearch` | Search documents | Belgelerde ara | البحث في المستندات | Phone home: the search field's placeholder (FmMHome t.search). |
| `startPhoneToolCombine` | Combine | Birleştir | دمج | Phone home: a quick tool, one short word under its icon (FmMHome tools). |
| `startPhoneToolOcr` | OCR | OCR | OCR | Phone home: the text recognition quick tool, the short form under its icon (FmMHome tools). |
| `startPhoneEmptyTitle` | No documents yet | Henüz belge yok | لا توجد مستندات بعد | Phone home with no files: the title (FmMHome t.emptyTitle). |
| `startPhoneEmptySubtitle` | Open a PDF from your phone or a cloud drive, or scan a paper document. | Telefonunuzdan ya da bir bulut sürücüsünden PDF açın veya kâğıt bir belgeyi tarayın. | افتح ملف PDF من هاتفك أو من خدمة سحابية، أو امسح مستندًا ورقيًا. | Phone home with no files: the line under the title (FmMHome t.emptySub). |
| `startPhoneOpen` | Open a file | Dosya aç | فتح ملف | Phone home with no files: the first action, a button (FmMHome t.open). |
| `startPhoneScan` | Scan a document | Belge tara | مسح مستند | Phone home with no files: the second action, a button (FmMHome t.scan). |
| `startPhoneSeeAll` | See all | Tümü | عرض الكل | Phone home: the link beside Recent to every file (FmMHome t.all). |
| `startPhoneOpenFrom` | Open from | Şuradan aç | فتح من | Phone home: the label over the places to open from, shown in capitals through the locale's casing (FmMHome t.import). |
| `startPhoneSourceDownloads` | Downloads | İndirilenler | التنزيلات | Phone home: a place to open from, the phone's downloads folder (FmMHome sources). |
| `startPhoneSourceGoogleDrive` | Google Drive | Google Drive | Google Drive | Phone home: a place to open from, a product name that stays as it is (FmMHome sources). |
| `startPhoneSourceOneDrive` | OneDrive | OneDrive | OneDrive | Phone home: a place to open from, a product name that stays as it is (FmMHome sources). |
| `startPhoneRecent` | Recent | Son açılanlar | الأخيرة | Phone home: heading of the recent files (FmMHome recent). |
| `startPinned` | Pinned | Sabitlenenler | المثبّتة | Heading of the pinned files on the start screen (a1-4, FmStart pinned). |
| `startPin` | Pin | Sabitle | تثبيت | Accessible name and tooltip of the button that pins a recent file above the list (not drawn, G118). |
| `startUnpin` | Unpin | Sabitlemeyi kaldır | إلغاء التثبيت | Accessible name and tooltip of a pinned file’s pin button (a1-4, FmStart unpin). |
| `startRecent` | Recent | Son kullanılanlar | الأخيرة | Heading of the recent files on the start screen (a1-4, FmStart recent). |
| `startSearchRecent` | Search recent files | Son dosyalarda ara | البحث في الملفات الأخيرة | Placeholder and accessible name of the recent files’ search field (a1-4, FmStart searchRecent). |
| `startSort` | Sort | Sıralama | الترتيب | Accessible name of the recent files’ sort menu (a1-4, the Select’s aria-label). |
| `startSortOpened` | Last opened | Son açılma | آخر فتح | Sort option: most recently opened first (a1-4, FmStart sort). |
| `startSortName` | Name | Ad | الاسم | Sort option and list column: the file name, in the UI language’s order (a1-4, FmStart sort, name). |
| `startSortLocation` | Location | Konum | الموقع | Sort option and list column: the folder the file is in (a1-4, FmStart sort, where). |
| `startView` | View | Görünüm | العرض | Accessible name of the grid and list switch of the recent files (a1-4, FmStart view). |
| `startViewGrid` | Grid | Izgara | شبكة | Tooltip of the grid view of the recent files (a1-4, FmStart grid). |
| `startViewList` | List | Liste | قائمة | Tooltip of the list view of the recent files (a1-4c, FmStart list). |
| `startColumnPages` | Pages | Sayfa | الصفحات | Column of the recent files’ list: the page count (a1-4c, FmStart pagesH). |
| `startColumnOpened` | Last opened | Son açılma | آخر فتح | Column of the recent files’ list: when the file was last opened (a1-4c, FmStart opened). |
| `startRecentFooter` | Recent files are listed only on this device. | Son dosyalar yalnızca bu cihazda listelenir. | تُعرض الملفات الأخيرة على هذا الجهاز فقط. | Note under the recent files (a1-4, FmStart footer). |
| `startClearList` | Clear list | Listeyi temizle | مسح القائمة | Link under the recent files that empties the list but for the pinned files (a1-4, FmStart clear). |
| `startNoRecentMatch` | No recent file matches “{query}”. | “{query}” ile eşleşen son dosya yok. | لا يطابق أي ملف حديث «{query}». | Shown in place of the recent files when the search finds none (not drawn, G118). |
| `startPages` | {count, plural, =1{1 page} other{{pages} pages}} | {count, plural, other{{pages} sayfa}} | {count, plural, other{{pages} صفحة}} | A recent file’s page count, after its time (a1-4, FmStart pages); pages is the count in the region’s digits. |
| `startOpenedToday` | Today {time} | Bugün {time} | اليوم {time} | When a recent file was opened today, with the region’s time (a1-4, FmStart). |
| `startOpenedYesterday` | Yesterday {time} | Dün {time} | أمس {time} | When a recent file was opened yesterday, with the region’s time (a1-4, FmStart). |
| `startBadgeEdited` | Edited | Düzenlendi | معدّل | Recent files (a1-4, FmStart): the badge of a file saved after an edit in Ferman. |
| `startBadgeSigned` | Signed | İmzalı | موقّع | Neutral badge of a recent file that carries signatures, before signature checking ships (a1-4-m2, FmStart signedNeutral). |
| `startBadgeForm` | Form | Form | نموذج | Badge on a recent file that has form fields (a1-4, accent). |
| `startBadgeScanned` | Scanned | Taranmış | ممسوح ضوئيًا | Badge on a recent file whose first page has no text, most likely a scan (a1-4, neutral). |
| `startMissingTitle` | “{name}” can’t be found | “{name}” bulunamadı | تعذّر العثور على «{name}» | Title of the dialog for a recent file that was moved, renamed or deleted (a1-9e, missTitle); name is the file name, isolated. |
| `startMissingDescription` | It was moved, renamed or deleted after you last opened it. It was in {folder}. | Dosya son açılışınızdan sonra taşınmış, yeniden adlandırılmış veya silinmiş. Önceki konumu: {folder}. | نُقل الملف أو أُعيدت تسميته أو حُذف بعد آخر مرة فتحته فيها. كان في {folder}. | Line under startMissingTitle (a1-9e, missDesc); folder is where the file was, “\~” for the home folder, isolated. |
| `startMissingRemove` | Remove from list | Listeden kaldır | إزالة من القائمة | Button of a1-9e that takes the missing file off the recent files (a1-9e, remove). |
| `startMissingLocate` | Locate… | Bul… | تحديد الموقع… | Button of a1-9e that opens the system open panel to find the file where it is now (a1-9e, locate). |
| `startMissingClose` | Close | Kapat | إغلاق | Accessible name of a1-9e’s close button, which keeps the file in the list (G118). |
| `selectSheetSearch` | Search | Ara | بحث | Phone: the search field over a long list in a bottom sheet (a13-8c, G129). |
| `selectSheetNoMatch` | No matches | Eşleşme yok | لا توجد نتائج | Phone: shown when the search finds nothing in a bottom sheet's list (a13-8c). |
| `selectSheetClose` | Close | Kapat | إغلاق | Phone: accessible name of the scrim behind a bottom sheet, which closes it. |
| `errorInternal` | Something went wrong inside Ferman. Copy the technical details to report it. | Ferman’ın içinde bir şeyler ters gitti. Bildirmek için teknik ayrıntıları kopyalayın. | حدث خطأ داخل Ferman. انسخ التفاصيل التقنية للإبلاغ عنه. | The line of an error tab (a1-9b) for a bug in Ferman. |
| `errorFileNotFound` | The file isn’t there any more. It may have been moved, renamed or deleted. | Dosya artık orada değil. Taşınmış, adı değiştirilmiş ya da silinmiş olabilir. | لم يعد الملف موجودًا. ربما نُقل أو أُعيدت تسميته أو حُذف. | The line of an error tab (a1-9b) for a file that is gone. |
| `errorFilePermissionDenied` | This computer doesn’t let Ferman read the file. Check who may open it, or copy it to a folder of yours. | Bu bilgisayar Ferman’ın dosyayı okumasına izin vermiyor. Dosyayı kimlerin açabileceğine bakın ya da kendi klasörlerinizden birine kopyalayın. | لا يسمح هذا الجهاز لـ Ferman بقراءة الملف. تحقّق من صلاحيات فتحه، أو انسخه إلى أحد مجلداتك. | The line of an error tab (a1-9b) for a file the system does not let Ferman read (G119). |
| `errorFileRead` | Ferman couldn’t read the file from its disk. Check that the disk is still connected, then try again. | Ferman dosyayı bulunduğu diskten okuyamadı. Diskin hâlâ bağlı olduğuna bakıp yeniden deneyin. | تعذّر على Ferman قراءة الملف من القرص. تأكّد من أن القرص ما زال متصلًا، ثم أعد المحاولة. | The line of an error tab (a1-9b) when reading the file failed. |
| `errorNotPdf` | “{name}” isn’t a PDF file. Ferman opens PDF files. | “{name}” bir PDF dosyası değil. Ferman PDF dosyalarını açar. | «{name}» ليس ملف PDF. يفتح Ferman ملفات PDF. | The line of a1-9c’s error tab under openNotPdfTitle. {name} is the file name (G119: the kind of file is not named). |
| `errorPasswordRequired` | This PDF is password-protected | Bu PDF parolayla korunuyor | ملف PDF هذا محمي بكلمة مرور | Title of the unlock dialog over a locked tab (a1-8). |
| `errorWrongPassword` | That password didn’t work. Check Caps Lock and the keyboard layout: on a Turkish keyboard ı and i are different keys. | Bu parola işe yaramadı. Caps Lock’a ve klavye düzenine bakın: Türkçe klavyede ı ile i ayrı tuşlardır. | لم تنجح كلمة المرور هذه. تحقّق من مفتاح Caps Lock ومن تخطيط لوحة المفاتيح: في لوحة المفاتيح التركية الحرفان ı وi مفتاحان مختلفان. | Error under the password field of the unlock dialog (a1-8b). |
| `errorDamaged` | The file is damaged and Ferman can’t repair it. Try getting the file again. | Dosya bozuk ve Ferman onaramıyor. Dosyayı yeniden edinmeyi deneyin. | الملف تالف ولا يستطيع Ferman إصلاحه. حاول الحصول على الملف مرة أخرى. | The line of an error tab (a1-9b) for a damaged file. |
| `errorDamagedTruncated` | The file stops before its end and the rest is missing. It was probably cut off while downloading or copying. Try getting the file again. | Dosya sonuna gelmeden bitiyor, geri kalanı eksik. Büyük olasılıkla indirilirken ya da kopyalanırken yarıda kesildi. Dosyayı yeniden edinmeyi deneyin. | ينتهي الملف قبل نهايته والباقي مفقود. ربما انقطع أثناء التنزيل أو النسخ. حاول الحصول على الملف مرة أخرى. | The line of a1-9b’s error tab for a truncated file (without the board’s size, G119). |
| `errorDamagedEmpty` | The file starts like a PDF, but nothing after that is readable. Try getting the file again. | Dosya bir PDF gibi başlıyor, ama sonrası okunamıyor. Dosyayı yeniden edinmeyi deneyin. | يبدأ الملف كملف PDF، لكن لا شيء بعد ذلك قابل للقراءة. حاول الحصول على الملف مرة أخرى. | The line of an error tab (a1-9b) for a file with a PDF header and no objects. |
| `errorUnsupported` | It uses something Ferman doesn’t support yet, such as encryption with a certificate. | Ferman’ın henüz desteklemediği bir şey kullanıyor, örneğin sertifikayla şifreleme. | يستخدم شيئًا لا يدعمه Ferman بعد، مثل التشفير بشهادة. | The line of an error tab (a1-9b) for a file Ferman does not support yet (a2-10a: certificate encryption). |
| `errorTooComplex` | This file is too complex to open within Ferman’s safety limits. Your other documents are open and unchanged. | Bu dosya Ferman’ın güvenlik sınırları içinde açılamayacak kadar karmaşık. Diğer belgeleriniz açık ve değişmedi. | هذا الملف معقّد جدًا لفتحه ضمن حدود الأمان في Ferman. مستنداتك الأخرى مفتوحة ولم تتغيّر. | Message of a1-9f’s toast when a resource limit stopped the open. |
| `errorOutOfMemory` | This computer ran out of memory while opening it. Your other documents are open and unchanged. | Dosya açılırken bilgisayarın belleği yetmedi. Diğer belgeleriniz açık ve değişmedi. | نفدت ذاكرة الجهاز أثناء فتحه. مستنداتك الأخرى مفتوحة ولم تتغيّر. | Message of a1-9f’s toast. |
| `openClosedTitle` | “{name}” was closed | “{name}” kapatıldı | أُغلق «{name}» | Title of a1-9f’s toast (and the start screen’s banner) when a file ran out of memory or past a limit while opening. {name} is the file name. |
| `openTryAgain` | Try again | Yeniden dene | إعادة المحاولة | Action of a1-9f’s toast: opens the file again. |
| `openNotPdfTitle` | That file isn’t a PDF. | Bu dosya bir PDF değil. | هذا الملف ليس ملف PDF. | Title of a1-9c’s error tab. |
| `openAnotherFile` | Open another file… | Başka bir dosya aç… | فتح ملف آخر… | Primary button of an error tab (a1-9b, a1-9c): shows the open panel. |
| `openShowInFinder` | Show in Finder | Finder’da göster | إظهار في Finder | Button of an error tab on macOS (a1-9b, a1-9c). |
| `openShowInExplorer` | Show in File Explorer | Dosya Gezgini’nde göster | إظهار في مستكشف الملفات | Button of an error tab on Windows (a1-9b, a1-9c; G119). |
| `openShowInFolder` | Show in folder | Klasörde göster | إظهار في المجلد | Button of an error tab on Linux (a1-9b, a1-9c; G119). |
| `openConvertToPdf` | Convert to PDF… | PDF’ye dönüştür… | تحويل إلى PDF… | Disabled button of a1-9c’s error tab until conversion ships (P3). |
| `unlockDescription` | Enter the password for “{name}”. Ferman forgets it when you close the file. | “{name}” dosyasının parolasını girin. Ferman dosyayı kapattığınızda parolayı unutur. | أدخل كلمة مرور «{name}». ينسى Ferman كلمة المرور عند إغلاق الملف. | Description of the unlock dialog (a1-8). {name} is the file name. |
| `unlockPassword` | Password | Parola | كلمة المرور | Label of the unlock dialog’s field (a1-8). |
| `unlockShowPassword` | Show password | Parolayı göster | إظهار كلمة المرور | Checkbox of the unlock dialog (a1-8). |
| `unlockCancel` | Cancel | Vazgeç | إلغاء | Button of the unlock dialog (a1-8): closes the locked tab. |
| `unlockOpen` | Open | Aç | فتح | Primary button of the unlock dialog (a1-8). |
| `restrictedTitle` | The author restricted this document. | Belgenin yazarı bu belgeyi kısıtladı. | قيّد المؤلف هذا المستند. | Title of the bar above the pages of a document whose author restricted it (a2-10a). |
| `restrictedBody` | You can read and print it. Editing, comments and form filling are turned off. | Belgeyi okuyabilir ve yazdırabilirsiniz. Düzenleme, yorum ve form doldurma kapalı. | يمكنك قراءته وطباعته. التحرير والتعليقات وتعبئة النماذج معطّلة. | Message of the restricted bar (a2-10a), shown when printing is allowed and changes, comments and form filling are not. |
| `restrictedBodyOther` | You can read it. The author turned some actions off. | Belgeyi okuyabilirsiniz. Yazar bazı işlemleri kapattı. | يمكنك قراءته. عطّل المؤلف بعض الإجراءات. | Message of the restricted bar for any other set of permissions (G106; not on a board). |
| `restrictedUnlock` | Unlock with owner password… | Sahip parolasıyla kilidi aç… | فتح القفل بكلمة مرور المالك… | Button of the restricted bar (a2-10a) that opens the owner-password dialog. |
| `ownerUnlockTitle` | Unlock with owner password | Sahip parolasıyla kilidi aç | فتح القفل بكلمة مرور المالك | Title of the owner-password dialog (G106; not on a board). |
| `ownerUnlockDescription` | Enter the owner password for “{name}”. Ferman forgets it when you close the file. | “{name}” için sahip parolasını girin. Dosyayı kapattığınızda Ferman parolayı unutur. | أدخل كلمة مرور المالك لـ«{name}». ينسى Ferman كلمة المرور عند إغلاق الملف. | Text of the owner-password dialog (G106). {name} is the file name. |
| `ownerUnlockPassword` | Owner password | Sahip parolası | كلمة مرور المالك | Label of the owner-password dialog's field (G106). |
| `ownerUnlockAction` | Unlock | Kilidi aç | فتح القفل | Primary button of the owner-password dialog (G106). |
| `scriptsTitle` | {count, plural, =1{This document contains 1 script.} other{This document contains {countText} scripts.}} | {count, plural, other{Bu belgede {countText} betik var.}} | {count, plural, =1{يحتوي هذا المستند على برنامج نصي واحد.} =2{يحتوي هذا المستند على برنامجين نصيين.} few{يحتوي هذا المستند على {countText} برامج نصية.} many{يحتوي هذا المستند على {countText} برنامجًا نصيًا.} other{يحتوي هذا المستند على {countText} برنامج نصي.}} | Title of the bar above the pages of a document with scripts (G100; not on a board). {countText} is {count} formatted for the region. |
| `scriptsBody` | Ferman never runs scripts; other apps might. | Ferman betikleri hiçbir zaman çalıştırmaz; başka uygulamalar çalıştırabilir. | لا يشغّل Ferman البرامج النصية أبدًا، وقد تشغّلها تطبيقات أخرى. | Message of the scripts bar (G100), a8-4's sentence. |
| `scriptsDismiss` | Dismiss | Kapat | إغلاق | Screen-reader name of the scripts bar's dismiss button (G100). |
| `repairedTitle` | Ferman repaired this file. | Ferman bu dosyayı onardı. | أصلح Ferman هذا الملف. | a1-9: title of the bar above the pages of a file Ferman repaired on open. |
| `repairedBody` | {count, plural, =0{Problems were fixed in this copy.} =1{1 problem was fixed in this copy.} other{{countText} problems were fixed in this copy.}} The original stays as it was until you save. | {count, plural, =0{Bu kopyadaki sorunlar giderildi.} other{Bu kopyada {countText} sorun giderildi.}} Siz kaydedene kadar özgün dosya olduğu gibi kalır. | {count, plural, =0{أُصلحت مشكلات في هذه النسخة.} =1{أُصلحت مشكلة واحدة في هذه النسخة.} =2{أُصلحت مشكلتان في هذه النسخة.} few{أُصلحت {countText} مشكلات في هذه النسخة.} many{أُصلحت {countText} مشكلة في هذه النسخة.} other{أُصلحت {countText} مشكلة في هذه النسخة.}} يبقى الأصل كما هو حتى تحفظ. | a1-9: message of the repaired bar. {count} is how many repairs the engine reports (0 when it names none), {countText} is {count} formatted for the region. |
| `repairedDetails` | Details | Ayrıntılar | التفاصيل | a1-9: the repaired bar's button that opens the list of repairs (What Ferman repaired). |
| `repairedSave` | Save repaired copy… | Onarılmış kopyayı kaydet… | حفظ النسخة المُصلَحة… | a1-9: the repaired bar's button that saves the repaired file as a new file (disabled until saving ships, B103). |
| `repairDetailsTitle` | What Ferman repaired | Ferman neleri onardı | ما الذي أصلحه Ferman | a1-9: title of the popover that lists the repairs. |
| `repairCopyDetails` | Copy details | Ayrıntıları kopyala | نسخ التفاصيل | a1-9: button in the repairs popover that copies the list of repairs. |
| `repairXrefTitle` | The cross-reference table was broken | Çapraz başvuru tablosu bozuktu | كان جدول الإسناد الترافقي تالفًا | a1-9: a repair: the file's table of where its objects are was rebuilt. |
| `repairXrefBody` | {count, plural, =1{Rebuilt from the 1 object found in the file.} other{Rebuilt from the {countText} objects found in the file.}} | {count, plural, other{Dosyada bulunan {countText} nesneden yeniden oluşturuldu.}} | {count, plural, =1{أُعيد بناؤه من الكائن الوحيد الموجود في الملف.} =2{أُعيد بناؤه من الكائنين الموجودين في الملف.} few{أُعيد بناؤه من {countText} كائنات موجودة في الملف.} many{أُعيد بناؤه من {countText} كائنًا موجودًا في الملف.} other{أُعيد بناؤه من {countText} كائن موجود في الملف.}} | a1-9: detail of the cross-reference repair. {count} is the objects found, {countText} is {count} formatted for the region. |
| `repairPagesPresent` | {count, plural, =1{The page is present.} other{All {countText} pages are present.}} | {count, plural, =1{Sayfa yerinde.} other{{countText} sayfanın tümü yerinde.}} | {count, plural, =1{الصفحة موجودة.} =2{الصفحتان موجودتان.} few{الصفحات الـ{countText} كلها موجودة.} many{الصفحات الـ{countText} كلها موجودة.} other{الصفحات الـ{countText} كلها موجودة.}} | a1-9: second sentence of the cross-reference repair's detail. {count} is the document's pages, {countText} is {count} formatted for the region. |
| `repairTrailerTitle` | The file’s trailer was missing | Dosyanın trailer bölümü eksikti | كان مقطع الذيل (trailer) في الملف مفقودًا | a1-9: a repair: the file's trailer (the part that says where the document starts) was missing (not on the board). |
| `repairTrailerBody` | Ferman found where the document starts among its objects. | Ferman, belgenin nereden başladığını nesneleri arasında buldu. | عثر Ferman على بداية المستند بين كائناته. | a1-9: detail of the trailer repair (not on the board). |
| `repairStreamsTitle` | {count, plural, =1{1 stream had the wrong length} other{{countText} streams had the wrong length}} | {count, plural, other{{countText} veri akışının uzunluğu yanlıştı}} | {count, plural, =1{كان طول تدفق واحد خاطئًا} =2{كان طول تدفقين خاطئًا} few{كان طول {countText} تدفقات خاطئًا} many{كان طول {countText} تدفقًا خاطئًا} other{كان طول {countText} تدفق خاطئًا}} | a1-9: a repair: data streams whose stated length was wrong (not on the board). {countText} is {count} formatted for the region. |
| `repairStreamsBody` | Ferman read each one up to its end. | Ferman her birini sonuna kadar okudu. | قرأ Ferman كل واحد منها حتى نهايته. | a1-9: detail of the stream-length repair (not on the board). |
| `repairUnreadableTitle` | {count, plural, =1{1 object couldn’t be read} other{{countText} objects couldn’t be read}} | {count, plural, other{{countText} nesne okunamadı}} | {count, plural, =1{تعذّرت قراءة كائن واحد} =2{تعذّرت قراءة كائنين} few{تعذّرت قراءة {countText} كائنات} many{تعذّرت قراءة {countText} كائنًا} other{تعذّرت قراءة {countText} كائن}} | a1-9: objects of the file that could not be read (not on the board). {countText} is {count} formatted for the region. |
| `repairUnreadableBody` | Pages and features that use them may be incomplete. | Bunları kullanan sayfalar ve özellikler eksik olabilir. | قد تكون الصفحات والميزات التي تستخدمها غير مكتملة. | a1-9: detail of the unreadable objects (not on the board). |
| `xfaTitle` | This is an XFA form, which Ferman can’t show. | Bu bir XFA formu; Ferman bu formu gösteremiyor. | هذا نموذج XFA، ولا يستطيع Ferman عرضه. | a11-7c: title of the bar above the pages of an XFA-only form. |
| `xfaBody` | XFA is a discontinued Adobe format. Open it in Adobe Acrobat Reader, or ask the sender for a regular PDF. | XFA, Adobe’ın artık sürdürmediği bir biçimdir. Dosyayı Adobe Acrobat Reader’da açın ya da gönderenden normal bir PDF isteyin. | XFA تنسيق متوقف من Adobe. افتحه في Adobe Acrobat Reader، أو اطلب من المرسل ملف PDF عاديًا. | a11-7c: message of the XFA bar. |
| `disagreeTitle` | Ferman opened “{name}” read-only. | Ferman “{name}” dosyasını salt okunur açtı. | فتح Ferman «{name}» للقراءة فقط. | G102: title of the bar above the pages of a file whose two parsers disagree (not on a board). {name} is the file name. |
| `disagreeBody` | Parts of this file don’t match each other, which can mean it is damaged. You can read it as usual. | Bu dosyanın bazı bölümleri birbiriyle uyuşmuyor; bu, dosyanın hasarlı olduğu anlamına gelebilir. Dosyayı her zamanki gibi okuyabilirsiniz. | بعض أجزاء هذا الملف لا تتطابق مع بعضها، وقد يعني ذلك أنه تالف. يمكنك قراءته كالمعتاد. | G102: message of the parsers-disagree bar (not on a board). |
| `propertiesFile` | File | Dosya | الملف | Right panel section with the file's facts (FmDocPanel \`view\`). |
| `propertiesFonts` | Fonts in this document | Bu belgedeki yazı tipleri | الخطوط في هذا المستند | Right panel section listing the document's fonts (FmDocPanel). |
| `propertiesSecurity` | Security | Güvenlik | الأمان | Right panel section, the properties dialog's Security tab and its Summary row (FmDocPanel, a2-7, a2-10b). |
| `propertiesPages` | Pages | Sayfalar | الصفحات | Label of the page count (FmDocPanel, a2-7). |
| `propertiesPageSize` | Page size | Sayfa boyutu | حجم الصفحة | Label of the first page's size (FmDocPanel, a2-7). |
| `propertiesFileSize` | File size | Dosya boyutu | حجم الملف | Label of the file's size (FmDocPanel, a2-7). |
| `propertiesVersion` | PDF version | PDF sürümü | إصدار PDF | Label of the PDF version (FmDocPanel, a2-7). |
| `propertiesVersionAcrobat` | {version} (Acrobat {acrobat}.x) | {version} (Acrobat {acrobat}.x) | {version} (Acrobat {acrobat}.x) | A PDF version with the Acrobat version that introduced it, as a2-7 shows it: '1.7 (Acrobat 8.x)'. |
| `propertiesLocation` | Location | Konum | الموقع | Label of the file's path (FmDocPanel). |
| `propertiesCreated` | Created | Oluşturulma | تاريخ الإنشاء | Label of the creation date (a2-7). |
| `propertiesModified` | Modified | Değiştirilme | تاريخ التعديل | Label of the modification date (FmDocPanel, a2-7). |
| `propertiesTitle` | Title | Başlık | العنوان | Label of the document's title (a2-7). |
| `propertiesAuthor` | Author | Yazar | المؤلف | Label of the document's author (a2-7). |
| `propertiesSubject` | Subject | Konu | الموضوع | Label of the document's subject (a2-7). |
| `propertiesKeywords` | Keywords | Anahtar sözcükler | الكلمات المفتاحية | Label of the document's keywords (a2-7). |
| `propertiesTagged` | Tagged PDF | Etiketli PDF | PDF موسوم | Label: whether the PDF is tagged (a2-7). |
| `propertiesFastWebView` | Fast web view | Hızlı web görünümü | عرض ويب سريع | Label: whether the PDF is linearized (a2-7). |
| `propertiesMadeWith` | Made with | Oluşturan uygulama | أُنشئ باستخدام | Label of the application that wrote the PDF (a2-7). |
| `propertiesYes` | Yes | Evet | نعم | A yes/no value (a2-7). |
| `propertiesNo` | No | Hayır | لا | A yes/no value (a2-7). |
| `propertiesNone` | None | Yok | لا يوجد | A value the file does not give (a2-10b's 'Password to open: None'; also empty metadata, not on a board). |
| `propertiesNoPassword` | No password | Parola yok | بلا كلمة مرور | An unencrypted document's security (FmDocPanel, a2-7). |
| `propertiesOwnerPassword` | Owner password | Sahip parolası | كلمة مرور المالك | Security of a document restricted by an owner password, opening without one (not on a board). |
| `propertiesSignatures` | {count, plural, =1{1 signature} other{{countText} signatures}} | {count, plural, other{{countText} imza}} | {count, plural, =1{توقيع واحد} =2{توقيعان} few{{countText} توقيعات} many{{countText} توقيعًا} other{{countText} توقيع}} | Signatures in the document (a2-7: 'No password · 1 signature'). {countText} is {count} formatted for the region. |
| `propertiesSignatureOnPage` | 1 signature, page {page} | 1 imza, sayfa {page} | توقيع واحد، الصفحة {page} | The one signature of a document and its page (FmDocPanel). {page} is formatted for the region. |
| `propertiesEmbedded` | Embedded | Gömülü | مضمَّن | A font whose program is in the file (FmDocPanel, a2-7). |
| `propertiesPartial` | Partial | Kısmi | جزئي | A subset font in the right panel (FmDocPanel). |
| `propertiesPartialNote` | Subset: only characters already in the file. | Alt küme: yalnızca dosyada zaten bulunan karakterler. | مجموعة فرعية: الأحرف الموجودة في الملف فقط. | Note under a subset font in the right panel (FmDocPanel); propertiesPartialMissing follows it when letters are missing. |
| `propertiesPartialMissing` | No {letters}. | {letters} yok. | لا يتضمن {letters}. | After propertiesPartialNote: the letters the subset lacks, each in single quotation marks (FmDocPanel's "No ‘ğ’, ‘Ğ’."). |
| `propertiesSubset` | Subset | Alt küme | مجموعة فرعية | A subset font in the properties dialog (a2-7). |
| `propertiesSubsetNote` | Only the characters already used. | Yalnızca zaten kullanılan karakterler. | الأحرف المستخدمة فقط. | Note under a subset font in the properties dialog (a2-7); propertiesSubsetMissing follows it when letters are missing. |
| `propertiesSubsetMissing` | Typing {letters} needs a substitute. | {letters} yazmak için yedek yazı tipi gerekir. | كتابة {letters} تحتاج إلى خط بديل. | After propertiesSubsetNote: the letters the subset lacks, each in single quotation marks (a2-7). |
| `propertiesShownInstead` | Ferman is showing {font} instead. | Ferman bunun yerine {font} gösteriyor. | يعرض Ferman الخط {font} بدلًا منه. | Note under a font that is not embedded (a2-7, FmDocPanel): the font the page is drawn in. |
| `propertiesNotEmbedded` | Not embedded | Gömülü değil | غير مضمَّن | A font whose program is not in the file (a2-7). |
| `propertiesFontType1` | Type 1 | Type 1 | Type 1 | A font type in the properties dialog's Type column (a2-7); a format name. |
| `propertiesFontMultipleMaster` | Multiple Master | Multiple Master | Multiple Master | A font type (Multiple Master Type 1) in the Type column (a2-7); a format name. |
| `propertiesFontTrueType` | TrueType | TrueType | TrueType | A font type in the Type column (a2-7); a format name. |
| `propertiesFontType0` | Type 0 | Type 0 | Type 0 | A composite font in the Type column (a2-7); a format name. |
| `propertiesFontType3` | Type 3 | Type 3 | Type 3 | A font drawn by the file itself, in the Type column (a2-7); a format name. |
| `propertiesFontOther` | Other | Diğer | أخرى | Any other font type, in the Type column (a2-7). |
| `propertiesFontColumn` | Font | Yazı tipi | الخط | Column heading of the fonts table, shown in capitals (a2-7). |
| `propertiesTypeColumn` | Type | Tür | النوع | Column heading of the fonts table, shown in capitals (a2-7). |
| `propertiesStatusColumn` | Status | Durum | الحالة | Column heading of the fonts table, shown in capitals (a2-7). |
| `propertiesDialogTitle` | {name} — Properties | {name} — Özellikler | {name} — الخصائص | Title of the properties dialog (a2-7, a2-10b). |
| `propertiesSection` | Section | Bölüm | القسم | Accessible name of the properties dialog's tabs (a2-7). |
| `propertiesSummary` | Summary | Özet | ملخّص | Tab of the properties dialog (a2-7). |
| `propertiesAdvanced` | Advanced | Gelişmiş | متقدّم | Tab of the properties dialog (a2-7). |
| `propertiesDone` | Done | Bitti | تم | Closes the properties dialog (a2-7, a2-10b). |
| `propertiesClose` | Close | Kapat | إغلاق | Accessible name of the properties dialog's close button and scrim (not on a board). |
| `propertiesEncryption` | Encryption | Şifreleme | التشفير | Label of the encryption method (a2-10b). |
| `propertiesRc4` | RC4, {bits}-bit | RC4, {bits} bit | RC4، {bits} بت | RC4 encryption with its key length (a2-10b's Encryption row; not on a board). {bits} is formatted for the region. |
| `propertiesAes128` | AES-128 | AES-128 | AES-128 | AES-128 encryption (a2-10b's Encryption row); a method name. |
| `propertiesAes256` | AES-256 | AES-256 | AES-256 | AES-256 encryption (a2-10b's Encryption row); a method name. |
| `propertiesOwnerPasswordSuffix` | owner password | sahip parolası | كلمة مرور المالك | After the encryption method of a restricted file (a2-10b: 'AES-256 · owner password'). |
| `propertiesOpenPassword` | Password to open | Açma parolası | كلمة مرور الفتح | Label: whether opening needs a password (a2-10b); also a document's security when it does (not on a board). |
| `propertiesRequired` | Required | Gerekli | مطلوبة | Opening needs a password (a2-10b's row; not on a board). |
| `propertiesPermissions` | Permissions | İzinler | الأذونات | Heading of the permissions, shown in capitals (a2-10b). |
| `propertiesPrinting` | Printing | Yazdırma | الطباعة | A permission (a2-10b). |
| `propertiesChanging` | Changing the document | Belgeyi değiştirme | تغيير المستند | A permission (a2-10b). |
| `propertiesCommenting` | Adding comments | Yorum ekleme | إضافة التعليقات | A permission (a2-10b). |
| `propertiesFilling` | Filling form fields | Form alanlarını doldurma | تعبئة حقول النماذج | A permission (a2-10b). |
| `propertiesSigning` | Signing | İmzalama | التوقيع | A permission (a2-10b). |
| `propertiesCopying` | Copying text and images | Metin ve görselleri kopyalama | نسخ النصوص والصور | A permission (a2-10b). |
| `propertiesScreenReaders` | Text access for screen readers | Ekran okuyucular için metin erişimi | وصول قارئات الشاشة إلى النص | A permission (a2-10b). |
| `propertiesAssembling` | Assembling pages | Sayfaları birleştirme ve düzenleme | تجميع الصفحات | A permission (a2-10b). |
| `propertiesAllowed` | Allowed | İzin veriliyor | مسموح | A permission's state (a2-10b). |
| `propertiesAllowedHighQuality` | Allowed, high quality | İzin veriliyor, yüksek kalite | مسموح، بجودة عالية | Printing allowed at full quality (a2-10b). |
| `propertiesNotAllowed` | Not allowed | İzin verilmiyor | غير مسموح | A permission's state (a2-10b). |
| `propertiesLanguage` | Language | Dil | اللغة | Label of the document's language tag in the Advanced tab (not on a board). |
| `propertiesScripts` | JavaScript | JavaScript | JavaScript | Label of the scripts row in the Advanced tab (G100, a8-3's row name). |
| `propertiesScriptsValue` | {count, plural, =1{A script that runs when the file opens. Ferman never runs it.} other{{countText} scripts that run when the file opens. Ferman never runs them.}} | {count, plural, other{Dosya açılırken çalışan {countText} betik. Ferman bunları hiçbir zaman çalıştırmaz.}} | {count, plural, =1{برنامج نصي يعمل عند فتح الملف. لا يشغّله Ferman أبدًا.} =2{برنامجان نصيان يعملان عند فتح الملف. لا يشغّلهما Ferman أبدًا.} few{{countText} برامج نصية تعمل عند فتح الملف. لا يشغّلها Ferman أبدًا.} many{{countText} برنامجًا نصيًا يعمل عند فتح الملف. لا يشغّلها Ferman أبدًا.} other{{countText} برنامج نصي يعمل عند فتح الملف. لا يشغّلها Ferman أبدًا.}} | The scripts row of the Advanced tab, in a8-3's words (G100; not on a board). {countText} is {count} formatted for the region. |
| `openingTitle` | Opening “{name}” | “{name}” açılıyor | جارٍ فتح «{name}» | a1-7: the title of the progress card while a file takes long to open. {name} is the file name. |
| `openingCancel` | Cancel | Vazgeç | إلغاء | a1-7: the progress card's button (also Esc) that stops opening the file and closes its tab. |
| `defaultAppTitle` | Open PDFs with Ferman? | PDF’ler Ferman ile açılsın mı? | هل تريد فتح ملفات PDF باستخدام Ferman؟ | Title of the first-run question that offers to make Ferman the app that opens PDF files (a1-3), asked after onboarding on macOS. |
| `defaultAppDescription` | Ferman can be the app that opens when you double-click a PDF. macOS asks you to confirm the change. | Ferman, bir PDF’e çift tıkladığınızda açılan uygulama olabilir. macOS bu değişikliği onaylamanızı ister. | يمكن أن يكون Ferman التطبيق الذي يُفتح عند النقر المزدوج على ملف PDF. سيطلب منك macOS تأكيد التغيير. | Line under defaultAppTitle (a1-3). |
| `defaultAppNow` | Opens PDFs now: | PDF’leri şu an açan: | يفتح ملفات PDF الآن: | Label before the app that opens PDF files now, an arrow and Ferman (a1-3). |
| `defaultAppNotNow` | Not now | Şimdi değil | ليس الآن | Button of a1-3 that closes the question; Settings › General keeps the button. |
| `defaultAppUse` | Use Ferman for PDFs | PDF’ler için Ferman’ı kullan | استخدام Ferman لملفات PDF | Primary button of a1-3: asks macOS to make Ferman the app that opens PDF files. |
| `defaultAppDontAsk` | Don’t ask again | Bir daha sorma | عدم السؤال مرة أخرى | Checkbox of a1-3: with it, Not now never asks again. |
| `settingsDefaultAppOther` | {app} opens PDFs on this Mac. | Bu Mac’te PDF’leri {app} açıyor. | يفتح {app} ملفات PDF على جهاز Mac هذا. | Text beside Make Ferman the default… in Settings › General on macOS (a11-1); app is the app that opens PDF files now, as macOS names it, isolated. |
| `settingsDefaultAppFerman` | Ferman opens PDFs on this Mac. | Bu Mac’te PDF’leri Ferman açıyor. | يفتح Ferman ملفات PDF على جهاز Mac هذا. | Text in Settings › General on macOS when Ferman already opens PDF files; the button is then not shown. |
| `attachmentNotSaved` | “{name}” wasn’t saved | “{name}” kaydedilmedi | لم يُحفَظ “{name}” | Title of the editor’s danger toast when Save attachment as… failed (a2-3b, G124); name is the attachment’s file name, isolated. |
| `attachmentWriteFailed` | Ferman couldn’t write the file there. Choose another folder, or check that the disk has space and is still connected. | Ferman dosyayı oraya yazamadı. Başka bir klasör seçin ya da diskte yer olduğunu ve diskin hâlâ bağlı olduğunu denetleyin. | تعذّر على Ferman كتابة الملف هناك. اختر مجلدًا آخر، أو تحقق من وجود مساحة كافية على القرص ومن أنه لا يزال متصلًا. | Message of the toast of attachmentNotSaved when the file could not be written. |
| `editStepText` | Edited text · page {page} | Metin düzenlendi · sayfa {page} | تحرير النص · الصفحة {page} | Edit mode: the name of a history step that changed the text of a block, in the Undo history panel (a3-10). {page} is the page number, formatted for the region. |
| `editHistoryClose` | Close history | Geçmişi kapat | إغلاق السجل | Undo history panel (a3-10): tooltip and screen-reader name of the button that closes the panel. |
| `editHistorySteps` | Steps | Adımlar | الخطوات | Undo history panel (a3-10): screen-reader name of the list of history steps. |
| `editHistoryOpened` | Opened {name} | {name} açıldı | فتح {name} | Undo history panel (a3-10): the first row, the document as it was opened. {name} is the file name, isolated. |
| `editHistoryNote` | Click a step to go back to it. Greyed steps can be redone until you make a new change. History is kept until you close the document; saved versions are in Version history. | Geri dönmek için bir adıma tıklayın. Soluk adımlar, yeni bir değişiklik yapana kadar yinelenebilir. Geçmiş, belgeyi kapatana kadar saklanır; kaydedilen sürümler Sürüm geçmişi’ndedir. | انقر على خطوة للعودة إليها. يمكن إعادة الخطوات الرمادية إلى أن تُجري تغييرًا جديدًا. يُحتفظ بالسجل إلى أن تغلق المستند، والإصدارات المحفوظة في سجل الإصدارات. | Undo history panel (a3-10): the note at the bottom of the panel. |
| `editNothingToUndo` | Nothing to undo | Geri alınacak bir şey yok | لا شيء للتراجع عنه | Edit tool row: why Undo is disabled, as its tooltip, when the document has no step to undo (G126). |
| `editNothingToRedo` | Nothing to redo | Yinelenecek bir şey yok | لا شيء لإعادته | Edit tool row: why Redo is disabled, as its tooltip, when no step was undone (G126). |
| `editOverflowTitle` | Text doesn’t fit | Metin sığmıyor | النص لا يتسع | Edit panel (a3-4, a3-18): the warning's title when the edited text needs more lines than its block's frame. |
| `editOverflowBody` | {count, plural, =1{The edited paragraph needs {n} more line than its frame.} other{The edited paragraph needs {n} more lines than its frame.}} | {count, plural, other{Düzenlenen paragraf, çerçevesinden {n} satır fazla yer istiyor.}} | {count, plural, =1{تحتاج الفقرة المعدّلة إلى سطر واحد أكثر من إطارها.} =2{تحتاج الفقرة المعدّلة إلى سطرين أكثر من إطارها.} few{تحتاج الفقرة المعدّلة إلى {n} أسطر أكثر من إطارها.} many{تحتاج الفقرة المعدّلة إلى {n} سطرًا أكثر من إطارها.} other{تحتاج الفقرة المعدّلة إلى {n} سطر أكثر من إطارها.}} | Edit panel (a3-4, a3-18): the overflow warning's message. {n} is the number of lines written for the region; {count} picks the plural form. |
| `editOverflowExtend` | {count, plural, =1{Extend block by {n} line} other{Extend block by {n} lines}} | {count, plural, other{Bloğu {n} satır uzat}} | {count, plural, =1{توسيع الكتلة بسطر واحد} =2{توسيع الكتلة بسطرين} few{توسيع الكتلة بـ{n} أسطر} many{توسيع الكتلة بـ{n} سطرًا} other{توسيع الكتلة بـ{n} سطر}} | Edit panel (a3-4): the choice that grows the block's frame by the lines the engine computed. {n} is the number written for the region; {count} picks the plural form. |
| `editOverflowTighten` | Tighten spacing slightly (−{percent}) | Aralığı biraz daralt (−{percent}) | تضييق التباعد قليلًا (−{percent}) | Edit panel (a3-4): the choice that tightens the block's spacing by the amount the engine computed. {percent} is the percentage written for the region, such as 0.6% or %0,6. |
| `editOverflowKeep` | Keep and warn | Koru ve uyar | إبقاء مع تحذير | Edit panel (a3-4): the choice that keeps the frame and hides the lines that don't fit, with a warning on the page and its thumbnail. |
| `editOverflowExtendLabelBelow` | The {label} line sits right below this block. | {label} satırı bu bloğun hemen altında. | سطر {label} يقع مباشرة أسفل هذه الكتلة. | Edit panel (a3-18): why Extend is disabled when a labelled line, such as 'IBAN: …', sits right below the block. {label} is the line's label in the document's own words. |
| `editOverflowExtendBelow` | The line “{text}” sits right below this block. | “{text}” satırı bu bloğun hemen altında. | السطر «{text}» يقع مباشرة أسفل هذه الكتلة. | Edit panel (a3-18): why Extend is disabled when another line sits right below the block. {text} is the start of that line in the document's own words. |
| `editOverflowExtendPageEdge` | Extending the block would run it past the page’s edge. | Blok uzarsa sayfanın kenarını aşar. | توسيع الكتلة سيجعلها تتجاوز حافة الصفحة. | Edit panel (a3-18): why Extend is disabled when the block already reaches the edge of the page. |
| `editOverflowTightenShort` | {count, plural, =1{Even the tightest allowed spacing leaves {n} line over.} other{Even the tightest allowed spacing leaves {n} lines over.}} | {count, plural, other{İzin verilen en dar aralıkta bile {n} satır taşıyor.}} | {count, plural, =1{حتى أضيق تباعد مسموح يترك سطرًا واحدًا زائدًا.} =2{حتى أضيق تباعد مسموح يترك سطرين زائدين.} few{حتى أضيق تباعد مسموح يترك {n} أسطر زائدة.} many{حتى أضيق تباعد مسموح يترك {n} سطرًا زائدًا.} other{حتى أضيق تباعد مسموح يترك {n} سطر زائد.}} | Edit panel (a3-18): why Tighten is disabled. {n} is the number of lines still over, written for the region; {count} picks the plural form. |
| `editOverflowHidden` | {count, plural, =1{+{n} line hidden} other{+{n} lines hidden}} | {count, plural, other{+{n} satır gizli}} | {count, plural, =1{+سطر واحد مخفي} =2{+سطران مخفيان} few{+{n} أسطر مخفية} many{+{n} سطرًا مخفيًا} other{+{n} سطر مخفي}} | Edit mode (a3-4, a3-18): the amber status in the page margin beside a block whose last lines Keep and warn hides, and the page thumbnail's warning. {n} is the number written for the region; {count} picks the plural form. |
| `editTotalsTitle` | Totals don’t update | Toplamlar güncellenmez | لا تُحدَّث المجاميع | Edit panel (a3-9): the warning's title after a number in a table cell was edited and other cells likely depend on it. |
| `editTotalsBody` | A PDF stores numbers as text. The marked cells still show the old amounts. | PDF, sayıları metin olarak saklar. İşaretli hücreler hâlâ eski tutarları gösteriyor. | يخزّن ملف PDF الأرقام كنص. لا تزال الخلايا المعلّمة تعرض المبالغ القديمة. | Edit panel (a3-9): the warning's message; the cells that likely depend on the edited one are tinted on the page. |
| `editTotalsReview` | {count, plural, =1{Review the marked cell} other{Review the {n} marked cells}} | {count, plural, =1{İşaretli hücreyi incele} other{İşaretli {n} hücreyi incele}} | {count, plural, =1{مراجعة الخلية المعلّمة} =2{مراجعة الخليتين المعلّمتين} few{مراجعة الخلايا الـ{n} المعلّمة} many{مراجعة الـ{n} خلية المعلّمة} other{مراجعة الـ{n} خلية المعلّمة}} | Edit panel (a3-9): the button that opens the cells that likely depend on the edited one in Review edits. {n} is the number written for the region; {count} picks the plural form. |
| `editBadgeEdited` | Edited | Düzenlendi | معدّل | Edit panel heading (a3-9, FmEditPanel): the badge once the open block's text changed. |
| `editGlyphTitle` | Missing character | Eksik karakter | حرف مفقود | Edit panel (a3-3a, FmEditPanel): the title of the warning when the block's font has no glyph for a typed character (missing-glyph step 3). |
| `editGlyphBody` | This font has no {chars}. Ferman will use a similar font for this character. | Bu yazı tipinde {chars} yok. Ferman bu karakter için benzer bir yazı tipi kullanacak. | لا يحتوي هذا الخط على الحرف {chars}. سيستخدم Ferman خطًا مشابهًا لهذا الحرف. | Edit panel (a3-3a, FmEditPanel): the warning's message for one missing character. {chars} is the character in ‘ ’. |
| `editGlyphBodyMany` | This font has no {chars}. Ferman will use a similar font for these characters. | Bu yazı tipinde {chars} yok. Ferman bu karakterler için benzer bir yazı tipi kullanacak. | لا يحتوي هذا الخط على الأحرف {chars}. سيستخدم Ferman خطًا مشابهًا لهذه الأحرف. | Edit panel (a3-3a): the warning's message for several missing characters. {chars} is the characters, each in ‘ ’ and separated by the list separator. |
| `editGlyphMarkedBody` | This font has no {chars}. Ferman keeps the original font and marks what’s missing. | Bu yazı tipinde {chars} yok. Ferman özgün yazı tipini koruyor ve eksik olanı işaretliyor. | لا يحتوي هذا الخط على {chars}. يُبقي Ferman الخط الأصلي ويضع علامة على ما ينقصه. | Edit panel: the warning's message with Settings › Editing › Keep the original font and mark the character (a11-1c). {chars} is the characters, each in ‘ ’. |
| `editGlyphChoose` | Choose a font… | Yazı tipi seç… | اختيار خط… | Edit panel (a3-3a, a3-17): the button that opens the font picker for the missing characters. |
| `editGlyphKeep` | Keep as is | Böyle kalsın | إبقاء كما هو | Edit panel (a3-3a, a3-17): the button that keeps the missing characters as Ferman drew them. |
| `editGlyphNoneTitle` | No font has this character | Bu karakter hiçbir yazı tipinde yok | لا يوجد خط يحتوي هذا الحرف | Edit panel (a3-17): the title when no font has the missing character. |
| `editGlyphNoneBody` | Neither this font nor any font on this computer has {chars}. Choose a font that has it, or keep the character as is. | Ne bu yazı tipinde ne de bu bilgisayardaki yazı tiplerinde {chars} var. Bu karakteri içeren bir yazı tipi seçin ya da böyle bırakın. | لا يحتوي هذا الخط ولا أي خط على هذا الجهاز على الحرف {chars}. اختر خطًا يحتويه أو أبقِه كما هو. | Edit panel (a3-17): the message when no font has the missing character. {chars} is the characters, each in ‘ ’ and separated by the list separator. |
| `editGlyphLicenceTitle` | This font can’t be embedded | Bu yazı tipi gömülemiyor | لا يمكن تضمين هذا الخط | Edit panel (a3-17): the title when the font's licence forbids embedding it for new text. |
| `editGlyphLicenceBody` | {font} is installed, but its licence allows only preview and print. Ferman will use a similar font for {chars} instead. | {font} yüklü, ancak lisansı yalnızca önizleme ve yazdırmaya izin veriyor. Ferman {chars} için bunun yerine benzer bir yazı tipi kullanacak. | خط {font} مثبّت، لكن ترخيصه يسمح بالمعاينة والطباعة فقط. سيستخدم Ferman خطًا مشابهًا للحرف {chars} بدلًا منه. | Edit panel (a3-17): the message when the installed copy of the font allows only preview and print. {font} is the font's name; {chars} is the characters, each in ‘ ’ and separated by the list separator. |
| `editGlyphLicenceBodyRestricted` | {font} is installed, but its licence doesn’t allow embedding it. Ferman will use a similar font for {chars} instead. | {font} yüklü, ancak lisansı yazı tipinin gömülmesine izin vermiyor. Ferman {chars} için bunun yerine benzer bir yazı tipi kullanacak. | خط {font} مثبّت، لكن ترخيصه لا يسمح بتضمينه. سيستخدم Ferman خطًا مشابهًا للحرف {chars} بدلًا منه. | Edit panel (a3-17, G37): the message when the installed copy of the font forbids embedding altogether. {font} is the font's name; {chars} is the characters, each in ‘ ’ and separated by the list separator. |
| `editGlyphOwnFontBody` | The licence of {font} in this document allows only preview and print, so Ferman doesn’t reuse its glyphs. Ferman will use a similar font for {chars} instead. | Bu belgedeki {font} yazı tipinin lisansı yalnızca önizleme ve yazdırmaya izin verdiği için Ferman onun karakterlerini yeniden kullanmıyor. Ferman {chars} için bunun yerine benzer bir yazı tipi kullanacak. | يسمح ترخيص خط {font} في هذا المستند بالمعاينة والطباعة فقط، لذا لا يعيد Ferman استخدام أحرفه. سيستخدم Ferman خطًا مشابهًا للحرف {chars} بدلًا منه. | Edit panel (a3-17, G37, Q09): the message when the document's own font allows only preview and print. {font} is the font's name; {chars} is the characters, each in ‘ ’ and separated by the list separator. |
| `editGlyphAddedTitle` | Character added from this computer | Karakter bu bilgisayardan eklendi | أُضيف الحرف من هذا الجهاز | Edit panel (a3-17): the notice, said once, when missing-glyph step 2 took the character from the same font installed on this computer. |
| `editGlyphAddedBody` | Ferman took {chars} from {font} installed on this computer and added it to the document’s font. | Ferman {chars} karakterini bu bilgisayarda yüklü {font} yazı tipinden aldı ve belgenin yazı tipine ekledi. | أخذ Ferman الحرف {chars} من خط {font} المثبّت على هذا الجهاز وأضافه إلى خط المستند. | Edit panel (a3-17): the step 2 notice's message. {chars} is the characters, each in ‘ ’ and separated by the list separator; {font} is the font's name. |
| `fontPickerTitle` | Choose a font for this block | Bu blok için bir yazı tipi seçin | اختيار خط لهذه الكتلة | Font picker (a3-3b): the dialog's title. |
| `fontPickerClose` | Close | Kapat | إغلاق | Font picker (a3-3b): the close button's name. |
| `fontPickerScope` | Replace | Değiştir | الاستبدال | Font picker (a3-3b): the name of the scope control. |
| `fontPickerScopeMissing` | Missing characters only | Yalnızca eksik karakterler | الأحرف المفقودة فقط | Font picker (a3-3b): the scope that sets only the missing characters in the chosen font. |
| `fontPickerScopeBlock` | Whole block | Bloğun tamamı | الكتلة كاملة | Font picker (a3-3b): the scope that sets the whole block in the chosen font (not built yet). |
| `fontPickerSearch` | Search fonts | Yazı tiplerinde ara | البحث في الخطوط | Font picker (a3-3b): the search field's placeholder and name. |
| `fontPickerEmbedded` | Embedded in this document | Bu belgeye gömülü | مضمّنة في هذا المستند | Font picker (a3-3b): the group of the document's own fonts; shown in capitals. |
| `fontPickerInstalled` | Installed on this computer | Bu bilgisayarda yüklü | مثبّتة على هذا الجهاز | Font picker (a3-3b): the group of the installed fonts; shown in capitals. |
| `fontPickerBundled` | Similar fonts included with Ferman | Ferman ile gelen benzer yazı tipleri | خطوط مشابهة مرفقة مع Ferman | Font picker (a3-3b): the group of the fonts that ship with Ferman; shown in capitals. |
| `fontPickerClosest` | Closest match | En yakın eşleşme | الأقرب تطابقًا | Font picker (a3-3b): the tag of the candidate whose metrics are closest to the original's. |
| `fontPickerHas` | Has {chars} | {chars} var | يحتوي {chars} | Font picker (a3-3b): the coverage badge of a font with every missing character. {chars} is the characters, each in ‘ ’ and separated by the list separator. |
| `fontPickerHasNone` | No {chars} | {chars} yok | لا يحتوي {chars} | Font picker (a3-3b): the coverage badge of a font with none of the missing characters. {chars} is the characters, each in ‘ ’ and separated by the list separator. |
| `fontPickerHasSome` | {covered} of {needed} characters | {needed} karakterin {covered} tanesi | {covered} من {needed} أحرف | Font picker (a3-3b): the coverage badge of a font with some of the missing characters. {covered} and {needed} are numbers written for the region. |
| `fontPickerNotEmbeddable` | Can’t be embedded | Gömülemez | لا يمكن تضمينه | Font picker (a3-3b, G37): the badge of a font whose licence forbids using it for new text. |
| `fontPickerNoMatch` | No font matches “{query}”. | “{query}” ile eşleşen yazı tipi yok. | لا يوجد خط يطابق «{query}». | Font picker (a3-3b): shown when the search finds no font. {query} is what was typed. |
| `fontPickerCancel` | Cancel | İptal | إلغاء | Font picker (a3-3b): the button that closes it without a choice. |
| `fontPickerUse` | Use {font} | {font} kullan | استخدام {font} | Font picker (a3-3b): the button that sets the missing characters in the selected font. {font} is its name. |
| `editFontSubstituted` | Font substituted | Yazı tipi değiştirildi | استُبدل الخط | Toast (a11-6): the title after a commit set characters in a similar font, said once per font. |
| `editFontSubstitutedBody` | This block uses {font} for {chars}. | Bu blok {chars} için {font} kullanıyor. | تستخدم هذه الكتلة خط {font} للحرف {chars}. | Toast (a11-6): the message. {font} is the font's name; {chars} is the characters, each in ‘ ’ and separated by the list separator. |
| `editFontSubstitutedDismiss` | Dismiss | Kapat | إغلاق | Toast (a11-6): the name of the toast's close button. |
| `saveAsTitle` | Save as | Farklı kaydet | حفظ باسم | Save as sheet (a1-11): the title. |
| `saveAsName` | File name | Dosya adı | اسم الملف | Save as sheet (a1-11): the file name field's label. |
| `saveAsNameEmpty` | Enter a file name. | Bir dosya adı girin. | أدخل اسم ملف. | Save as sheet: the error under an empty file name. |
| `saveAsNameInvalid` | A file name can’t contain / or \\. | Dosya adı / veya \\ içeremez. | لا يمكن أن يحتوي اسم الملف على / أو \\. | Save as sheet: the error under a file name with a folder separator. |
| `saveAsNameTaken` | A file with this name is already there. Choose another name, or use Other location… | Bu adda bir dosya zaten var. Başka bir ad seçin ya da Başka bir konum… seçeneğini kullanın. | يوجد ملف بهذا الاسم هناك. اختر اسمًا آخر أو استخدم «موقع آخر…». | Save as sheet: the error under a name a file in the chosen folder already has; the system panel of Other location… asks before replacing. |
| `saveAsWhere` | Where | Konum | الموقع | Save as sheet (a1-11): the label of the folder menu. |
| `saveAsOtherLocation` | Other location… | Başka bir konum… | موقع آخر… | Save as sheet (a1-11): the folder menu's item that opens the system save panel (a1-11b). |
| `saveAsFormat` | Format | Biçim | التنسيق | Save as sheet: the accessible name of the format choices. |
| `saveAsPdf` | PDF | PDF | PDF | Save as sheet (a1-11): the standard PDF format. |
| `saveAsPdfDescription` | Standard PDF. Keeps text editable in Ferman and other editors. | Standart PDF. Metin Ferman’da ve diğer düzenleyicilerde düzenlenebilir kalır. | ملف PDF قياسي. يبقى النص قابلًا للتحرير في Ferman والمحررات الأخرى. | Save as sheet (a1-11): the line under PDF. |
| `saveAsPdfA` | PDF/A-2b, for archiving | PDF/A-2b, arşivleme için | PDF/A-2b، للأرشفة | Save as sheet (a1-11): the archiving format, disabled until P4 (G111). |
| `saveAsWeb` | Optimized for web | Web için optimize edilmiş | محسّن للويب | Save as sheet (a1-11): the web format, disabled until M4 (G111). |
| `saveAsCopy` | Save as a copy | Kopya olarak kaydet | حفظ كنسخة | Save as sheet (a1-11): the checkbox that saves a copy and leaves the document as it was. |
| `saveAsCopyDescription` | “{name}” stays open and unchanged; the copy is saved in {folder}. | “{name}” açık ve değişmeden kalır; kopya {folder} klasörüne kaydedilir. | يبقى «{name}» مفتوحًا دون تغيير، وتُحفظ النسخة في {folder}. | Save as sheet (a1-11b): the line under Save as a copy. {name} is the open file's name, {folder} the folder chosen in Where. |
| `saveAsComments` | Include comments and markup | Yorumları ve işaretlemeleri dâhil et | تضمين التعليقات والتعليقات التوضيحية | Save as sheet (a1-11): a checkbox, disabled until saving without comments works. |
| `saveAsHistory` | Remove edit history from the file | Düzenleme geçmişini dosyadan kaldır | إزالة سجل التحرير من الملف | Save as sheet (a1-11): a checkbox, disabled until version history arrives. |
| `saveAsCancel` | Cancel | İptal | إلغاء | Save as sheet: the button that closes it without saving. |
| `saveAsClose` | Close | Kapat | إغلاق | Save dialogs: the name of the close button and of the backdrop. |
| `saveFailedTitle` | Couldn’t save “{name}” | “{name}” kaydedilemedi | تعذّر حفظ «{name}» | Save failure dialog (a11-7, a11-7d): the title. {name} is the file name. |
| `saveFailedDiskFull` | The disk is full. Free some space or save somewhere else. Your edits are kept. | Disk dolu. Biraz yer açın ya da başka bir yere kaydedin. Düzenlemeleriniz korunuyor. | القرص ممتلئ. أفرغ بعض المساحة أو احفظ في مكان آخر. تعديلاتك محفوظة. | Save failure dialog (a11-7): the disk is full. |
| `saveFailedPermission` | You don’t have permission to change this file or its folder. Save it somewhere else, or ask the owner for access. Your edits are kept. | Bu dosyayı veya klasörünü değiştirme izniniz yok. Başka bir yere kaydedin ya da dosyanın sahibinden erişim isteyin. Düzenlemeleriniz korunuyor. | ليس لديك إذن بتغيير هذا الملف أو مجلده. احفظه في مكان آخر أو اطلب الإذن من مالكه. تعديلاتك محفوظة. | Save failure dialog (a11-7d): read-only file or permission denied. |
| `saveFailedLocked` | Another app has the file open and locked. Close it there and try again, or save a copy somewhere else. Your edits are kept. | Dosya başka bir uygulamada açık ve kilitli. Oradan kapatıp yeniden deneyin ya da başka bir yere kopya kaydedin. Düzenlemeleriniz korunuyor. | الملف مفتوح ومقفل في تطبيق آخر. أغلقه هناك ثم أعد المحاولة، أو احفظ نسخة في مكان آخر. تعديلاتك محفوظة. | Save failure dialog (a11-7d): another app locks the file. |
| `saveFailedRename` | Ferman wrote your changes to a temporary file but couldn’t put it in place of the original. The original is unchanged and your edits are kept. | Ferman değişikliklerinizi geçici bir dosyaya yazdı ama özgün dosyanın yerine koyamadı. Özgün dosya değişmedi, düzenlemeleriniz korunuyor. | كتب Ferman تغييراتك في ملف مؤقت، لكنه لم يتمكّن من وضعه مكان الملف الأصلي. لم يتغيّر الملف الأصلي، وتعديلاتك محفوظة. | Save failure dialog (a11-7d): the new file could not replace the original. |
| `saveFailedVolume` | The drive with this file is no longer connected. Reconnect it and try again, or save somewhere else. Your edits are kept. | Bu dosyanın bulunduğu sürücünün bağlantısı kesildi. Sürücüyü yeniden bağlayıp tekrar deneyin ya da başka bir yere kaydedin. Düzenlemeleriniz korunuyor. | لم يعد القرص الذي يحوي هذا الملف متصلًا. أعد توصيله ثم أعد المحاولة، أو احفظ في مكان آخر. تعديلاتك محفوظة. | Save failure dialog (a11-7d): the drive went away during the save. |
| `saveFailedHardLinked` | This file has other links to it, which replacing it would break. Save it somewhere else. Your edits are kept. | Bu dosyaya başka bağlantılar var ve dosyayı değiştirmek onları bozar. Başka bir yere kaydedin. Düzenlemeleriniz korunuyor. | لهذا الملف روابط أخرى سيكسرها استبداله. احفظه في مكان آخر. تعديلاتك محفوظة. | Save failure dialog (G40): the file has other hard links. |
| `saveFailedNotOwner` | This file belongs to someone else, and Ferman couldn’t keep its owner. Save it somewhere else. Your edits are kept. | Bu dosya başka birine ait ve Ferman sahibini koruyamadı. Başka bir yere kaydedin. Düzenlemeleriniz korunuyor. | هذا الملف ملك لشخص آخر، ولم يتمكّن Ferman من الإبقاء على مالكه. احفظه في مكان آخر. تعديلاتك محفوظة. | Save failure dialog (G40): the file belongs to another user. |
| `saveFailedOther` | Ferman couldn’t write the file. Try again, or save somewhere else. Your edits are kept. | Ferman dosyayı yazamadı. Yeniden deneyin ya da başka bir yere kaydedin. Düzenlemeleriniz korunuyor. | تعذّر على Ferman كتابة الملف. أعد المحاولة أو احفظ في مكان آخر. تعديلاتك محفوظة. | Save failure dialog: any other failure. |
| `saveFailedNoRecoveryCopy` | No recovery copy exists: Ferman couldn’t write one either, so until you save, these edits are only in this window. | Kurtarma kopyası yok: Ferman onu da yazamadı; bu düzenlemeler siz kaydedene kadar yalnızca bu pencerede. | لا توجد نسخة استرداد: تعذّر على Ferman كتابتها أيضًا، لذا تبقى هذه التعديلات في هذه النافذة فقط حتى تحفظ. | After a11-7's and a11-7d's message when the recovery copy could not be written either (ARCHITECTURE §7.8, G40): the board's reassurance would not be true. |
| `saveTryAgain` | Try again | Yeniden dene | إعادة المحاولة | Save failure dialog (a11-7d): saves again. |
| `saveSomewhereElse` | Save somewhere else… | Başka bir yere kaydet… | الحفظ في مكان آخر… | Save failure dialog (a11-7): opens Save as when the disk is full. |
| `saveAsEllipsis` | Save as… | Farklı kaydet… | حفظ باسم… | Save failure dialog (a11-7d) and toast (f4): opens Save as. |
| `saveToastDiskFull` | The disk is full. Free some space or save somewhere else. | Disk dolu. Biraz yer açın ya da başka bir yere kaydedin. | القرص ممتلئ. أفرغ بعض المساحة أو احفظ في مكان آخر. | Toast (f4): the message after a save failed on a full disk. |
| `saveToastOther` | Your edits are kept. Try again, or save somewhere else. | Düzenlemeleriniz korunuyor. Yeniden deneyin ya da başka bir yere kaydedin. | تعديلاتك محفوظة. أعد المحاولة أو احفظ في مكان آخر. | Toast (f4): the message after any other failed save. |
| `saveToastDismiss` | Dismiss | Kapat | تجاهل | Toast (f4): the name of the close button. |
| `fileChangedTitle` | “{name}” changed on disk. | “{name}” diskte değişti. | تغيّر «{name}» على القرص. | Bar (a11-7b): another app changed the open file. {name} is the file name. |
| `fileChangedBody` | Another app or a sync service changed it while it was open. Reload it, keep your version, or compare first. | Açıkken başka bir uygulama ya da eşitleme hizmeti değiştirdi. Yeniden yükleyin, kendi sürümünüzü koruyun ya da önce karşılaştırın. | غيّره تطبيق آخر أو خدمة مزامنة أثناء فتحه. أعد تحميله أو احتفظ بنسختك أو قارن أولًا. | Bar (a11-7b): the sentence under the title. |
| `fileChangedCompare` | Compare | Karşılaştır | مقارنة | Bar (a11-7b): compare the two versions (disabled until Compare ships). |
| `fileChangedKeepMine` | Keep mine | Benimkini koru | الاحتفاظ بنسختي | Bar (a11-7b): saves over the change. |
| `fileChangedReload` | Reload | Yeniden yükle | إعادة التحميل | Bar (a11-7b): drops the edits and opens the file again. |
| `optimizeTitle` | Optimize and clean “{name}”? | “{name}” optimize edilip temizlensin mi? | هل تريد تحسين «{name}» وتنظيفه؟ | Warning before Optimize and clean breaks signatures (G35). {name} is the file name. |
| `optimizeSignedBody` | Ferman rewrites the whole file without its earlier versions. Its signatures will no longer be valid. | Ferman dosyanın tamamını önceki sürümleri olmadan yeniden yazar. İmzaları artık geçerli olmaz. | يعيد Ferman كتابة الملف كاملًا دون إصداراته السابقة. لن تبقى تواقيعه صالحة. | Warning before Optimize and clean (G35): what happens to the signatures. |
| `optimizeAction` | Optimize and clean | Optimize et ve temizle | تحسين وتنظيف | Warning before Optimize and clean: the button that rewrites the file. |
| `saveAsNameInvalidWindows` | A file name can’t contain any of these: / \\ : \* ? " &lt; &gt; \| | Dosya adı şunları içeremez: / \\ : \* ? " &lt; &gt; \| | لا يمكن أن يحتوي اسم الملف على أيٍّ من هذه: / \\ : \* ? " &lt; &gt; \| | Save as sheet on Windows: the error under a file name with a character Windows reserves. |
| `saveAsNameOpen` | This file is open in another tab. Close it there, or choose another name. | Bu dosya başka bir sekmede açık. Orada kapatın ya da başka bir ad seçin. | هذا الملف مفتوح في علامة تبويب أخرى. أغلقه هناك أو اختر اسمًا آخر. | Save as sheet: the error when the chosen file is the file of another open tab, which saving over would pull from under it. |
| `saveAsCopyDescriptionHere` | “{name}” stays open and unchanged; the copy is saved alongside it. | “{name}” açık ve değişmeden kalır; kopya yanına kaydedilir. | يبقى «{name}» مفتوحًا دون تغيير، وتُحفظ النسخة بجواره. | Save as sheet (a1-11): the line under Save as a copy while Where is the document's own folder. {name} is the open file's name. |
| `readOnlyFileTitle` | “{name}” is read-only. | “{name}” salt okunur. | «{name}» للقراءة فقط. | a1-9d: the banner's title on a file no one may write. |
| `readOnlyFileBody` | Ferman can’t save changes to this file. To keep your changes, save a copy. | Ferman bu dosyaya değişiklik kaydedemez. Değişikliklerinizi saklamak için bir kopya kaydedin. | لا يستطيع Ferman حفظ التغييرات في هذا الملف. لتحتفظ بتغييراتك، احفظ نسخة. | a1-9d: the banner's text. |
| `readOnlyFileSaveCopy` | Save a copy… | Kopya kaydet… | حفظ نسخة… | a1-9d: the banner's button, which opens the Save as sheet with Save as a copy checked. |
| `closeUnsavedTitle` | Save changes to “{name}”? | “{name}” dosyasındaki değişiklikler kaydedilsin mi? | هل تريد حفظ التغييرات في «{name}»؟ | a1-10b: the question. |
| `closeUnsavedBody` | If you don’t save, your {edits} from this session will be lost. | Kaydetmezseniz bu oturumdaki {edits} kaybolur. | إذا لم تحفظ، ستضيع {edits} التي أجريتها في هذه الجلسة. | a1-10b: what is lost; {edits} is closingEdits. |
| `closingEdits` | {count, plural, =1{1 edit} other{{formatted} edits}} | {count, plural, =1{1 düzenleme} other{{formatted} düzenleme}} | {count, plural, =1{تعديل واحد} =2{تعديلان} few{{formatted} تعديلات} many{{formatted} تعديلًا} other{{formatted} تعديل}} | a1-10b, a1-12, a11-7e: how many edits. |
| `closeUnsavedSave` | Save | Kaydet | حفظ | a1-10b: the default button. |
| `closeUnsavedDiscard` | Don’t save | Kaydetme | عدم الحفظ | a1-10b: closes without saving; the recovery copy goes. |
| `quitReviewTitle` | Save changes to {count, plural, other{{formatted} documents}} before quitting? | Çıkmadan önce {count, plural, other{{formatted} belgedeki}} değişiklikler kaydedilsin mi? | هل تريد حفظ التغييرات في {count, plural, =2{مستندين} few{{formatted} مستندات} many{{formatted} مستندًا} other{{formatted} مستند}} قبل الإنهاء؟ | a11-7e: the question, for two documents or more. |
| `quitReviewBody` | Ferman saves the checked documents, then quits. Changes to unchecked documents are lost. | Ferman işaretli belgeleri kaydedip çıkar. İşaretsiz belgelerdeki değişiklikler kaybolur. | يحفظ Ferman المستندات المحدّدة ثم يُنهي عمله. تضيع تغييرات المستندات غير المحدّدة. | a11-7e. |
| `quitReviewSave` | Save and quit | Kaydet ve çık | حفظ وإنهاء | a11-7e. |
| `quitReviewDiscard` | Quit without saving | Kaydetmeden çık | إنهاء دون حفظ | a11-7e. |
| `recoveryTitle` | Ferman restored {count, plural, =1{1 document} other{{formatted} documents}} | Ferman {count, plural, other{{formatted} belgeyi}} geri yükledi | استعاد Ferman {count, plural, =1{مستندًا واحدًا} =2{مستندين} few{{formatted} مستندات} many{{formatted} مستندًا} other{{formatted} مستند}} | a1-12: the title. |
| `recoveryBody` | Ferman closed unexpectedly. These documents had unsaved changes, and Ferman had kept a copy of each on this device. | Ferman beklenmedik şekilde kapandı. Bu belgelerde kaydedilmemiş değişiklikler vardı ve Ferman her birinin bir kopyasını bu cihazda tuttu. | أُغلق Ferman على نحو غير متوقع. كانت في هذه المستندات تغييرات غير محفوظة، واحتفظ Ferman بنسخة من كلٍّ منها على هذا الجهاز. | a1-12, without the board’s time, which the engine does not know (G40). |
| `recoveryNote` | Restored documents open as unsaved; the files on disk haven’t changed. Nothing was sent anywhere. | Geri yüklenen belgeler kaydedilmemiş olarak açılır; diskteki dosyalar değişmedi. Hiçbir yere bir şey gönderilmedi. | تُفتح المستندات المستعادة كغير محفوظة؛ ولم تتغيّر الملفات على القرص. لم يُرسَل أي شيء إلى أي مكان. | a1-12: under the list. |
| `recoveryDiscard` | Discard | Kopyaları sil | تجاهل النسخ | a1-12: deletes every copy. |
| `recoveryOpen` | {count, plural, =1{Open 1 document} other{Open {formatted} documents}} | {count, plural, other{{formatted} belgeyi aç}} | {count, plural, =1{فتح المستند} =2{فتح المستندين} few{فتح {formatted} مستندات} many{فتح {formatted} مستندًا} other{فتح {formatted} مستند}} | a1-12: the default button; counts the checked rows. |
| `recoveryChangedBadge` | Changed on disk | Diskte değişti | تغيّر على القرص | a11-7f: the badge of a row whose original changed. |
| `recoveryChangedBody` | The file on disk changed after Ferman’s copy. The restored version opens under a new name, so neither is overwritten. | Diskteki dosya, Ferman’ın kopyasından sonra değişti. Geri yüklenen sürüm yeni bir adla açılır; hiçbiri üzerine yazılmaz. | تغيّر الملف على القرص بعد نسخة Ferman. تُفتح النسخة المستعادة باسم جديد، فلا يُستبدل أيٌّ منهما. | a11-7f, without the board’s time and name, which the engine gives only once it opens (G40). |
| `recoveryFileSuffix` | recovered | kurtarılan | مستعاد | a11-7f: the word in brackets in a restored document's new file name, “e-Arşiv fatura 4187 (recovered).pdf”. No slashes. |
| `signedTitle` | Edit a signed document? | İmzalı bir belge düzenlensin mi? | هل تريد تحرير مستند موقّع؟ | a3-16a: the question. |
| `signedBodyBy` | “{name}” has 1 signature, by {signer} on {date}. Any change to the document makes that signature invalid. | “{name}” belgesinde {signer} tarafından {date} tarihinde atılmış 1 imza var. Belgedeki her değişiklik bu imzayı geçersiz kılar. | في «{name}» توقيع واحد من {signer} بتاريخ {date}. أي تغيير في المستند يجعل هذا التوقيع غير صالح. | a3-16a: one signature whose signer and date the file gives. |
| `signedBody` | {count, plural, =1{“{name}” has 1 signature. Any change to the document makes that signature invalid.} other{“{name}” has {formatted} signatures. Any change to the document makes those signatures invalid.}} | {count, plural, =1{“{name}” belgesinde 1 imza var. Belgedeki her değişiklik bu imzayı geçersiz kılar.} other{“{name}” belgesinde {formatted} imza var. Belgedeki her değişiklik bu imzaları geçersiz kılar.}} | {count, plural, =1{في «{name}» توقيع واحد. أي تغيير في المستند يجعل هذا التوقيع غير صالح.} =2{في «{name}» توقيعان. أي تغيير في المستند يجعل هذين التوقيعين غير صالحين.} few{في «{name}» {formatted} توقيعات. أي تغيير في المستند يجعل هذه التوقيعات غير صالحة.} many{في «{name}» {formatted} توقيعًا. أي تغيير في المستند يجعل هذه التوقيعات غير صالحة.} other{في «{name}» {formatted} توقيع. أي تغيير في المستند يجعل هذه التوقيعات غير صالحة.}} | a3-16a: any other number of signatures, or no name or date in the file. |
| `signedEditCopy` | Edit a copy | Bir kopyayı düzenle | تحرير نسخة | a3-16a: the default button. |
| `signedEditAnyway` | Edit anyway | Yine de düzenle | التحرير على أي حال | a3-16a. |
| `signedCopyHint` | The copy opens in a new tab as “{name}”. The signed original stays as it is. | Kopya yeni bir sekmede “{name}” olarak açılır. İmzalı özgün belge olduğu gibi kalır. | تُفتح النسخة في علامة تبويب جديدة باسم «{name}». يبقى الأصل الموقّع كما هو. | a3-16a: under the question. |
| `signedCopyName` | {stem} (copy) | {stem} (kopya) | {stem} (نسخة) | a3-16a: the copy’s file name without its extension. |
| `signedCopyNameNumbered` | {stem} (copy {number}) | {stem} (kopya {number}) | {stem} (نسخة {number}) | a3-16a: the same, when that name is taken; {number} is 2 or more. |
| `signedBannerTitle` | {count, plural, =1{The signature in this document is no longer valid.} other{The signatures in this document are no longer valid.}} | {count, plural, =1{Bu belgedeki imza artık geçerli değil.} other{Bu belgedeki imzalar artık geçerli değil.}} | {count, plural, =1{لم يعد التوقيع في هذا المستند صالحًا.} =2{لم يعد التوقيعان في هذا المستند صالحين.} other{لم تعد التوقيعات في هذا المستند صالحة.}} | a3-16b: the bar after Edit anyway. |
| `signedBannerBodyBy` | You changed the document after {signer} signed it. Saving keeps the signature, but it will show as invalid. | Belgeyi {signer} imzaladıktan sonra değiştirdiniz. Kaydettiğinizde imza belgede kalır ama geçersiz görünür. | غيّرت المستند بعد أن وقّعه {signer}. يبقى التوقيع عند الحفظ، لكنه سيظهر غير صالح. | a3-16b: one signer the file names. |
| `signedBannerBody` | You changed the document after it was signed. Saving keeps the signatures, but they will show as invalid. | Belgeyi imzalandıktan sonra değiştirdiniz. Kaydettiğinizde imzalar belgede kalır ama geçersiz görünür. | غيّرت المستند بعد توقيعه. تبقى التواقيع عند الحفظ، لكنها ستظهر غير صالحة. | a3-16b: otherwise. |
| `signedBannerReview` | Review edits | Düzenlemeleri incele | مراجعة التعديلات | a3-16b: the bar’s button. |
| `signedReviewRow` | {signer}’s signature is no longer valid | {signer} imzası artık geçerli değil | لم يعد توقيع {signer} صالحًا | a3-12: the signature row, at the top of the review list. |
| `signedReviewRowOther` | The signatures are no longer valid | İmzalar artık geçerli değil | لم تعد التواقيع صالحة | a3-12: the same without one named signer. |
| `settingsEditMarks` | Mark edited text | Düzenlenen metni işaretle | وضع علامة على النص المعدَّل | a11-1c. |
| `settingsEditMarksNote` | Shown only in Ferman while you edit. Never saved into the file or printed. | Yalnızca düzenlerken Ferman’da görünür. Dosyaya hiç kaydedilmez, yazdırılmaz. | تظهر في Ferman فقط أثناء التحرير. لا تُحفظ في الملف ولا تُطبع أبدًا. | a11-1c. |
| `settingsMissingGlyphs` | When a font is missing a character | Bir yazı tipinde karakter eksik olduğunda | عندما ينقص خطًّا حرفٌ ما | a11-1c. |
| `settingsMissingGlyphsSimilar` | Use a similar font and say so | Benzer bir yazı tipi kullan ve bunu söyle | استخدام خط مشابه والإشارة إلى ذلك | a11-1c. |
| `settingsMissingGlyphsAsk` | Ask each time | Her seferinde sor | السؤال في كل مرة | a11-1c. |
| `settingsMissingGlyphsMark` | Keep the original font and mark the character | Özgün yazı tipini koru ve karakteri işaretle | الإبقاء على الخط الأصلي ووضع علامة على الحرف | a11-1c. |
| `settingsFontForNewText` | Font for new text | Yeni metnin yazı tipi | خط النص الجديد | a11-1c. |
| `settingsFontForNewTextMatch` | Match surrounding text | Çevredeki metinle aynı | مطابقة النص المحيط | a11-1c: the option shown, while Add text waits (B042). |
| `settingsKeepVersions` | Keep versions | Sürümleri sakla | الاحتفاظ بالإصدارات | a11-1c. |
| `settingsKeepVersions30` | 30 days, next to the file | 30 gün, dosyanın yanında | 30 يومًا، بجانب الملف | a11-1c: the option shown, while version history waits (B060). |
| `settingsReflow` | Let paragraphs reflow inside their frame while typing | Yazarken paragraflar çerçevelerinin içinde yeniden aksın | السماح بإعادة تدفق الفقرات داخل إطارها أثناء الكتابة | a11-1c. |
| `settingsRecoveryCopies` | Save a recovery copy every minute | Her dakika bir kurtarma kopyası kaydet | حفظ نسخة استرداد كل دقيقة | a11-1c: the switch the engine follows. |
| `settingsSaving` | Saving | Kaydetme | الحفظ | a11-1c: the group of G43. |
| `settingsSavingEnd` | Changes are added to the end of the file | Değişiklikler dosyanın sonuna eklenir | تُضاف التغييرات إلى نهاية الملف | a11-1c. |
| `settingsSavingEndBody` | Saving stays fast, and signatures made before your changes stay intact. Ferman rewrites the whole file only when you choose Optimize and clean. | Kaydetme hızlı kalır, değişikliklerinizden önce atılan imzalar bozulmaz. Ferman tüm dosyayı yalnızca siz Optimize et ve temizle’yi seçtiğinizde yeniden yazar. | يبقى الحفظ سريعًا، وتبقى التواقيع السابقة لتغييراتك سليمة. لا يعيد Ferman كتابة الملف كله إلا عندما تختار «التحسين والتنظيف». | a11-1c. |
| `settingsOptimize` | Optimize and clean | Optimize et ve temizle | التحسين والتنظيف | a11-1c. |
| `settingsOptimizeBody` | Rewrites the whole file to make it smaller. Run it from the command palette; it’s never used on its own, and Ferman warns you first if signatures would become invalid. | Küçültmek için tüm dosyayı yeniden yazar. Komut paletinden çalıştırın; kendiliğinden hiç kullanılmaz ve imzalar geçersiz olacaksa Ferman önce sizi uyarır. | يعيد كتابة الملف كله لتصغيره. شغّله من لوحة الأوامر؛ لا يُستخدم من تلقاء نفسه أبدًا، ويحذّرك Ferman أولًا إذا كانت التواقيع ستصبح غير صالحة. | a11-1c. |
| `settingsRecoveryFolder` | Recovery copies | Kurtarma kopyaları | نسخ الاسترداد | a11-1c: above the folder. |
| `shellZoomTypeHint` | Type a zoom from {min} to {max} | {min} ile {max} arasında bir yakınlaştırma yazın | اكتب نسبة تكبير من {min} إلى {max} | View row: what a screen reader says the zoom field takes (a2-2, B127). {min} and {max} are percentages already written for the region. |
| `shellEditForbidden` | The author doesn’t allow editing | Yazar düzenlemeye izin vermiyor | لا يسمح المؤلف بالتحرير | Tooltip of the Edit tab and the Edit text tool on a document whose permissions forbid changes (a2-10a rTip, G27). |
| `editPanelTipClick` | Click any text to select its block. Click again to place the caret. | Bloğunu seçmek için herhangi bir metne tıklayın. İmleci yerleştirmek için yeniden tıklayın. | انقر على أي نص لتحديد كتلته. انقر مرة أخرى لوضع المؤشر. | Edit panel (a3-1a): the first tip. |
| `editPanelTipKeys` | Tab moves between blocks; Enter starts editing. Hold {key} to show every block. | Tab bloklar arasında gezinir; Enter düzenlemeyi başlatır. Tüm blokları göstermek için {key} tuşunu basılı tutun. | ينتقل Tab بين الكتل ويبدأ Enter التحرير. اضغط مع الاستمرار على {key} لإظهار كل الكتل. | Edit panel (a3-1a): the second tip. {key} is the key cap of Option or Alt, drawn as a key. |
| `editPanelInSession` | in this session | bu oturumda | في هذه الجلسة | Edit panel (a3-1a): after the badge with the number of edits, as in "3 edits in this session". |
| `editPanelReview` | Review | İncele | مراجعة | Edit panel (a3-1a): the button that opens the list of edits, after their number. |
| `languageNameGerman` | German | Almanca | الألمانية | The German language, named in the interface language: the Language select of the Edit panel (a3-14, FmEditPanel langs). |
| `languageNameJapanese` | Japanese | Japonca | اليابانية | The Japanese language, named in the interface language: the Language select of the Edit panel (a3-14, FmEditPanel langs). |
| `languageWithRegion` | {language} ({region}) | {language} ({region}) | {language} ({region}) | A text block's language with its region, in the status bar (a3-14: "English (United Kingdom)"). |
| `editLanguage` | Language | Dil | اللغة | Edit panel: title of the section with the language of the block being edited, and the name of its select (a3-14, FmEditPanel t.lang). |
| `editCheckSpelling` | Check spelling | Yazım denetimi | التدقيق الإملائي | Edit panel, Language section: the switch that spell-checks the block (a3-14, FmEditPanel t.spell). |
| `editHyphenate` | Hyphenate | Tireleme | الوصل بشرطة | Edit panel, Language section: the switch that hyphenates the block (a3-14, FmEditPanel t.hyph). |
| `editStepLanguage` | Changed language · page {page} | Dil değiştirildi · sayfa {page} | تغيير اللغة · الصفحة {page} | Edit mode: the name of a history step that changed only the language of a block, in the Undo history panel (a3-10). {page} is the page number, formatted for the region. |
| `reviewClose` | Close review | İncelemeyi kapat | إغلاق المراجعة | a3-12: the panel’s close button. |
| `reviewShow` | Show | Göster | عرض | a3-12: the filter’s accessible name. |
| `reviewFilterAll` | All | Tümü | الكل | a3-12: filter. |
| `reviewFilterText` | Text | Metin | النص | a3-12: filter. |
| `reviewFilterFonts` | Fonts | Yazı tipleri | الخطوط | a3-12: filter. |
| `reviewFilterWarnings` | Warnings | Uyarılar | التحذيرات | a3-12: filter. |
| `reviewEmptyTitle` | No edits yet | Henüz düzenleme yok | لا توجد تعديلات بعد | a3-12b: the empty list. |
| `reviewEmptyBody` | Changes you make in this session appear here. The list clears when you close the document; earlier sessions are in Version history. | Bu oturumda yaptığınız değişiklikler burada görünür. Liste belgeyi kapattığınızda temizlenir; önceki oturumlar Sürüm geçmişi’nde. | تظهر هنا التغييرات التي تجريها في هذه الجلسة. تُمسح القائمة عند إغلاق المستند، والجلسات السابقة في سجل الإصدارات. | a3-12b: the empty list. |
| `reviewNothing` | No edits yet | Henüz düzenleme yok | لا توجد تعديلات بعد | a3-12b: why Revert all and Export list are disabled. |
| `reviewRevertAll` | Revert all… | Tümünü geri al… | التراجع عن الكل… | a3-12: footer. |
| `reviewExportList` | Export list… | Listeyi dışa aktar… | تصدير القائمة… | a3-12: footer. |
| `reviewGoTo` | Go to | Git | الانتقال | a3-12: a row’s button. |
| `reviewRevert` | Revert | Geri al | تراجع | a3-12: a row’s button. |
| `reviewStepReverted` | Reverted an edit | Bir düzenleme geri alındı | تم التراجع عن تعديل | a3-10: the history step of a revert from the review list. |
| `reviewStepRevertedAll` | Reverted all edits | Tüm düzenlemeler geri alındı | تم التراجع عن كل التعديلات | a3-10: the history step of Revert all. |
| `reviewWhereSignature` | Signature | İmza | التوقيع | a3-12: where the signature row is when several signatures on different pages are gone. |
| `reviewWhereSignaturePage` | Page {page} · signature | Sayfa {page} · imza | الصفحة {page} · التوقيع | a3-12: where the signature row is, with one signer. {page} is formatted for the region. |
| `reviewWhereText` | Page {page} · text | Sayfa {page} · metin | الصفحة {page} · النص | a3-12: where a row is. {page} is formatted for the region. The block has no name (G125). |
| `reviewWhereFont` | Page {page} · font | Sayfa {page} · yazı tipi | الصفحة {page} · الخط | a3-12: where a row is. |
| `reviewWhereWarning` | Page {page} · kept warning | Sayfa {page} · korunan uyarı | الصفحة {page} · تحذير محفوظ | a3-12: where a row is. |
| `reviewExportName` | {name} edits | {name} düzenlemeleri | تعديلات {name} | a3-12: the file name Export list suggests, without its extension. |
| `reviewExportFailed` | The list couldn’t be saved. | Liste kaydedilemedi. | تعذّر حفظ القائمة. | a3-12: Export list failed. |
| `reviewRevertAllBody` | “{name}” goes back to how it was when you opened it. Undo brings the edits back until you close the document. | “{name}”, açtığınızdaki hâline döner. Belgeyi kapatana kadar Geri al ile düzenlemeleri geri getirebilirsiniz. | يعود «{name}» إلى ما كان عليه عند فتحه. يمكنك استعادة التعديلات بالأمر «تراجع» حتى تغلق المستند. | a3-12b: Revert all’s question. The board also names the time it opened, which the app does not keep. |
| `reviewDependentBody` | “{later}” was typed into the sentence after this change. Reverting “{change}” removes it too. | “{later}” bu değişiklikten sonra aynı cümleye yazıldı. “{change}” geri alınırsa o da kaldırılır. | كُتب «{later}» في الجملة بعد هذا التغيير. التراجع عن «{change}» يزيله أيضًا. | a3-12b: an edit a later edit depends on (G42). |
| `reviewDependentsBody` | {count, plural, other{{shown} later edits build on this change. Reverting “{change}” removes them too.}} | {count, plural, other{{shown} sonraki düzenleme bu değişikliğe bağlı. “{change}” geri alınırsa onlar da kaldırılır.}} | {count, plural, =2{يعتمد تعديلان لاحقان على هذا التغيير. التراجع عن «{change}» يزيلها أيضًا.} few{تعتمد {shown} تعديلات لاحقة على هذا التغيير. التراجع عن «{change}» يزيلها أيضًا.} many{يعتمد {shown} تعديلًا لاحقًا على هذا التغيير. التراجع عن «{change}» يزيلها أيضًا.} other{يعتمد {shown} تعديل لاحق على هذا التغيير. التراجع عن «{change}» يزيلها أيضًا.}} | a3-12b: the same with several later edits, always two or more. {shown} is {count} formatted for the region. |
| `reviewKeptWarning` | {count, plural, =1{{shown} line hidden — overflow kept} other{{shown} lines hidden — overflow kept}} | {count, plural, other{{shown} satır gizli — taşma korundu}} | {count, plural, =1{{shown} سطر مخفي — أُبقي التجاوز} =2{سطران مخفيان — أُبقي التجاوز} few{{shown} أسطر مخفية — أُبقي التجاوز} many{{shown} سطرًا مخفيًا — أُبقي التجاوز} other{{shown} سطر مخفي — أُبقي التجاوز}} | a3-12: a kept warning’s row. |
| `reviewRevertAllTitle` | {count, plural, =1{Revert the edit?} other{Revert all {shown} edits?}} | {count, plural, =1{Düzenleme geri alınsın mı?} other{{shown} düzenlemenin tümü geri alınsın mı?}} | {count, plural, =1{هل تريد التراجع عن التعديل؟} other{هل تريد التراجع عن التعديلات الـ{shown} كلها؟}} | a3-12b. |
| `reviewRevertAllButton` | {count, plural, =1{Revert {shown} edit} other{Revert {shown} edits}} | {count, plural, other{{shown} düzenlemeyi geri al}} | {count, plural, =1{التراجع عن تعديل واحد} =2{التراجع عن تعديلين} few{التراجع عن {shown} تعديلات} many{التراجع عن {shown} تعديلًا} other{التراجع عن {shown} تعديل}} | a3-12b. |
| `reviewDependentTitle` | {count, plural, =1{Also revert the edit that depends on it?} other{Also revert the {shown} edits that depend on it?}} | {count, plural, =1{Buna bağlı düzenleme de geri alınsın mı?} other{Buna bağlı {shown} düzenleme de geri alınsın mı?}} | {count, plural, =1{هل تريد أيضًا التراجع عن التعديل المعتمد عليه؟} other{هل تريد أيضًا التراجع عن التعديلات الـ{shown} المعتمدة عليه؟}} | a3-12b (G42). |
| `reviewDependentButton` | {count, plural, =1{Revert both} other{Revert all {shown}}} | {count, plural, =1{İkisini de geri al} other{{shown} düzenlemeyi de geri al}} | {count, plural, =1{التراجع عن كليهما} other{التراجع عن الـ{shown} كلها}} | a3-12b (G42). {shown} counts the edit asked about too. |
| `editPanelTitle` | Text block | Metin bloğu | كتلة نص | a3-2 (FmEditPanel t.title): the title of the right panel while a block is edited. |
| `editPanelText` | Text | Metin | النص | a3-2: section. |
| `editPanelSize` | Size | Boyut | الحجم | a3-2: the font size field's screen-reader name. |
| `editPanelColour` | Text color | Metin rengi | لون النص | a3-2: the colour popover's screen-reader name. |
| `editPanelColoursDocument` | In this document | Bu belgede | في هذا المستند | a3-2: colours section of the colour popover. |
| `editPanelColoursStandard` | Standard | Standart | قياسية | a3-2: colours section of the colour popover. |
| `editPanelFontsDocument` | In this document | Bu belgede | في هذا المستند | a3-2: fonts section of the font popover. |
| `editPanelFontsDevice` | On this device | Bu cihazda | على هذا الجهاز | a3-2: fonts section of the font popover. |
| `editPanelBold` | Bold | Kalın | غامق | a3-2: button. |
| `editPanelItalic` | Italic | İtalik | مائل | a3-2: button. |
| `editPanelUnderline` | Underline | Altı çizili | تسطير | a3-2: button. |
| `editPanelNoBold` | This font has no other weight on this computer that can draw this text. | Bu yazı tipinin bu bilgisayarda bu metni çizebilecek başka bir kalınlığı yok. | لا يتوفر لهذا الخط على هذا الكمبيوتر وزن آخر يمكنه رسم هذا النص. | a3-2: why Bold is disabled; bold is never faked. |
| `editPanelNoItalic` | This font has no italic on this computer that can draw this text. | Bu yazı tipinin bu bilgisayarda bu metni çizebilecek bir italiği yok. | لا يتوفر لهذا الخط على هذا الكمبيوتر شكل مائل يمكنه رسم هذا النص. | a3-2: why Italic is disabled; italic is never faked. |
| `editPanelNoUnderline` | A PDF font has no underline to switch to, and Ferman does not draw a false one. | PDF yazı tiplerinde geçilecek bir altı çizili biçim yoktur ve Ferman sahtesini çizmez. | لا يوجد في خطوط PDF شكل مسطّر للتبديل إليه، ولا يرسم Ferman تسطيرًا زائفًا. | a3-2: why Underline is disabled. |
| `editPanelAlignment` | Alignment | Hizalama | المحاذاة | a3-2: the alignment group's screen-reader name. |
| `editPanelAlignLeft` | Align left | Sola hizala | محاذاة لليسار | a3-2: segment. |
| `editPanelAlignCenter` | Center | Ortala | توسيط | a3-2: segment. |
| `editPanelAlignRight` | Align right | Sağa hizala | محاذاة لليمين | a3-2: segment. |
| `editPanelAlignJustify` | Justify | İki yana yasla | ضبط | a3-2: segment. |
| `editPanelSpacing` | Spacing | Aralık | التباعد | a3-2: section. |
| `editPanelCharacter` | Character | Karakter | الأحرف | a3-2: spacing between characters. |
| `editPanelLine` | Line | Satır | الأسطر | a3-2: spacing between lines. |
| `editPanelBefore` | Before | Önce | قبل | a3-2: spacing before the block. |
| `editPanelAfter` | After | Sonra | بعد | a3-2: spacing after the block. |
| `editPanelPosition` | Position and size | Konum ve boyut | الموضع والحجم | a3-2: section. |
| `editPanelWidth` | Width | Genişlik | العرض | a3-2: field. |
| `editPanelHeight` | Height | Yükseklik | الارتفاع | a3-2: field. |
| `editPanelReset` | Reset text style | Metin stilini sıfırla | إعادة تعيين نمط النص | a3-2: button in the heading. |
| `editPanelHint` | Text reflows inside the frame. Drag a handle to resize it. | Metin çerçevenin içinde yeniden akar. Boyutlandırmak için bir tutamacı sürükleyin. | يُعاد تدفق النص داخل الإطار. اسحب مقبضًا لتغيير الحجم. | a3-2: the note at the panel's end. |
| `editBarLabel` | Format selection | Seçimi biçimlendir | تنسيق التحديد | a3-1c: the accessible name of the floating format bar. |
| `editBarLink` | Add link | Bağlantı ekle | إضافة رابط | a3-1c: button, disabled until links work. |
| `editBarHighlight` | Highlight (adds a comment) | Vurgula (yorum ekler) | تمييز (يضيف تعليقًا) | a3-1c: button, disabled until comments work. |
| `editBarComment` | Comment on selection | Seçime yorum ekle | التعليق على التحديد | a3-1c: button, disabled until comments work. |
| `editBarReplace` | Find and replace these words | Bu sözcükleri bul ve değiştir | البحث عن هذه الكلمات واستبدالها | a3-1c: button, disabled until find and replace works. |
| `editStepStyle` | Changed text style · page {page} | Metin stili değiştirildi · sayfa {page} | تغيير نمط النص · الصفحة {page} | a3-10: the name of a history step: a change in the text panel (a3-2) or a handle's drag. {page} is the page number, formatted for the region. |
| `editStepMoved` | Moved text block · page {page} | Metin bloğu taşındı · sayfa {page} | نقل كتلة النص · الصفحة {page} | a3-10: the name of a history step: a change in the text panel (a3-2) or a handle's drag. {page} is the page number, formatted for the region. |
| `editStepResized` | Resized text block · page {page} | Metin bloğu boyutlandırıldı · sayfa {page} | تغيير حجم كتلة النص · الصفحة {page} | a3-10: the name of a history step: a change in the text panel (a3-2) or a handle's drag. {page} is the page number, formatted for the region. |
| `phoneSections` | Sections | Bölümler | الأقسام | Phone navigation bar: its name for screen readers (FmPhone, tabsLabel). |
| `phoneTabHome` | Home | Ana sayfa | الرئيسية | Phone navigation bar: the start screen (FmPhone). |
| `phoneTabFiles` | Files | Dosyalar | الملفات | Phone navigation bar: the file browser (FmPhone). |
| `phoneTabScan` | Scan | Tara | مسح | Phone navigation bar: Scan to PDF (FmPhone). |
| `phoneTabSettings` | Settings | Ayarlar | الإعدادات | Phone navigation bar: Settings (FmPhone). |
| `jobPageOf` | Page {page} of {pages} | Sayfa {page} / {pages} | الصفحة {page} من {pages} | a11-6b: where a background task is. |
| `jobPausedAtPage` | Paused at page {page} | {page}. sayfada duraklatıldı | متوقفة مؤقتًا عند الصفحة {page} | a11-6b: a paused task's place. |
| `jobFailedDiskFull` | The disk is full. Free some space and try again. | Disk dolu. Biraz yer açıp yeniden deneyin. | القرص ممتلئ. أفرغ بعض المساحة ثم حاول مرة أخرى. | a11-6b: why a background task failed. |
| `jobCopyingTitle` | Copying {name} | {name} kopyalanıyor | جارٍ نسخ {name} | a11-6b: the title of a task that copies a document. |
| `jobCopiedTitle` | Copied {name} | {name} kopyalandı | تم نسخ {name} | a11-6b: the title of the finished copy. |
| `jobCopyFailedTitle` | Couldn’t copy {name} | {name} kopyalanamadı | تعذّر نسخ {name} | a11-6b: the title of a failed copy. |
| `tasksTitle` | Background tasks | Arka plan görevleri | المهام في الخلفية | a11-6b: the drawer's title and its region's name. |
| `tasksClose` | Close drawer | Paneli kapat | إغلاق اللوحة | a11-6b: the drawer's close button. |
| `tasksOpen` | Show or hide background tasks | Arka plan görevlerini göster veya gizle | إظهار المهام في الخلفية أو إخفاؤها | Status bar: screen-reader name of the task line, which opens the drawer. |
| `tasksEmptyTitle` | No background tasks | Arka plan görevi yok | لا توجد مهام في الخلفية | G49: the empty drawer. |
| `tasksEmptyBody` | Long work, such as compressing a file, runs here while you keep working. | Dosya sıkıştırma gibi uzun işler, siz çalışmaya devam ederken burada yürür. | تُنفَّذ هنا الأعمال الطويلة، مثل ضغط ملف، بينما تواصل عملك. | G49: the empty drawer. |
| `tasksRunning` | {count, plural, =1{1 task running} other{{formatted} tasks running}} | {count, plural, other{{formatted} görev sürüyor}} | {count, plural, =1{مهمة واحدة قيد التنفيذ} =2{مهمتان قيد التنفيذ} few{{formatted} مهام قيد التنفيذ} many{{formatted} مهمةً قيد التنفيذ} other{{formatted} مهمة قيد التنفيذ}} | Status bar: several background tasks in the one task line. |
| `taskPause` | Pause | Duraklat | إيقاف مؤقت | a11-6b: pauses a task. |
| `taskResume` | Resume | Sürdür | متابعة | a11-6b: resumes a paused task. |
| `taskShow` | Show | Göster | إظهار | a11-6b: shows a finished task's file in the file manager. |
| `taskDismiss` | Dismiss | Kapat | إغلاق | a11-6b: takes a finished task's row away. |
| `taskCancelTitle` | Cancel “{task}”? | “{task}” iptal edilsin mi? | هل تريد إلغاء ”{task}“؟ | G49: the question before a running task is cancelled; task is its title. |
| `taskCancelBody` | Its work so far is discarded, and no file is left behind. | Şimdiye kadarki işi silinir ve geride dosya kalmaz. | يُتجاهل ما أُنجز منها حتى الآن، ولا يبقى أي ملف. | G49: the question before a running task is cancelled. |
| `taskKeepRunning` | Keep running | Sürmeye devam etsin | متابعة التنفيذ | G49: leaves the task running. |
| `taskCancelConfirm` | Cancel task | Görevi iptal et | إلغاء المهمة | G49: cancels the task. |
| `tasksQuitTitle` | {count, plural, =1{A background task is still running} other{{formatted} background tasks are still running}} | {count, plural, other{{formatted} arka plan görevi hâlâ sürüyor}} | {count, plural, =1{لا تزال مهمة واحدة قيد التنفيذ في الخلفية} =2{لا تزال مهمتان قيد التنفيذ في الخلفية} few{لا تزال {formatted} مهام قيد التنفيذ في الخلفية} many{لا تزال {formatted} مهمةً قيد التنفيذ في الخلفية} other{لا تزال {formatted} مهمة قيد التنفيذ في الخلفية}} | Quitting with background tasks running: the question. |
| `tasksQuitBody` | Quitting cancels them, and they leave no partial files. | Çıkmak onları iptal eder; geride yarım dosya kalmaz. | يؤدي الإنهاء إلى إلغائها، ولا تترك ملفات غير مكتملة. | Quitting with background tasks running. |
| `tasksQuitKeep` | Keep working | Çalışmaya devam et | مواصلة العمل | Quitting with background tasks running: stays in the app. |
| `tasksQuitConfirm` | Cancel tasks and quit | Görevleri iptal et ve çık | إلغاء المهام والإنهاء | Quitting with background tasks running: goes on. |
| `organizeGridLabel` | Pages | Sayfalar | الصفحات | Organize (a6-1): the screen-reader name of the page grid. |
| `organizePanelLabel` | Selection | Seçim | التحديد | Organize (a6-1): the screen-reader name of the right panel. |
| `organizeHintSelected` | {total, plural, =1{{selected} of {pages} page selected} other{{selected} of {pages} pages selected}} | {total, plural, other{{selected}/{pages} sayfa seçili}} | {total, plural, =1{{selected} من صفحة واحدة محددة} =2{{selected} من صفحتين محددة} few{{selected} من {pages} صفحات محددة} other{{selected} من {pages} صفحة محددة}} | Organize tool row (a6-1): the hint with a selection. {selected} and {pages} are written for the region; {total} picks the plural form. |
| `organizeHintMoving` | {count, plural, =1{Moving {n} page} other{Moving {n} pages}} | {count, plural, other{{n} sayfa taşınıyor}} | {count, plural, =1{جارٍ نقل صفحة واحدة} =2{جارٍ نقل صفحتين} few{جارٍ نقل {n} صفحات} other{جارٍ نقل {n} صفحة}} | Organize tool row (a6-1b): the hint during a drag. |
| `organizePanelTitle` | {count, plural, =1{{n} page selected} other{{n} pages selected}} | {count, plural, other{{n} sayfa seçili}} | {count, plural, =1{صفحة واحدة محددة} =2{صفحتان محددتان} few{{n} صفحات محددة} other{{n} صفحة محددة}} | Organize panel (a6-1): the heading. |
| `organizePanelPages` | Pages | Sayfalar | الصفحات | Organize panel (a6-1): the section, and its first row's name. |
| `organizePanelPagesLabels` | {pages} (labels {labels}) | {pages} (etiketler {labels}) | {pages} (التسميات {labels}) | Organize panel (a6-1): the selected pages' numbers and their page labels. |
| `organizePanelSize` | Size | Boyut | الحجم | Organize panel (a6-1): the row with the pages' size. |
| `organizePanelRotation` | Rotation | Döndürme | التدوير | Organize panel (a6-1): the row with the pages' rotation. |
| `organizePanelMixed` | Mixed | Karışık | متنوع | Organize panel: pages of the selection differ in this value; not drawn. |
| `organizePanelCommands` | Commands | Komutlar | الأوامر | Organize panel (a6-1): the section of commands. |
| `organizePanelExtract` | Extract… | Ayıkla… | استخراج… | Organize panel (a6-1): opens Extract. |
| `organizePanelReplace` | Replace… | Değiştir… | استبدال… | Organize panel (a6-1): opens Replace. |
| `organizePanelInsertAfter` | Insert after page {page} | {page}. sayfadan sonra ekle | إدراج بعد الصفحة {page} | Organize panel (a6-1): the section. {page} is the last selected page's number. |
| `organizePanelBlankPage` | Blank page | Boş sayfa | صفحة فارغة | Organize panel (a6-1): inserts a blank page. |
| `organizePanelFromFile` | Pages from a file… | Dosyadan sayfalar… | صفحات من ملف… | Organize panel (a6-1): inserts pages from a file. |
| `organizePanelFromScanner` | From scanner or camera… | Tarayıcıdan veya kameradan… | من ماسح ضوئي أو كاميرا… | Organize panel (a6-1): inserts pages from a scanner or camera. |
| `organizePagesCount` | {count, plural, =1{{n} page} other{{n} pages}} | {count, plural, other{{n} sayfa}} | {count, plural, =1{صفحة واحدة} =2{صفحتان} few{{n} صفحات} other{{n} صفحة}} | Organize's page menu (a6-1): its heading. |
| `organizeMenuExtract` | Extract as new PDF… | Yeni PDF olarak ayıkla… | استخراج كملف PDF جديد… | Organize's page menu (a6-1). |
| `organizeMenuInsertBlank` | Insert blank page after | Sonrasına boş sayfa ekle | إدراج صفحة فارغة بعدها | Organize's page menu (a6-1). |
| `organizeMenuInsertFile` | Insert pages from file… | Dosyadan sayfa ekle… | إدراج صفحات من ملف… | Organize's page menu (a6-1). |
| `organizeMenuReplace` | Replace with pages from file… | Dosyadaki sayfalarla değiştir… | استبدال بصفحات من ملف… | Organize's page menu (a6-1). |
| `organizeMenuDelete` | {count, plural, =1{Delete {n} page} other{Delete {n} pages}} | {count, plural, other{{n} sayfayı sil}} | {count, plural, =1{حذف صفحة واحدة} =2{حذف صفحتين} few{حذف {n} صفحات} other{حذف {n} صفحة}} | Organize's page menu (a6-1). |
| `organizeDeleteAllReason` | A document keeps at least one page | Belgede en az bir sayfa kalmalı | يجب أن يحتفظ المستند بصفحة واحدة على الأقل | Organize: why Delete is disabled with every page selected; not drawn. |
| `organizeToastDeleted` | {count, plural, =1{{n} page deleted} other{{n} pages deleted}} | {count, plural, other{{n} sayfa silindi}} | {count, plural, =1{حُذفت صفحة واحدة} =2{حُذفت صفحتان} few{حُذفت {n} صفحات} other{حُذفت {n} صفحة}} | Toast (a11-6) and history step: after deleting pages. |
| `organizeToastRotated` | {count, plural, =1{{n} page rotated} other{{n} pages rotated}} | {count, plural, other{{n} sayfa döndürüldü}} | {count, plural, =1{دُوّرت صفحة واحدة} =2{دُوّرت صفحتان} few{دُوّرت {n} صفحات} other{دُوّرت {n} صفحة}} | Toast and history step: after rotating pages. |
| `organizeToastDuplicated` | {count, plural, =1{{n} page duplicated} other{{n} pages duplicated}} | {count, plural, other{{n} sayfa çoğaltıldı}} | {count, plural, =1{كُررت صفحة واحدة} =2{كُررت صفحتان} few{كُررت {n} صفحات} other{كُررت {n} صفحة}} | Toast and history step: after duplicating pages. |
| `organizeToastMoved` | {count, plural, =1{{n} page moved} other{{n} pages moved}} | {count, plural, other{{n} sayfa taşındı}} | {count, plural, =1{نُقلت صفحة واحدة} =2{نُقلت صفحتان} few{نُقلت {n} صفحات} other{نُقلت {n} صفحة}} | Toast (a6-1b) and history step: after moving pages. |
| `organizeToastInserted` | {count, plural, =1{{n} page inserted} other{{n} pages inserted}} | {count, plural, other{{n} sayfa eklendi}} | {count, plural, =1{أُدرجت صفحة واحدة} =2{أُدرجت صفحتان} few{أُدرجت {n} صفحات} other{أُدرجت {n} صفحة}} | Toast: after a drop on the page grid inserted a file's pages. |
| `organizeToastPages` | {count, plural, =1{Page {pages}} other{Pages {pages}}} | {count, plural, =1{Sayfa {pages}} other{Sayfalar {pages}}} | {count, plural, =1{الصفحة {pages}} other{الصفحات {pages}}} | Toast (a11-6): the pages a command acted on, such as 4–6. |
| `organizeToastDeletedNote` | {count, plural, =1{{pages}. It stays in the file until you run Optimize and clean.} other{{pages}. They stay in the file until you run Optimize and clean.}} | {count, plural, other{{pages}. Optimize et ve temizle’yi seçene kadar dosyada kalır.}} | {count, plural, =1{{pages}. تبقى في الملف إلى أن تشغّل «تحسين وتنظيف».} other{{pages}. تبقى في الملف إلى أن تشغّل «تحسين وتنظيف».}} | Toast after deleting pages (M4 plan question 5): {pages} is organizeToastPages. Say that the content remains recoverable from the file. Use the name of the Optimize and clean command. |
| `organizeStepInsert` | Insert {name} | {name} ekle | إدراج {name} | History step: inserted the file {name}. |
| `organizeFailed` | The pages weren’t changed | Sayfalar değiştirilmedi | لم تتغير الصفحات | Toast: a page command failed; the document is as it was. |
| `organizeInsertFailed` | Couldn’t insert {name} | {name} eklenemedi | تعذّر إدراج {name} | Toast and task drawer: a dropped file's pages could not go in. |
| `organizeDropMoveBefore` | {count, plural, =1{Drop to move page {pages} before page {before}} other{Drop to move pages {pages} before page {before}}} | {count, plural, =1{{pages}. sayfayı {before}. sayfanın önüne taşımak için bırakın} other{{pages}. sayfaları {before}. sayfanın önüne taşımak için bırakın}} | {count, plural, =1{أفلت لنقل الصفحة {pages} قبل الصفحة {before}} other{أفلت لنقل الصفحات {pages} قبل الصفحة {before}}} | Page grid (a6-1b): what a drop does. |
| `organizeDropMoveEnd` | {count, plural, =1{Drop to move page {pages} to the end} other{Drop to move pages {pages} to the end}} | {count, plural, =1{{pages}. sayfayı sona taşımak için bırakın} other{{pages}. sayfaları sona taşımak için bırakın}} | {count, plural, =1{أفلت لنقل الصفحة {pages} إلى النهاية} other{أفلت لنقل الصفحات {pages} إلى النهاية}} | Page grid (a6-1b): what a drop past the last page does. |
| `organizeDropFilesBefore` | Drop to insert before page {before} | {before}. sayfanın önüne eklemek için bırakın | أفلت للإدراج قبل الصفحة {before} | Page grid: files over the grid (G105), what a drop does. |
| `organizeDropFilesEnd` | Drop to insert at the end | Sona eklemek için bırakın | أفلت للإدراج في النهاية | Page grid: files over the grid past the last page (G105). |
| `jobInsertingTitle` | Reading {name} | {name} okunuyor | جارٍ قراءة {name} | Task drawer: a dropped file's pages being read. |
| `jobInsertedTitle` | Inserted {name} | {name} eklendi | أُدرج {name} | Task drawer: a dropped file's pages are read. |
| `organizeSelectFirst` | Select pages first | Önce sayfaları seçin | حدد الصفحات أولًا | Organize tool row: why a command on the selection is disabled while none is selected; not drawn. |

<!-- END GENERATED TRANSLATION TABLE -->
