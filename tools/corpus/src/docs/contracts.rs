//! The two contracts in other languages:
//!
//! - **mietvertrag-de:** a 6-page German residential lease ("Mietvertrag Berlin.pdf") with
//!   umlauts and ß, all inside Windows-1252: simple TrueType fonts only, justified with `TJ` as
//!   office suites other than Word do. Search finds "Müller" for "muller" (G61).
//! - **nda-en:** a 4-page English mutual NDA ("Mutual NDA — Northwind.pdf") with a signature
//!   on page 4: a `/Sig` field whose value has a correct `/ByteRange` around a `/Contents`
//!   placeholder of zeros. Its structure is a signature's; there is no cryptographic signature
//!   to check (that is P3).

use super::{Doc, generated, info, open_first, opens};
use crate::pdf::{self, Content, rect, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Flow, Frame, PageText, Paragraph, Style};
use crate::{Generated, Generator};
use lopdf::{Object, dictionary};

/// The German lease.
pub const MIETVERTRAG_DE: Generator = Generator {
    name: "mietvertrag-de",
    build: mietvertrag,
    expect: opens(),
};

/// The English NDA.
pub const NDA_EN: Generator = Generator {
    name: "nda-en",
    build: nda,
    expect: opens(),
};

const MIETVERTRAG: [(&str, &[&str]); 16] = [
    (
        "§ 1 Vertragsparteien",
        &[
            "Zwischen Herrn Klaus Müller, Schönhauser Allee 112, 10437 Berlin (im Folgenden „Vermieter“), und Frau Jana Weißmann, Kastanienallee 7, 10435 Berlin (im Folgenden „Mieterin“), wird folgender Mietvertrag über Wohnraum geschlossen.",
        ],
    ),
    (
        "§ 2 Mieträume",
        &[
            "Vermietet wird die Wohnung im dritten Obergeschoss rechts des Hauses Gleimstraße 24, 10437 Berlin, bestehend aus drei Zimmern, einer Küche, einem Bad mit Fenster, einem Flur und einem Balkon. Die Wohnfläche beträgt 78,4 Quadratmeter. Zur Wohnung gehört ein Kellerabteil mit der Nummer 9.",
            "Die Mieterin ist berechtigt, den Fahrradraum im Hof und die Gemeinschaftswaschküche nach Maßgabe der Hausordnung mitzubenutzen. Eine Änderung der Größe oder des Zuschnitts der Räume bedarf der schriftlichen Zustimmung des Vermieters.",
        ],
    ),
    (
        "§ 3 Mietzeit",
        &[
            "Das Mietverhältnis beginnt am 1. Dezember 2026 und läuft auf unbestimmte Zeit. Es kann von beiden Parteien nach den gesetzlichen Vorschriften gekündigt werden.",
            "Die Kündigung muss schriftlich erfolgen. Für die Rechtzeitigkeit der Kündigung kommt es nicht auf die Absendung, sondern auf den Zugang des Kündigungsschreibens an.",
        ],
    ),
    (
        "§ 4 Miete und Nebenkosten",
        &[
            "Die monatliche Nettokaltmiete beträgt 1.096,00 €. Daneben zahlt die Mieterin monatliche Vorauszahlungen auf die Betriebskosten in Höhe von 210,00 € und auf die Heiz- und Warmwasserkosten in Höhe von 95,00 €. Die Gesamtmiete beträgt somit 1.401,00 €.",
            "Über die Vorauszahlungen wird jährlich abgerechnet. Die Abrechnung ist der Mieterin spätestens zwölf Monate nach Ende des Abrechnungszeitraums mitzuteilen. Nachforderungen und Guthaben sind innerhalb von dreißig Tagen nach Zugang der Abrechnung auszugleichen.",
        ],
    ),
    (
        "§ 5 Zahlung der Miete",
        &[
            "Die Miete ist monatlich im Voraus, spätestens am dritten Werktag eines jeden Monats, kostenfrei auf das Konto des Vermieters bei der Berliner Volksbank, IBAN DE89 3704 0044 0532 0130 00, zu zahlen. Für die Rechtzeitigkeit der Zahlung kommt es auf die Gutschrift auf dem Konto des Vermieters an.",
        ],
    ),
    (
        "§ 6 Mietsicherheit",
        &[
            "Die Mieterin leistet eine Sicherheit in Höhe von drei Nettokaltmieten, also 3.288,00 €. Sie ist berechtigt, die Sicherheit in drei gleichen monatlichen Teilzahlungen zu erbringen; die erste Teilzahlung ist zu Beginn des Mietverhältnisses fällig. Der Vermieter legt die Sicherheit getrennt von seinem Vermögen bei einem Kreditinstitut zu dem für Spareinlagen mit dreimonatiger Kündigungsfrist üblichen Zinssatz an.",
        ],
    ),
    (
        "§ 7 Zustand der Mieträume",
        &[
            "Die Wohnung wird in renoviertem Zustand übergeben. Bei Übergabe wird ein Protokoll erstellt, das von beiden Parteien unterschrieben wird und Bestandteil dieses Vertrags ist.",
            "Die Mieterin hat die Mieträume pfleglich zu behandeln und für ausreichende Lüftung und Heizung zu sorgen. Schäden in den Mieträumen sind dem Vermieter unverzüglich anzuzeigen.",
        ],
    ),
    (
        "§ 8 Schönheitsreparaturen",
        &[
            "Schönheitsreparaturen trägt die Mieterin, soweit sie durch ihren Gebrauch erforderlich werden. Dazu gehören das Tapezieren und Anstreichen der Wände und Decken, das Streichen der Heizkörper und der Innentüren sowie der Fenster und Außentüren von innen. Die Arbeiten sind fachgerecht und in neutralen, hellen Farbtönen auszuführen.",
        ],
    ),
    (
        "§ 9 Kleinreparaturen",
        &[
            "Die Kosten für kleine Instandhaltungen an Teilen der Wohnung, die dem häufigen Zugriff der Mieterin ausgesetzt sind, wie Wasserhähne, Lichtschalter, Steckdosen, Fenster- und Türverschlüsse, trägt die Mieterin bis zu einem Betrag von 100,00 € im Einzelfall, höchstens jedoch bis zu acht Prozent der jährlichen Nettokaltmiete.",
        ],
    ),
    (
        "§ 10 Bauliche Veränderungen",
        &[
            "Bauliche Veränderungen durch die Mieterin, insbesondere Um- und Einbauten sowie Installationen, bedürfen der vorherigen schriftlichen Erlaubnis des Vermieters. Die Erlaubnis darf nur aus wichtigem Grund versagt werden. Bei Beendigung des Mietverhältnisses ist der ursprüngliche Zustand wiederherzustellen, soweit nichts anderes vereinbart ist.",
        ],
    ),
    (
        "§ 11 Untervermietung und Tierhaltung",
        &[
            "Die Untervermietung der Wohnung oder einzelner Räume ist nur mit Erlaubnis des Vermieters zulässig. Die Aufnahme des Ehegatten, des eingetragenen Lebenspartners und von Kindern bedarf keiner Erlaubnis.",
            "Die Haltung von Kleintieren wie Ziervögeln, Zierfischen und Hamstern ist ohne Erlaubnis zulässig. Für die Haltung von Hunden und Katzen ist die Zustimmung des Vermieters erforderlich, die nur aus sachlichem Grund verweigert werden darf.",
        ],
    ),
    (
        "§ 12 Betreten der Mieträume",
        &[
            "Der Vermieter oder ein von ihm Beauftragter darf die Mieträume nach rechtzeitiger Ankündigung zu angemessener Tageszeit betreten, um die Notwendigkeit von Instandsetzungsarbeiten festzustellen oder die Räume Kauf- oder Mietinteressenten zu zeigen. Bei Gefahr im Verzug ist der Zutritt jederzeit gestattet.",
        ],
    ),
    (
        "§ 13 Hausordnung",
        &[
            "Die beigefügte Hausordnung ist Bestandteil dieses Vertrags. Die Mieterin verpflichtet sich, sie einzuhalten und auf die Belange der übrigen Hausbewohner Rücksicht zu nehmen. Insbesondere sind die Ruhezeiten von 22 Uhr bis 6 Uhr und von 13 Uhr bis 15 Uhr einzuhalten.",
        ],
    ),
    (
        "§ 14 Rückgabe der Mieträume",
        &[
            "Bei Beendigung des Mietverhältnisses hat die Mieterin die Mieträume vollständig geräumt und gereinigt zurückzugeben. Sämtliche Schlüssel, auch selbst beschaffte, sind dem Vermieter auszuhändigen. Über die Rückgabe wird ein gemeinsames Protokoll erstellt.",
        ],
    ),
    (
        "§ 15 Datenschutz",
        &[
            "Der Vermieter verarbeitet die personenbezogenen Daten der Mieterin ausschließlich zur Durchführung dieses Mietverhältnisses. Eine Weitergabe an Dritte erfolgt nur, soweit sie für die Erfüllung des Vertrags erforderlich ist, etwa an den Abrechnungsdienstleister für die Heizkosten.",
        ],
    ),
    (
        "§ 16 Schlussbestimmungen",
        &[
            "Änderungen und Ergänzungen dieses Vertrags bedürfen der Schriftform. Sollte eine Bestimmung dieses Vertrags unwirksam sein oder werden, so wird die Wirksamkeit der übrigen Bestimmungen hiervon nicht berührt. Gerichtsstand ist Berlin.",
        ],
    ),
];

const NDA: [(&str, &str); 15] = [
    (
        "1. Purpose",
        "The parties wish to explore a possible collaboration on the design of a data platform for retail analytics (the “Purpose”). In the course of their discussions each party may disclose to the other information that it regards as confidential.",
    ),
    (
        "2. Confidential Information",
        "“Confidential Information” means any information disclosed by one party (the “Discloser”) to the other (the “Recipient”), whether in writing, orally or by any other means, that is marked as confidential or that a reasonable person would understand to be confidential, including business plans, customer lists, prices, designs, source code and data.",
    ),
    (
        "3. Exclusions",
        "Confidential Information does not include information that (a) is or becomes public through no fault of the Recipient; (b) was lawfully known to the Recipient before disclosure; (c) is lawfully received from a third party without a duty of confidence; or (d) is independently developed by the Recipient without use of the Discloser’s information.",
    ),
    (
        "4. Obligations",
        "The Recipient shall use the Confidential Information only for the Purpose, shall not disclose it to any person other than its employees and advisers who need to know it for the Purpose and are bound by obligations of confidence at least as strict as these, and shall protect it with at least the care it uses for its own confidential information, and never less than reasonable care.",
    ),
    (
        "5. Required Disclosure",
        "If the Recipient is required by law, regulation or court order to disclose Confidential Information, it may do so, provided that it gives the Discloser prompt written notice where lawful and discloses only the part that is legally required.",
    ),
    (
        "6. Return and Destruction",
        "On written request, and in any event when the discussions end, the Recipient shall return or destroy all Confidential Information and confirm in writing that it has done so, except for copies it must keep by law or that are held in routine backups, which remain subject to this Agreement.",
    ),
    (
        "7. No Licence",
        "Nothing in this Agreement grants the Recipient any licence or right in the Discloser’s intellectual property, other than the limited right to use Confidential Information for the Purpose. All Confidential Information is provided “as is”.",
    ),
    (
        "8. No Obligation",
        "This Agreement does not oblige either party to disclose any particular information or to enter into any further agreement. Either party may end the discussions at any time by written notice.",
    ),
    (
        "9. Term",
        "This Agreement takes effect on the date of the last signature and continues for two years. The obligations in sections 4 to 7 survive for five years after it ends, and for trade secrets for as long as they remain trade secrets.",
    ),
    (
        "10. Remedies",
        "Each party acknowledges that damages alone may not be an adequate remedy for a breach of this Agreement and that the Discloser may seek injunctive relief in addition to any other remedy available to it.",
    ),
    (
        "11. Entire Agreement",
        "This Agreement is the entire agreement between the parties about its subject and supersedes all earlier discussions. It may be changed only in writing signed by both parties.",
    ),
    (
        "12. Non-Solicitation",
        "During the term of this Agreement and for twelve months after it ends, neither party shall solicit for employment any employee of the other party with whom it had contact in connection with the Purpose, except through general advertisements not aimed at those employees.",
    ),
    (
        "13. Notices",
        "Notices under this Agreement shall be in writing and sent by email with a copy by recorded delivery to the addresses given above, or to any other address a party notifies to the other. A notice takes effect on the business day after it is sent.",
    ),
    (
        "14. Counterparts",
        "This Agreement may be signed in counterparts, including by electronic signature, each of which is an original and which together form one agreement.",
    ),
    (
        "15. Governing Law",
        "This Agreement is governed by the laws of England and Wales, and the courts of England have exclusive jurisdiction over any dispute arising from it.",
    ),
];

struct Layout {
    left: f64,
    width: f64,
    top: f64,
    bottom: f64,
}

fn flow_for(layout: &Layout) -> Flow {
    Flow::new(Frame {
        x: layout.left,
        top: layout.top,
        bottom: layout.bottom,
        width: layout.width,
    })
}

/// "Seite n von m" or "Page n of m" at the foot of every page.
fn footers(
    doc: &mut Doc,
    pages: &mut [PageText],
    style: &Style,
    layout: &Layout,
    word: (&str, &str),
) -> Result<(), String> {
    let total = pages.len();
    for (index, page) in pages.iter_mut().enumerate() {
        let label = format!("{} {} {} {total}", word.0, index + 1, word.1);
        doc.line(
            page,
            style,
            &label,
            (layout.left, 40.0),
            layout.width,
            Align::Center,
        )?;
    }
    Ok(())
}

fn mietvertrag(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.6");
    let mut body = doc.word_style(sources, FontFile::PlexSerif, 12.0)?;
    body.word_spacing = false;
    body.fallback = None;
    let mut heading = doc.word_style(sources, FontFile::PlexSerifSemiBold, 11.5)?;
    heading.fallback = None;
    let layout = Layout {
        left: 79.0,
        width: pdf::A4.0 - 158.0,
        top: pdf::A4.1 - 79.0,
        bottom: 85.0,
    };
    let mut flow = flow_for(&layout);
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(&heading.sized(18.0), "Mietvertrag über Wohnraum")
            .aligned(Align::Center)
            .spaced(0.0, 6.0),
    )?;
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(
            &body.sized(10.0),
            "Gleimstraße 24, 3. OG rechts, 10437 Berlin",
        )
        .aligned(Align::Center)
        .spaced(0.0, 22.0),
    )?;
    for (title, paragraphs) in MIETVERTRAG {
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&heading, title)
                .aligned(Align::Left)
                .spaced(12.0, 4.0)
                .kept(),
        )?;
        for paragraph in paragraphs {
            let mut paragraph = Paragraph::new(&body, paragraph)
                .spaced(0.0, 8.0)
                .leading(1.6);
            paragraph.word_spacing = false;
            flow.paragraph(&mut doc.fonts, &paragraph)?;
        }
    }
    flow.break_page();
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(&heading, "Unterschriften")
            .aligned(Align::Left)
            .spaced(0.0, 8.0),
    )?;
    flow.paragraph(&mut doc.fonts, &Paragraph::new(&body, "Beide Parteien bestätigen, eine Ausfertigung dieses Vertrags einschließlich der Hausordnung und des Übergabeprotokolls erhalten zu haben.").spaced(0.0, 40.0))?;
    let mut pages = flow.into_pages();
    if let Some(page) = pages.last_mut() {
        let y = 560.0;
        for (index, role) in ["Vermieter: Klaus Müller", "Mieterin: Jana Weißmann"]
            .iter()
            .enumerate()
        {
            #[allow(clippy::cast_precision_loss)]
            let x = layout.left + (layout.width / 2.0 + 10.0) * index as f64;
            let width = layout.width / 2.0 - 10.0;
            page.content.line_width(0.5).line((x, y), (x + width, y));
            doc.line(
                page,
                &body.sized(9.5),
                "Berlin, den ____________",
                (x, y + 30.0),
                width,
                Align::Left,
            )?;
            doc.line(
                page,
                &body.sized(9.5),
                role,
                (x, y - 14.0),
                width,
                Align::Left,
            )?;
        }
    }
    pages.push(handover(&mut doc, &body, &heading, &layout)?);
    if pages.len() != 6 {
        return Err(format!("the lease has {} pages, not 6", pages.len()));
    }
    footers(
        &mut doc,
        &mut pages,
        &body.sized(9.0),
        &layout,
        ("Seite", "von"),
    )?;
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let catalog = dictionary! { "Lang" => text("de-DE"), "OpenAction" => open_first(ids[0]) };
    let bytes = doc.close(
        catalog,
        &info(
            "Mietvertrag Berlin",
            "Klaus Müller",
            "Textverarbeitung",
            "D:20261102101500+01'00'",
        ),
        "mietvertrag-de",
        None,
    )?;
    Ok(generated(bytes, expected))
}

/// Annex 1, the handover record: rooms, meter readings and keys.
fn handover(
    doc: &mut Doc,
    body: &Style,
    heading: &Style,
    layout: &Layout,
) -> Result<PageText, String> {
    let mut page = PageText::default();
    let mut y = layout.top - 14.0;
    doc.line(
        &mut page,
        &heading.sized(14.0),
        "Anlage 1: Übergabeprotokoll",
        (layout.left, y),
        layout.width,
        Align::Left,
    )?;
    y -= 30.0;
    let small = body.sized(10.0);
    let bold = heading.sized(10.0);
    let columns = [(0.0, "Raum"), (130.0, "Zustand"), (250.0, "Bemerkungen")];
    for (offset, title) in columns {
        doc.line(
            &mut page,
            &bold,
            title,
            (layout.left + offset, y),
            200.0,
            Align::Left,
        )?;
    }
    page.content.line_width(0.75).line(
        (layout.left, y - 6.0),
        (layout.left + layout.width, y - 6.0),
    );
    y -= 22.0;
    let rows = [
        ("Flur", "renoviert", "Garderobenhaken an der Wand"),
        ("Küche", "renoviert", "Einbauküche mit Herd und Kühlschrank"),
        ("Bad", "gut", "Fugen an der Dusche neu verfugt"),
        ("Wohnzimmer", "renoviert", "Dielenboden geschliffen"),
        ("Schlafzimmer", "renoviert", "keine"),
        (
            "Arbeitszimmer",
            "renoviert",
            "zwei Dübellöcher verschlossen",
        ),
        ("Balkon", "gut", "Geländer gestrichen"),
        ("Kellerabteil Nr. 9", "gut", "leer übergeben"),
    ];
    for (room, state, note) in rows {
        for (offset, cell) in [(0.0, room), (130.0, state), (250.0, note)] {
            doc.line(
                &mut page,
                &small,
                cell,
                (layout.left + offset, y),
                200.0,
                Align::Left,
            )?;
        }
        page.content.line_width(0.25).line(
            (layout.left, y - 6.0),
            (layout.left + layout.width, y - 6.0),
        );
        y -= 20.0;
    }
    y -= 18.0;
    for line in [
        "Zählerstände am 1. Dezember 2026:",
        "Stromzähler Nr. 1ESY 1160 4471: 18.432,7 kWh",
        "Wasserzähler Küche: 112,45 m³ · Wasserzähler Bad: 87,10 m³",
        "Wärmemengenzähler: 6.204 kWh",
        "Übergebene Schlüssel: 2 Haustür, 2 Wohnungstür, 1 Briefkasten, 1 Kellertür.",
    ] {
        doc.line(
            &mut page,
            &small,
            line,
            (layout.left, y),
            layout.width,
            Align::Left,
        )?;
        y -= 16.0;
    }
    Ok(page)
}

/// The size of the `/Contents` placeholder in bytes.
const SIGNATURE_BYTES: usize = 8192;

fn nda(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.7");
    let mut body = doc.word_style(sources, FontFile::PlexSans, 11.0)?;
    body.fallback = None;
    let mut heading = doc.word_style(sources, FontFile::PlexSansSemiBold, 11.0)?;
    heading.fallback = None;
    let layout = Layout {
        left: 72.0,
        width: pdf::A4.0 - 144.0,
        top: pdf::A4.1 - 72.0,
        bottom: 80.0,
    };
    let mut flow = flow_for(&layout);
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(&heading.sized(17.0), "Mutual Non-Disclosure Agreement")
            .aligned(Align::Left)
            .spaced(0.0, 10.0),
    )?;
    flow.paragraph(&mut doc.fonts, &Paragraph::new(&body, "This Agreement is made between Northwind Analytics Ltd., 14 Wharf Road, London N1 7GR, United Kingdom (“Northwind”), and Kestrel Design Studio LLC, 220 Harbor Street, Portland, ME 04101, United States (“Kestrel”), each a “party”.").spaced(0.0, 14.0).leading(1.6))?;
    for (title, text_body) in NDA {
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&heading, title)
                .aligned(Align::Left)
                .spaced(10.0, 4.0)
                .kept(),
        )?;
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&body, text_body)
                .spaced(0.0, 4.0)
                .leading(1.6),
        )?;
    }
    flow.break_page();
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(&heading, "Signatures")
            .aligned(Align::Left)
            .spaced(0.0, 8.0),
    )?;
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(
            &body,
            "Signed by the authorised representatives of the parties.",
        )
        .spaced(0.0, 0.0),
    )?;
    let mut pages = flow.into_pages();
    let signature_rect = [layout.left, 560.0, layout.left + 220.0, 620.0];
    if let Some(page) = pages.last_mut() {
        for (index, (party, name)) in [
            ("Northwind Analytics Ltd.", "Jordan Lee, Managing Director"),
            ("Kestrel Design Studio LLC", "Priya Raman, Partner"),
        ]
        .iter()
        .enumerate()
        {
            let y = 690.0 - 200.0 * f64::from(u8::try_from(index).unwrap_or(0));
            doc.line(
                page,
                &heading,
                party,
                (layout.left, y),
                layout.width,
                Align::Left,
            )?;
            page.content
                .line_width(0.5)
                .line((layout.left, y - 80.0), (layout.left + 220.0, y - 80.0));
            doc.line(
                page,
                &body.sized(9.0),
                name,
                (layout.left, y - 94.0),
                layout.width,
                Align::Left,
            )?;
            doc.line(
                page,
                &body.sized(9.0),
                if index == 0 {
                    "Date: 8 October 2026"
                } else {
                    "Date:"
                },
                (layout.left, y - 108.0),
                layout.width,
                Align::Left,
            )?;
        }
    }
    if pages.len() != 4 {
        return Err(format!("the NDA has {} pages, not 4", pages.len()));
    }
    footers(
        &mut doc,
        &mut pages,
        &body.sized(8.5),
        &layout,
        ("Page", "of"),
    )?;
    let (ids, expected) = doc.add_pages(pages, pdf::A4);

    // The signature value: a /ByteRange and /Contents filled in after writing.
    let signature = doc.pdf.add(dictionary! {
        "Type" => "Sig",
        "Filter" => "Adobe.PPKLite",
        "SubFilter" => "adbe.pkcs7.detached",
        "Name" => text("Jordan Lee"),
        "Reason" => text("I agree to the terms of this Agreement."),
        "Location" => text("London"),
        "M" => text("D:20261008143000+01'00'"),
        "ByteRange" => vec![Object::Integer(0), Object::Integer(1_111_111_111), Object::Integer(2_222_222_222), Object::Integer(3_333_333_333)],
        "Contents" => pdf::hex(&[0u8; SIGNATURE_BYTES]),
    });
    let [x1, y1, x2, y2] = signature_rect;
    let mut look = Content::new();
    look.op("q 0.165 0.302 0.686 RG 0.75 w 0.5 0.5 219 59 re S Q");
    let appearance = doc.pdf.stream(
        dictionary! { "Type" => "XObject", "Subtype" => "Form", "BBox" => rect(0.0, 0.0, x2 - x1, y2 - y1) },
        look.into_bytes(),
    );
    let field = doc.pdf.add(dictionary! {
        "Type" => "Annot",
        "Subtype" => "Widget",
        "FT" => "Sig",
        "T" => text("Northwind signature"),
        "V" => signature,
        "Rect" => rect(x1, y1, x2, y2),
        "F" => 132,
        "P" => ids[3],
        "AP" => dictionary! { "N" => appearance },
    });
    super::kira::set_page_entry(
        &mut doc.pdf,
        ids[3],
        "Annots",
        Object::Array(vec![field.into()]),
    );
    let catalog = dictionary! {
        "Lang" => text("en-GB"),
        "OpenAction" => open_first(ids[0]),
        "AcroForm" => dictionary! { "Fields" => vec![Object::Reference(field)], "SigFlags" => 3 },
    };
    let bytes = doc.close(
        catalog,
        &info(
            "Mutual NDA — Northwind",
            "Northwind Analytics Ltd.",
            "Word processor",
            "D:20261007160000+01'00'",
        ),
        "nda-en",
        None,
    )?;
    Ok(generated(byte_range(bytes)?, expected))
}

/// Fills in the signature's `/ByteRange`: everything but its `/Contents` hex string.
fn byte_range(mut file: Vec<u8>) -> Result<Vec<u8>, String> {
    let placeholder = b"[0 1111111111 2222222222 3333333333]";
    let range_at = file
        .windows(placeholder.len())
        .position(|window| window == placeholder)
        .ok_or("no /ByteRange placeholder")?;
    let zeros = vec![b'0'; SIGNATURE_BYTES * 2];
    let mut contents = Vec::with_capacity(zeros.len() + 2);
    contents.push(b'<');
    contents.extend_from_slice(&zeros);
    contents.push(b'>');
    let start = file
        .windows(contents.len())
        .position(|window| window == contents.as_slice())
        .ok_or("no /Contents placeholder")?;
    let end = start + contents.len();
    let rest = file.len() - end;
    let filled = format!("[0 {start:<10} {end:<10} {rest:<10}]");
    if filled.len() != placeholder.len() {
        return Err("the /ByteRange does not fit its placeholder".to_owned());
    }
    file[range_at..range_at + placeholder.len()].copy_from_slice(filled.as_bytes());
    Ok(file)
}
