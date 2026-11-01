//! Locale-aware order of names, such as recent files and font lists (ADR 0021): ICU4X's collator
//! with its compiled data, so Turkish puts "Ç" after "C" and "ı" before "i".

use icu_collator::options::CollatorOptions;
use icu_collator::preferences::CollationNumericOrdering;
use icu_collator::{Collator, CollatorPreferences};
use icu_locale_core::Locale;

/// The order of `texts` in the language of `locale`, a BCP 47 tag such as `tr` or `ar-SA`: their
/// indices, first to last. Digits compare by their value, so "Fatura 2" comes before
/// "Fatura 10", and equal texts keep their order. A tag that does not parse sorts by the root
/// order of the Unicode Collation Algorithm.
#[must_use]
pub fn collation_order(locale: &str, texts: &[String]) -> Vec<usize> {
    let mut prefs = Locale::try_from_str(locale)
        .map(|locale| CollatorPreferences::from(&locale))
        .unwrap_or_default();
    prefs.numeric_ordering = Some(CollationNumericOrdering::True);
    let mut order: Vec<(usize, &str)> = texts.iter().map(String::as_str).enumerate().collect();
    match Collator::try_new(prefs, CollatorOptions::default()) {
        Ok(collator) => order.sort_by(|(_, a), (_, b)| collator.compare(a, b)),
        // The compiled data covers every locale through fallback; code points are the last
        // resort.
        Err(_) => order.sort_by_key(|(_, text)| *text),
    }
    order.into_iter().map(|(index, _)| index).collect()
}

#[cfg(test)]
mod tests {
    use super::collation_order;

    fn sorted<'a>(locale: &str, texts: &[&'a str]) -> Vec<&'a str> {
        let owned: Vec<String> = texts.iter().map(|text| (*text).to_owned()).collect();
        collation_order(locale, &owned)
            .into_iter()
            .filter_map(|index| texts.get(index).copied())
            .collect()
    }

    #[test]
    fn turkish_puts_its_letters_after_their_latin_neighbours() {
        let names = [
            "Cuma.pdf",
            "Çağrı.pdf",
            "ikna.pdf",
            "ılık.pdf",
            "Ozan.pdf",
            "Ömer.pdf",
        ];
        assert_eq!(
            sorted("tr", &names),
            [
                "Cuma.pdf",
                "Çağrı.pdf",
                "ılık.pdf",
                "ikna.pdf",
                "Ozan.pdf",
                "Ömer.pdf"
            ]
        );
        // The root order folds Ç into C and puts ı after i.
        assert_eq!(
            sorted("en", &names),
            [
                "Çağrı.pdf",
                "Cuma.pdf",
                "ikna.pdf",
                "ılık.pdf",
                "Ömer.pdf",
                "Ozan.pdf"
            ]
        );
    }

    #[test]
    fn digits_compare_by_value_and_case_is_secondary() {
        assert_eq!(
            sorted("tr", &["fatura 10.pdf", "Fatura 2.pdf", "fatura 2.pdf"]),
            ["fatura 2.pdf", "Fatura 2.pdf", "fatura 10.pdf"]
        );
    }

    #[test]
    fn equal_texts_keep_their_order_and_a_bad_tag_uses_the_root_order() {
        let texts: Vec<String> = ["b", "a", "b"].map(str::to_owned).to_vec();
        assert_eq!(collation_order("tr", &texts), [1, 0, 2]);
        assert_eq!(collation_order("not a tag!", &texts), [1, 0, 2]);
        assert!(collation_order("tr", &[]).is_empty());
    }
}
