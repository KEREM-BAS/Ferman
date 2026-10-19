//! `tez-tr`: a 64-page tagged Turkish master's thesis, as LaTeX-like tools write one:
//!
//! - composite IBM Plex Serif with ligatures, justified with `TJ`;
//! - object streams and a cross-reference stream (PDF 1.5);
//! - page labels: eight front-matter pages i to viii, then 1 to 56;
//! - a nested outline: chapters, sections and subsections;
//! - a structure tree (`Document`, `H1` to `H3`, `P`, `BlockQuote`) with marked content, the
//!   page numbers as artifacts, `/Lang (tr-TR)` and `/Lang (en-US)` on the English abstract and
//!   the English block quote (ROADMAP E08).
//!
//! The text is invented; the paragraphs are drawn from a fixed set of sentences in a fixed
//! pseudo-random order.

use super::{Doc, generated, info, opens};
use crate::pdf::{self, name, real, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Flow, Frame, PageText, Paragraph, Style};
use crate::{Generated, Generator};
use lopdf::{Object, ObjectId, dictionary};

/// The thesis.
pub const TEZ_TR: Generator = Generator {
    name: "tez-tr",
    build,
    expect: opens(),
};

const FRONT_PAGES: usize = 8;
const BODY_PAGES: usize = 56;
const LEFT: f64 = 85.0;
const RIGHT: f64 = 71.0;
const TOP: f64 = pdf::A4.1 - 71.0;
const BOTTOM: f64 = 78.0;
const WIDTH: f64 = pdf::A4.0 - LEFT - RIGHT;

/// A small deterministic generator (xorshift64*).
pub struct Random(u64);

impl Random {
    /// A generator from `seed`, never zero.
    #[must_use]
    pub fn new(seed: u64) -> Self {
        Self(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1)
    }

    /// The next number below `bound`.
    pub fn below(&mut self, bound: usize) -> usize {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        let value = self.0.wrapping_mul(0x2545_F491_4F6C_DD1D) >> 33;
        usize::try_from(value).unwrap_or(0) % bound.max(1)
    }
}

const SENTENCES: [&str; 24] = [
    "Kentsel dönüşüm, yalnızca yapı stokunun yenilenmesi değil, kentte yaşayanların gündelik hayatını da yeniden biçimlendiren bir süreçtir.",
    "Kiracılar, dönüşüm kararlarının alındığı müzakere masasında çoğu zaman temsil edilmemektedir.",
    "Bu çalışmada İstanbul’un üç ilçesinde yürütülen dönüşüm projeleri kiracıların bakış açısından incelenmiştir.",
    "Görüşmeye katılanların önemli bir kısmı, tahliye bildirimini resmî bir yazıdan önce komşularından öğrendiğini belirtmiştir.",
    "Kira artışlarının dönüşüm ilanıyla birlikte hızlandığı, özellikle Kadıköy ve Üsküdar örneklerinde açıkça görülmektedir.",
    "Yasal düzenlemeler malikin haklarını ayrıntılı biçimde tanımlarken kiracının konumunu büyük ölçüde sözleşme hükümlerine bırakmaktadır.",
    "Kira yardımı uygulaması kısa vadeli bir rahatlama sağlasa da kiracının aynı mahallede kalmasını güvence altına almamaktadır.",
    "Mahalle ağlarının dağılması, yaşlı kiracılar için konut kaybından daha ağır bir kayıp olarak tanımlanmıştır.",
    "Araştırmanın verileri yarı yapılandırılmış görüşmeler, belge incelemesi ve çevrim içi bir anket aracılığıyla toplanmıştır.",
    "Elde edilen bulgular, şeffaf bir bilgilendirme sürecinin uyuşmazlıkları belirgin biçimde azalttığını göstermektedir.",
    "Belediyelerin kurduğu danışma masaları, başvuru yapan kiracıların haklarını öğrenmesinde etkili olmuştur.",
    "Öte yandan bu masaların çalışma saatleri, düzenli bir işte çalışan kiracılar için erişimi güçleştirmektedir.",
    "Dönüşüm sonrasında aynı yapıya dönebilen kiracı oranı, incelenen projelerde yüzde on beşin altında kalmıştır.",
    "Sözleşme sürelerinin belirsizliği, kiracıların taşınma planı yapmasını ve çocuklarının okul düzenini korumasını zorlaştırmaktadır.",
    "Katılımcıların çoğu, süreç boyunca tek bir muhatapla görüşebilmenin güven duygusunu artırdığını ifade etmiştir.",
    "Bu bulgular, kiracıların sürece erken aşamada dâhil edilmesinin hem sosyal hem de ekonomik maliyetleri düşürdüğüne işaret etmektedir.",
    "Uluslararası örnekler, geçici barınma çözümlerinin mahalle içinde sunulmasının yerinden edilmeyi önemli ölçüde sınırladığını ortaya koymaktadır.",
    "Yerel yönetimlerin elindeki kamu arazileri, dönüşüm süresince kiracılar için ara konut üretiminde kullanılabilir.",
    "Hukuki çerçevenin kiracıya bildirim, itiraz ve tazminat hakları tanıyacak biçimde güncellenmesi önerilmektedir.",
    "Fiyat artışlarının izlenmesi için ilçe düzeyinde düzenli bir kira endeksi yayımlanması yararlı olacaktır.",
    "Görüşmelerde sıkça dile getirilen bir başka sorun, taşınma masraflarının tümüyle kiracıya bırakılmasıdır.",
    "Çalışmanın sınırlılıkları arasında örneklemin büyüklüğü ve verilerin tek bir yıla ait olması sayılabilir.",
    "Gelecekteki araştırmalar, dönüşümün kiracılar üzerindeki etkilerini daha uzun bir zaman diliminde izlemelidir.",
    "Sonuç olarak kiracı hakları, kentsel dönüşüm politikalarının tali değil, kurucu bir bileşeni olarak ele alınmalıdır.",
];

const QUOTE: &str = "Housing is not merely a roof over one’s head; it is the place from which people take part in the life of their city. When renewal displaces tenants without a fair process, the city loses more than buildings. (Hartley, 2019, p. 42)";

const ABSTRACT_EN: &str = "This thesis examines the rights of tenants in urban renewal projects in three districts of Istanbul. Drawing on semi-structured interviews, document analysis and an online survey, it finds that tenants are rarely represented when renewal decisions are made, that rents rise quickly once a project is announced, and that few tenants return to their buildings afterwards. It argues that early notice, a single point of contact and temporary housing within the neighbourhood reduce both conflict and displacement, and it proposes changes to the legal framework that would give tenants rights of notice, objection and compensation.";

const ABSTRACT_TR: &str = "Bu tez, İstanbul’un üç ilçesinde yürütülen kentsel dönüşüm projelerinde kiracı haklarını incelemektedir. Yarı yapılandırılmış görüşmeler, belge incelemesi ve çevrim içi bir anketle toplanan veriler, kiracıların dönüşüm kararlarında nadiren temsil edildiğini, proje ilanıyla birlikte kiraların hızla arttığını ve dönüşüm sonrasında yapılarına dönebilen kiracıların az olduğunu göstermektedir. Tez, erken bildirim, tek muhatap ilkesi ve mahalle içinde geçici barınmanın hem uyuşmazlıkları hem de yerinden edilmeyi azalttığını savunmakta; kiracıya bildirim, itiraz ve tazminat hakları tanıyan yasal düzenlemeler önermektedir.";

/// A section: its title, its subsections and the paragraphs of each part.
type Section = (&'static str, &'static [&'static str], usize);

/// The chapters: title, then sections.
const CHAPTERS: [(&str, &[Section]); 6] = [
    (
        "1. GİRİŞ",
        &[
            ("1.1. Araştırmanın Amacı", &[], 5),
            ("1.2. Araştırmanın Önemi", &[], 5),
            ("1.3. Yöntem ve Sınırlılıklar", &[], 5),
        ],
    ),
    (
        "2. KAVRAMSAL ÇERÇEVE",
        &[
            (
                "2.1. Kentsel Dönüşüm Kavramı",
                &["2.1.1. Tarihsel Gelişim", "2.1.2. Yasal Dayanaklar"],
                6,
            ),
            ("2.2. Kiracılık ve Barınma Hakkı", &[], 8),
        ],
    ),
    (
        "3. YÖNTEM",
        &[
            ("3.1. Araştırma Deseni", &[], 6),
            (
                "3.2. Veri Toplama ve Çözümleme",
                &["3.2.1. Görüşmeler", "3.2.2. Anket"],
                5,
            ),
        ],
    ),
    (
        "4. BULGULAR",
        &[
            ("4.1. Bildirim ve Bilgilendirme", &[], 8),
            ("4.2. Kira Artışları", &[], 8),
            (
                "4.3. Geri Dönüş ve Yerinden Edilme",
                &["4.3.1. Kadıköy", "4.3.2. Üsküdar", "4.3.3. Kâğıthane"],
                5,
            ),
        ],
    ),
    (
        "5. TARTIŞMA",
        &[
            ("5.1. Bulguların Değerlendirilmesi", &[], 9),
            ("5.2. Politika Önerileri", &[], 8),
        ],
    ),
    (
        "6. SONUÇ VE ÖNERİLER",
        &[("6.1. Sonuç", &[], 5), ("6.2. Öneriler", &[], 5)],
    ),
];

const SURNAMES: [&str; 12] = [
    "Akın",
    "Balcı",
    "Çelik",
    "Demirtaş",
    "Erdem",
    "Güneş",
    "Hartley",
    "Işık",
    "Karaca",
    "Lefebvre",
    "Şahin",
    "Yıldız",
];
const TOPICS: [&str; 8] = [
    "Kentsel dönüşüm ve kiracılık",
    "Mahalle ağları ve yerinden edilme",
    "Konut politikaları üzerine bir değerlendirme",
    "İstanbul’da kira artışları",
    "Barınma hakkı ve yerel yönetimler",
    "Geçici konut uygulamaları",
    "Dönüşüm projelerinde katılım",
    "Kent hakkı tartışmaları",
];

/// A tagged block for the structure tree.
struct Element {
    tag: &'static str,
    lang: Option<&'static str>,
    marks: Vec<(usize, i64)>,
}

/// An outline entry: title, page index, depth.
struct Entry {
    title: String,
    page: usize,
    depth: usize,
}

struct Styles {
    body: Style,
    italic: Style,
    h1: Style,
    h2: Style,
    h3: Style,
    folio: Style,
}

/// `sentences` different sentences in a pseudo-random order.
fn paragraph_text(random: &mut Random, sentences: usize) -> String {
    let mut chosen: Vec<&str> = Vec::with_capacity(sentences);
    while chosen.len() < sentences {
        let sentence = SENTENCES[random.below(SENTENCES.len())];
        if !chosen.contains(&sentence) {
            chosen.push(sentence);
        }
    }
    chosen.join(" ")
}

fn frame() -> Frame {
    Frame {
        x: LEFT,
        top: TOP,
        bottom: BOTTOM,
        width: WIDTH,
    }
}

/// Adds a paragraph to the flow and records it as a structure element.
fn add(
    flow: &mut Flow,
    doc: &mut Doc,
    elements: &mut Vec<Element>,
    paragraph: Paragraph,
    lang: Option<&'static str>,
) -> Result<(), String> {
    let tag = paragraph.tag.unwrap_or("P");
    let marks = flow.paragraph(&mut doc.fonts, &paragraph.tagged(tag))?;
    elements.push(Element { tag, lang, marks });
    Ok(())
}

/// The body: the chapters and the references, exactly [`BODY_PAGES`] pages.
fn body(
    doc: &mut Doc,
    styles: &Styles,
    elements: &mut Vec<Element>,
    outline: &mut Vec<Entry>,
) -> Result<Vec<PageText>, String> {
    let mut flow = Flow::new(frame());
    let mut random = Random::new(64);
    for (chapter_index, (chapter, sections)) in CHAPTERS.iter().enumerate() {
        if chapter_index > 0 {
            flow.break_page();
        }
        outline.push(Entry {
            title: (*chapter).to_owned(),
            page: flow.pages.len() - 1,
            depth: 0,
        });
        let heading = Paragraph::new(&styles.h1, chapter)
            .aligned(Align::Left)
            .spaced(0.0, 18.0)
            .tagged("H1");
        add(&mut flow, doc, elements, heading, None)?;
        for (section, subsections, paragraphs) in *sections {
            let heading = Paragraph::new(&styles.h2, section)
                .aligned(Align::Left)
                .spaced(12.0, 6.0)
                .kept()
                .tagged("H2");
            add(&mut flow, doc, elements, heading, None)?;
            outline.push(Entry {
                title: (*section).to_owned(),
                page: flow.pages.len() - 1,
                depth: 1,
            });
            let parts = subsections.len().max(1);
            for part in 0..parts {
                if let Some(subsection) = subsections.get(part) {
                    let heading = Paragraph::new(&styles.h3, subsection)
                        .aligned(Align::Left)
                        .spaced(10.0, 4.0)
                        .kept()
                        .tagged("H3");
                    add(&mut flow, doc, elements, heading, None)?;
                    outline.push(Entry {
                        title: (*subsection).to_owned(),
                        page: flow.pages.len() - 1,
                        depth: 2,
                    });
                }
                for index in 0..*paragraphs {
                    let sentences = 4 + random.below(3);
                    let text = paragraph_text(&mut random, sentences);
                    add(
                        &mut flow,
                        doc,
                        elements,
                        Paragraph::new(&styles.body, &text).spaced(0.0, 6.0),
                        None,
                    )?;
                    if section.starts_with("2.2.") && index == 2 {
                        let mut quote = Paragraph::new(&styles.italic, QUOTE)
                            .spaced(4.0, 10.0)
                            .leading(1.3)
                            .tagged("BlockQuote");
                        quote.align = Align::Justify;
                        // Indented 1 cm on both sides, as a block quote.
                        let indented = Frame {
                            x: LEFT + 28.35,
                            width: WIDTH - 56.7,
                            ..frame()
                        };
                        let marks = flow.paragraph_in(&mut doc.fonts, &quote, indented)?;
                        elements.push(Element {
                            tag: "BlockQuote",
                            lang: Some("en-US"),
                            marks,
                        });
                    }
                }
            }
        }
    }
    // The references fill the rest, so the body is exactly BODY_PAGES pages long.
    flow.break_page();
    outline.push(Entry {
        title: "KAYNAKLAR".to_owned(),
        page: flow.pages.len() - 1,
        depth: 0,
    });
    let heading = Paragraph::new(&styles.h1, "KAYNAKLAR")
        .aligned(Align::Left)
        .spaced(0.0, 18.0)
        .tagged("H1");
    add(&mut flow, doc, elements, heading, None)?;
    let mut number = 0usize;
    loop {
        if flow.pages.len() > BODY_PAGES {
            return Err(format!(
                "the body has {} pages, more than {BODY_PAGES}",
                flow.pages.len()
            ));
        }
        if flow.pages.len() == BODY_PAGES && flow.y() - BOTTOM < 60.0 {
            break;
        }
        let surname = SURNAMES[number % SURNAMES.len()];
        let second = SURNAMES[(number * 7 + 3) % SURNAMES.len()];
        let topic = TOPICS[(number * 5 + 1) % TOPICS.len()];
        let year = 2005 + (number * 3) % 21;
        let reference = format!(
            "{surname}, A. ve {second}, B. ({year}). {topic}. Kent ve Toplum Dergisi, {}({}), {}–{}.",
            10 + number % 9,
            1 + number % 4,
            11 + number * 13 % 200,
            31 + number * 13 % 200
        );
        add(
            &mut flow,
            doc,
            elements,
            Paragraph::new(&styles.body, &reference)
                .aligned(Align::Left)
                .spaced(0.0, 4.0),
            None,
        )?;
        number += 1;
    }
    let mut pages = flow.into_pages();
    if pages.len() != BODY_PAGES {
        return Err(format!(
            "the body has {} pages, not {BODY_PAGES}",
            pages.len()
        ));
    }
    for (index, page) in pages.iter_mut().enumerate() {
        folio(doc, page, &styles.folio, &(index + 1).to_string())?;
    }
    Ok(pages)
}

/// The page number at the foot, as an artifact.
fn folio(doc: &mut Doc, page: &mut PageText, style: &Style, label: &str) -> Result<(), String> {
    page.content.op("/Artifact <</Type /Pagination>> BDC");
    doc.line(page, style, label, (LEFT, 42.0), WIDTH, Align::Center)?;
    page.content.op("EMC");
    Ok(())
}

fn roman(number: usize) -> &'static str {
    ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x"]
        .get(number.saturating_sub(1))
        .copied()
        .unwrap_or("x")
}

/// The front matter: cover, approval, the two abstracts, acknowledgements, contents and
/// abbreviations, exactly [`FRONT_PAGES`] pages.
fn front(
    doc: &mut Doc,
    styles: &Styles,
    elements: &mut Vec<Element>,
    outline: &[Entry],
) -> Result<(Vec<PageText>, Vec<Entry>), String> {
    let mut flow = Flow::new(frame());
    let mut entries = Vec::new();
    let center = |style: &Style, text: &str, after: f64| {
        Paragraph::new(style, text)
            .aligned(Align::Center)
            .spaced(0.0, after)
    };
    for (text, style, after) in [
        ("T.C.", &styles.h2, 4.0),
        ("İSTANBUL ÖRNEK ÜNİVERSİTESİ", &styles.h2, 4.0),
        ("SOSYAL BİLİMLER ENSTİTÜSÜ", &styles.h2, 4.0),
        ("KENT ÇALIŞMALARI ANABİLİM DALI", &styles.h2, 120.0),
        (
            "KENTSEL DÖNÜŞÜM SÜRECİNDE KİRACI HAKLARI: İSTANBUL ÖRNEĞİ",
            &styles.h1,
            30.0,
        ),
        ("Yüksek Lisans Tezi", &styles.body, 80.0),
        ("Zeynep ARSLAN", &styles.h2, 30.0),
        ("Danışman: Doç. Dr. Mehmet ÖZTÜRK", &styles.body, 160.0),
        ("İSTANBUL, 2026", &styles.h2, 0.0),
    ] {
        add(
            &mut flow,
            doc,
            elements,
            center(style, text, after).tagged(if style.size > 13.0 { "H1" } else { "P" }),
            None,
        )?;
    }
    let sections: [(&str, &[&str], Option<&'static str>); 4] = [
        (
            "KABUL VE ONAY",
            &[
                "Zeynep ARSLAN tarafından hazırlanan “Kentsel Dönüşüm Sürecinde Kiracı Hakları: İstanbul Örneği” başlıklı bu çalışma, 18.09.2026 tarihinde yapılan savunma sınavı sonucunda oy birliği ile başarılı bulunarak jürimiz tarafından Yüksek Lisans Tezi olarak kabul edilmiştir.",
                "Doç. Dr. Mehmet ÖZTÜRK (Danışman) · Prof. Dr. Ayşe GÜLER · Dr. Öğr. Üyesi Can ŞENER",
            ],
            None,
        ),
        (
            "ÖZET",
            &[
                ABSTRACT_TR,
                "Anahtar sözcükler: kentsel dönüşüm, kiracı hakları, yerinden edilme, İstanbul.",
            ],
            None,
        ),
        (
            "ABSTRACT",
            &[
                ABSTRACT_EN,
                "Keywords: urban renewal, tenant rights, displacement, Istanbul.",
            ],
            Some("en-US"),
        ),
        (
            "TEŞEKKÜR",
            &[
                "Bu çalışmanın her aşamasında desteğini esirgemeyen danışmanım Doç. Dr. Mehmet Öztürk’e, görüşmelere katılarak deneyimlerini paylaşan kiracılara ve sabırları için aileme teşekkür ederim.",
                "Zeynep Arslan, İstanbul, Eylül 2026",
            ],
            None,
        ),
    ];
    for (title, paragraphs, lang) in sections {
        flow.break_page();
        if title != "KABUL VE ONAY" {
            entries.push(Entry {
                title: title.to_owned(),
                page: flow.pages.len() - 1,
                depth: 0,
            });
        }
        let heading = Paragraph::new(&styles.h1, title)
            .aligned(Align::Center)
            .spaced(0.0, 24.0)
            .tagged("H1");
        add(&mut flow, doc, elements, heading, lang)?;
        for paragraph in paragraphs {
            add(
                &mut flow,
                doc,
                elements,
                Paragraph::new(&styles.body, paragraph).spaced(0.0, 10.0),
                lang,
            )?;
        }
    }
    flow.break_page();
    entries.push(Entry {
        title: "İÇİNDEKİLER".to_owned(),
        page: flow.pages.len() - 1,
        depth: 0,
    });
    let heading = Paragraph::new(&styles.h1, "İÇİNDEKİLER")
        .aligned(Align::Center)
        .spaced(0.0, 24.0)
        .tagged("H1");
    add(&mut flow, doc, elements, heading, None)?;
    for entry in outline {
        let indent = "    ".repeat(entry.depth);
        let line = format!("{indent}{} ··· {}", entry.title, entry.page + 1);
        add(
            &mut flow,
            doc,
            elements,
            Paragraph::new(&styles.body, &line)
                .aligned(Align::Left)
                .spaced(0.0, 2.0),
            None,
        )?;
    }
    // Pad the contents to two pages, as a contents page with a list of figures would be.
    while flow.pages.len() < FRONT_PAGES - 1 {
        add(
            &mut flow,
            doc,
            elements,
            Paragraph::new(&styles.body, "Şekiller ve tablolar listesi için bkz. Ek A.")
                .aligned(Align::Left)
                .spaced(0.0, 2.0),
            None,
        )?;
    }
    flow.break_page();
    entries.push(Entry {
        title: "KISALTMALAR".to_owned(),
        page: flow.pages.len() - 1,
        depth: 0,
    });
    let heading = Paragraph::new(&styles.h1, "KISALTMALAR")
        .aligned(Align::Center)
        .spaced(0.0, 24.0)
        .tagged("H1");
    add(&mut flow, doc, elements, heading, None)?;
    for line in [
        "AFAD: Afet ve Acil Durum Yönetimi Başkanlığı",
        "İBB: İstanbul Büyükşehir Belediyesi",
        "TOKİ: Toplu Konut İdaresi Başkanlığı",
        "TÜFE: Tüketici Fiyat Endeksi",
        "TÜİK: Türkiye İstatistik Kurumu",
    ] {
        add(
            &mut flow,
            doc,
            elements,
            Paragraph::new(&styles.body, line)
                .aligned(Align::Left)
                .spaced(0.0, 2.0),
            None,
        )?;
    }
    let mut pages = flow.into_pages();
    if pages.len() != FRONT_PAGES {
        return Err(format!(
            "the front matter has {} pages, not {FRONT_PAGES}",
            pages.len()
        ));
    }
    for (index, page) in pages.iter_mut().enumerate().skip(1) {
        folio(doc, page, &styles.folio, roman(index + 1))?;
    }
    Ok((pages, entries))
}

/// The outline as nested dictionaries, returning the root.
fn outline(doc: &mut Doc, entries: &[Entry], pages: &[ObjectId]) -> ObjectId {
    let root = doc.pdf.reserve();
    let ids: Vec<ObjectId> = entries.iter().map(|_| doc.pdf.reserve()).collect();
    // Parent of each entry: the closest earlier entry one level up.
    let parent = |index: usize| -> Option<usize> {
        let depth = entries[index].depth;
        (0..index)
            .rev()
            .find(|&earlier| entries[earlier].depth + 1 == depth)
            .filter(|_| depth > 0)
    };
    let children = |of: Option<usize>| -> Vec<usize> {
        (0..entries.len())
            .filter(|&index| parent(index) == of && (of.is_some() || entries[index].depth == 0))
            .collect()
    };
    for (index, entry) in entries.iter().enumerate() {
        let siblings = children(parent(index));
        let position = siblings
            .iter()
            .position(|&sibling| sibling == index)
            .unwrap_or(0);
        let mut dict = dictionary! {
            "Title" => text(&entry.title),
            "Parent" => parent(index).map_or(root, |p| ids[p]),
            "Dest" => vec![pages[entry.page].into(), name("XYZ"), Object::Null, real(TOP + 20.0), Object::Null],
        };
        if position > 0 {
            dict.set("Prev", ids[siblings[position - 1]]);
        }
        if let Some(next) = siblings.get(position + 1) {
            dict.set("Next", ids[*next]);
        }
        let kids = children(Some(index));
        if let (Some(first), Some(last)) = (kids.first(), kids.last()) {
            dict.set("First", ids[*first]);
            dict.set("Last", ids[*last]);
            // Chapters open, sections closed.
            let count = i64::try_from(kids.len()).unwrap_or(0);
            dict.set("Count", if entry.depth == 0 { count } else { -count });
        }
        doc.pdf.set(ids[index], dict);
    }
    let top = children(None);
    let mut dict = dictionary! { "Type" => "Outlines" };
    if let (Some(first), Some(last)) = (top.first(), top.last()) {
        dict.set("First", ids[*first]);
        dict.set("Last", ids[*last]);
        dict.set("Count", i64::try_from(top.len()).unwrap_or(0));
    }
    doc.pdf.set(root, dict);
    root
}

/// The structure tree and each page's `/StructParents`.
fn structure(doc: &mut Doc, elements: &[Element], pages: &[ObjectId]) -> ObjectId {
    let root = doc.pdf.reserve();
    let document = doc.pdf.reserve();
    let mut per_page: Vec<Vec<(i64, ObjectId)>> = vec![Vec::new(); pages.len()];
    let mut kids = Vec::new();
    for element in elements {
        let id = doc.pdf.reserve();
        let marks: Vec<Object> = element
            .marks
            .iter()
            .map(|(page, mcid)| {
                per_page[*page].push((*mcid, id));
                dictionary! { "Type" => "MCR", "Pg" => pages[*page], "MCID" => *mcid }.into()
            })
            .collect();
        let mut dict = dictionary! {
            "Type" => "StructElem",
            "S" => element.tag,
            "P" => document,
            "K" => marks,
        };
        if let Some(page) = element.marks.first() {
            dict.set("Pg", pages[page.0]);
        }
        if let Some(lang) = element.lang {
            dict.set("Lang", text(lang));
        }
        doc.pdf.set(id, dict);
        kids.push(Object::Reference(id));
    }
    doc.pdf.set(
        document,
        dictionary! { "Type" => "StructElem", "S" => "Document", "P" => root, "K" => kids },
    );
    let mut nums = Vec::new();
    for (index, marks) in per_page.iter_mut().enumerate() {
        marks.sort_by_key(|(mcid, _)| *mcid);
        nums.push(Object::Integer(i64::try_from(index).unwrap_or(0)));
        nums.push(Object::Array(
            marks.iter().map(|(_, id)| Object::Reference(*id)).collect(),
        ));
        super::kira::set_page_entry(
            &mut doc.pdf,
            pages[index],
            "StructParents",
            Object::Integer(i64::try_from(index).unwrap_or(0)),
        );
        super::kira::set_page_entry(&mut doc.pdf, pages[index], "Tabs", name("S"));
    }
    let parent_tree = doc.pdf.add(dictionary! { "Nums" => nums });
    doc.pdf.set(
        root,
        dictionary! {
            "Type" => "StructTreeRoot",
            "K" => document,
            "ParentTree" => parent_tree,
            "ParentTreeNextKey" => i64::try_from(pages.len()).unwrap_or(0),
        },
    );
    root
}

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.5");
    doc.pdf.modern = true;
    let mut body_style = doc.composite_style(sources, FontFile::PlexSerif, 11.0)?;
    body_style.ligatures = true;
    let mut italic = doc.composite_style(sources, FontFile::PlexSerifItalic, 10.5)?;
    italic.ligatures = true;
    let mut h1 = doc.composite_style(sources, FontFile::PlexSerifSemiBold, 15.0)?;
    h1.ligatures = true;
    let styles = Styles {
        body: body_style.clone(),
        italic,
        h2: h1.sized(12.5),
        h3: h1.sized(11.0),
        h1,
        folio: body_style.sized(10.0),
    };
    let mut body_elements = Vec::new();
    let mut body_outline = Vec::new();
    let body_pages = body(&mut doc, &styles, &mut body_elements, &mut body_outline)?;
    let mut elements = Vec::new();
    let (front_pages, front_outline) = front(&mut doc, &styles, &mut elements, &body_outline)?;
    for element in &mut body_elements {
        for mark in &mut element.marks {
            mark.0 += FRONT_PAGES;
        }
    }
    elements.extend(body_elements);
    let mut entries = front_outline;
    for entry in body_outline {
        entries.push(Entry {
            page: entry.page + FRONT_PAGES,
            ..entry
        });
    }
    let mut pages = front_pages;
    pages.extend(body_pages);
    let (ids, expected) = doc.add_pages(pages, pdf::A4);
    let outline_root = outline(&mut doc, &entries, &ids);
    let struct_root = structure(&mut doc, &elements, &ids);
    let front = i64::try_from(FRONT_PAGES).unwrap_or(0);
    let catalog = dictionary! {
        "Lang" => text("tr-TR"),
        "MarkInfo" => dictionary! { "Marked" => true },
        "StructTreeRoot" => struct_root,
        "Outlines" => outline_root,
        "PageMode" => "UseOutlines",
        "PageLabels" => dictionary! { "Nums" => vec![
            Object::Integer(0), dictionary! { "S" => "r" }.into(),
            Object::Integer(front), dictionary! { "S" => "D" }.into(),
        ]},
        "ViewerPreferences" => dictionary! { "DisplayDocTitle" => true },
    };
    let bytes = doc.close(
        catalog,
        &info(
            "Kentsel Dönüşüm Sürecinde Kiracı Hakları: İstanbul Örneği",
            "Zeynep Arslan",
            "LaTeX benzeri dizgi",
            "D:20260925120000+03'00'",
        ),
        "tez-tr",
        None,
    )?;
    Ok(generated(bytes, expected))
}
