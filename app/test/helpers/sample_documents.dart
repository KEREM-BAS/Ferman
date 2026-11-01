import 'package:ferman/design/components/components.dart';
import 'package:ferman/features/shell/shell_state.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// The sample tabs that show every tab state the design draws (DS additions
/// `tabStates`, a1-10): the active clean contract, an idle clean invoice,
/// an idle statement with unsaved changes, a report still opening, a locked
/// payslip, and three more behind "+3". The names are the design's sample
/// files, not copy. None has a file or an engine document.
final List<ShellDocument> sampleDocuments = [
  ShellDocument(
    name: 'Kira sözleşmesi.pdf',
    saveState: SaveState.saved,
    savedAt: DateTime(2026, 10, 13, 14, 32),
    pageCount: 3,
  ),
  ShellDocument(
    name: 'e-Arşiv fatura 4187.pdf',
    saveState: SaveState.saved,
    savedAt: DateTime(2026, 10, 13, 11, 5),
    pageCount: 1,
  ),
  const ShellDocument(
    name: 'Hesap ekstresi Eylül 2026.pdf',
    saveState: SaveState.unsaved,
    pageCount: 2,
    editCount: 3,
  ),
  const ShellDocument(name: 'İmar planı açıklama raporu.pdf'),
  const ShellDocument(
    name: 'Maaş bordrosu Eylül 2026.pdf',
    icon: IconName.lock,
    saveState: SaveState.readOnly,
  ),
];

/// The shell's documents start as [sampleDocuments].
Override sampleDocumentsOverride() =>
    shellDocumentsProvider.overrideWith(_SampleDocuments.new);

class _SampleDocuments extends ShellDocuments {
  @override
  ShellDocumentList build() =>
      ShellDocumentList(documents: sampleDocuments, overflowCount: 3);
}
