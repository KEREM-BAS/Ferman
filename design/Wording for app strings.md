# Wording for the app strings

Strings added or changed on the gap boards, in English, Turkish and Arabic. Turkish and Arabic start from docs/TRANSLATION_REVIEW.md: rows marked **ARB** reuse that key’s text as is; every other row is new wording that the ARB files don’t have yet and that a native speaker should review. Board-only annotations (captions in capitals) are left out.

## Changed in existing keys

| Key | Was | Now | Why |
|---|---|---|---|
| `startDropTitle` (tr) | PDF'yi buraya bırakın | PDF’yi buraya bırakın | Typographic apostrophe, as everywhere else in the Turkish strings |
| zoom and status-bar percentages (tr) | 100% | %100 | CLDR Turkish percent pattern (G34); also ar-SA ١٠٠٪؜ |
| Shortcut table | Sidebar ⌥⌘S, Add signature ⌥⌘S | Sidebar ⌃⌘S, Add signature ⇧S, Save a copy ⌥⌘S | G44, matches app/lib/features/shell/shortcuts.dart |

## 01 First run and files (a1-2c-m1, a1-9c–f, a1-11b)

| Key | English | Turkish | Arabic | |
|---|---|---|---|---|
| future | Available in a future version | Gelecek bir sürümde sunulacak | متاح في إصدار قادم | **ARB** `availableInFutureVersion` |
| included | Included | Dâhil | مضمّنة | **ARB** `onboardingFeatureIncluded` |
| step2 | 2 of 2 | 2 / 2 | ٢ من ٢ |  |
| step2Label | Step 2 of 2 | Adım 2, toplam 2 | الخطوة ٢ من ٢ |  |
| back | Back | Geri | رجوع | **ARB** `onboardingBack` |
| startUsing | Start using Ferman | Ferman’ı kullanmaya başla | بدء استخدام Ferman | **ARB** `onboardingStartUsing` |
| freeTitle | Free forever, nothing locked | Sonsuza dek ücretsiz, hiçbir şey kilitli değil | مجاني إلى الأبد، ولا شيء مقفل | **ARB** `onboardingFreeTitle` |
| freeBody | Every feature is included, with no trial, no subscription and no paid tier. Ferman is open source, so anyone can read, check and improve the code. | Tüm özellikler dâhildir; deneme süresi, abonelik ya da ücretli sürüm yoktur. Ferman açık kaynaklıdır, bu yüzden herkes kodunu okuyabilir, denetleyebilir ve geliştirebilir. | كل الميزات مضمّنة، دون فترة تجريبية أو اشتراك أو باقة مدفوعة. Ferman مفتوح المصدر، لذا يمكن لأي شخص قراءة شيفرته وفحصها وتحسينها. | **ARB** `onboardingFreeBody` |
| licence | Licence: Apache-2.0 | Lisans: Apache-2.0 | الترخيص: Apache-2.0 | **ARB** `onboardingFreeLicence` |
| source | Source code | Kaynak kodu | الشيفرة المصدرية | **ARB** `onboardingFreeSourceCode` |
| support | Support the project | Projeyi destekleyin | دعم المشروع | **ARB** `onboardingFreeSupport` |
| feats | Edit text and images · Text recognition (OCR) · Fill and sign forms · e-imza and digital signatures · Redaction · Convert to and from Office · Compare documents · Batch actions · Accessibility checker · 3 interface languages | Metin ve görsel düzenleme · Metin tanıma (OCR) · Form doldurma ve imzalama · e-imza ve dijital imzalar · Karartma · Office’e ve Office’ten dönüştürme · Belge karşılaştırma · Toplu işlemler · Erişilebilirlik denetleyicisi · 3 arayüz dili | تحرير النصوص والصور · التعرّف على النص (OCR) · تعبئة النماذج وتوقيعها · e-imza والتوقيعات الرقمية · حجب المحتوى · التحويل من Office وإليه · مقارنة المستندات · إجراءات مجمّعة · مدقّق إمكانية الوصول · ٣ لغات للواجهة |  |
| npTitle | That file isn’t a PDF. | Bu dosya bir PDF değil. | هذا الملف ليس ملف PDF. |  |
| npSub | “Ek-1 Demirbaş listesi.xlsx” is an Excel file. Ferman opens PDF files. | “Ek-1 Demirbaş listesi.xlsx” bir Excel dosyası. Ferman PDF dosyalarını açar. | «Ek-1 Demirbaş listesi.xlsx» ملف Excel. يفتح Ferman ملفات PDF. |  |
| openAnother | Open another file… | Başka bir dosya aç… | فتح ملف آخر… |  |
| showIn | Show in Finder | Finder’da göster | إظهار في Finder |  |
| convert | Convert to PDF… | PDF’ye dönüştür… | تحويل إلى PDF… |  |
| roTitle | “Kira sözleşmesi.pdf” is read-only. | “Kira sözleşmesi.pdf” salt okunur. | «Kira sözleşmesi.pdf» للقراءة فقط. |  |
| roBody | Ferman can’t save changes to this file. To keep your changes, save a copy. | Ferman bu dosyaya değişiklik kaydedemez. Değişikliklerinizi saklamak için bir kopya kaydedin. | لا يستطيع Ferman حفظ التغييرات في هذا الملف. لتحتفظ بتغييراتك، احفظ نسخة. |  |
| saveCopy | Save a copy… | Kopya kaydet… | حفظ نسخة… |  |
| missTitle | “Hesap ekstresi Eylül 2026.pdf” can’t be found | “Hesap ekstresi Eylül 2026.pdf” bulunamadı | تعذّر العثور على «Hesap ekstresi Eylül 2026.pdf» |  |
| missDesc | It was moved, renamed or deleted after you last opened it. It was in ~/Belgeler/Banka. | Dosya son açılışınızdan sonra taşınmış, yeniden adlandırılmış veya silinmiş. Önceki konumu: ~/Belgeler/Banka. | نُقل الملف أو أُعيدت تسميته أو حُذف بعد آخر مرة فتحته فيها. كان في ~/Belgeler/Banka. |  |
| remove | Remove from list | Listeden kaldır | إزالة من القائمة |  |
| locate | Locate… | Bul… | تحديد الموقع… |  |
| oomTitle | “İmar planı açıklama raporu.pdf” was closed | “İmar planı açıklama raporu.pdf” kapatıldı | أُغلق «İmar planı açıklama raporu.pdf» |  |
| oomMsg | This computer ran out of memory while opening it. Your other documents are open and unchanged. | Dosya açılırken bilgisayarın belleği yetmedi. Diğer belgeleriniz açık ve değişmedi. | نفدت ذاكرة الجهاز أثناء فتحه. مستنداتك الأخرى مفتوحة ولم تتغيّر. |  |
| tryAgain | Try again | Yeniden dene | إعادة المحاولة |  |
| saTitle | Save as | Farklı kaydet | حفظ باسم |  |
| saName | File name | Dosya adı | اسم الملف |  |
| saWhere | Where | Konum | الموقع |  |
| saOther | Other location… | Başka bir konum… | موقع آخر… |  |
| saPdf | Standard PDF. Keeps text editable in Ferman and other editors. | Standart PDF. Metin Ferman’da ve diğer düzenleyicilerde düzenlenebilir kalır. | ملف PDF قياسي. يبقى النص قابلًا للتحرير في Ferman والمحررات الأخرى. |  |
| saPdfa | PDF/A-2b, for archiving | PDF/A-2b, arşivleme için | PDF/A-2b، للأرشفة |  |
| saPdfaFuture | Available in a future version | Gelecek bir sürümde sunulacak | متاح في إصدار قادم | **ARB** `availableInFutureVersion` |
| saWeb | Optimized for web | Web için optimize edilmiş | محسّن للويب |  |
| saWebDesc | The first page opens before the whole file downloads. Images are compressed to 150 ppi. | İlk sayfa, dosyanın tamamı inmeden açılır. Görseller 150 ppi’ye sıkıştırılır. | تُفتح الصفحة الأولى قبل تنزيل الملف كاملًا. تُضغط الصور إلى ١٥٠ ppi. |  |
| saCopy | Save as a copy | Kopya olarak kaydet | حفظ كنسخة |  |
| saCopyDesc | “Kira sözleşmesi.pdf” stays open and unchanged; the copy is saved in Projeler › 2026. | “Kira sözleşmesi.pdf” açık ve değişmeden kalır; kopya Projeler › 2026 klasörüne kaydedilir. | يبقى «Kira sözleşmesi.pdf» مفتوحًا دون تغيير، وتُحفظ النسخة في Projeler › 2026. |  |
| saComments | Include comments and markup | Yorumları ve işaretlemeleri dâhil et | تضمين التعليقات والتعليقات التوضيحية |  |
| saHistory | Remove edit history from the file | Düzenleme geçmişini dosyadan kaldır | إزالة سجل التحرير من الملف |  |
| saHistoryDesc | Ferman keeps version history next to the file, not inside it, unless you turn this off in Settings. | Ayarlar’dan kapatmadığınız sürece Ferman sürüm geçmişini dosyanın içinde değil, yanında tutar. | يحتفظ Ferman بسجل الإصدارات بجوار الملف لا داخله، ما لم توقف ذلك من الإعدادات. |  |
| cancel | Cancel | İptal | إلغاء |  |
| save | Save | Kaydet | حفظ | **ARB** `shellSave` |

## 02 View (a2-4c/d, a2-10a/b, a2-13)

| Key | English | Turkish | Arabic | |
|---|---|---|---|---|
| searching | Searching · page 840 of 2,400 | Aranıyor · sayfa 840 / 2.400 | جارٍ البحث · الصفحة ٨٤٠ من ٢٬٤٠٠ |  |
| searchingSub | Matches appear as they’re found. | Eşleşmeler bulundukça görünür. | تظهر النتائج فور العثور عليها. |  |
| cancel | Cancel | İptal | إلغاء |  |
| noneTitle | No results for “depozito” | “depozito” için sonuç yok | لا نتائج لـ«depozito» |  |
| noneBody | Ferman searched all 3 pages, ignoring accents and dotted/dotless i. Comments and form fields weren’t searched. | Ferman 3 sayfanın tamamında aradı; aksanlar ve noktalı/noktasız i yok sayıldı. Yorumlar ve form alanları aranmadı. | بحث Ferman في الصفحات الثلاث كلها، مع تجاهل علامات التشكيل والفرق بين i المنقوطة وغير المنقوطة. لم يُبحث في التعليقات وحقول النماذج. |  |
| noneAction | Also search comments and fields | Yorumlarda ve alanlarda da ara | البحث في التعليقات والحقول أيضًا |  |
| rTitle | The author restricted this document. | Belgenin yazarı bu belgeyi kısıtladı. | قيّد المؤلف هذا المستند. |  |
| rBody | You can read and print it. Editing, comments and form filling are turned off. | Belgeyi okuyabilir ve yazdırabilirsiniz. Düzenleme, yorum ve form doldurma kapalı. | يمكنك قراءته وطباعته. التحرير والتعليقات وتعبئة النماذج معطّلة. |  |
| unlock | Unlock with owner password… | Sahip parolasıyla kilidi aç… | فتح القفل بكلمة مرور المالك… |  |
| rTip | The author doesn’t allow editing | Yazar düzenlemeye izin vermiyor | لا يسمح المؤلف بالتحرير |  |
| pTitle | Kira sözleşmesi.pdf — Properties | Kira sözleşmesi.pdf — Özellikler | Kira sözleşmesi.pdf — الخصائص |  |
| ptabs | Summary · Security · Advanced | Özet · Güvenlik · Gelişmiş | ملخّص · الأمان · متقدّم |  |
| enc | Encryption | Şifreleme | التشفير |  |
| encV | AES-256 · owner password | AES-256 · sahip parolası | AES-256 · كلمة مرور المالك |  |
| openPw | Password to open | Açma parolası | كلمة مرور الفتح |  |
| openPwV | None | Yok | لا يوجد |  |
| perms | PERMISSIONS | İZİNLER | الأذونات |  |
| permNames | Printing · Changing the document · Adding comments · Filling form fields · Signing · Copying text and images · Text access for screen readers · Assembling pages | Yazdırma · Belgeyi değiştirme · Yorum ekleme · Form alanlarını doldurma · İmzalama · Metin ve görselleri kopyalama · Ekran okuyucular için metin erişimi · Sayfaları birleştirme ve düzenleme | الطباعة · تغيير المستند · إضافة التعليقات · تعبئة حقول النماذج · التوقيع · نسخ النصوص والصور · وصول قارئات الشاشة إلى النص · تجميع الصفحات |  |
| yes | Allowed | İzin veriliyor | مسموح |  |
| hq | Allowed, high quality | İzin veriliyor, yüksek kalite | مسموح، بجودة عالية |  |
| no | Not allowed | İzin verilmiyor | غير مسموح |  |
| done | Done | Bitti | تم |  |
| failTitle | Ferman couldn’t draw page 3. | Ferman 3. sayfayı çizemedi. | تعذّر على Ferman عرض الصفحة ٣. |  |
| failBody | Something on this page can’t be read. The rest of the document works as usual. | Bu sayfadaki bir öğe okunamıyor. Belgenin geri kalanı her zamanki gibi çalışır. | تعذّرت قراءة عنصر في هذه الصفحة. يعمل باقي المستند كالمعتاد. |  |
| retry | Try again | Yeniden dene | إعادة المحاولة |  |

## 03a Edit text (a3-16a/b, a3-17, a3-18, a3-19)

| Key | English | Turkish | Arabic | |
|---|---|---|---|---|
| cancel | Cancel | İptal | إلغاء |  |
| sTitle | Edit a signed document? | İmzalı bir belge düzenlensin mi? | هل تريد تحرير مستند موقّع؟ |  |
| sDesc | “Kira sözleşmesi.pdf” has 1 signature, by Mert Kaya on 13.10.2026. Any change to the document makes that signature invalid. | “Kira sözleşmesi.pdf” belgesinde Mert Kaya’nın 13.10.2026 tarihli 1 imzası var. Belgedeki her değişiklik bu imzayı geçersiz kılar. | في «Kira sözleşmesi.pdf» توقيع واحد من Mert Kaya بتاريخ ١٣‏/١٠‏/٢٠٢٦. أي تغيير في المستند يجعل هذا التوقيع غير صالح. |  |
| sCopy | Edit a copy | Bir kopyayı düzenle | تحرير نسخة |  |
| sAnyway | Edit anyway | Yine de düzenle | التحرير على أي حال |  |
| sCopyHint | The copy opens in a new tab as “Kira sözleşmesi (copy).pdf”. The signed original stays as it is. | Kopya yeni bir sekmede “Kira sözleşmesi (kopya).pdf” olarak açılır. İmzalı özgün belge olduğu gibi kalır. | تُفتح النسخة في علامة تبويب جديدة باسم «Kira sözleşmesi (نسخة).pdf». يبقى الأصل الموقّع كما هو. |  |
| sBannerTitle | The signature in this document is no longer valid. | Bu belgedeki imza artık geçerli değil. | لم يعد التوقيع في هذا المستند صالحًا. |  |
| sBannerBody | You changed the document after Mert Kaya signed it. Saving keeps the signature, but it will show as invalid. | Belgeyi Mert Kaya imzaladıktan sonra değiştirdiniz. Kaydettiğinizde imza belgede kalır ama geçersiz görünür. | غيّرت المستند بعد أن وقّعه Mert Kaya. يبقى التوقيع عند الحفظ، لكنه سيظهر غير صالح. |  |
| review | Review edits | Düzenlemeleri incele | مراجعة التعديلات | **ARB** `shellReviewEdits` |
| g2Title | Character added from this computer | Karakter bu bilgisayardan eklendi | أُضيف الحرف من هذا الجهاز |  |
| g2Body | Ferman took ‘ğ’ from Garamond Premier Pro installed on this computer and added it to the document’s font. | Ferman ‘ğ’ karakterini bu bilgisayarda yüklü Garamond Premier Pro’dan aldı ve belgenin yazı tipine ekledi. | أخذ Ferman الحرف ‘ğ’ من خط Garamond Premier Pro المثبّت على هذا الجهاز وأضافه إلى خط المستند. |  |
| gnTitle | No font has this character | Bu karakter hiçbir yazı tipinde yok | لا يوجد خط يحتوي هذا الحرف |  |
| gnBody | Neither this font nor any font on this computer has ‘ǧ’. Choose a font that has it, or keep the character as is. | Ne bu yazı tipinde ne de bu bilgisayardaki yazı tiplerinde ‘ǧ’ var. Bu karakteri içeren bir yazı tipi seçin ya da böyle bırakın. | لا يحتوي هذا الخط ولا أي خط على هذا الجهاز على الحرف ‘ǧ’. اختر خطًا يحتويه أو أبقِه كما هو. |  |
| glTitle | This font can’t be embedded | Bu yazı tipi gömülemiyor | لا يمكن تضمين هذا الخط |  |
| glBody | Garamond Premier Pro is installed, but its licence allows only preview and print. Ferman will use a similar font for ‘ğ’ instead. | Garamond Premier Pro yüklü, ancak lisansı yalnızca önizleme ve yazdırmaya izin veriyor. Ferman ‘ğ’ için bunun yerine benzer bir yazı tipi kullanacak. | خط Garamond Premier Pro مثبّت، لكن ترخيصه يسمح بالمعاينة والطباعة فقط. سيستخدم Ferman خطًا مشابهًا للحرف ‘ğ’ بدلًا منه. |  |
| choose | Choose a font… | Yazı tipi seç… | اختيار خط… |  |
| keep | Keep as is | Böyle kalsın | إبقاء كما هو |  |
| oTitle | Text doesn’t fit | Metin sığmıyor | النص لا يتسع |  |
| oBody | The edited paragraph needs 1 more line than its frame. | Düzenlenen paragraf, çerçevesinden 1 satır fazla yer istiyor. | تحتاج الفقرة المعدّلة إلى سطر واحد أكثر من إطارها. |  |
| ext | Extend block by 1 line | Bloğu 1 satır uzat | توسيع الكتلة بسطر واحد |  |
| tight | Tighten spacing slightly (−0.6%) | Aralığı biraz daralt (−%0,6) | تضييق التباعد قليلًا (−٠٫٦٪؜) |  |
| keepWarn | Keep and warn | Koru ve uyar | إبقاء مع تحذير |  |
| extReason | The IBAN line sits right below this block. | IBAN satırı bu bloğun hemen altında. | سطر IBAN يقع مباشرة أسفل هذه الكتلة. |  |
| tightReason | Even the tightest allowed spacing leaves 1 line over. | İzin verilen en dar aralıkta bile 1 satır taşıyor. | حتى أضيق تباعد مسموح يترك سطرًا واحدًا زائدًا. |  |
| nTip | This text is drawn as shapes, so it can’t be edited | Bu metin şekillerle çizilmiş, düzenlenemez | هذا النص مرسوم كأشكال، فلا يمكن تحريره |  |
| nTitle | This text can’t be edited | Bu metin düzenlenemez | لا يمكن تحرير هذا النص |  |
| nBody | The heading is drawn as vector shapes, not letters. Ferman can’t change it without redrawing it. | Başlık harflerle değil, vektör şekillerle çizilmiş. Ferman onu yeniden çizmeden değiştiremez. | العنوان مرسوم كأشكال متجهة لا كحروف. لا يستطيع Ferman تغييره دون إعادة رسمه. |  |

## 03c Edit review and translate (a3-12b)

| Key | English | Turkish | Arabic | |
|---|---|---|---|---|
| rv | Review edits | Düzenlemeleri incele | مراجعة التعديلات | **ARB** `shellReviewEdits` |
| close | Close review | İncelemeyi kapat | إغلاق المراجعة |  |
| filters | All · Text · Fonts · Warnings | Tümü · Metin · Yazı tipleri · Uyarılar | الكل · النص · الخطوط · التحذيرات |  |
| emptyTitle | No edits yet | Henüz düzenleme yok | لا توجد تعديلات بعد |  |
| emptyBody | Changes you make in this session appear here. The list clears when you close the document; earlier sessions are in Version history. | Bu oturumda yaptığınız değişiklikler burada görünür. Liste belgeyi kapattığınızda temizlenir; önceki oturumlar Sürüm geçmişi’nde. | تظهر هنا التغييرات التي تجريها في هذه الجلسة. تُمسح القائمة عند إغلاق المستند، والجلسات السابقة في سجل الإصدارات. |  |
| revertAll | Revert all… | Tümünü geri al… | التراجع عن الكل… |  |
| exportL | Export list… | Listeyi dışa aktar… | تصدير القائمة… |  |
| raTitle | Revert all 5 edits? | 5 düzenlemenin tümü geri alınsın mı? | هل تريد التراجع عن التعديلات الخمسة كلها؟ |  |
| raDesc | “Kira sözleşmesi.pdf” goes back to how it was when you opened it at 13:41. Undo brings the edits back until you close the document. | “Kira sözleşmesi.pdf”, saat 13:41’de açtığınızdaki hâline döner. Belgeyi kapatana kadar Geri al ile düzenlemeleri geri getirebilirsiniz. | يعود «Kira sözleşmesi.pdf» إلى ما كان عليه عند فتحه الساعة ١٣:٤١. يمكنك استعادة التعديلات بالأمر «تراجع» حتى تغلق المستند. |  |
| raBtn | Revert 5 edits | 5 düzenlemeyi geri al | التراجع عن ٥ تعديلات |  |
| cancel | Cancel | İptal | إلغاء |  |
| rdTitle | Also revert the edit that depends on it? | Buna bağlı düzenleme de geri alınsın mı? | هل تريد أيضًا التراجع عن التعديل المعتمد عليه؟ |  |
| rdDesc | “(on dokuz bin beş yüz TL)” was typed into the sentence after this change. Reverting “18.500 TL → 19.500 TL” removes it too. | “(on dokuz bin beş yüz TL)” bu değişiklikten sonra aynı cümleye yazıldı. “18.500 TL → 19.500 TL” geri alınırsa o da kaldırılır. | كُتب «(on dokuz bin beş yüz TL)» في الجملة بعد هذا التغيير. التراجع عن «18.500 TL → 19.500 TL» يزيله أيضًا. |  |
| rdBtn | Revert both | İkisini de geri al | التراجع عن كليهما |  |

## 11b App (a11-7d–f)

| Key | English | Turkish | Arabic | |
|---|---|---|---|---|
| errTitle | Couldn’t save “Kira sözleşmesi.pdf” | “Kira sözleşmesi.pdf” kaydedilemedi | تعذّر حفظ «Kira sözleşmesi.pdf» |  |
| err1 | You don’t have permission to change this file or its folder. Save it somewhere else, or ask the owner for access. Your edits are kept. | Bu dosyayı veya klasörünü değiştirme izniniz yok. Başka bir yere kaydedin ya da dosyanın sahibinden erişim isteyin. Düzenlemeleriniz korunuyor. | ليس لديك إذن بتغيير هذا الملف أو مجلده. احفظه في مكان آخر أو اطلب الإذن من مالكه. تعديلاتك محفوظة. |  |
| err2 | Another app has the file open and locked. Close it there and try again, or save a copy somewhere else. Your edits are kept. | Dosya başka bir uygulamada açık ve kilitli. Oradan kapatıp yeniden deneyin ya da başka bir yere kopya kaydedin. Düzenlemeleriniz korunuyor. | الملف مفتوح ومقفل في تطبيق آخر. أغلقه هناك ثم أعد المحاولة، أو احفظ نسخة في مكان آخر. تعديلاتك محفوظة. |  |
| err3 | Ferman wrote your changes to a temporary file but couldn’t put it in place of the original. The original is unchanged and your edits are kept. | Ferman değişikliklerinizi geçici bir dosyaya yazdı ama özgün dosyanın yerine koyamadı. Özgün dosya değişmedi, düzenlemeleriniz korunuyor. | كتب Ferman تغييراتك في ملف مؤقت، لكنه لم يتمكّن من وضعه مكان الملف الأصلي. لم يتغيّر الملف الأصلي، وتعديلاتك محفوظة. |  |
| err4 | “Ortak” is no longer connected. Reconnect the drive and try again, or save somewhere else. Your edits are kept. | “Ortak” sürücüsünün bağlantısı kesildi. Sürücüyü yeniden bağlayıp tekrar deneyin ya da başka bir yere kaydedin. Düzenlemeleriniz korunuyor. | لم يعد «Ortak» متصلًا. أعد توصيل القرص ثم أعد المحاولة، أو احفظ في مكان آخر. تعديلاتك محفوظة. |  |
| tryAgain | Try again | Yeniden dene | إعادة المحاولة |  |
| saveAs | Save as… | Farklı kaydet… | حفظ باسم… |  |
| qTitle | Save changes to 3 documents before quitting? | Çıkmadan önce 3 belgedeki değişiklikler kaydedilsin mi? | هل تريد حفظ التغييرات في ٣ مستندات قبل الإنهاء؟ |  |
| qDesc | Ferman saves the checked documents, then quits. Changes to unchecked documents are lost. | Ferman işaretli belgeleri kaydedip çıkar. İşaretsiz belgelerdeki değişiklikler kaybolur. | يحفظ Ferman المستندات المحدّدة ثم يُنهي عمله. تضيع تغييرات المستندات غير المحدّدة. |  |
| q1 | 3 edits | 3 düzenleme | ٣ تعديلات |  |
| q2 | 2 comments | 2 yorum | تعليقان |  |
| q3 | 1 edit | 1 düzenleme | تعديل واحد |  |
| cancel | Cancel | İptal | إلغاء |  |
| saveQuit | Save and quit | Kaydet ve çık | حفظ وإنهاء |  |
| quitNo | Quit without saving | Kaydetmeden çık | إنهاء دون حفظ |  |
| rTitle | Ferman restored 2 documents | Ferman 2 belgeyi geri yükledi | استعاد Ferman مستندين |  |
| rDesc | Ferman closed unexpectedly at 13:58. These documents had unsaved changes, and Ferman had kept a copy of each on this device. | Ferman saat 13:58’de beklenmedik şekilde kapandı. Bu belgelerde kaydedilmemiş değişiklikler vardı ve Ferman her birinin bir kopyasını bu cihazda tuttu. | أُغلق Ferman على نحو غير متوقع الساعة ١٣:٥٨. كانت في هذه المستندات تغييرات غير محفوظة، واحتفظ Ferman بنسخة من كلٍّ منها على هذا الجهاز. |  |
| r1 | 6 edits · last change 13:57 · ~/Belgeler/Ev | 6 düzenleme · son değişiklik 13:57 · ~/Belgeler/Ev | ٦ تعديلات · آخر تغيير ١٣:٥٧ · ~/Belgeler/Ev |  |
| rBadge | Changed on disk | Diskte değişti | تغيّر على القرص |  |
| r2 | The file on disk changed at 14:05, after Ferman’s copy. The restored version opens as “e-Arşiv fatura 4187 (recovered).pdf”, so neither is overwritten. | Diskteki dosya, Ferman’ın kopyasından sonra 14:05’te değişti. Geri yüklenen sürüm “e-Arşiv fatura 4187 (kurtarılan).pdf” adıyla açılır; hiçbiri üzerine yazılmaz. | تغيّر الملف على القرص الساعة ١٤:٠٥، بعد نسخة Ferman. تُفتح النسخة المستعادة باسم «e-Arşiv fatura 4187 (مستعاد).pdf»، فلا يُستبدل أيٌّ منهما. |  |
| discard | Discard | Kopyaları sil | تجاهل النسخ |  |
| open2 | Open 2 documents | 2 belgeyi aç | فتح المستندين |  |

## FmSidebar (a2-3m, a2-14)

| Key | English | Turkish | Arabic | |
|---|---|---|---|---|
| future | Available in a future version | Gelecek bir sürümde sunulacak | متاح في إصدار قادم | **ARB** `availableInFutureVersion` |
| sigFuture | Signature checking is available in a future version. | İmza denetimi gelecek bir sürümde sunulacak. | التحقق من التوقيعات متاح في إصدار قادم. |  |
| outline | list-tree · No bookmarks · This document has no outline. Add a bookmark to mark a place you want to come back to. | list-tree · Yer işareti yok · Bu belgede yer işareti yok. Geri dönmek istediğiniz bir yeri işaretlemek için yer işareti ekleyin. | list-tree · لا توجد إشارات مرجعية · لا يحتوي هذا المستند على إشارات مرجعية. أضف إشارة لتعليم موضع تريد العودة إليه. |  |
| attachments | paperclip · No attachments · Files embedded in this PDF appear here. | paperclip · Ek yok · Bu PDF’ye gömülü dosyalar burada görünür. | paperclip · لا توجد مرفقات · تظهر هنا الملفات المضمّنة في ملف PDF هذا. |  |
| layers | layers · No layers · This document has no layers to show or hide. | layers · Katman yok · Bu belgede gösterilip gizlenebilecek katman yok. | layers · لا توجد طبقات · لا يحتوي هذا المستند على طبقات يمكن إظهارها أو إخفاؤها. |  |
| signatures | signature · No signatures · This document isn’t signed and has no signature fields. | signature · İmza yok · Bu belge imzalı değil ve imza alanı içermiyor. | signature · لا توجد توقيعات · هذا المستند غير موقّع ولا يحتوي على حقول توقيع. |  |
| nomatch | search · No results for “{q}” · Ferman searched all 3 pages, ignoring accents and dotted/dotless i. | search · “{q}” için sonuç yok · Ferman 3 sayfanın tamamında aradı; aksanlar ve noktalı/noktasız i yok sayıldı. | search · لا نتائج لـ«{q}» · بحث Ferman في الصفحات الثلاث كلها، مع تجاهل علامات التشكيل والفرق بين i المنقوطة وغير المنقوطة. |  |
| notext | scan-text · No text to search · These pages are scanned images. Recognizing text makes them searchable. · Recognize text (OCR) | scan-text · Aranacak metin yok · Bu sayfalar taranmış görüntülerden oluşuyor. Metin tanıma, sayfaları aranabilir yapar. · Metni tanı (OCR) | scan-text · لا يوجد نص للبحث فيه · هذه الصفحات صور ممسوحة ضوئيًا. التعرّف على النص يجعلها قابلة للبحث. · التعرّف على النص (OCR) |  |

## FmStart and FmSettings

FmStart gained Turkish for the recent-files screen and FmSettings Turkish for the pane list and Language and region; General and Privacy reuse the ARB keys `settings*` unchanged. New Turkish there: Sabitlenenler, Sabitlemeyi kaldır, Son kullanılanlar, Son dosyalarda ara, Görünüm, Izgara, Liste, Son açılma, Ad, Konum, Sayfa, Son dosyalar yalnızca bu cihazda listelenir., Listeyi temizle, Dosyaları bu pencerede herhangi bir yere bırakın, PDF dosyaları sekmelerde açılır., Bölge biçimleri, Kâğıt boyutu, Birimler, Haftanın ilk günü, ÖRNEKLER. New Arabic: تُفتح ملفات PDF في علامات تبويب.
