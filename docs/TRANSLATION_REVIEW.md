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

424 messages in `app_en.arb`; translated: Turkish 424, Arabic 424.

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
| `onboardingLanguageSearchLabel` | Search languages | Dil ara | ابحث عن لغة | Screen-reader name of the search field of the first-run language picker (a1-1). |
| `onboardingLanguageNoMatch` | No language matches “{query}”. | “{query}” ile eşleşen dil yok. | لا توجد لغة تطابق «{query}». | Shown in the first-run language picker (a1-1) when the search finds no language. {query} is what the person typed. |
| `onboardingLanguageMissing` | Missing your language? | Dilinizi bulamadınız mı? | لم تجد لغتك؟ | Footer of the first-run language picker (a1-1), before the Help translate Ferman link. |
| `onboardingLanguageHelpTranslate` | Help translate Ferman | Ferman’ı çevirmeye yardım edin | ساعد في ترجمة Ferman | Link in the footer of the first-run language picker (a1-1) to the community translation project. |
| `onboardingContinue` | Continue | Devam | متابعة | Button that leaves the first-run language picker for the welcome steps (a1-1). |
| `onboardingStep` | {step} of {count} | {step} / {count} | {step} من {count} | Step counter above the heading of a first-run welcome step (a1-2b, a1-2c), such as 1 of 2. The numbers come already formatted for the region. |
| `onboardingStepLabel` | Step {step} of {count} | Adım {step}, toplam {count} | الخطوة {step} من {count} | Screen-reader name of the step dots at the bottom of a first-run welcome step (a1-2b, a1-2c). The numbers come already formatted for the region. |
| `onboardingSkip` | Skip | Atla | تخطّي | Button at the bottom start of a first-run welcome step that goes straight to the start screen (a1-2b). |
| `onboardingBack` | Back | Geri | رجوع | Button that returns to the previous first-run step (a1-2b, a1-2c). |
| `onboardingNext` | Next | İleri | التالي | Button that moves to the next first-run welcome step (a1-2b). |
| `onboardingStartUsing` | Start using Ferman | Ferman’ı kullanmaya başla | بدء استخدام Ferman | Button on the last first-run welcome step that ends first run and opens the start screen (a1-2c). |
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
| `onboardingFeatureEditing` | Edit text and images | Metin ve görsel düzenleme | تحرير النصوص والصور | Feature tile on the last first-run welcome step (a1-2c). |
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
| `findSearching` | Searching · page {page} of {pages} | Aranıyor · sayfa {page} / {pages} | جارٍ البحث · الصفحة {page} من {pages} | A long search's progress (a2-4c); numbers in the region's format. |
| `findNoneTitle` | No results for “{query}” | “{query}” için sonuç yok | لا نتائج لـ«{query}» | No results: the title, with the query as typed (a2-4d). |
| `findNoneBody` | Ferman searched {count, plural, =1{the only page} other{all {pages} pages}}, ignoring accents and dotted/dotless i. Comments and form fields weren’t searched. | Ferman {count, plural, =1{tek sayfada} other{{pages} sayfanın tamamında}} aradı; aksanlar ve noktalı/noktasız i yok sayıldı. Yorumlar ve form alanları aranmadı. | بحث Ferman في {count, plural, =1{الصفحة الوحيدة} =2{الصفحتين كلتيهما} other{الصفحات الـ{pages} كلها}}، مع تجاهل علامات التشكيل والفرق بين i المنقوطة وغير المنقوطة. لم يُبحث في التعليقات وحقول النماذج. | No results: what was searched and how, with Ignore accents on (a2-4d). count is the page count, pages the same number in the region's format. |
| `findNoneBodyExact` | Ferman searched {count, plural, =1{the only page} other{all {pages} pages}}. Comments and form fields weren’t searched. | Ferman {count, plural, =1{tek sayfada} other{{pages} sayfanın tamamında}} aradı. Yorumlar ve form alanları aranmadı. | بحث Ferman في {count, plural, =1{الصفحة الوحيدة} =2{الصفحتين كلتيهما} other{الصفحات الـ{pages} كلها}}. لم يُبحث في التعليقات وحقول النماذج. | No results: what was searched, with Ignore accents off (a2-4d). count is the page count, pages the same number in the region's format. |
| `sidebarSearchField` | Search in document | Belgede ara | البحث في المستند | Sidebar › Search results: the field's accessible name (a2-3e). |
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
| `startBadgeSigned` | Signed | İmzalı | موقّع | Neutral badge of a recent file that carries signatures, before signature checking ships (a1-4-m2, FmStart signedNeutral). |
| `startMissingTitle` | “{name}” can’t be found | “{name}” bulunamadı | تعذّر العثور على «{name}» | Title of the dialog for a recent file that was moved, renamed or deleted (a1-9e, missTitle); name is the file name, isolated. |
| `startMissingDescription` | It was moved, renamed or deleted after you last opened it. It was in {folder}. | Dosya son açılışınızdan sonra taşınmış, yeniden adlandırılmış veya silinmiş. Önceki konumu: {folder}. | نُقل الملف أو أُعيدت تسميته أو حُذف بعد آخر مرة فتحته فيها. كان في {folder}. | Line under startMissingTitle (a1-9e, missDesc); folder is where the file was, “\~” for the home folder, isolated. |
| `startMissingRemove` | Remove from list | Listeden kaldır | إزالة من القائمة | Button of a1-9e that takes the missing file off the recent files (a1-9e, remove). |
| `startMissingLocate` | Locate… | Bul… | تحديد الموقع… | Button of a1-9e that opens the system open panel to find the file where it is now (a1-9e, locate). |
| `startMissingClose` | Close | Kapat | إغلاق | Accessible name of a1-9e’s close button, which keeps the file in the list (G118). |
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

<!-- END GENERATED TRANSLATION TABLE -->
