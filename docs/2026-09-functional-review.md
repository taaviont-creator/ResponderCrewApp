> Hilisemad täiendused ja praegused piirid: [avalduse lõpetamine](2026-09-release-completion.md). Allolev kirjeldab PR #29 kontrolli hetke. PPA vorm kontrolliti hiljem ning SMTP, PDF-eksport, manused ja profiili hilisem muutmine on lisatud.

# RespondCrew: olemasoleva lahenduse ülevaatus 29.09.2026

Alus: main d5ed906 ja pooleliolev op-logi kasutusmugavuse parandus. Allpool on algseis ning teostatud muudatuste ja kontrollide kokkuvõte.

| Valdkond | Olemas | Puuduv või vastuoluline |
|---|---|---|
| Rollid | `users.systemRole` ja ühingupõhine `memberships/{uid}_{org}` | Platvormiõigus lubab mitmes UI/serveriharus operatiivmuudatusi. Tavaliikme logikirjutamise seade on uue nõudega vastuolus. II astme liikme logiõigus olemas, sündmuse loomine/lõpetamine pole sellega kooskõlas. |
| Ühingutaotlused | Loomine `pending`; kinnitamine/tagasilükkamine koos looja liikmelisuse uuendusega | Loomisvorm küsib ainult nime. Puudub terviklik tehniline organisatsioonide ülevaade ja eraldi platvormihalduse kontekst. |
| Liitumine | Koodiga liitumine `pending`; ühingu admin kinnitab; teavituste funktsioon olemas | Säilitada olemasolev töövoog. Platvorm ei kinnita tavapäraseid liikmeid. |
| Viimane admin | Lahkumisel kliendi päring kontrollib teist admini | Pole tehinguga kaitstud; rolli eemaldamise ja paralleelsete eemaldamiste serverikaitse puudulik. Vajalik tehinguline haldus ning kliendi otsese möödapääsu sulgemine. |
| Op-logi | Seotud väljakutse, ajad/GPS, sündmused, kokkuvõte/tulemus, tekstiväljavõte, tagantjärele kommentaarid, kokkuvõtte audit | Pooleliolev parandus teeb nupud suureks, eemaldab vahekinnitused, lubab suletud väljakutse kokkuvõtet ka puudulike verstapostide korral. |
| Meeskond | `calloutAttendance`, tegeliku osalemise kinnitamine, tunnid ja muutmatu `attendanceHistory`; admin/II aste, ka pärast lõppu | Aruandes kasutada neid samu andmeid; reageerimisvastus ei võrdu kinnitatud osalemisega. |
| Tervikaruanne | Op-logi väljavõte ja olemasolev `summary`/`outcome` | Puuduvad tervikaruanne, koostaja/juht, tehnika seos, ettepanekud, aruande staatus, eraldi piiratud isikuandmed. Kokkuvõtet ja logi ei tohi kopeerida uude dokumenti. |
| Manused | Sündmuse failide hoidlat ega manuste töövoogu ei leitud | Selles etapis mitte luua teist failihoidlat. Dokumenteerida tulevane seos; täisfailide/PDF eksport eraldi etapp. |
| Statistika | Valvetunnid ajaloost ja planeeritud puudumistega, kinnitatud tegevuspanus, väljakutseosalemised, reageerimised | Puuduvad sündmuste koondarvud/SAR/TROSS ning organisatsiooni valvepauside välistamine. `commands.isOnDuty` on vana kasutamata algväärtus, mitte usaldusväärne valveajalugu. |
| Avalehe tegevused | Admini väljakutsenupp; liikmel tuleva tegevuse eelvaade; tegevuste vastused ja loomisteavitus olemas | Ühtne lähitegevuste plokk koos kiire vastusega mõlemas vaates; admini tegevuse lisamise kiirnupp tagasi. |
| Audit | Osalejate audit, kokkuvõtte logikanne, statistika muudatuste ajalugu | Ühtne oluline haldusaudit ja sündmuse põhiandmete muudatuste audit puuduvad. |

## Teostuspiirid ja andmeallikad

- Säilitada `commands`, `memberships`, `callouts`, `operationLogs/events`, `calloutAttendance`, `activities/activityParticipants`.
- Õigus lähtub aktiivsest sama ühingu kanoonilisest liikmelisusest. Platvormiroll üksi ei anna sündmuse muutmise õigust.
- Aruande üldandmed koostatakse allikatest; aruandespetsiifiline dokument hoiab viiteid, ettepanekuid, staatust ja versiooni. Olemasolev kokkuvõte/tulemus jääb op-logisse.
- Abivajajate andmed eraldi piiratud dokumendis; tavaliikme vastuses, üldkokkuvõttes ega platvormi üldülevaates neid ei avaldata.
- Adminikaitse vajab serveritehingut ja ühise organisatsioonidokumendi lukku, et kaks admini ei saaks üheaegselt lahkuda.
- Valvepaus peab säilitama ajalised intervallid; liikmete staatuseid ega varasemat statistikat ei kirjutata ümber. Tegevustunnid jätkuvad.
- PPA referentsvorm pole praeguste manuste hulgast leitav. Vormi täielikku väljade vastavust ei saa enne faili saamist kinnitada.

## Kontrolliplaan

Õiguste maatriks (liige/admin/II aste/platvorm/teine ühing/eemaldatud), viimase admini paralleelsed muudatused, aruande versioonikonflikt ja privaatandmete eraldatus, lõpetatud sündmuse täiendused koos auditiga, valvepausi piirid statistikas, avalehe vastused ja kitsas ekraan. Flutter analüüs/testid, Functions testid, Firestore emulaator ning Android/iOS CI. Pärisseadmel GPS/push/alarm on eraldi lõppkatse.


## Teostatud lahendus

- Platvormihaldus avatakse eraldi juurkontekstis. `systemRole` ei anna organisatsiooni operatiivõigusi. Ühingu õigused tulenevad aktiivsest sama ühingu liikmelisusest; admin ja II aste saavad sündmust juhtida, liige lugeda.
- Ühingute tehniline ülevaade: ootel taotlused, liikmete/adminide/sündmuste arv, teadaolevad ajad, profiil, peatamine/taastamine. Kontohalduses kontode loend ning seansside tühistamine. Olemasolev taotluse kinnitamise/tagasilükkamise tehing säilib.
- Loomise vorm salvestab kontaktid eraldi `organizationProfiles/{org}` dokumenti (looja, platvormihaldur, ühingu admin). Organisatsiooni nimi jääb `commands` dokumenti. Kohustuslikud on nimi, kontaktisik ja kontaktisiku e-post.
- Rollimuudatused ja admini lahkumine toimuvad serveritehingus. Organisatsiooni ühine versioonilukk kaitseb kahe admini samaaegse lahkumise eest. Otsene rolli või aktiivse admini staatuse muutmine kliendist keelatud. Kustutamisõigust pole.
- Suletud sündmuse pealkirja, kirjeldust ja asukohta saab parandada admin/II aste; muutus ja autor salvestuvad. Algsed op-logi sündmused jäävad muutmatuks, parandused lisatakse tagantjärele kommentaarina koos tegeliku sündmuse ajaga. Osalejate olemasolev kinnitamise/auditi töövoog säilib.
- Suured op-logi nupud salvestavad ühe vajutusega; lõpukinnitus jääb baasi naasmise/lõpetamise juurde. Kommentaarid ja osalejad on hallatavad ka pärast sündmust.
- Avalehe õiguspõhised kiirtegevused ning kolm lähimat tegevust/koolitust kasutavad olemasolevaid `activities` ja `activityParticipants` andmeid. Osalemisvastus ei tähenda tegeliku osalemise kinnitust.
- Admini kogu ühingu valvepaus hoiab `organizationDutyPauses` ajavahemikke. Kattuvaid pause lahutatakse üks kord; pooleliolev paus lõpeb arvestuse hetkel. Koolituste, tegevuste ja väljakutsete kinnitatud panust paus ei vähenda. Isiklikud valvesolekud jäävad alles.
- Statistika näitab eraldi kõiki sündmusi ja perioodi sündmusi, SAR/TROSS ja lõpetatud/tühistatud sündmusi. Liikme tegelik osalemine põhineb endiselt kinnitatud meeskonnal.

## Aruande andmemudel ja kasutamine

`getCalloutReport` koostab vaate sama ühingu sündmusest, kronoloogilistest `operationLogs/events` kirjetest, kinnitatud `calloutAttendance` meeskonnast ja seotud varustusest. Sündmuse loomise/lõpetamise ajad kuvatakse olemasolevatest ajatemplidest; fiktiivseid vaheetappe ei tekitata.

`calloutReports/{calloutId}` sisaldab põhiloogi viidet, koostaja/juhi kasutaja-ID-d, tehnika ID-sid, vajadusel registreerimisnumbreid, ettepanekuid, staatust (`draft`/`completed`), versiooni ja viimast muutjat/aega. Kokkuvõte ja tulemus jäävad olemasoleva op-logi `summary`/`outcome` väljadesse. `reportLog` koopiat ei teki. Nii aruande versioon kui algse kokkuvõtte väärtus kontrollitakse tehingus, et samaaegne töö ei kirjutaks võõraid parandusi üle.

`calloutPrivate/{calloutId}` sisaldab struktureeritud seotud isikuid: nimi, kontakt, tunnus, roll, märkused. Lugeda/muuta saab ainult aktiivne sama ühingu admin või II aste. Tavaliikme serverivastus ei sisalda neid välju üldse. Muutmise ajalugu asub eraldi sama piiranguga alamkogus.

`reportHistory`, `changeHistory`, olemasolev osalemiste ajalugu ja kokkuvõtte logikanne annavad detailse muudatuste jälje. `platformAudit` annab oluliste toimingute üldvaate (muutja/aeg/objekt/muudetud väljad), kopeerimata abivajajate isikuandmeid. Firestore'i sündmuste audit kasutab autentimise konteksti ja korduv tarnimine ei dubleeri kirjet.

Kasutaja valib vajadusel koostaja/juhi ja tehnika, lisab kokkuvõtte/tulemuse, seotud isikud ja ettepanekud. Valmis aruande saab märkida pärast sündmuse sulgemist; hilisem parandus jääb auditisse. Meeskonda muudetakse olemasolevas osalejate vaates. Merepääste aste salvestatakse uutel osalemiskinnitustel; vanemate puhul märgib vaade, et näitab praegust astet.

## Kontrollid 29.09.2026

- Flutter analüüs: vigadeta.
- Flutter: 83 testi läbivad, sh suured op-logi nupud, kitsas aruande vaade, liikme lugemisvaade ja sisestuse säilimine salvestusvea korral.
- Functions: 37 testi läbivad, sh valvepausi piirid/kattumine/ühingupõhisus ja panuse säilimine, sündmuste statistika ja auditi korduskindlus.
- Firestore + päris serveritehingud emulaatoris: 64 testi läbivad. Sh viimase admini paralleelsed lahkumised, aruande privaatandmed, versioonikonflikt, lõpetatud sündmuse täiendamine, platvormirolli piirang, uue ühingu profiili loomine.
- Firebase respondcrew: 15 uut/uuendatud funktsiooni ACTIVE, europe-north1, Node.js 22. Aruande, platvormiülevaate ja valvepausi anonüümsed päringud tagastavad UNAUTHENTICATED. Alarmifunktsioon on jätkuvalt ACTIVE.
- Androidi/iOS ehituste ja maini ühendamise tulemused lisatakse pärast CI lõppu. Pärisseadme katseid pole automaattestidega asendatud.

## Teadlikult eraldi etapp

- PPA referentsvormi tegelikku faili pole leitud: täielikku vormiväljade vastavust ei ole kinnitatud. Aruande olemasolevaid allikaid saab kasutada tulevases ekspordis.
- PDF/PPA eksport ja sündmuste failihoidla/manuste lisamine ei kuulunud olemasoleva lahenduse funktsioonidesse; neid selles etapis juurde ei tehtud.
- Tehniline kontohaldus ei kustuta ega deaktiveeri kontosid; nii ei teki kõrvalteed viimase aktiivse admini eemaldamiseks.
- Ühingu loomise kontaktprofiili hilisem redigeerimine ning mahuka platvormiülevaate lehekülgedele jagamine on eraldi edasiarendus.
- Olemasolevad vanade dokumentide üldised pikkuspiirangud vajavad eraldi laiema ulatusega korrastust; uutel aruande/profiili andmetel on tüübi- ja pikkuspiirangud.
- Kutsete automaatne e-post ja uue ühingu platvormihalduri e-post vajavad endiselt teenuse/SMTP/API saladuse seadistamist.
