# RespondCrew: töökindluse ja väljalaske ülevaatus

Kuupäev: 01.10.2026. Kontrollitud baas: main `0e1c35f` (PR #36); jätkutöö allpool.
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
| Enne keskuse laiemat kasutust | Tootmismahu koormuskatse | 25 ühingu piirang eemaldatud ja 54 ühinguga kontroll läbib. Valmidus arvutatakse iga lehekülje päringus; suurte koosseisude ja samaaegsete keskusekasutajate koormus vajab eraldi mõõtmist. |
| Enne keskuse operatiivset kasutust | Kaardipaanide teenus ja püsiv veebiaadress | Püsiv katseaadress on `https://respondcrew-katse.web.app` (eraldi Hosting sait). OSM standardpaanide asemel tuleb operatiivse kasutuse jaoks valida mahule ja töökindlusnõuetele sobiv teenus; tasulist lepingut pole automaatselt sõlmitud. Oma domeen ei ole kohustuslik. |
| Lõppkatse | Tegelik e-kirja ja telefoni push'i kättesaamine | SMTP/FCM serveri vastuvõtt ja seadistus on olemas. Kontrollida testsaajaga tegelik saabumine ning logi vead; ei saadeta proovihäireid pärisliikmetele ilma kokkuleppeta. |

Vanade `commandId` väljade ühilduvuskihti ei eemaldata: kasutuses võib olla vanu dokumente. Keskusest väljakutsete saatmine, vastuvõtmine ning sündmuskohale saabumise aja arvutus jäävad kokkulepitud järgmisse arendusetappi, mitte käesoleva paranduse varjatud lisafunktsiooniks.

## Kontrollid ja avaldamise seis

Uued regressioonid kontrollivad sisestuse ja vaate säilimist, õiguse eemaldamise jätkuvat jõustamist, vigase kaardivastuse atomaarset käsitlust ning teavituse püsimist kordusarvutuse järel ja aegunud hoiatuse kadumist tegelikul taastumisel. Kohalik lõppkontroll: `flutter analyze` 0 probleemi; 173 Flutteri testi, 93 Functions’i testi ja 119 Firestore/Storage’i ning serveri töövoogude testi läbivad. Security Rules ja õigused ei muutunud. APK-d ei koostata. GitHubi CI ja pilve avaldamise tulemust kontrollitakse eraldi enne üleandmist; kohalikku kontrolli ei esitata pilve avaldamise tõendina.


## Jätkutöö: navigeerimine, mahupiirid ja püsiv katseveeb

- Aruande ja ühingu teenuste/kontakti seadete lahkumiskaitse on ühendatud alumise menüü, ühingu vahetamise, töökeskkonna vahetamise, rakenduses tagasiliikumise, väljalogimise ja väljakutseteavitusega. Valikud: salvesta ja jätka, lahku salvestamata, jätka täitmist. Salvestusviga jätab vormi avatuks. Kui väljakutse avamine katkestatakse vormi täitmise jätkamiseks, jääb samasse ühinguvaatesse nupp täpse väljakutse avamiseks. Sisselogimis-/ligipääsuõiguse kaotus ei jää vormi taha kinni. Kaitse ei ole automaatne mustandi varundus ega kaitse brauseri täieliku sulgemise/värskendamise eest.
- Kaardipäring loeb ainult soovitud ja kinnitatud jagamisi. Serveri lehekülg on kuni 100 kirjet, rakendus kasutab kaardil 25 ning halduse taotlustes 50 kirjet. Dokumendi ID kursor väldib nihkepõhist lehekülgede lugemist. Kaart avaldab koondvastuse alles pärast kõigi lehekülgede edukat laadimist; rike ei näita poolikut loendit täielikuna. Keskuseõigust kontrollitakse igal leheküljel. Kaardilaadimisel säilib 40 sekundi tähtaeg; hilinenud vastus ei algata järgmisi lehekülgi.
- Platvormihalduri taotluste 100 kirje piirang eemaldatud; 107 kirjet loetakse kolmel leheküljel. Vana klient saab üle 100 kirje puhul selge uuendamisvea, mitte vaikimisi pooliku loendi.
- Firestore'i andmemudel, Security Rules ja ärireeglid ei muutu. Vastustele lisandub `nextCursor`; puuduv kursor tähendab viimast lehekülge. Olemasolevad kliendid töötavad väikese loendiga edasi. Andmemigratsiooni ei ole. Päring kontrollitud päris Standard-edition Firestore'is; täiendavat indeksit polnud vaja.
- `functions/eslint.config.cjs` kasutab ESLinti soovituslikku veakontrolli CommonJS/Node keskkonnas. Senine teateskript on asendatud käsuga `eslint . --max-warnings 0`; olemasolev CI käivitab selle. Eemaldatud kaks kasutamata importi. Kolmel tahtlikul juhtmärkide filtreerimise regulaaravaldisel on selgitusega ühe rea erand; filtreerimise turvakäitumist ei muudeta. Seadistuse alus: [ESLint configuration](https://eslint.org/docs/latest/use/configure/configuration-files).
- Püsivale katseveebile on eraldi `firebase.katse.json`, saidiga `respondcrew-katse`. Põhisaidi live-versiooni ei asendata. Ajutise lingi jaoks jääb alles `firebase.web.json`. Uue domeeni brauserisalvestus on eraldi, mistõttu sinna esmakordsel sisenemisel tuleb uuesti sisse logida.

Kontrollid: `flutter analyze` 0 probleemi; kõik **185 Flutteri**, **93 Functions'i**, **120 Firestore/Storage'i ja serverivoogude testi** läbivad; ESLint 0 viga/hoiatust. Uued regressioonid katavad vormi salvestamise/loobumise/vea, konkureeriva navigeerimise, töökeskkonna marsruudid, 54 kaardikirjet, 107 halduse jagamistaotlust, osalise vastuse vältimise ja ligipääsu eemaldamise lehekülgede vahel. Veebikoost läbis. Mõlemad kaardipäringufunktsioonid olid 01.10.2026 18:24 UTC järel ACTIVE; püsiva ja vana katseveebi põhifailide SHA-256 vastavus kontrollitud. Brauseris kontrollitud uus sisselogimisleht ning olemasoleva sessiooniga SAR 3/3 + II aste 1, Tross 3/2 ja kaardipunkt. APK-d selles töös ei koostata.

### Avaldamise kord

1. `flutter build web --release --no-web-resources-cdn` ja olemasolevad veebi kontrollskriptid.
2. `firebase deploy --project respondcrew --only functions:getCenterReadinessBoard,functions:getCenterSharingRequests`.
3. `firebase deploy --config firebase.katse.json --project respondcrew --only hosting` püsiva katseveebi jaoks.
4. Vajadusel vana lingi värskendamine: `firebase hosting:channel:deploy keskused-katse --config firebase.web.json --project respondcrew --expires 30d`.
5. Kontrollida Functions'i ACTIVE-olekut, avaldatud failide räside vastavust ning sisselogimisvaadet. Päriskonto kontroll tehakse kasutaja olemasoleva sessiooniga; paroole ei kirjutata lähtekoodi ega logidesse.


### Sõltuvuste kontroll

Serveri käitusaegsete sõltuvuste kontroll leidis 13 teadet (1 kõrge, 12 mõõdukat). Ühilduvad parandused lisati lukufaili ilma otseste sõltuvuste põhiversioone muutmata: gRPC, body-parser, qs, protobufjs ja uuid uuem ühilduv alamversioon. Pärast parandust on kõrgeid/kriitilisi teateid 0; alles on 8 mõõdukat sõltuvusahela teadet, mille alus on `uuid <11.1.1` v3/v5/v6 puhvripiiride probleem (GHSA-w5hq-g745-h8pq). npm soovitab täielikuks lahenduseks Firebase Admin 14 põhiversiooni. Seda ei rakendata jõuga ega kirjutata ühildumatut `overrides` reeglit. Vajalik on eraldi Firebase Admin/Google Cloud SDK ühilduvusring; käesolev kontroll ei võrdu kõigi võimalike turvaprobleemide puudumise kinnitusega.

Lukufaili turvaparanduste rakendamiseks tuleb uuendada olemasolevad selle repo Cloud Functions'id, mitte ainult kaks muudetud kaardipäringut. Avaldamisel võrreldakse repo eksporditud funktsioone projekti olemasoleva loendiga; võõraid funktsioone ei kustutata. SMTP/FCM prooviteateid pärisliikmetele ei saadeta.
