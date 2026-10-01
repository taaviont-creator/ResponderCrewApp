# RespondCrew: töökindluse ja väljalaske ülevaatus

Kuupäev: 01.10.2026. Kontrollitud baas: main `61787f9` (PR #35).
See on praegune tööjärg. Varasemad etapiraportid on ajaloolised; nende „puudu” või „pole avaldatud” väited ei kirjelda automaatselt tänast seisu.

## Kontrollitud ulatus

Üle vaadati töökeskkondade/sisselogimise elutsükkel, navigeerimine, keskuse andmete laadimine ja värskus, sama valmiduse kasutamine telefonis ja kaardil, valmiduse teavituste sündmused, rollide olemasolevad testid, avaldamise töövood ja väljalaske juhendid. Lähtefailid: `app_context_screen.dart`, `center_access_service.dart`, `center_board_service.dart`, `main_navigation_shell.dart`, `home_screen.dart`, `crew_readiness_card.dart`, `functions/organization-readiness.js`, `center-board.js`, `organization-center-readiness.js` ning vastavad Flutteri ja emulaatori testid.

See ei ole tõend kõigi rollide päriskontodega läbimisest ega kõigi võimalike turvavigade puudumisest. Olemasolevaid õigusi, rolliotsuseid ja andmemudelit selles parandusringis ei muudeta.

## Juba olemas

- SAR/Trossi keskuse eraldi õigused ja sama Firebase'i andmestik; ühingu kontakt ja tegelik baasi asukoht; serveripoolne teenusepõhine valmidus; aktiivse keskuseõiguse kontroll igas serveripäringus.
- Ühingu enda miinimumkoosseis, admini määratud II aste, planeeritud mittevalved, ühingu valve peatamine, aluste kasutatavus ja administraatori piirangud. Liikmete jagamist teiste ühingute vahel ei nõuta.
- Liikme liitumiskoodi kinnitusring, viimase admini kaitse, liikmesuspõhised õigused, isikuandmete eraldamine, sündmuse aruanne ja PDF, tegevuste/statistika moodul ning SMTP saatmisvoog.
- Ühtne mobiili/arvuti navigatsioon ja grupeeritud seaded; Flutteri, Functions'i, turvareeglite, veebi ning iOS-i CI. APK on ainult käsitsi valitav.

## Selle ringi parandused

| Leitud puudus | Mõju | Parandus |
|---|---|---|
| Keskuse õiguste loendi ajutine tühjenemine vahetas ühinguvaate välist ülesehitust | Avatud vaade ja sisestus võisid kaduda võrguvea või taustale mineku järel | Püsiv rakenduseraam ja võtmega sisuala; õiguste nupud muutuvad sisu taasloomiseta. Algse töökeskkonnavaliku otsus ei muutu hilisema päringu tõttu. Eemaldatud keskuseõigus sulgeb endiselt keskuse vaate. |
| Valmidusteavituse tunnus sisaldas arvutuse ja värskuse kellaaegu | Minutiline kordusarvutus võis ootel koosseisuhoiatuse kehtetuks muuta ilma tegeliku valmidusmuutuseta | Tunnus põhineb sisulistel andmetel; värskuse ajatemplid uuenevad eraldi. Tegelik valmiduse taastumine muudab tunnust ja välistab aegunud hoiatuse. |
| Kaardivastus vahetas üksuste loendi enne ligipääsu aegumisandmete valideerimist | Vigane vastus võis segada uue loendi vana kontrolliajaga | Uus vastus avaldatakse tervikuna alles pärast valideerimist; võrgu-/vorminguviga säilitab eelmise loendi selgelt aegunud olekus. |
| Vigase kujuga vanad valikulised loendid katkestasid kaardivastuse parsimise | Üks vana väli võis takistada kogu kaardi uuendamist | Puuduvad/vigased valikulised põhjuste ja aluste loendid on tühjad; teadmata staatust ei muudeta roheliseks. |
| Seadmekatse ja osa juhendeid viitasid vanale harule või juba lõpetatud etappidele | Testija ei teadnud, millist seisu kontrollida | Praegune ülevaatus ja juhendite selged ajaloolise etapi märked. |

## Veel tähelepanu vajav töö

| Prioriteet | Teema | Järgmine konkreetne samm / läbimise tingimus |
|---|---|---|
| Enne operatiivset kasutust | Androidi pärisseadme alarm, taust/lukuekraan, täpne väljakutse, GPS ja ekraani ärkvelhoidmine | Kasutaja läbib seadmekatse konkreetse APK commit'iga, kui APK koostamine on uuesti tellitud. Ükski veebitest ei tõenda telefoni heli ega taustakäitumist. |
| Enne Apple'i telefonikatset | Apple Developer, lõplik rakenduse identiteet, allkirjastamine, APNs ja TestFlight | Kontrollida kontol tegelik seadistus ning siduda allkirjastatud rakendusega. Edukas iOS-i simulaatori CI on olemas; see ei ole paigaldatav allkirjastatud iPhone'i väljalase. Apple'i Critical Alerts on eraldi heakskiit, mitte olemasolev funktsioon. |
| Enne keskuse laiemat kasutust | Kaart on endiselt piiratud katsemahuga | `getCenterReadinessBoard` loeb kuni 26 jagamiskirjet ja annab vea üle 25 kirje korral; ka ootel/tühistatud jagamised lähevad praegu piirangu sisse. Vajalik on heakskiidetud kirjete päring, lehekülgede laadimine ja koormuskatse. Päring arvutab valmiduse uuesti iga keskuse värskenduse ajal; seda ei tohi piiramatuteks mahtudeks kuulutada. |
| Enne keskuse operatiivset kasutust | Kaardipaanide teenus ja püsiv veebiaadress | Praegune OSM standardpaanide teenus ja ajutine `keskused-katse` kanal sobivad katseks. Valida operatiivse kasutuse mahule sobiv kaarditeenus ja püsiv Firebase Hosting avaldamisviis. Oma domeen ei ole kohustuslik. |
| Järgmine kasutajateekonna parandus | Teavituse kaudu avamine ja töökeskkonna/ühingu vahetamine salvestamata vormi ajal | Alumine menüü austab vormi lahkumiskaitset; välised teavitusmarsruudid ja kontekstivahetus vajavad sama kaitse eraldi ühendamist. Häire ei tohi kaduda: pärast salvestamist või teadlikku loobumist tuleb avada täpne väljakutse. |
| Lõppkatse | Tegelik e-kirja ja telefoni push'i kättesaamine | SMTP/FCM serveri vastuvõtt ja seadistus on olemas. Kontrollida testsaajaga tegelik saabumine ning logi vead; ei saadeta proovihäireid pärisliikmetele ilma kokkuleppeta. |
| Hooldus | Functions'i `lint` on praegu teateskript | CI testib serveriloogikat ja kontrollib sisenemispunkti süntaksit, kuid see ei ole täielik staatiline lintimine. Eraldi ulatusega lisada tegelik kontroll ilma kogu serverikoodi põhjendamatu vormindusrefaktorita. |

Vanade `commandId` väljade ühilduvuskihti ei eemaldata: kasutuses võib olla vanu dokumente. Keskusest väljakutsete saatmine, vastuvõtmine ning sündmuskohale saabumise aja arvutus jäävad kokkulepitud järgmisse arendusetappi, mitte käesoleva paranduse varjatud lisafunktsiooniks.

## Kontrollid ja avaldamise seis

Uued regressioonid kontrollivad sisestuse ja vaate säilimist, õiguse eemaldamise jätkuvat jõustamist, vigase kaardivastuse atomaarset käsitlust ning teavituse püsimist kordusarvutuse järel ja aegunud hoiatuse kadumist tegelikul taastumisel. Kohalik lõppkontroll: `flutter analyze` 0 probleemi; 173 Flutteri testi, 93 Functions’i testi ja 119 Firestore/Storage’i ning serveri töövoogude testi läbivad. Security Rules ja õigused ei muutunud. APK-d ei koostata. GitHubi CI ja pilve avaldamise tulemust kontrollitakse eraldi enne üleandmist; kohalikku kontrolli ei esitata pilve avaldamise tõendina.
