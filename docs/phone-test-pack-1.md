# Telefonitesti paranduste pakett 1 — 29.09.2026

## Kontrollitud olemasolev lahendus

- Väljakutse loomine loob juba seotud op-logi ja alguskande samas kirjutuspaketis.
- Vabatekst, autor, aeg, tagantjärele märgitud aeg ja GPS on olemasolevas `operationLogs/{id}/events` mudelis.
- FCM tausta- ja külmkäivituse ning kohaliku esiplaaniteavituse avamine kannab edasi ühingu ja väljakutse ID. Avamise ID-andmed olid olemas, aga juurvaate uuesti loodavad vood võisid detaili kohe sulgeda ja jätta kasutaja nimekirja. Parandatud püsivate voogude ning ID-põhise avajaga; telefoni kõiki olekuid kohapeal ei testitud.
- Sündmuse ametlik lõpetamine kinnitusega ning admini/II astme õigused olid olemas, aga nupp oli liiga all.
- Olemasolevad liikme- ja enda profiilivaated jäävad kasutusse.

## Muudatused

- Teavitus avab väljakutse otse ID järgi, ootamata nimekirja päringut. Avalehe kasutaja-, liikmesuse- ja ühinguvood püsivad samad läbi ümberjoonistamiste, nii et avamise kinnitus ei hävita navigaatorit. Puuduva/keelatud sündmuse korral kuvatakse selge viga ja korduskatse.

- Ühine `ActiveCalloutsCard` asendab mõlema avalehe dubleeritud sündmusekaardid. Aktiivsed sündmused on enne pikka isikliku staatuse plokki. Kaardil on tüüp, pealkiri, algus, asukoht, vastus ja avamine. Tühjal nimekirjal ei jää kaardi ruumi.
- `CalloutResponseControls` annab avalehel ja detaili alguses samad Tulen / Hilinen / Ei tule nupud. Valik on nähtav, muudetav, salvestus on lukustatud kordusvajutuse vastu. Hilinemise olemasolev aeg ja märkus säilivad avamisel. Oma vastuse päring on ühingu/kasutaja/sündmuse järgi piiratud ka enne esimese vastuse salvestamist.
- Detaili ülamenüüs on Lõpeta sündmus. Senine kinnitusküsimus ja staatuse salvestamine säilivad; andmeid ega logi ei kustutata.
- Valves oleva liikme nimi avab olemasoleva profiili; enda nimi avab enda profiili. Õigused tulevad sama ühingu liikmesusest.
- Op-logi aktiivne osaleja võib lisada vabateksti ja kiirmärkeid. Osaleja on aktiivne liige, kes vastas Tulen/Hilinen või kelle osalemine kinnitati. Juhi märgitud puudumine tühistab vastuse alusel tekkiva õiguse. Õigus kaob ka sündmuse/logi lõppedes, liikmesuse eemaldamisel või ühingu peatamisel.
- Osaleja kiirnupud lisavad kirjeid ega muuda sündmuse või logi olekut. Senised juhi olekumuutused ja lõppkokkuvõtte õigused säilivad. Osaleja „Väljasõit” kirjet arvestab ka olemasolev väljasõiduaja näit.
- „Sündmus lõpetatud” lisab ainult kiirmärke, ka teel olles; ei lõpeta sündmust ega op-logi. Tagasisõidu märge jääb võimalikuks.
- Puudutatud nupud on kompaktsemad: vastused vähemalt 48 px, op-logi kiirnupud vähemalt 56 px, pikk tekst murrab rida.

## Turvareeglid

`isOperationLogEventCreate` kontrollib endiselt sama logi, ühingut, autorit, aega, GPS-i, kirje tüüpi ja logi olekut. Osaleja uus haru lubab ainult olemasolevasse aktiivse sündmuse logisse manualNote/quickAction lisamist, määratleb lubatud väljad ja teksti pikkuspiiri (4000). Vana kirje muutmine/kustutamine, kokkuvõte, uue logi loomine ning sündmuse/logi staatuse muutmine jäävad osalejale keelatuks. Autor on autentitud kasutaja. Ühingute ja platvormihalduri õigusi ei laiendatud.

Reegli ühised väärtused on taaskasutatud, et lisamisõiguse kontroll mahuks Firestore'i arvutuspiiri sisse. Kontrollitud ka GPS-iga positiivne kirjutamine, mitte ainult keelatud toimingud.

## Muudetud failid

- `lib/widgets/active_callouts_card.dart`, `callout_response_controls.dart`: ühised sündmuse- ja vastamiskomponendid.
- `lib/screens/admin_home_dashboard.dart`, `member_home_dashboard.dart`, `home_screen.dart`, `callout_detail_screen.dart`: paigutus, andmed ja lõpetamise menüü.
- `lib/services/callout_service.dart`: oma vastuse piiratud päring.
- `lib/widgets/callout_link_opener.dart`, `lib/screens/callouts_screen.dart`, `test/callout_link_opener_test.dart`: otsene avamine ID järgi ja navigeerimise regressioonid.
- `lib/services/operation_log_access_service.dart`, `operation_log_service.dart`, `lib/screens/operation_log_screen.dart`, `lib/widgets/operation_log_actions.dart`: osaleja lisamisõigus ja kiirmärked.
- `lib/widgets/callout_departure_timing.dart`: ka osaleja väljasõidumärge.
- `lib/widgets/crew_readiness_card.dart`: olemasoleva profiili avamine.
- `firestore.rules`, `rules-tests/firestore.rules.test.js`, `test/phone_test_pack_test.dart`, `test/operation_log_actions_test.dart`: õigused ja regressioonid.

Samasse PR-i kuulub varasem seni maini ühendamata liikme valmisoleku parandus (`dfb548f`), vt `member-readiness-fix.md`. See ei avalda liikme privaatseid mittevalve plaane teistele: server väljastab üksnes hetkel mittevalves liikmete ID-d.

## Kontrollid

- Flutter analyze: puhas.
- Flutter: 98 testi läbis.
- Firestore/Storage ja serveritöövood emulaatorites: 78 testi läbis.
- Functions: 51 testi läbis.
- Kokku 227 automaattesti. Lisatud/uuendatud vastuste kooskõla, kordusvajutus, salvestusvea järel uuesti proovimine, hilinemine, kitsas ekraan, sündmuse kadumine, õige profiil, informatiivne lõpetamise märge, osalemine, GPS, õiguse kaotamine ja keelatud muutmised.
- APK koostamise, avaldamise ja GitHubi CI lõpptulemus on üleandmise kokkuvõttes.

## Minimaalne pärisseadme test

A. Aktiivne väljakutse on kohe avalehe ülaosas. Vasta Tulen, ava detail: sama vastus. Muuda Hilinen (30 min), mine tagasi: sama vastus. Kontrolli ka Ei tule.
B. Vajuta konkreetse sündmuse teavitusele esiplaanil, taustal ja suletud äpiga; kontrolli õiget ühingut, sündmust ning nähtavaid vastamisnuppe. Ka teise ühingu teavitus peab avama õige sündmuse.
C. Tavaliige vastab Tulen. Ava op-logi, lisa vabatekst ja kiirmärge. Kontrolli autorit, aega ja võimalusel GPS-i väljavõttes/aruandes. „Sündmus lõpetatud” märge ei tohi sündmust sulgeda.
D. Admin või II astme liige valib detaili ülamenüüst Lõpeta sündmus. Loobu esmalt, seejärel kinnita. Kaart kaob avalehelt; logi ja aruanne säilivad. Tavaliikmel lõpetamise õigust ei ole.
E. Vajuta valmisoleku nimekirjas liikme nimele ja enda nimele: õiged olemasolevad profiilid, õigused endised. Helistamine/SMS töötavad eraldi nuppudest.

Füüsilise Androidi testi teeb kasutaja. iOS-i allkirjastamist, APNs-i seadistust ega TestFlighti see pakett ei lisa. Varustuse, planeerimise, profiili üldstruktuuri ja teavituste seadete ümberkujundamist ei tehtud. Üksnes andmete/serverireeglite uuendus ei lisa uusi nuppe: selle paketi jaoks on vaja uut APK-d.
