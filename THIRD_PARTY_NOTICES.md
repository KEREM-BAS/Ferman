# Third-party notices

Ferman's own code and documentation are licensed under the Apache License 2.0 (see [LICENSE](LICENSE)).

This file covers third-party material that is **already in this repository** inside `design/`, the read-only Claude Design export, the handwriting and similar fonts ([below](#handwriting-and-similar-fonts)), the generated table of standard 14 font widths in ferman-text ([below](#standard-14-font-widths)) and the predefined CMaps bundled in ferman-fonts ([below](#adobe-cmap-resources)). `design/` is a reference for the product design. It is never shipped in the app. The Ferman app will carry its own licence files for the fonts, icons and libraries it bundles, in `app/assets` and in an in-app licences view (see [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md)).

The export itself ships no licence files (see [docs/DESIGN_GAPS.md](docs/DESIGN_GAPS.md#g08)), and `design/` must not be edited. The licence texts therefore live here, outside `design/`.

| Material | Where in `design/` | Licence |
|---|---|---|
| IBM Plex Sans, Sans Arabic, Serif and Mono (woff2 subsets) | `_ds/ferman-design-system-…/assets/fonts/` | SIL Open Font License 1.1, Reserved Font Name "Plex" |
| Lucide icon path data (145 glyphs in `ICON_PATHS`, plus most of the 84 glyphs in `fm-icons.js`) | `_ds/ferman-design-system-…/_ds_bundle.js`, `ds-additions/fm-icons.js` | ISC; icons derived from Feather are also under MIT |

Not in the repository, so not covered here: React, ReactDOM and Babel, which `design/support.js` loads from unpkg when an artboard is opened in a browser, and the font families that `design/ds-additions/fm-additions.css` loads from Google Fonts at view time.

## IBM Plex

Source: <https://github.com/IBM/plex>

```text
Copyright © 2017 IBM Corp. with Reserved Font Name "Plex"

This Font Software is licensed under the SIL Open Font License, Version 1.1.

This license is copied below, and is also available with a FAQ at: http://scripts.sil.org/OFL


-----------------------------------------------------------
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007
-----------------------------------------------------------

PREAMBLE
The goals of the Open Font License (OFL) are to stimulate worldwide
development of collaborative font projects, to support the font creation
efforts of academic and linguistic communities, and to provide a free and
open framework in which fonts may be shared and improved in partnership
with others.

The OFL allows the licensed fonts to be used, studied, modified and
redistributed freely as long as they are not sold by themselves. The
fonts, including any derivative works, can be bundled, embedded, 
redistributed and/or sold with any software provided that any reserved
names are not used by derivative works. The fonts and derivatives,
however, cannot be released under any other type of license. The
requirement for fonts to remain under this license does not apply
to any document created using the fonts or their derivatives.

DEFINITIONS
"Font Software" refers to the set of files released by the Copyright
Holder(s) under this license and clearly marked as such. This may
include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the
copyright statement(s).

"Original Version" refers to the collection of Font Software components as
distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting,
or substituting -- in part or in whole -- any of the components of the
Original Version, by changing formats or by porting the Font Software to a
new environment.

"Author" refers to any designer, engineer, programmer, technical
writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS
Permission is hereby granted, free of charge, to any person obtaining
a copy of the Font Software, to use, study, copy, merge, embed, modify,
redistribute, and sell modified and unmodified copies of the Font
Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components,
in Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled,
redistributed and/or sold with any software, provided that each copy
contains the above copyright notice and this license. These can be
included either as stand-alone text files, human-readable headers or
in the appropriate machine-readable metadata fields within text or
binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font
Name(s) unless explicit written permission is granted by the corresponding
Copyright Holder. This restriction only applies to the primary font name as
presented to the users.

4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font
Software shall not be used to promote, endorse or advertise any
Modified Version, except to acknowledge the contribution(s) of the
Copyright Holder(s) and the Author(s) or with their explicit written
permission.

5) The Font Software, modified or unmodified, in part or in whole,
must be distributed entirely under this license, and must not be
distributed under any other license. The requirement for fonts to
remain under this license does not apply to any document created
using the Font Software.

TERMINATION
This license becomes null and void if any of the above conditions are
not met.

DISCLAIMER
THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE
COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL
DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM
OTHER DEALINGS IN THE FONT SOFTWARE.
```

## Lucide (and Feather)

Source: <https://github.com/lucide-icons/lucide>

```text
ISC License

Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

---

The following Lucide icons are derived from the Feather project:

airplay, alert-circle, alert-octagon, alert-triangle, aperture, arrow-down-circle, arrow-down-left, arrow-down-right, arrow-down, arrow-left-circle, arrow-left, arrow-right-circle, arrow-right, arrow-up-circle, arrow-up-left, arrow-up-right, arrow-up, at-sign, calendar, cast, check, chevron-down, chevron-left, chevron-right, chevron-up, chevrons-down, chevrons-left, chevrons-right, chevrons-up, circle, clipboard, clock, code, columns, command, compass, corner-down-left, corner-down-right, corner-left-down, corner-left-up, corner-right-down, corner-right-up, corner-up-left, corner-up-right, crosshair, database, divide-circle, divide-square, dollar-sign, download, external-link, feather, frown, hash, headphones, help-circle, info, italic, key, layout, life-buoy, link-2, link, loader, lock, log-in, log-out, maximize, meh, minimize, minimize-2, minus-circle, minus-square, minus, monitor, moon, more-horizontal, more-vertical, move, music, navigation-2, navigation, octagon, pause-circle, percent, plus-circle, plus-square, plus, power, radio, rss, search, server, share, shopping-bag, sidebar, smartphone, smile, square, table-2, tablet, target, terminal, trash-2, trash, triangle, tv, type, upload, x-circle, x-octagon, x-square, x, zoom-in, zoom-out

The MIT License (MIT) (for the icons listed above)

Copyright (c) 2013-present Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Handwriting and similar fonts

`app/assets/fonts/` bundles these unmodified, each with its upstream licence as `LICENSE.txt`, which
the in-app licences view shows. Sources and hashes are in `tools/fonts/fonts.lock`.

| Family | Copyright | Licence |
|---|---|---|
| Caveat | Copyright 2014 The Caveat Project Authors (<https://github.com/googlefonts/caveat>) | SIL Open Font License 1.1 |
| Dancing Script | Copyright 2016 The Dancing Script Project Authors (<https://github.com/googlefonts/DancingScript>), with Reserved Font Name "Dancing Script" | SIL Open Font License 1.1 |
| Homemade Apple | Copyright (c) 2010 by Font Diner, Inc. All rights reserved. | Apache License 2.0 |
| Cormorant Garamond | Copyright 2015 the Cormorant Project Authors (github.com/CatharsisFonts/Cormorant) | SIL Open Font License 1.1 |
| Crimson Pro | Copyright 2018 The Crimson Pro Project Authors (<https://github.com/Fonthausen/CrimsonPro>) | SIL Open Font License 1.1 |

## Standard 14 font widths

`crates/ferman-text/src/standard14.rs` holds the advance widths of the twelve Latin standard 14 fonts
(Courier, Helvetica and Times in four styles each), which a PDF may name without embedding them or
listing `/Widths`. They are not copied from a font or an AFM file: `tools/standard14/generate.py`
measures them by drawing each character with the pinned PDFium library (`tools/pdfium`), whose
built-in standard fonts are metric-compatible with Adobe's Core14 AFM files, so the numbers are the
AFM widths a reader uses. PDFium is BSD-3-Clause; its licence (`licenses/pdfium.txt` of the PDFium
archive) ships with the app, see [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md). Adobe's Core14 AFM
files may be used, copied and distributed with their notice kept; Ferman ships none of them.

## Adobe CMap resources

`crates/ferman-fonts/data/cmap-resources/` holds predefined CMaps from Adobe's cmap-resources
(<https://github.com/adobe-type-tools/cmap-resources>), unmodified, so that text drawn through them
reads and edits right: `90ms-RKSJ-H` (version 11.006, Adobe-Japan1, SHA-256
`e0b104bcc8dfb3c2d3e025e12c59182d7e0ee1b5df6f55bc8550d4b3fc83ecd3`). Each file keeps its own
copyright and licence header, which is:

```text
Copyright 1990-2019 Adobe. All rights reserved.

Redistribution and use in source and binary forms, with or
without modification, are permitted provided that the
following conditions are met:

Redistributions of source code must retain the above
copyright notice, this list of conditions and the following
disclaimer.

Redistributions in binary form must reproduce the above
copyright notice, this list of conditions and the following
disclaimer in the documentation and/or other materials
provided with the distribution.

Neither the name of Adobe nor the names of its contributors
may be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
