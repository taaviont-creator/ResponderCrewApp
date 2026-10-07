# RespondCrew: tervikkontroll ja viimane parandusring

Kontroll: 07.10.2026. Baas `e3e5c7f`, haru `fix/android-native-alarm`, PR #59.
See raport kirjeldab selle kontrolli tõendeid. Varasemad etapiraportid on ajaloolised.

## Tulemus ja kontrolli piir

Käidi läbi rakenduse navigatsioon, põhivaadete andmeallikad, rollid, Firestore/Storage reeglid, serveri töövood, valmiduse ajaloogika, statistika, salvestusvead, sõltuvused ja pilve taastamisvalmidus. Leitud parandused on allpool. Automaatkontrollide läbimine ei tõenda kõigi seadmete, andmekombinatsioonide või kasutusolukordade veatust. Kõiki vaateid ei läbitud selles ringis tootmiskeskkonna päriskontodega; rollide piirid on kontrollitud testandmetega emulaatorites ja komponentides.

Keskused jäävad peidetuks. Uut APK-d ega allkirjastatud iOS-i väljalaset selles ringis ei koostata. Pärisliikmetele ei saadetud proovihäireid ega muudeti nende andmeid.

## Parandatud leiud

| Leid | Mõju | Parandus ja kontroll |
|---|---|---|
| Isikliku valmisoleku hilinemise valik ületas kitsa ekraani piiri | 320 px laiuse ja suure teksti korral 85 px ülekate | Valik kasutab olemasolevat laiust ja muutuva kõrgusega ridu. Sama põhimõte rakendatud tegevuse, tunnistuse, varustuse, aruande, geofence'i, planeeringute ja seadete valikutele. |
| Sektsiooni pealkiri ja tegevus võistlesid sama rea ruumi pärast | Suur tekst surus pealkirja kokku ja põhjustas ülekande | Ühine `SectionHeading` paigutab tegevuse kitsal pinnal või suure teksti korral pealkirja alla. Arvutis jääb kompaktne rida. |
| Varustuse lisamise/muutmise dialoog sulgus enne salvestuse kinnitust | Võrguvea järel kadus kasutaja sisestus | Ühine olekuga `EquipmentEditor`; salvestuse ajal korduv vajutus ja lahkumine blokeeritud, vea korral vorm ning sisestus säilivad. Korduskatse testitud. |
| Varustuse üldandmete muutmine kirjutas kaasa vana oleku ja märkuse | Vahepeal parandatud rikke olek võis tagasi muutuda | Üldandmete tehing muudab ainult nime, kategooriat, asukohta ja hoolduskuupäeva. Olek/märkus muudetakse eraldi olemasoleva olekutoiminguga; väljastamine ei muutu. |
| Korduv mittevalve kasutas telefonis seadme ajavööndit, serveris Eesti aega | Välismaal või UTC-ajaga kliendis erines valmidus serverist | Efektiivne valmidus ja lähiaja planeeringud kasutavad `Europe/Tallinn` aega. Kontrollitud suvi/talv, kuupäevapiir ja korduv sügisene tund. |
| Serveri sõltuvustes kõrge/kriitilise taseme teated | Teadaolevad sõltuvuste turvariskid | `proxy-addr` 2.0.8 ja `@fastify/busboy` 3.2.2 lukufailis; ühilduvad parandused. CI kontrollib edaspidi tootmissõltuvusi tasemega `high`. Pilve avaldamise seis eraldi allpool. |
| Veebikoost leidis puuduva Cupertino ikoonifondi | Flutteri platvormipõhised ikoonid võivad jääda kuvamata | Lisatud Flutteri standardne `cupertino_icons` fondipakett; muid Flutteri sõltuvusi ei uuendatud. |

Andmemudel, kogumid, kasutajate rollid ja ärilised õigused selles ringis ei muutu. Migratsiooni ei tehta. Vanade dokumentide ühilduvuskiht säilib. Kujunduse ühised suurused jäävad teemasse; pikki tekste lastakse ümber murda. Kokkuvõtteloendi teadlik lühendus on lubatud ainult siis, kui täielik info avaneb detailvaates.

## Kontrollmaatriks

| Valdkond | Kontrollitud käitumine / allikad | Tõend ja piirang |
|---|---|---|
| Sisselogimine, töökeskkond ja ühingu vahetus | `app_context_screen.dart`, `main_navigation_shell.dart`, konteksti ja ligipääsu teenused | `auth_context_stability`, `main_navigation_shell`, `navigation_protection`, `ux_navigation_layout`: vaate ja mustandi püsimine, organisatsiooni vahetus, eemaldatud õigused. Päriskonto taastatud sessiooni katsed jäävad kasutaja seadmele. |
| Töölaud ja valmidus | `home_screen.dart`, `effective_availability.dart`, `personal_availability_card.dart`, `crew_readiness_card.dart`, serveri `effective-readiness.js` | SAR miinimum + admini määratud II aste; Tross eraldi; hilinemine, planeering, ühingu valve peatamine. Uued Eesti ajavööndi regressioonid; ülevaate ja detailide olemasolevad testid läbivad. |
| Planeerimine ja geofence | `upcoming_absence.dart`, `unavailability_editor.dart`, `geofence_card.dart` | Korduvad/ühekordsed perioodid, omaniku piirangud, käsitsi ja planeeritud mittevalve prioriteet, tagasituleku kinnituse loogika. OS-i tegelik taustal piirkonnatuvastus vajab telefonikatset. |
| Liikmed ja tunnistused | `member_profile_screen.dart`, `certificate_editor.dart`, tunnistuste teenus ja reeglid | Omanik saab oma tunnistusi lisada; teise liikme/admini/teise ühingu piirid; kuupäevad kalendrist, staaž, profiili sektsioonid ja meeldetuletuse saajate privaatsus. |
| Tegevused, koolitused ja panused | `activity_editor.dart`, kalendri ja osalemise komponendid; serveri panuste/statistika moodulid | Kalendripäevade eristus, kuupäevade parsimine, checkbox-osalemine, kinnitamata panus ei muutu kinnitatud statistikaks, õigused ei sõltu kliendi lipust. |
| Väljakutsed ja täpne avamine | väljakutse loend/detail, `callout_link_opener`, `callout_notification_open_event` | Aktiivsed/lõpetatud eraldi, SAR/Tross kiire loomine, testmärgis, täpne väljakutse-ID, organisatsiooni õige kontekst, reageerimine. Telefoniteavituse tegelik jõudmine ei ole veebitesti tulemus. |
| Operatiivlogi ja aruanne | `operation_log_*`, `callout_report_screen.dart`, aruande teenus ja server | Sündmuse andmete taaskasutus, kronoloogia, osalejad, tehnika, kahju/kaotuse info, privaatsete isikute eraldus, lõpetatud logi lugemine, õigustatud parandused ja audit. PDF ning pikad osalejaloendid testitud. |
| Varustus ja alused | `equipment_screen.dart`, `equipment_care_screen.dart`, `equipment_service.dart`, `functions/equipment-care.js` | Viis vaadet, olek ja selgitus, ladu/väljastamine, serveri ajalugu, remondipanuse seos, kinnitatud inimtunnid. Panus ei muuda alust automaatselt korras olevaks. Uus metadata-salvestus ei kirjuta olekut üle. |
| Statistika ja eksport | `statistics_screen.dart`, statistika teenus/mudel, serveri koondid | Ühing/mina/liikmed/sündmused/panused/tunnistused; sama filter ekraanil ja failis; kõik tulemused ekspordis, mitte üks lehekülg; teadmatud tunnid eraldi nullist; CSV erimärgid ja PDF. Tavaliikmele ei lisata admini eksporti. |
| Teavitused | `notification_read_service`, `notifications_screen.dart`, serveri teavitustöövood | Kõik loetuks kasutab õigustele vastavaid eraldi kirjutusi; korduskatse ja eri postkastid. Tokeni omaniku piirang, eelistused ja adminile liikmetaotlus. Tegelik SMS-/telefonirakendus ja push vajavad seadmekatset. |
| Seaded ja platvormihaldus | seadete ning platvormihalduse vaated, liikmesuse serveritoimingud | Ühingu roll konkreetse liikmesuse järgi; platvormiõigus ei anna operatiivset adminiõigust; viimane admin kaitstud ka konkureerivas tehingus. Keskuse tööriistad jäävad väljalaskes peitu. |
| Failid ja privaatsus | `firestore.rules`, `storage.rules`, serveri manuste toimingud | Otsene Storage lugemine/kirjutamine keelatud ka ühingu adminile; kontrollitud serveritee, suuruse/loendi piir, autori/ühingu kontroll. Bucketi IAM-is ei leitud `allUsers`/`allAuthenticatedUsers` avalikku õigust. |
| Salvestamine ja taastamine | Firestore Admin API, avaldatud funktsioonide metaandmed | Standard/native, `europe-north1`; 71 olemasolevat funktsiooni ACTIVE. Varukoopia ja kustutuskaitse leitud puudus, vt allpool. |

## Rollid ja andmete piirid

| Tegevus | Aktiivne liige | Ühingu admin | II aste | Ainult platvormihaldur |
|---|---|---|---|---|
| Ühingu valmiduse ja lubatud meeskonna info lugemine | Jah | Jah | Jah | Mitte rolli enda alusel |
| Isiklik staatus, planeering ja oma tunnistus | Enda andmed | Enda andmed; liikme haldus olemasoleva õiguse piires | Enda andmed | Oma liikmesuse alusel |
| Ühingu seaded, kvalifikatsiooni muutmine | Ei | Oma ühing | Ei, kui pole admin | Ei |
| Sündmuse üldinfo/logi lugemine | Jah | Jah | Jah | Ei |
| Sündmuse/aruanne juhtiv muutmine | Ei | Jah | Olemasolevate operatiivõigustega | Ei |
| Aktiivse sündmuse osaleja käsitsi märkus | Ainult olemasoleva osalejapõhise lisamisõigusega | Jah | Jah | Ei |
| Ühingu tehnika olek | Lugemine ja oma remondipanus | Muutmine | Ainult liikme õigused, kui pole admin | Ei |
| Admini väljavõtted | Ei | Oma ühing | Mitte astme enda alusel | Ei |
| Organisatsioonitaotluste/keskuse õiguste haldus | Ei | Ei | Ei | Jah |

Osaleja märkuse erand ei anna tavaliikmele sündmuse üldandmete ega ajaloo muutmise õigust. Seda hilisemates telefonitestides kokku lepitud loogikat ei eemaldatud.

## Testitõendid

- `flutter analyze --no-pub`: **0 probleemi**.
- Kogu Flutteri komplekt: **357 testi läbis**.
- Uus paigutuse audit: **43 testi**, laiused 320/390/1280, tekstiskaala 1 ja 2; ühised komponendid, varustus, ajalugu, tunnistuse/varustuse/oleku vorm ja operatsiooni kokkuvõte; lisaks ebaõnnestunud salvestuse korduskatse.
- Uus ajavööndi komplekt: **3 testi**; koos olemasolevate valmiduse/planeeringutestidega läbis 54 fokusseeritud testi.
- Functions: **116 testi läbis**, ESLint ilma vigade ja hoiatusteta. Kohalik Node 24; CI kasutab Functions-kontrolliks tootmisega sama Node 22.
- Repositooriumi Firestore/Storage/serveritöövood: **153 testi läbis**.
- Praegu avaldatud reeglite emulaatorikatse: **143 testi läbis**. 10 mitteavaldatud `dispatch` katset jäeti selles eraldi kontrollis teadlikult välja; need sisalduvad täielikus 153-testises repositooriumi testis. Esimene filtrikatse kaasas ekslikult ka dispatch-testid ja andis ühe oodatud ligipääsuvea; lõplik jooks kasutab selget `--test-skip-pattern=^dispatch ` valikut.
- Varustuse ja statistika tegelikud Flutteri vaated renderdatud telefoni/arvuti mõõtudes ja visuaalselt üle vaadatud; need kasutavad kontrollitud testandmeid, mitte kõiki tootmise dokumente.
- Veebikoostu, avaldamise ja GitHubi CI tulemus lisatakse eraldi; kohalik test ei ole pilve avaldamise tõend.

Tõendilogid asuvad kohalikus ignoreeritud `.local-cache/final-*` failides. Neid ei lisata reposse, sest osa sisaldab taristu metaandmeid ja pikki emulaatori keelatud päringute väljundeid. `PERMISSION_DENIED` on negatiivsetes turvatestides oodatud tulemus; määrav on testi läbimise tulemus.

## Turvareeglid ja sõltuvused

Reegleid selles parandusringis ei muudeta. Avaldatud Firestore reeglistik `68f9977a-2f3d-4176-a510-d02b12f28ec2`, SHA-256 `8d0a8dcbb0bb94d7f246a11e40aeeed64896fd125938d9a499b59b7514022387`, ei ole bait-baidilt sama kui repo fail: repos on lisaks varasema keskuse väljakutse etapi ligipääsud. Neid ei avaldata kogemata koos UI parandustega. 11 veel avaldamata funktsiooni ei lisata selle auditi käigus.

Audit kontrollib loomise ja muutmise erinevust, tegeliku kasutaja/ühingu autoriteeti, serveri omanduses olevaid välju, andmetüüpe, privaatsust ja mahupiire. Masinloetav hinnang: [final-security-audit-2026-10-07.json](final-security-audit-2026-10-07.json). Põhilistes kontrollitud rolli- ja ühingupiirides möödapääsu ei leitud. Mõnel vanal vabatekstiväljal puudub rakendusepõhine ülempiir; Firestore dokumendipiir ei asenda seda. Ühtset piirangut ei lisatud pimesi olemasolevaid dokumente vigaseks muutma.

Sõltuvuste järelkontroll: 0 kriitilist, 0 kõrget, **8 mõõdukat sõltuvuskirjet**. Need on sama `uuid` probleemi levik sõltuvuspuus, mitte kaheksa tõendatud eraldi rakenduse rünnakut. Kontrollitud Google'i teekide kasutuskohad kutsuvad `uuid.v4`; see ei tõenda kogu sõltuvuspuu ohutust. npm pakutud täielik parandus nõuab Firebase Admin/Functions põhiversioonide vahetust. Sunnitud põhiversiooniuuendust ei tehtud ilma eraldi ühilduvuskontrollita.

Allikad: [proxy-addr advisory](https://github.com/advisories/GHSA-jqcg-44mw-7w3h), [busboy advisory](https://github.com/advisories/GHSA-xjh9-v7x6-24jw), [uuid advisory](https://github.com/advisories/GHSA-w5hq-g745-h8pq).

## Andmete säilitamine ja avaldamine

Pilve lugemiskontrollis: ajastatud varukoopiad puuduvad, PITR on välja lülitatud ja andmebaasi kustutuskaitse välja lülitatud. Reeglid kaitsevad kliendi ligipääsu; need ei asenda taastamisvõimalust eksliku haldustoimingu korral.

Kasutajale on esitatud konkreetne valik: igapäevane varukoopia 7-päevase säilitusega ja kustutuskaitse või ainult kustutuskaitse. Varukoopial on salvestusmahu põhine püsikulu. Kinnituse saabumiseni neid seadeid ei muudeta. Firestore varukoopia ei kata automaatselt Authi kasutajaid ega Storage'i manuseid; taastamine tuleb eraldi läbi proovida uude andmebaasi. [Firebase backup documentation](https://firebase.google.com/docs/firestore/backups).

71 olemasoleva funktsiooni sõltuvusparanduste massavaldamise peatas automaatne heakskiidukontroll laia tootmismõju tõttu. Eraldi kasutajaluba on küsitud. Lubamata funktsioonide avaldamist ei jaotata väikesteks sammudeks piirangust möödumiseks.

## Enne operatiivset väljalaset veel vajalik

1. Xiaomi 14 / Android 16: uusima rakenduse SAR heli vaikses/DND-režiimis, lukuekraanil ja kõne ajal; 10-sekundiline test, täpse väljakutse avamine, taustal push. Kasutaja seatud OS-i keelde ei tohi lubada ületada.
2. Telefon: GPS/wakelock, geofence'i taustasiirded ja valvesse naasmise kinnitus, failijagamine, helistamine ning püsiv sisselogimine. Veebiversioon ei ole APK-ga võrdne taustateenus.
3. iOS: Apple'i allkirjastamine, APNs/TestFlight ja pärisseadme katse. Simulaatori koost ei ole iPhone'i valmis väljalase.
4. Varunduse/kustutuskaitse otsus, esimese tegeliku varukoopia kontroll ja taastamise läbimäng.
5. Mõõdukate sõltuvusteadete põhiversiooniuuendus eraldi kontrollitud etapina; pärisandmete pikkuste inventuur enne vanade väljade rangemate limiitide rakendamist.
6. Keskuste avalik kasutus, koormuskatse ja kaarditeenuse leping jäävad teadlikult hilisemaks. SMTP seadistus on olemas; seda ei loeta enam varasemate raportite põhjal puuduvaks funktsiooniks.

Neid punkte ei esitata läbitud testidena ega peideta üldise „kõik valmis” väite taha.
