//! `js-openaction`: a one-page English registration notice with document JavaScript in three
//! places: the `/OpenAction`, the `/JavaScript` name tree and the page's open action
//! (`/AA /O`). Ferman never runs it and says the document contains scripts (Q13, G100). The
//! text is in Helvetica, named but not embedded, with the widths of IBM Plex Sans.

use super::{Doc, generated, info, opens};
use crate::pdf::{self, text};
use crate::sources::{FontFile, Sources};
use crate::text::{Align, Flow, Frame, Paragraph};
use crate::{Generated, Generator};
use lopdf::{Object, dictionary};

/// The document with scripts.
pub const JS_OPENACTION: Generator = Generator {
    name: "js-openaction",
    build,
    expect: opens(),
};

fn js(script: &str) -> lopdf::Dictionary {
    dictionary! { "Type" => "Action", "S" => "JavaScript", "JS" => Object::string_literal(script) }
}

fn build(sources: &Sources) -> Result<Generated, String> {
    let mut doc = Doc::new("1.6");
    let body = doc.standard_style(
        sources,
        FontFile::PlexSans,
        "Helvetica",
        "Type1",
        false,
        11.0,
    )?;
    let bold = doc.standard_style(
        sources,
        FontFile::PlexSansSemiBold,
        "Helvetica-Bold",
        "Type1",
        false,
        11.0,
    )?;
    let mut flow = Flow::new(Frame {
        x: 72.0,
        top: pdf::A4.1 - 80.0,
        bottom: 80.0,
        width: pdf::A4.0 - 144.0,
    });
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(&bold.sized(18.0), "Annual Members’ Meeting 2026")
            .aligned(Align::Left)
            .spaced(0.0, 6.0),
    )?;
    flow.paragraph(
        &mut doc.fonts,
        &Paragraph::new(&body, "Registration notice")
            .aligned(Align::Left)
            .spaced(0.0, 18.0),
    )?;
    for paragraph in [
        "The Annual Members’ Meeting of the Harbour Housing Cooperative takes place on Friday, 20 November 2026, at 18:30 in the community hall, 3 Quay Street.",
        "Members who wish to attend are asked to register by 13 November 2026. Each member may bring one guest. Please tell us in advance if you need step-free access or a sign language interpreter.",
        "The agenda covers the annual report, the accounts for 2025, the election of two board members and the proposal to renovate the shared laundry.",
        "This document contains scripts that check the registration details when it is opened in a viewer that runs them.",
    ] {
        flow.paragraph(
            &mut doc.fonts,
            &Paragraph::new(&body, paragraph)
                .aligned(Align::Left)
                .spaced(0.0, 10.0)
                .leading(1.45),
        )?;
    }
    let (pages, expected) = doc.add_pages(flow.into_pages(), pdf::A4);
    super::kira::set_page_entry(
        &mut doc.pdf,
        pages[0],
        "AA",
        dictionary! { "O" => js("console.println(\"Page 1 opened\");") }.into(),
    );
    let open = doc.pdf.add(js(
        "app.alert(\"Please register by 13 November 2026.\", 3);",
    ));
    let init = doc.pdf.add(js("var meetingDate = util.scand(\"yyyy-mm-dd\", \"2026-11-20\");\nfunction daysLeft() { return Math.ceil((meetingDate - new Date()) / 86400000); }"));
    let names = doc
        .pdf
        .add(dictionary! { "Names" => vec![text("init"), init.into()] });
    let catalog = dictionary! {
        "Lang" => text("en-GB"),
        "OpenAction" => open,
        "Names" => dictionary! { "JavaScript" => names },
    };
    let bytes = doc.close(
        catalog,
        &info(
            "Members’ meeting registration",
            "Harbour Housing Cooperative",
            "Form designer",
            "D:20261020090000+01'00'",
        ),
        "js-openaction",
        None,
    )?;
    Ok(generated(bytes, expected))
}
