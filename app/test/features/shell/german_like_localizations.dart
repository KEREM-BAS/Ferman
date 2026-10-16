import 'package:ferman/l10n/gen/app_localizations.dart';
import 'package:ferman/l10n/gen/app_localizations_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Long, German-like labels for the shell's bars, to check narrow windows
/// with text as long as German's (G21: the mode tabs are checked at the
/// minimum width in English, Turkish, German and Arabic). The app has no
/// German, so this is test data, never shipped and never a translation:
/// the mode names, the Edit tools, Save and the toggles are FmWindow's
/// `de` strings (`FmWindow.dc.html` line 186); the other tool names are
/// German-style stand-ins of a German length. Everything else is English.
class GermanLikeLocalizations extends AppLocalizationsEn {
  /// The labels.
  new();

  // FmWindow `de`.
  @override
  String get shellModeView => 'Ansicht';
  @override
  String get shellModeEdit => 'Bearbeiten';
  @override
  String get shellModeComment => 'Kommentieren';
  @override
  String get shellModeSign => 'Ausfüllen & Signieren';
  @override
  String get shellModeOrganize => 'Organisieren';
  @override
  String get shellModeConvert => 'Konvertieren';
  @override
  String get shellModeProtect => 'Schützen';
  @override
  String get shellModeTools => 'Werkzeuge';
  @override
  String get shellModeLabel => 'Modus';
  @override
  String get shellSave => 'Speichern';
  @override
  String get shellNoChangesToSave => 'Keine Änderungen zu speichern';
  @override
  String get shellToggleSidebar => 'Seitenleiste ein- oder ausblenden';
  @override
  String get shellTogglePanel => 'Bereich ein- oder ausblenden';
  @override
  String get shellAiAssistant => 'KI-Assistent';
  @override
  String get shellSearch => 'Suchen';
  @override
  String get shellSettings => 'Einstellungen';
  @override
  String get shellToolEditText => 'Text bearbeiten';
  @override
  String get shellToolAddText => 'Text hinzufügen';
  @override
  String get shellToolAddImage => 'Bild hinzufügen';
  @override
  String get shellToolLink => 'Link';
  @override
  String get shellToolFindReplace => 'Suchen & ersetzen';
  @override
  String get shellToolPageMarks => 'Seitenmarkierungen';
  @override
  String get shellUndo => 'Rückgängig';
  @override
  String get shellRedo => 'Wiederholen';
  @override
  String get shellEditHistory => 'Bearbeitungsverlauf';
  @override
  String get shellMarkEditedText => 'Bearbeiteten Text markieren';
  @override
  String get shellReviewEdits => 'Änderungen prüfen';
  @override
  String get shellZoomIn => 'Vergrößern';
  @override
  String get shellZoomOut => 'Verkleinern';

  // German-length stand-ins.
  @override
  String get availableInFutureVersion =>
      'In einer zukünftigen Version verfügbar';
  @override
  String get shellMore => 'Weitere Werkzeuge';
  @override
  String get shellToolSelect => 'Auswählen';
  @override
  String get shellToolHand => 'Hand';
  @override
  String get shellToolMarqueeZoom => 'Auswahlrechteck-Zoom';
  @override
  String get shellZoom => 'Zoom';
  @override
  String get shellFit => 'Einpassen';
  @override
  String get shellFitWidth => 'Breite einpassen';
  @override
  String get shellFitPage => 'Seite einpassen';
  @override
  String get shellActualSize => 'Originalgröße';
  @override
  String get shellPageLayout => 'Seitenlayout';
  @override
  String get shellLayoutSingle => 'Einzelne Seite';
  @override
  String get shellLayoutContinuous => 'Fortlaufend blättern';
  @override
  String get shellLayoutTwoPage => 'Doppelseite';
  @override
  String get shellLayoutBook => 'Buch (Deckblatt einzeln)';
  @override
  String get shellToolSplitView => 'Geteilte Ansicht';
  @override
  String get shellToolReadAloud => 'Vorlesen';
  @override
  String get shellToolPresent => 'Präsentieren';
  @override
  String get shellDarkReadingMode => 'Dunkler Lesemodus';
  @override
  String get shellAnnotationHighlight => 'Hervorheben';
  @override
  String get shellAnnotationUnderline => 'Unterstreichen';
  @override
  String get shellAnnotationStrikethrough => 'Durchstreichen';
  @override
  String get shellAnnotationNote => 'Notiz';
  @override
  String get shellAnnotationText => 'Text';
  @override
  String get shellAnnotationCallout => 'Legende';
  @override
  String get shellAnnotationDraw => 'Zeichnen';
  @override
  String get shellAnnotationShapes => 'Formen';
  @override
  String get shellAnnotationStamp => 'Stempel';
  @override
  String get shellToolMeasure => 'Messen';
  @override
  String get shellShowComments => 'Kommentare anzeigen';
  @override
  String get shellColor => 'Farbe';
  @override
  String get shellToolFillFields => 'Felder ausfüllen';
  @override
  String get shellToolCheckmark => 'Häkchen';
  @override
  String get shellToolDate => 'Datum';
  @override
  String get shellToolSign => 'Signieren';
  @override
  String get shellToolInitials => 'Initialen';
  @override
  String get shellToolDigitalSignature => 'Digitale Signatur';
  @override
  String get shellToolEimza => 'e-imza';
  @override
  String get shellToolPrepareForm => 'Formular vorbereiten';
  @override
  String get shellToolInsert => 'Einfügen';
  @override
  String get shellToolRotateLeft => 'Nach links drehen';
  @override
  String get shellToolRotateRight => 'Nach rechts drehen';
  @override
  String get shellToolDuplicate => 'Duplizieren';
  @override
  String get shellToolExtract => 'Extrahieren';
  @override
  String get shellToolReplace => 'Ersetzen';
  @override
  String get shellToolDelete => 'Löschen';
  @override
  String get shellToolSplit => 'Teilen';
  @override
  String get shellToolCombineFiles => 'Dateien zusammenführen';
  @override
  String get shellToolCrop => 'Zuschneiden';
  @override
  String get shellToolPageLabels => 'Seitenbeschriftungen';
  @override
  String get shellOrganizeHint =>
      'Seiten zum Neuordnen ziehen. Rechtsklick für mehr.';
  @override
  String get shellConvertImage => 'Bild';
  @override
  String get shellToolCreatePdf => 'PDF erstellen';
  @override
  String get shellToolScan => 'Scannen';
  @override
  String get shellToolRecognizeText => 'Text erkennen (OCR)';
  @override
  String get shellToolRedact => 'Schwärzen';
  @override
  String get shellToolFindRedact => 'Suchen & schwärzen';
  @override
  String get shellToolPassword => 'Kennwort';
  @override
  String get shellToolRemoveHidden => 'Ausgeblendete Informationen entfernen';
  @override
  String get shellToolSecurityReport => 'Sicherheitsbericht';
  @override
  String get shellApplyRedactions => 'Schwärzungen anwenden';
  @override
  String get shellToolCompress => 'Komprimieren';
  @override
  String get shellToolCompare => 'Vergleichen';
  @override
  String get shellToolAccessibility => 'Barrierefreiheit';
  @override
  String get shellToolPdfA => 'PDF/A & Preflight';
  @override
  String get shellToolBatch => 'Stapelverarbeitung';
  @override
  String get shellToolPrint => 'Drucken';
  @override
  String get shellToolVersionHistory => 'Versionsverlauf';
}

/// Gives [GermanLikeLocalizations] to the widgets below it in place of the
/// English messages.
class GermanLikeDelegate extends LocalizationsDelegate<AppLocalizations> {
  /// The delegate.
  const new();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(GermanLikeLocalizations());

  @override
  bool shouldReload(GermanLikeDelegate old) => false;
}
