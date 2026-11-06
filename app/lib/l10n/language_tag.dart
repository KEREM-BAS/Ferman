/// The primary language subtag of the language tag [tag] in lower case:
/// `en` for "EN-gb". Tags are ASCII, so no locale's casing rules apply.
String languageTagCode(String tag) => tag.split('-').first.toLowerCase();
