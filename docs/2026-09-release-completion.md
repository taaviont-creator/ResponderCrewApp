# Aruande ja avaldamise lõpetamine — 29.09.2026

## Tehtud
- Sündmuse aruande PDF kasutab sündmust, kinnitatud osalejaid, seotud tehnikat ning sama op-logi. Font on rakenduses; eksport ei vaja fondi allalaadimist. PDF näitab kasutatud ajavööndit.
- Isikuandmete ja privaatsete manuste loendi lisamine PDF-i on eraldi valik, ainult adminile / II astmele. Tavaliikme vastuses privaatandmeid ei ole.
- Sündmuse fotod/dokumendid/lühivideod: kuni 30 manust, igaüks kuni 8 MB. Manused on piiratud adminile / II astmele. Üks fail ühe sündmuse all; aruande jaoks ei looda koopiat. Allalaadimine kontrollib liikmelisust uuesti ega väljasta avalikku URL-i. Katkestatud üleslaadimist saab sama tunnusega korrata.
- Ühingu kontaktprofiili hilisem muutmine kasutab sama vormi, serveri adminiõigust, versioonikontrolli ja muutmisajalugu.
- Sündmuse tegeliku alguse/lõpu ja SAR/TROSS-tüübi järelparandus on adminile / II astmele. Algne loomise/lõpetamise ajatempel ja kronoloogilised logikirjed säilivad. Statistika kasutab parandatud algusaega, vanadel andmetel loomisaega.
- Alarm võtab enne FCM-i saatmist serveris ühekordse saatmisluku. Korduv Firestore'i sündmus ei saada sama alarmi uuesti. Ebamäärase saatmisvea korral säilib `unknown`, mitte eksitav edukuse märge. FCM ei võimalda garanteerida täpselt ühte kättetoimetamist: katkestus pärast lukku võib jätta alarmi saatmata. Sündmus on äpis eraldi olemas; telefoni kättesaamine vajab seadmekatset.

## Kontroll
Kohalikud testid: 86 Flutteri, 49 Functions'i ning 70 Firestore'i/Storage'i ja serveri integratsioonitesti. PDF-i kuueleheküljelist eestikeelset näidist kontrolliti teksti ja pildina; privaatandmed ning valimata tehnika puuduvad tavalisest ekspordist. CI kontrollib Androidi APK-d ja iPhone/iPadi simulaatori ehitust.

## Teadlikud piirid
- PDF sisaldab PPA referentsvormi sisulisi andmeid RespondCrew kujunduses; see ei ole PPA ametliku plangi visuaalne koopia.
- Manuseid PDF-i binaarfailidena ei põimita. Ligipääs neile on sündmuse juures.
- Üle 8 MB videote üleslaadimine ning manuste kustutamine ei kuulu esimesse versiooni. Üleslaadimine vajab võrku.
- Platvormi kasutajahalduses on kontode ülevaade ja seansside tühistamine. Konto kustutamist või üle ühingute deaktiveerimist ei lisatud, sest sellel oleks eraldi mõju viimase admini kaitsele ja liikmelisustele.
- Apple'i pärisrakenduse jaoks tuleb seadistada Apple Developer, allkirjastamine ja APNs ning väljastada TestFlight. Simulaatori build ei ole iPhone'i paigaldusfail. Critical Alerts ei ole lubatud.
- Pärisseadmete alarmi, GPS-i ja kasutusvoogude lõppkatse teeb kasutaja. Meili SMTP on seadistatud; kirja tegelik postkasti jõudmine tuleb kinnitada päriskutsega.

Storage loodi olemasolevasse Blaze projekti `respondcrew`, piirkonda `europe-north1`, ametliku [Firebase defaultBucket API](https://firebase.google.com/docs/reference/rest/storage/rest/v1alpha/projects.defaultBucket/create) kaudu. Rakenduse õigused kontrollitakse callable-teenuses, Storage otsepääs on keelatud.
