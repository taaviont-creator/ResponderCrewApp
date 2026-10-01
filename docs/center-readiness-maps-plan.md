# Merevalvekeskuse ja Trossi keskuse kaardivaadete arendusplaan

Kuupäev: 30.09.2026. Allolev dokument kirjeldab algset kavandit. **Arendus on alanud ja keskuste kaardi proovivaade on kohalikus brauseris katsetatav.** Värske teostusseis, avamisjuhend ja operatiivse kasutuse eel vajalik töö: [keskuste kaardivaate katsetamine](center-board-testing.md).

Hilisem teostusseis: kasutaja kinnituse järel alustati veebipõhja ja keskuste ligipääsu etappi. Selle tulemused ning allesjäänud töö on [esimese etapi raportis](center-foundation-progress.md). Allolev analüüs kirjeldab plaani koostamise lähteolukorda.

## 1. Lähtekoht ja otsus

**Kinnitatud täpsustus 30.09.2026:** SAR-i II astme tingimuseks piisab admini määratud liikmelisuse astmest. Tunnistuse kehtivus ei ole täiendav valmiduse tingimus. Admini valmiduskinnitus kehtib kuni muutmiseni; miinimumkoosseisu kadumine muudab tegelikku valmidust automaatselt ja admin saab olemasolevate teavituseelistuste alusel teate. Need otsused asendavad allpool algses plaanis olnud kinnitamist ootavad tähtaja/pädevuse ettepanekud. Andmete arvutusaja värskuse kontroll säilib eraldi.


### Hilisem täpsustus: tavapäraselt üks ühing = üks päästebaas

30.09.2026 kasutaja täpsustuse järgi haldab admin eelkõige oma ühingut, millel on üks kindel baas. Esimese versiooni põhivoog on **Ühingu seaded → Ühingu asukoht kaardil**: admin sisestab päästebaasi tegelikud koordinaadid. Ta ei pea looma eraldi baasi ega reageerivat üksust, nimetama ühingut teist korda ega määrama ühingu liikmeid käsitsi uude nimekirja. Kaardipunkti nimi peab tulema ühingu kehtivast nimest.

See täpsustus asendab allpool kirjeldatud kohustusliku mitme üksuse haldusvoo. Järgnevate etappide vaikimisi valmidusarvutus kasutab ühingu olemasolevaid aktiivseid liikmesusi, efektiivset valvesolekut, pädevusi, ühingu pausi ja sama ühingu sobivat varustust. Ühingu olemasolevaid miinimumkoosseisu ja pausiseadeid ei dubleerita. Üksuse eraldi loomine, liikmete kandidaadiloend ja tähtajaline käsitsi jaotamine ei ole ühe baasiga ühingu töö alustamise eeltingimused.

Andmemudeli laiendusruum mitme iseseisva üksuse jaoks võib säilida, kuid tavakasutajale baaside/üksuste haldust ei kuvata. Mitme baasi erandvoog on võimalik hilisem eraldi vajadus, mitte esimese piloodi nõue. Sama liikme või füüsilise aluse kattumine eri ühingute vahel tuleb ühises valmidusmootoris endiselt lahendada: üks baas ühingus ei kõrvalda multi-org topeltarvestuse ohtu. Ebaselge ressurss ei või muuta kahte ühingut põhjendamatult roheliseks; selle lahendus ei tohi nõuda kõigilt adminidelt igapäevast käsitsi ressursijaotust.

Asukoht salvestatakse olemasoleva `rescueBases` mudeli ühte kirjesse; `commands.primaryRescueBaseId` on serveri hallatav viide. Koordinaate ei kopeerita `commands` dokumenti. Olemasolev ainus baas võetakse kasutusele, mitu varasemat baasi ilma põhiseoseta nõuavad kontrollitud lahendamist. Asukoha salvestamine ei anna keskusele ligipääsu ega kinnita SAR/Tross valmidust. Praegune teostus ja piirid: [ühingu asukoha raport](organization-map-location.md).

Soovitus on laiendada olemasolevat Flutteri rakendust keskuse kontekstiga ning avaldada selle veebiversioon Firebase Hostingus. Telefoniäpp ja brauser kasutavad sama Firebase'i projekti `respondcrew`, sama autentimist ja sama serveris arvutatud üksuse valmidust. Eraldi Reacti/Next.js rakendust ega teist tootmisandmebaasi pole esimeseks versiooniks vaja.

Kaart on **üksuste väljasõiduvalmiduse ülevaade**. See ei ole liikmete jälgimine, navigatsioonikaart, sündmuskohale saabumise prognoos ega väljakutsete juhtimise süsteem. Keskuse kaudu väljakutse saatmine/vastuvõtmine ja marsruudid jäävad järgmisse etappi.

Kontrollitud on kohalik repositoorium `taaviont-creator/ResponderCrewApp`, haru `fix/readiness-controls-and-labels`, HEAD `8af09ad3af952e3982dd6ed07cb74eb39d7ddf5e`, koos enne seda ülesannet olemas olnud kinnitamata kasutajaliidese muudatustega. Kaug-main'i värskust, pilves avaldatud versiooni, pärisandmete kvaliteeti ega tegelikke keskuse lepinguid pole selle ülesande käigus kontrollitud. Varasemad kohalikud muudatused jäävad puutumata.

Tehtud kontroll on koodi ja seadistuste analüüs. Veebi koostamist, brauseri vastuvõtuteste ega uut testiringi ei käivitatud: olemasolevaid failistruktuure ei esitata tõendina valmis veebilahendusest. Allpool on eraldi olemasolev ja kavandatav osa.

## 2. Kontrollitud olemasolev lahendus

Hilisem teostus: [ühingu SAR-i ja Trossi teenuste seadistus](organization-response-settings.md) lisab tavapärase ühe baasiga ühingu jaoks `organizationResponseSettings/{org}`. See asendab selle tavavoo puhul allpool kavandatud eraldi üksuse poliitika halduse; `responseUnits/.../policies` on võimalik tulevane mitme iseseisva üksuse erand, mitte teine paralleelne sama ühingu seadistus. Teenuse alused on olemasoleva varustuse viited, SAR miinimum pärandub senisest seadest. Valmiduse kinnitamine, piirangud ja ühine serveriarvutus jäävad järgmisse etappi.

| Valdkond | Koodist tuvastatud seis | Järeldus keskuste jaoks |
| --- | --- | --- |
| Flutter Web | `web/index.html`, `manifest.json`, ikoonid ja Flutteri bootstrap on olemas. Veebi kirjeldused on veel projekti algmalli omad. | Algstruktuur olemas; käivitamine, paigutus, süvalingid ja brauserikäitumine vajavad kontrolli. |
| Firebase Web | `DefaultFirebaseOptions.web` ja `kIsWeb` haru; `firebase.json` seob veebirakenduse projektiga `respondcrew`. | Sama Firebase on kasutatav. Ei tõenda Authi lubatud domeenide, App Checki ega Hosting saidi hetkeseisu. |
| Avaldamine | `firebase.json` sisaldab Functions/Firestore/Storage konfiguratsiooni, **Hosting plokk puudub**. Kohalik `.firebaserc` puudub. | Hosting siht tuleb teadlikult seadistada; senist saiti ei tohi oletades üle kirjutada. |
| CI | `.github/workflows/mvp-ci.yml`: Flutter analyze/test, Android APK, iOS simulaator, reeglitestid ja Functions testid. Veebikoostamist pole. Functions `lint` skript on hetkel üksnes teade, mitte sisuline lintimine. | Lisada tulevases arenduses veebi kontroll. Praeguses plaaniülesandes CI-d ei muudeta ega käivitata, sest PR töövoog koostaks APK. |
| Sisselogimine | Firebase Auth e-post/parool; `AuthGate` kuulab `authStateChanges` ja suunab kasutaja `HomeScreen` vaatesse. | Säilitada autentimine. Lisada keskuse konteksti valik ka kasutajale, kellel pole ühingu liikmesust. |
| Rollid | `users.systemRole`: `platformAdmin` (legacy `platformOwner`). `memberships/{uid}_{org}`: `member`/`orgAdmin`, aktiivsus ja merepäästeaste. | Keskuse õigusi veel pole. Neid ei lisata ühingu rollide enumisse ega tehta keskuse jaoks libaühingut. |
| Organisatsioon | Põhidokument `commands/{org}`, täiendav `organizationProfiles/{org}`. Pending/approved protsess, organisatsiooni admin, valve peatamine ja audit on olemas. | Taaskasutada. Ühingu heakskiit ei võrdu konkreetse teenuse/üksuse keskusele avaldamise heakskiiduga. |
| SAR-valmidus | `effective-readiness.js`: aktiivsed kanoonilised liikmesused, efektiivselt `onDuty` liikmete arv ≥ seadistatud miinimum, vähemalt üks `seaRescueLevel == level2`, ühing approved ja valve peatamata. | Sobiv olemasolev arvutusmootor, mida laiendada üksusele/teenusele. |
| Hilinemine | `availability.status == delayed` ja `responseMinutes`; hilinejaid loendatakse, kuid nad ei täida praegust SAR miinimumi. | Inimese hilinemine pole veel üksuse kinnitatud kollane väljasõiduvalmidus. |
| Planeeringud | `plannedUnavailability` ja `plannedUnavailabilityRules`; kordused Europe/Tallinn ajas. Aktiivne planeering muudab liikme efektiivselt mittevalves olevaks. | Säilitada serveri ajaloogika, lisada ajapiiride regressioonid. Kordusreegli praegune arvutus eeldab sama päeva algus-/lõpuminuteid; üle südaöö vahemikku ei tohi uues töös vaikselt teisiti tõlgendada. |
| Ühine serveriallikas | `getOrganizationReadinessAvailability` kasutab sama `loadReadiness/evaluateReadiness` arvutust kui muutuste teavitaja. Flutter kuulab `readinessNotificationState` muutusi ja küsib lisaks iga 30 s callable'i. | Hea lähtekoht. Keskuse jaoks ei küsita iga üksuse kogu koosseisu 30 s tagant. |
| Ajastamine | `refreshScheduledReadiness` töötab iga minuti järel; loeb kõik approved ühingud. Andmesündmused katavad liikmesused, staatuse, planeeringud, miinimumi ja organisatsiooni. | Ajapõhine mehhanism juba olemas. Laiendada ja optimeerida; mitte teha teist sõltumatut SAR arvutust. |
| Pädevused | Liikmelisuses on I/II aste; `certificates` sisaldab tüüpi, staatust ja kuupäevi tekstina. Igapäevane 09.00 töö saadab aegumise meeldetuletusi. | **Tunnistuse kehtivus ei mõjuta praegust valmidust.** `seaRescue` tunnistus ei erista ise I/II astet. Vajalik tõendi ja pädevuse seos. |
| Tehnika | `equipment` sisaldab `category=vessel`, seisundeid `ok/needsMaintenance/broken/outOfService`, omanikku, väljastamist, hoolduskuupäeva ja vabatekstilist `location`. | Alused on olemas, kuid puudub seos reageeriva üksuse, päästebaasi ja teenuse nõuetega. |
| Asukohad/kontaktid | Organisatsiooni profiilis piirkond, aadress ja kontaktid; vanas kokkuvõttes piirkond/kontakt. GPS koordinaadid on operatiivlogi kirjetel. | **Päästebaasi ega üksuse struktureeritud mudelit/koordinaate ei leitud.** Organisatsiooni postiaadress ega logi GPS pole päästebaasi asukoht. |
| Tross | `calloutType=sar/tross`; Trossi sündmuse `responseTargetMinutes` 1–60, SAR puhul null. | Sündmuse sihtaeg on olemas. Trossi üksuse iseseisev valmidusarvutus puudub; sündmuse välja ei kasutata üksuse püsiseadistusena. |
| Vana valmiduskokkuvõte | `organizationReadinessSummaries/{org}` hoiab korraga miinimumi, kontakti, tehnika hinnangut ja käsitsi kirjutatavaid valmidusvälju. | Pole sobiv keskuse usaldusväärne koondallikas. Selle seadistused tuleb säilitada ja arvutatud olek sellest lahutada. |

### 2.1 Olulised vastuolud ja piirangud

1. `evaluateReadiness` ei loe `equipment` ega `certificates` kogumeid. Katkine alus või aegunud tunnistus ei muuda seal täna rohelist olekut. Ka vanad `primaryVesselStatus/equipmentStatus` hinnangud ei osale selles arvutuses.
2. `PlatformReadinessService.saveOrganizationSummary` ja `isReadinessSummaryWrite` lubavad aktiivsel ühingu adminil kirjutada ka `readinessStatus`, loendusi ja `minimumCrewMet`. Praegune ühine SAR endpoint ei usalda neid loendusi, kuid keskuse kaart ei tohi hakata vana dokumenti usaldama.
3. `readinessNotificationState.updatedAt` muutub ainult tulemuse sõrmejälje muutumisel. Seda ei saa näidata viimase kontrolli ega inimese valmiduskinnituse ajana.
4. Pädevuse aste ja tunnistus on eraldi allikad. Ainuüksi käsitsi `status=valid` või liikme `level2` ei tõenda aegumata, selle teenuse jaoks sobivat pädevust.
5. `commands` on Firestore reeglites loetav kõigile sisselogitutele. Keskuse eraandmeid ei tohi sinna lisada eeldusel, et need oleksid peidetud. Olemasoleva kataloogi/liitumiskoodi voogu ei muudeta selle plaani koostamisel.
6. Reeglite `isActiveMember` lubab puuduva organisatsiooni staatuse korral legacy `approved` vaikeväärtust, serveriarvutus nõuab sõnaselgelt `approved`. Uus üksus avaldatakse ainult selgelt kinnitatud organisatsioonist; vanad puudulikud dokumendid vajavad ülevaatust.
7. SAR-valmidusnäitaja ja väljakutse loomise õigus pole sama asi. `isCalloutCreate` kontrollib admini/II astme juhtimisõigust ja andmeid, mitte kogu valmidusarvutust. Dokumentatsiooni väljendit „SAR nõuab miinimumi” ei tohi tõlgendada juba olemasolevaks universaalseks väljakutse loomise blokeeringuks. Käesolev kaart ei muuda väljakutsete töövoogu.
8. Ühingu `dutyPaused` on praegu ühinguülene piirang. Esimeses versioonis peatab see mõlemad teenused; teenusepõhine paus lisatakse üksuse piiranguna. Selle käitumise muutmine üksnes SAR pausiks vajab eraldi otsust.

### 2.2 Plaani aluseks olevad failid

- Veeb/käivitus: [pubspec.yaml](../pubspec.yaml), [pubspec.lock](../pubspec.lock), [web/index.html](../web/index.html), [firebase.json](../firebase.json), [firebase_options.dart](../lib/firebase_options.dart), [main.dart](../lib/main.dart), [CI](../.github/workflows/mvp-ci.yml).
- Identiteet/õigused: [auth_gate.dart](../lib/auth/auth_gate.dart), [auth_service.dart](../lib/services/auth_service.dart), [membership_model.dart](../lib/models/membership_model.dart), [command_service.dart](../lib/services/command_service.dart), [organization-management.js](../functions/organization-management.js), [statistics-handlers.js](../functions/statistics-handlers.js), [firestore.rules](../firestore.rules).
- Valmidus: [effective-readiness.js](../functions/effective-readiness.js), [organization-readiness.js](../functions/organization-readiness.js), [readiness-availability.js](../functions/readiness-availability.js), [index.js](../functions/index.js), [readiness_availability_service.dart](../lib/services/readiness_availability_service.dart), [crew_readiness_card.dart](../lib/widgets/crew_readiness_card.dart), [response_readiness.dart](../lib/models/response_readiness.dart), [organization_readiness_screen.dart](../lib/screens/organization_readiness_screen.dart).
- Andmed: [platform_readiness_model.dart](../lib/models/platform_readiness_model.dart), [platform_readiness_service.dart](../lib/services/platform_readiness_service.dart), [equipment_model.dart](../lib/models/equipment_model.dart), [certificate_model.dart](../lib/models/certificate_model.dart), [certificate-reminders.js](../functions/certificate-reminders.js), [organization-profile.js](../functions/organization-profile.js), [callout_model.dart](../lib/models/callout_model.dart).
- Platvormierisused: [callout_alarm_notification_service.dart](../lib/services/callout_alarm_notification_service.dart), [device_token_service.dart](../lib/services/device_token_service.dart), [wakelock_service.dart](../lib/services/wakelock_service.dart), [operation_log_screen.dart](../lib/screens/operation_log_screen.dart), [notification_settings_screen.dart](../lib/screens/notification_settings_screen.dart).
- Senise lahenduse kirjeldus: [telefonitesti paketid 2–3](phone-test-packs-2-3.md), [valmiduse vaated](readiness-views-refinement.md), [SAR/Tross](sar-tross-mobile.md). Vastuolu korral on käesolevas ülevaates eelistatud tegelikku koodi.

## 3. Veebitugi, kasutamine ja avaldamine

### 3.1 Sama projekt, eraldi kontekst

Lisada ülemisse kontekstivalikusse õigustele vastavad kirjed: kasutaja ühingud, „Merevalvekeskus”, „Trossi keskus” ja senine „RespondCrew haldus”. Keskus pole organisatsioon ega aktiivse liikmesuse uus roll. Ühingukonteksti vahetamisel säilib `activeOrganizationId`; keskuse valik ei kirjuta seda fiktiivseks ühingu ID-ks.

`AuthGate` järel peab konteksti lahendaja laadima platvormirolli, oma liikmesused ja enda keskuse grant'id. Ainult keskuse õigusega kasutaja pääseb otse keskusesse ega takerdu „Aktiivne ühing puudub” vaatesse. Mõlema keskuse õigusega inimene saab SAR/Tross vahetada. URL ei anna õigust: vale süvalink kuvab ligipääsu puudumise, mitte ajutiselt võõraid andmeid.

Telefoniäpp saab kasutada **sama kaardikomponenti ja andmeteenust**. Keskuse kontekst on nähtav ainult keskuse õigusega kontole; tavaline liige näeb senist oma ühingu vaadet. Telefonis kasutatakse kaart/nimekiri vahetust ja detailipaneeli alumise lehena, arvutis kõrvuti paneele. Native äppi uue vaate lisamine nõuab hiljem uut äpiversiooni; veebiversiooni uuendus ei nõua APK-d.

### 3.2 Brauseri ühilduvuse tööde tabel

| Komponent | Kontrollitud seis | Kavandatud tegevus / vastuvõtt |
| --- | --- | --- |
| Firebase Core/Auth/Firestore/Functions | FlutterFire veebikonfiguratsioon ja veebipaketid on olemas. | Koostada veeb; kontrollida sisselogimist, väljalogimist, loa kaotamist, CORS-i ja callable'i piirkonda. Keskuse ühiskasutusega arvutis eelistada seansipõhist Authi püsimist. |
| Teavitused | Rakenduse `_supportsClientNotifications` tagastab veebis false. Taustakäitleja registreeritakse `main()` alguses siiski tingimusteta. | Veebi käivitus ei tohi küsida telefoni häireõigusi. Taustaregistreerimine teha platvormipõhiseks. Esimese kaardiversiooni töö ei sõltu veebipushist. |
| `flutter_local_notifications` 22.0.1 | Selle paketi kohaliku pubspec'i ja [versiooni dokumentatsiooni](https://pub.dev/packages/flutter_local_notifications/versions/22.0.1) järgi on veebiteostus olemas. | Paketti ei pea ainuüksi veebi tõttu välja vahetama. Olemasolev rakenduse adapter ei luba veebiteateid; tulevane browser push vajab eraldi õiguse küsimist, service worker'it ja VAPID seadistust. Androidi alarmi garantiisid veebile ei anta. |
| DeviceTokenService | Platvormi nimi on Android/iOS, eraldi web rada puudub. | V1 keskuse kaart ei registreeri mobiilitokenit. Hilisem web tokeni tugi peab kontrollima `kIsWeb` enne OS platvormi, sh Androidi brauseris. |
| Wakelock/teavitusseaded | Kohandatud Android/iOS MethodChannel; wakelock püüab puuduvat pluginit; Androidi seadete nupp on juba piiratud. | Keskuse vaates neid ei käivitata. Veebi une-/taastumisest naastes tehakse värskuse kontroll; brauseriakna avatuna hoidmine pole serveri ajastaja asendus. |
| Geolocator | Olemasolev GPS kasutus on operatiivlogis, mitte baasides. | Kaart ei küsi asukohaluba. Olemasoleva logivaate veebikasutus vajab eraldi HTTPS/loa veateede testi; seda pole keskuse MVP jaoks vaja avada. |
| url_launcher | Telefoni/SMS-i avamine sõltub seadmes olevast rakendusest. | Keskuse kontaktpaneelis alati nähtav number ja „Kopeeri”; `tel:` ainult lisavõimalus. |
| pdf/printing/file_selector/share_plus | Projektis olemas; PDF kasutab baite, `file_selector_web` on lukufailis. `lib/` otsingus otsest `dart:io` importi ei leitud. | Need ei ole tõendatud koostamistakistused. Faili valik, allalaadimine/print ja jagamine vajavad brauseri kasutajatoimingu/popup piirangute teste, kui vastavad olemasolevad vaated veebi kaudu avatakse. Keskus ei saa automaatselt aruannetele ligipääsu. |
| Navigatsioon | Praegu `MaterialApp(home: AuthGate())` ja telefoni navigeerimine. | Lisada sama projekti marsruudilahendus keskuse süvalinkide, reload/back nupu ja õiguste ooteseisundiga. Mitte tuletada õigust ainult URL-ist ega `kIsWeb` väärtusest. |

Täpsed sõltuvusversioonid lukustada arenduse alguse ühilduvuskatse järel. Ei tehta massilist pakettide uuendamist kaardi lisamise kõrval.

### 3.3 Hosting ja aadressid

Soovitus: klassikaline **Firebase Hosting**, mis avaldab Flutteri `build/web` staatilised failid. SSR/App Hosting/eraldi veebiserver pole vajalik. Hosting annab HTTPS-i ning tasuta `web.app`/`firebaseapp.com` alamdomeeni; oma domeen on vabatahtlik. [Firebase Hosting](https://firebase.google.com/docs/hosting).

Kavandatud aadressid, **mitte väide praegu avaldatud saitidest**:

- `https://respondcrew.web.app/keskus/sar`
- `https://respondcrew.web.app/keskus/tross`
- `https://respondcrew.web.app/keskus/sar/uksus/{unitId}`

Enne esimest avaldamist kontrollida olemasolevaid Hosting sihte. Kui vaikimisi sait on teises kasutuses, luua sama Firebase'i projekti eraldi Hosting sait saadaoleva ID-ga, näiteks `respondcrew-keskus`; ülaltoodud teed jäävad samaks. Domeeni ost ega konkreetse site ID saadavus ei blokeeri prototüüpi.

Seadistada SPA rewrite `index.html`-ile, baastee `/`, korrektne Authi lubatud domeenide loend, turvapäised ja paaniserveri CORS. Firebase veebivõti pole serveri saladus; andmeid kaitsevad reeglid. Kaarditeenuse kliendivõti piirata teenusepakkuja võimaluste järgi domeeni/rakenduse ja kvoodiga.

Tulevane CI: eraldi web build/test töö, Hosting preview testandmetega, käsitsi kontrollitud tootmisesse avaldamine. Preview URL üksi pole ligipääsukaitse ning tootmis-Firebase'iga ühendatud preview pole eraldi testikeskkond. Testimiseks kasutada emulaatoreid või eraldi testprojekti; tootmises jääb kõigile sama `respondcrew` andmestik. HTML/bootstrap kontrollitava lühikese vahemäluga; versioon ja uuendusteade nähtavad. Äpi kest võib olla vahemälus, vana operatiivne valmidus ei tohi selle tõttu jääda värskeks.

## 4. Päästebaas, üksus ja ühiskasutusega ressursid

**Ühing** on olemasolev organisatsioon. **Päästebaas** on tegelik füüsiline asukoht. **Üksus** on ühe baasiga seotud iseseisvalt reageeriv koosseis ja tehnika. Ühingul võib olla mitu baasi; baasil mitu üksust; üksusel SAR, Tross või mõlemad teenused.

Koordinaadid sisestab/kinnitab volitatud ühingu kasutaja kaardipunkti või WGS84 laius-/pikkuskraadidena. Salvestada koordinaadi allikas ja kontrollimise aeg. Aadressiotsing võib tulevikus pakkuda kandidaati, kuid ei kinnita automaatselt baasi. Latitude/longitude peavad olema lõplikud arvud lubatud vahemikes; null tähendab puuduvat väärtust, mitte `(0,0)`. Eestist väljas olev sisestus saab kontrollihoiatuse, mitte vaikse ümberpaigutuse Eesti keskpunkti.

Puuduvate või kinnitamata koordinaatidega üksus jääb nimekirja märkega „Päästebaasi asukoht määramata”; teda kaardile ei joonistata. Valmidus ja asukohaandmete kvaliteet on eri tunnused: muidu valmis üksus võib olla nimekirjas roheline, kuid ilma punktita. Samas baasis olevad punktid koondada valitavaks loendiks, mitte nihutada nende tegelikke koordinaate püsivalt.

### 4.1 Ühe ressursi topeltarvestuse vältimine

- Eristada üksuse **võimalikku koosseisu** ja **praegu sellele üksusele eraldatud ressurssi**. Ühingu kõiki valves liikmeid ei loeta automaatselt igasse üksusse.
- Liige võib kuuluda mitme üksuse kandidaatkoosseisu, kuid tema Firebase UID-l saab korraga olla ainult üks aktiivne valmisolekujaotus. See piirang kehtib ka eri ühingute vahel.
- Sama füüsiline alus saab korraga kuuluda ühe reageeriva üksuse aktiivsesse jaotusse. Olemasolevale `equipment` kirjele jäävad seisund ja hooldus; eraldamist hoitakse eraldi serveri hallatavas seoses.
- Jaotuse muutmine on tehing: loetakse ressursi senine jaotus ja revisjon, kontrollitakse õigust, liikmesust/omandit ja aegumist; kirjutatakse uus omanik ja mõlema mõjutatud üksuse ümberarvutuse märge. Paralleelsetest taotlustest üks võidab, teine saab selge konflikti. Konfliktiteade ei avalda võõra ühingu liikmeid.
- Ühingu admin ei saa teise ühingu kehtivat jaotust ühepoolselt üle võtta. Üleminek eeldab senise jaotuse vabastamist või aegumist; liikme enda kinnitatud üksusevahetuse korral kontrollib server mõlemat liikmesust ja lõpetab senise jaotuse samas tehingus. Aluse üleandmine eeldab senise valdaja volitust. Uus valmiduskinnitus ei anna õigust võõrast ressurssi üle võtta.
- Sama paadi võimalikud topeltkirjed eri ühingutes tuleb enne keskusele avaldamist siduda ühe kontrollitud `physicalResourceId`-ga. Registrinumbri vabateksti põhjal automaatselt ei ühendata. Esmase andmesisestuse kontroll peab need duplikaadid üles leidma.
- Ühe üksuse SAR ja Tross on **alternatiivsed teenusevõimekused**, mitte kaks korraga väljuvat meeskonda. Mõlemad rohelised punktid eri teenusevaadetes tähistavad sama ressursikomplekti; ühises koguarvus üksust ei dubleerita. Hilisemas väljakutseetapis broneerib sündmus komplekti tervikuna.
- V1-s ei ehitata automaatset kõige parema meeskonna optimeerijat. Ühing valib oma üksuse ja koosseisu; teenuste valmidus kasutab seda tegelikku eraldust. Jaotuse/kinnituse lõpp ei muuda inimest iseenesest mõne teise üksuse valves liikmeks.

## 5. SAR-i ja Trossi reeglid

### 5.1 Teenuste tingimused

| Tingimus | SAR | Trossi mereabi |
| --- | --- | --- |
| Organisatsioon | Approved, teenus avaldatud, ühing/üksus pole peatatud | Sama |
| Inimesed | Üksuse SAR miinimum; algandmeks olemasolev `minimumCrewRequired` | Eraldi `minimumResponders`, ettepanek vaikimisi 1. **Kahe liikme nõuet ei lisata automaatselt.** |
| Liikme efektiivne staatus | Aktiivne liikmesus, jaotus sellele üksusele, planeering ei välista | Sama; SAR miinimumi puudumine üksi ei blokeeri |
| Pädevus | Vähemalt üks nõuetele vastav II aste; teenuse jaoks kokku lepitud kehtivad tõendid | SAR astmenõue vaikimisi puudub. Aluse juhtimise ja teenuse tegelikud pädevused seadistada eraldi; neid ei oletata puuduvaks ega täidetuks. |
| Alus | Vähemalt üks üksusele eraldatud sobiv kasutatav alus | Sama; üks valves inimene ilma kasutatava aluseta pole valmis |
| Muu varustus | Üksuse poliitikas sõnaselgelt kohustuslikud vahendid | Ainult Trossi jaoks määratud kohustuslikud vahendid |
| Tavapärane väljasõidusiht | `normalDepartureMinutes` üksuse järgi, näiteks 15/30/45/60; sisestatakse üks kord, mitte iga valve algul | Eraldi siht, ettepanek 60 minutit; kinnitatav poliitika |
| Hilinemine | Ainult kinnitatud üksuse realistliku aja ja seotud koosseisuga | Sama; pikem tavapärane siht on lubatud. 60 min jooksul väljuv üksus võib olla Trossi mõttes roheline. |
| Puuduv kohustuslik seadistus | Hall „Tingimused seadistamata” | Sama |

Varem kasutaja öeldud SAR 15/30/45/60 minuti erinevused pole praegu sündmuse seadistus. Kaardil „määratud aja jooksul” väite tegemiseks vajab üksus ühekordset kokkulepitud sihtaega. Seda ei küsita liikme tavalisel staatusevahetusel.

### 5.2 Väljasõidu aeg, viivitus ja kollane olek

Tavapärane `normalDepartureMinutes` tähendab aega aktiveerimisest väljasõiduvalmiduseni. Seda ei nimetata „sündmuskohale jõudmiseks”. `callouts.responseTargetMinutes` jääb konkreetse sündmuse sihiks ja liikme `responseMinutes` liikme hilinemise sisendiks; neid ei ühendata samanimeliseks üldväljaks.

Tähtajaline kinnitatud viivitus sisaldab `expectedReadyAt` absoluutset aega, põhjust, kinnitaja isikut ja kinnituse kehtivust. Näide: „Reageerib viivitusega · väljasõiduvalmidus täna 14.30 · kinnitatud 14.00”. Kõik ajad kuvatakse Europe/Tallinn ajavööndis, kuupäev üle päeva piiri.

Kollase tingimused: volitatud inimene on kinnitanud konkreetse koosseisu ja kasutatava tehnika; puudujääk on ajutine ajapiirang, mille lõpp on teada; ükski kõva nõue pole rikkis. `delayed` liikme võib arvestada ainult tulevase kinnitatud koosseisu hulka ja ainult juhul, kui teadaolevad planeeringud/pädevused/jaotused võimaldavad seda aega. Hilinejate arv või `responseMinutes` üksi kollast ei loo. Katkine alus või aegunud kohustuslik tunnistus jääb punaseks.

`expectedReadyAt` saabumine ei muuda kollast automaatselt roheliseks. Kui tegelik koosseis on selleks ajaks efektiivselt valves ja ülejäänud tingimused kehtivad, saab arvutus roheliseks. Kui lubatud aeg möödub ilma vajaliku tegeliku muutuseta, on olek hall „Väljasõiduvalmidus vajab uut kinnitust”; teadaolev värske kõva takistus kuvatakse lisapõhjusena. Maksimaalne lubatav kinnitatud viivitus on eraldi teenuse poliitika, mitte automaatselt olemasolev sündmuse 60 minuti piir.

### 5.3 Värvid ja prioriteedid

Rakendada tabelit ülevalt alla. Kuva alati tekst/sümbol ning masinloetavad `reasonCodes`, mitte ainult värv.

| Järjekord | Otsus | Kuvamine |
| --- | --- | --- |
| 1 | Keskusel pole teenuse/üksuse õigust või avaldamine lõpetatud | Üksust sellele keskusele ei väljastata. |
| 2 | Arvutuse tervisekontroll aegunud, kohustuslikud sisendid teadmata, kinnitus puudub/aegunud või kinnitatud aja lubadus aegus | **Hall ? Valmidus teadmata**; varasem seis ainult selgelt märgitud ajaloolise infona. Aegunud punastki ei esitata värske hinnanguna. |
| 3 | Värske käsitsi seatud kättesaamatus või ühingu paus | **Punane × Ei saa reageerida**, avaldamiseks sobiv põhjus. Roheline käsitsi kinnitus ei tühista pausi. |
| 4 | Värsked andmed tõendavad koosseisu/pädevuse/tehnika kohustusliku tingimuse puudumist, mida ei kata järgmise rea nõuetekohaselt kinnitatud ajaline viivitus | **Punane × Ei saa reageerida**. Kinnitus ei tohi puuduvat nõuet täidetuks muuta. |
| 5 | Kõvad tingimused on täidetavad kinnitatud tulevaseks ajaks ning kehtib volitatud viivitus | **Kollane kell Reageerib viivitusega**, konkreetne aeg. |
| 6 | Kõik teenuse tingimused täidetud ja väljasõit võimalik tavapärase sihi jooksul | **Roheline ✓ Valmis reageerima**, „väljasõit ≤ N min”. |

Puuduv liikmete laadimistulemus on teadmata, kinnitatud null reageerijat on punane. Puuduv nõutav tunnistus on punane, kaardistamata legacy tunnistuse tähendus hall. Värskuse puudumine ei vabasta piirangut: hallis detailis jääb teadaolev paus/rike nähtavaks viimase teadaoleva faktina. Puuduv koordinaat üksi ei muuda teenuse värvi.

Aluse `broken/outOfService` tähendab kättesaamatut ressurssi, `ok` võimaldab arvestamist muude tingimuste täitumisel. `needsMaintenance` vajab konkreetset teenuse kasutuspiirangut: kinnitatud kasutuskeeld on punane, kontrollitud kasutusluba võib lubada arvestamist, hindamata mõju on hall. Möödunud hoolduskuupäev üksi ei võrdu automaatselt kasutuskeeluga; poliitika peab eristama kohustuslikku kontrolli ja soovituslikku hooldust. Kui üksusel on teine sobiv kasutatav alus, hinnatakse nõutava tehnika olemasolu kogu sellele eraldatud komplektist.

## 6. Andmemudel

Allpool on **kavandatavad** teed/väljad, mitte juba olemasolev skeem. Algallikaid ei kopeerita teiseks iseseisvalt muudetavaks tõeks. Keskuse kokkuvõtted on serveri taastoodetavad, minimaalsed lugemisdokumendid.

| Tee | Põhiväljad ja eesmärk | Kirjutaja |
| --- | --- | --- |
| `commands/{org}` (olemas) | Organisatsiooni nimi/status, `dutyPaused`, `dutyPauseReason`. | Senine kontrollitud organisatsiooni haldus |
| `organizationReadinessSummaries/{org}` (olemas) | Ühingu SAR miinimumi olemasolev vaikeseadistus ja legacy seaded. Arvutatud värvi allikana lõpetada kasutamine. | Ülemineku ajal senine adminiseadistus; uues versioonis valideeritud callable |
| `rescueBases/{baseId}` | `organizationId`, `name`, `address`, `position: GeoPoint|null`, `positionVerifiedAt/By`, `positionSource`, `active`, `revision`. | Ühingu admin, serveriliidese kaudu |
| `responseUnits/{unitId}` | `organizationId`, `baseId`, `name`, `enabledServices: [sar,tross]`, `active`, keskuse jaoks kinnitatud avalik valvekontakt, `revision`. | Ühingu admin, serveriliidese kaudu |
| `responseUnits/{unitId}/policies/{service}` | `normalDepartureMinutes`, `minimumResponders` Trossile või SAR `minimumOverride:null|int`, `requiredQualifications`, `requiredEquipment`, `requiresVessel:true`, `confirmationTtlMinutes`, `maximumDelayMinutes`, `policyVersion`. SAR II astme nõuet ei saa nulliks seadistada. | Admin; keskusega kooskõlastatud kohustuslike piiride sees |
| `unitRoster/{unitId_uid}` | `unitId`, `organizationId`, `userId`, `active`; seos olemasoleva liikmesusega, mitte koopia rollist/pädevusest. | Admin |
| `unitEquipment/{unitId_equipmentId}` | Kandidaattehnika seos, `equipmentId`, vajadusel roll/teenus. Seisund loetakse `equipment` kirjest. | Admin |
| `resourceAllocations/{resourceKey}` | Üks aktiivne jaotus: `unitId`, `organizationId`, `kind`, `resourceId`, `validUntil`, `revision`. Liige: globaalne UID; alus: kontrollitud füüsilise ressursi ID. | Tehinguline serveritoiming |
| `unitOperators/{unitId_uid}` | Valikuline delegeering: valmiduse kinnitamine ja piirangute muutmine, andja/aeg/aegumine. Ei anna adminirolli ega poliitika muutmise õigust. | Ainult ühingu admini serveritoiming |
| `unitServiceState/{unitId_service}` | Piirang `unavailable/delay/none`, avalik `reason`, `expectedReadyAt`, `restrictionUntil`; `confirmedAt/By`, `confirmationValidUntil`, kinnitatud sisendite/poliitika revisjon. | Volitatud ühingu operaatori callable |
| `certificates/{id}` (olemas, laiendus) | Säilitada olemasolevad väljad; lisada vajadusel `qualificationCode`, `seaRescueLevel`, `verificationState`, `verifiedBy/At`, serveri normaliseeritud `validUntil`. Ainult nõuetes viidatud kontrollitud tõend on arvestatav. | Senine adminiõigus, laiendatud valideerimine |
| `equipment/{id}` (olemas, laiendus) | Säilitada seisund/hooldus. Alusele kontrollitud `physicalResourceId`, vajadusel `registrationNumber`, teenuse sobivused ja `operationalRestriction`. | Ühingu varustuse adminiõigus; server valideerib |
| `unitReadiness/{unitId_service}` | Privaatne serveritulemus koos arvestatud koosseisu/tehnika viidetega, põhjuste, loendurite, versiooni ja ajapiiridega. | Ainult server |
| `centers/{centerId}` | Keskuse nimi, lubatud teenused, active; algul üks merevalvekeskus ja üks Trossi keskus. | Platvormihalduri serveritoiming |
| `centerAccess/{uid}/grants/{centerId}` | `services`, `active`, `validUntil`, `grantedBy/At`, `revokedAt`, `revision`. Sõltumatu liikmesustest ja systemRole'ist. | Platvormihalduri serveritoiming |
| `unitPublication/{unitId_centerId_service}` | Ühingu jagamisnõusolek + platvormi/keskuse kokkuleppe kinnitus, `enabled`, `revision`; täpne nähtavuse seos. | Kontrollitud kahepoolne avaldamistoiming |
| `centerViews/{centerId}/services/{service}/units/{unitId}` | Lubatud avaldamise serveriprojektsioon: üksuse/ühingu nimi, kinnitatud baasi punkt või null, teenus, värv/tekst/põhjusekoodid, väljasõidusiht/viivituse aeg, avalik valvekontakt, sobivate aluste lühinfo, vajalikud koondarvud ja värskus. **Pole UID-sid, liikmenimesid, tunnistuse numbreid ega planeeringute põhjuseid.** | Ainult server |
| `readinessDue/{unitId_service}` | `nextEvaluationAt`, lähteversioon, töö rendiaeg/katsete info. | Ainult server |
| `platformAudit/{id}` (olemas) | Õiguse andmine/eemaldamine, üksuse avaldamine, poliitika, kinnituse, piirangu ja jaotuse muutus: mida/kes/millal, enne/pärast vajalikus ulatuses. | Ainult server |

`unitReadiness` ja `centerViews` pole kaks arvutusmootorit: üks arvutus toodab mõlemad sama `calculationId/inputVersion` järgi. Projektsioon on vajalik erineva ligipääsu jaoks; üldloetavasse dokumenti ei panda peidetavaid isikuandmeid, sest Firestore'i lugemisõigus kehtib tervele dokumendile.

Kokkuvõtte ajaväljad: `computedAt`, `sourceChangedAt`, `confirmedAt`, `confirmationValidUntil`, `nextTransitionAt`, `freshUntil`, `calculationVersion`, `calculationId`. `freshUntil` on varaseim teadaolev oluline ajapiir või arvutuse tervise tähtaeg. Avalik `confirmedAt` võib olla nähtav ilma kinnitaja isikuta; kinnitaja UID on privaatandmetes/auditis.

Piirangute põhjused jagada avalikuks lühitekstiks ja vajadusel privaatseks märkuseks. Keskusele ei anta automaatselt senist vabatekstilist `criticalIssues` või `dutyPauseReason` sisu: ühing kinnitab keskusele sobiva põhjuse, et sinna ei satuks liikme tervise- või muid isikuandmeid.

### 6.1 Miinimum, üleminek ja vanad dokumendid

Ühe üksusega ühing pärib vaikimisi praeguse `organizationReadinessSummaries.minimumCrewRequired`; uut paralleelset ühingu miinimumvälja ei tehta. `minimumOverride=null` tähendab pärimist. Mitme iseseisva üksuse puhul saab igale üksusele määrata põhjendatud miinimumi; telefonis kuvatakse üksuse valik, mitte ekslik kõigi üksuste ühine roheline värv.

Ühingu koondvaates näidata näiteks „SAR: 1/2 üksust valmis” ning üksuste read. Liikmete isiklik staatus on endiselt organisatsioonipõhine; üksuse aktiivne ressursside jaotus määrab, kus seda arvestatakse.

Migratsioon on kuivkäigu aruandega ja korratav: luua olemasolevale ühingule esialgne üksus, siduda kontrollitud liikmed/alused, pärida miinimum ja kontakt ainult admini kinnitusega. Koordinaati ei tuletata oletusest; ühtegi uut üksust automaatselt keskustele ei avaldata. `schemaVersion`, idempotentsed ID-d, varukoopia ja migratsioonilogi. Andmeid ei kustutata ega vanu sündmusi ümber kirjutata.

Legacy `equipment.status` puudumine taandub kliendimudelis praegu `ok` väärtuseks ja tunnistuse staatus `valid` väärtuseks. **Uus serverimootor ei kasuta neid ohutuskriitilise rohelise alusena**: toorandmetes puuduv seisund või kehtivus on teadmata. Kategooriata vana varustus jääb Muuks, mitte automaatselt aluseks. Kehtivuskuupäev normaliseerida Europe/Tallinn päeva lõpuni (kehtiv kuni järgmise päeva alguseni), kooskõlas praeguse meeldetuletuse „kuupäev kaasa arvatud” tähendusega; DST testida.

Üleminekul on uue mootoriga pilootüksused ja vanad ühingud selgelt eristatud. Keskustele avaldatakse ainult uue mudeliga kontrollitud üksused. Vana `saveOrganizationSummary` arvutatud väljade kirjutamine lõpetada uutes klientides ja kaitsta uusi kokkuvõtteid server-only reeglitega. Vanade klientide miinimumimuudatus peab üleminekuajal endiselt käivitama uue arvutuse. Enne vana kirjutusõiguse kitsendamist kontrollida kasutusel olevaid äpiversioone.

## 7. Ühine arvutus ja ajastamine

### 7.1 Arvutusahel

Laiendada `effective-readiness.js` puhta deterministliku `evaluateUnitReadiness(service, inputs, now)` funktsiooniga. Taaskasutada efektiivse liikmelisuse, planeeringute ja SAR nõuete olemasolevaid abifunktsioone. Trossil on eraldi poliitika sama mootori sees.

Algandmed → mõjutatud üksuste leidmine → versioonitud sisendite lugemine → SAR/Tross tulemused → `unitReadiness` ja lubatud `centerViews` projektsioonid → telefoni ja keskuse ühine kuvamudel.

Telefoni `ReadinessAvailabilityService` kohandada üksuse kokkuvõtteid lugema; avaliku kokkuvõtte ja oma ühingu privaatse koosseisu päring jäävad eraldi. `ResponseReadiness` lokaalne varuarvutus ei tohi enam näidata uue mootoriga üksust rohelisena, kui serveritulemus puudub. Fallback on hall/laadimisviga, mitte optimistlik roheline. Arvutuskäiku pole põhjust Flutteris teist korda sõltumatult ellu viia.

### 7.2 Käivitajad

| Muutus | Mõju ja töö |
| --- | --- |
| `availability`, liikmesus/aste/aktiivsus | Leia liikme aktiivse jaotuse ja kandidaatseoste mõjutatud üksused; uuenda mõlemad teenused. Organisatsioonidevahelise jaotuse muutus mõjutab vana ja uut üksust. |
| Planeeringu muutmine/tühistamine | Uuenda kohe praegune tulemus ja järgmise alguse/lõpu tähtaeg. Privaatset märkust kokkuvõttesse ei kanta. |
| Planeeringu algus/lõpp ilma kirjutuseta | Minutiline ajastaja loeb saabunud `readinessDue` tööd. |
| Tunnistuse lisamine/muutmine/kehtivuse lõpp | Uuenda mõjutatud liikme/üksuste mõlemad teenused nende poliitika järgi; päevane meeldetuletus jääb eraldi. |
| Koosseis, alus, seadistus, baas | Arvuta mõjutatud üksused; baasi muutus uuendab punkti ja asukoha kontrolli, poliitikamuutus tühistab asjakohase vana kinnituse. |
| Aluse seisund/hooldus/jaotus | Uuenda kõiki sellele alusele viitavaid üksusi; reaalselt eraldamata üksus ei saa seda kasutada. |
| Kinnitus, piirang, paus, avaldamine | Kontrollitud callable teeb muudatuse ja invalideerib/uuendab tulemuse. Õiguste/avaldamise tagasivõtt ei oota tavalise tööjärjekorra kordaminekut. |
| Kinnituse/jaotuse/viivituse aegumine | Tähtajatöö, mis võib muuta oleku halliks või eemaldada arvestatava ressursi. |

Firestore'i sündmused võivad korduda ja saabuda vales järjekorras. Arvutada **värsketest algandmetest**, mitte hilinenud triggeri `after` koopiast; kasutada tehingut/revisjoni ja idempotentset tulemust. Suurema sisendikomplekti puhul lugeda organisatsiooni/üksuse `inputRevision`, arvutada, seejärel võrrelda revisjoni avaldamise tehingus; muutunud revisjoniga tulemust ei avaldata. Mõjutatud üksuste seoseindeks peab arvestama ka eemaldatud vana seost. [Firestore triggerite piirangud](https://firebase.google.com/docs/functions/firestore-events).

### 7.3 Ajastamine ja värskus

Esialgsed teenusetaseme ettepanekud, mitte olemasolevad garantiid:

- Otsene andmemuutus jõuab mõlemasse vaatesse tavaliselt 5–15 sekundiga; piloodi vastuvõtupiir 30 sekundit tervel ühendusel.
- Tähtajad kontrollitakse iga minuti järel, mõõdetav serveri viivitus kuni 90 sekundit normaalolukorras. Täpne sekunditäpsus pole Cloud Scheduleri garantii.
- Iga üksuse arvutuse tervisekontroll vähemalt iga 5 minuti järel; `freshUntil` kuni 10 minutit pärast viimast edukat hindamist, kuid mitte üle planeeringu, pädevuse, jaotuse või kinnituse varasema tähtaja.
- SAR valmiduskinnitus esialgu kuni 12 h, Tross kuni 24 h. Hoiatus 30 min enne lõppu. Need ajad vajavad kasutuskorra kinnitamist.
- Kinnitatud kandidaatkoosseisu, eraldatud tehnika või poliitika sisuline vahetus muudab kinnituse kehtetuks; lihtsalt sama tulemuse uuesti arvutamine **ei pikenda inimese kinnitust**. Kinnituse konfiguratsioonirevisjon on eraldi iga sisendimuutuse `inputVersion`-ist. Liikme tavaline staatusemuutus või planeeringu algus/lõpp ei tühista iseenesest kinnitust: see arvutab kehtiva kinnituse piires rohelise/punase tulemuse uuesti. Vastasel juhul muutuks iga teadaolev puudujääk ekslikult halliks.

Arendada olemasolev `refreshScheduledReadiness` edasi: mitte lugeda kogu riigi kõiki liikmeid igal minutil, vaid päring `nextEvaluationAt <= now`, lehekülgedena. Iga töö lease/retry/backoff, ebaõnnestumise mõõdik, ülemäärase järjekorraviivituse häire. Vähemalt perioodiline tervikvõrdlus parandab vahele jäänud sõltuvusmärgistused. Vajalikud indeksid talletada repositooriumi, mitte ainult konsooli.

Valmiduse callable kasutab praeguses koodis `europe-north1`; Scheduleriga funktsioon on juba `europe-west1`. Firestore'i tegelikku asukohapiirkonda sellest ei järeldata: see tuleb projektist enne juurutamist kontrollida. Säilitada töötav paigutus ja kontrollida piirkonna tuge ning piirkondadevahelise liikluse mõju. [Scheduler piirkonnad](https://docs.cloud.google.com/scheduler/docs/locations).

Ainuüksi timestamp'i aegumine ei käivita Firestore listener'it. Seepärast kasutavad mõlemad kliendid sama väikest **värskuse kuvareeglit**: serveri `freshUntil/confirmationValidUntil` möödumisel ei näidata vana rohelist/kollast, vaid halli, isegi kui tähtajatöö hilineb. See ei arvuta koosseisu uuesti. Server uuendab ka salvestatud staatust. Hoida UI reegel ja serveri aegumise testjuhtumid ühes lepingus; arvestada serverilt saadud aja nihet ja ebausaldusväärset seadmekella. Brauseri taustalt naastes küsida kohe serverit enne värske oleku taastamist.

### 7.4 Koormuse juhtimine

Sama hetke arvutus väljastab ühe väikese dokumendi üksuse/teenuse/keskuse kohta. Nimekirja ei koostata liikme- ega tunnistusepäringutest. Tulemuse muutumise sündmus on eraldi `computedAt` tervisekontrollist: iga taimer ei saada uut pushi ega loo auditit. Heartbeat'i kirjutuse sagedus peab olema arvestatud kuludes; ei kirjutata iga minuti järel sama sisu igale kliendile põhjuseta.

## 8. Õigused ja nähtavus

### 8.1 Õiguste tabel

| Kasutaja | Keskuse kaart | Oma ühingu detail | Kinnitus/piirang | Poliitika/jaotus | Keskuse õiguste andmine |
| --- | --- | --- | --- | --- | --- |
| Tavaline aktiivne liige | Ei, kui eraldi grant puudub | Seniste õiguste järgi | Ei | Ei | Ei |
| II astme liige | Ei, kui grant puudub | Seniste õiguste järgi | Ainult eraldi üksuse delegeeringuga; operatiivlogi kõrgem õigus ei tähenda automaatselt uut õigust | Ei | Ei |
| Ühingu admin | Ainult eraldi keskuse grant'iga | Jah | Oma üksused | Oma üksused kokkulepitud piirides | Ei |
| Merevalvekeskuse töötaja | Oma keskuse lubatud SAR üksused | Ainult eraldi liikmesuse kaudu | Ei | Ei | Ei |
| Trossi keskuse töötaja | Oma keskuse lubatud Tross üksused | Ainult eraldi liikmesuse kaudu | Ei | Ei | Ei |
| Mõlema keskuse grant | Vahetab lubatud keskusi/teenuseid | Liikmesuse järgi | Liikmesuse/delegeeringu järgi | Liikmesuse järgi | Ei |
| Platvormihaldur | Õiguste/avaldamise haldus; operatiivkaart ainult eraldi keskuse grant'iga | Ei saa automaatselt ühingu adminiks | Ei, kui pole vastava ühingu admin/delegeeritud operaator | Ei automaatselt | Jah, auditeeritud serveritoiming |

Keskuse kasutajale ei lisata `systemRole=platformAdmin`. `setCenterAccess` loeb tehingus praegust platvormirolli, kontrollib sihtkasutajat/keskust/teenuseid/aegumist ja kirjutab granti ning auditi. Sama grant võib lubada teenuseid ainult keskuse määratud teenuste piires. Eemaldamine on `active=false` või dokumendi eemaldamine koos auditiga; klient ise granti muuta ei saa.

### 8.2 Kes näeb millist üksust?

Nähtavus ei teki piirkonna, ühingu nime ega pelga `enabledServices` järgi. Vaja on korraga:

1. kasutaja aktiivset granti konkreetsele keskusele ja teenusele;
2. keskuse aktiivset staatust;
3. ühingu kinnitatud jagamisnõusolekut konkreetse üksuse/teenuse kohta;
4. platvormihalduri kontrollitud keskusega liitumise/teenuse kokkulepet;
5. aktiivset üksust ja approved organisatsiooni.

Ühingu admin võib avaldamise lõpetada; platvormihaldur võib selle peatada. Tagasivõtt peab tühistama lugemisõiguse kohe serveris, sõltumata projektsiooni taustatöö õnnestumisest. Avaldamisel kontrollitakse kontaktandmete sobivust ja ressursiseoseid. Puuduvat baasi koordinaati lubatakse kuvada nimekirjas selge hoiatusena.

### 8.3 Firestore ja callable'i jõustamine

- `centerAccess`: klient saab lugeda ainult enda lubade dokumente; kirjutamine ainult serveris. Custom claim võib olla mugav navigeerimise vihje, kuid seda ei kasutata ainsa tühistamiskontrollina: vana ID-token ei tohi õigust säilitada.
- `centerViews`: klient ei saa luua, muuta ega kustutada. Reegel kontrollib request.auth UID granti, `active`, `validUntil > request.time`, keskuse/teenuse teed ja üksuse kehtivat avaldamisõigust. Ilma loata otse-ID päring peab samuti ebaõnnestuma.
- Keskuse listipäring on alati ühe lubatud keskuse/teenuse kollektsioonile. Ei loeta kogu riigi privaatset andmestikku ja filtreerita kliendis. Firestore reeglid **ei ole filtrid**. [Päringute turvareeglid](https://firebase.google.com/docs/firestore/security/rules-query).
- Avaldamise tühistamise callable muudab grant'i ja eemaldab projektsiooni samas tehingus, kui mahu piires võimalik. Reegli sõltuvuskontroll peab keelama ligipääsu ka vanale projektsioonile; organisatsiooni peatamine peab mõjuma samamoodi. Kui piiratud list sisaldab ajutiselt keelatud vana projektsiooni, võib kogu päring saada `permission-denied`: kliendil veateade/andmete eemaldamine, server parandab projektsioonid, mitte kliendis õigustest möödumine. Selle tegelik päringukuju, reeglite get-piirid ja tühistamine kontrollida emulaatoris enne mudeli lukustamist; vajadusel jagada lubatud päringud organisatsioonideks.
- Riigiülese listi teostatav varutee on lehekülgedega `getCenterReadiness` callable: iga päring kontrollib värsket keskuse granti ja avaldamisseoseid serveris ning väljastab samu minimaalseid projektsioone. Seda kasutada V1-s, kui otselugemise reeglite sõltuvuspiirid või päringu tõestatavus ei võimalda turvalist ühtset listener'it. Sel juhul keelata projektsioonide otselugemine kliendile, värskendada nähtavat kaarti näiteks iga 10 sekundi järel ja mõõta §7.3 kogulatentsust; taustal peatada korduspäringud. `UnitReadinessRepository` peidab transpordivaliku, arvutus ja andmemudel jäävad samaks. Turvareegleid ei lõdvendata listener'i saamiseks.
- `unitReadiness` detailset sisemist dokumenti klient otse ei loe. Olemasoleva autoriseeritud valmiduse callable'i laiendus väljastab oma ühingu aktiivsele liikmele sama arvutuse vähendatud liikmevaate koos talle lubatud koosseisuinfoga; tunnistuse tõendid ja piirangu privaatmärkused jäävad vastavate õiguste taha. Keskuse grant ei laienda `memberships/users/certificates/plannedUnavailability` lugemist.
- Kinnitus, piirang, poliitika ja jaotus käivad callable'ide kaudu. Neis kontrollitakse ka Admin SDK kasutamisel kõiki õigusi, sest Admin SDK möödub Security Rules'ist. Identiteet võetakse auth-kontekstist, mitte kliendi `confirmedBy/organizationId/role` väitest. Organisatsiooni viide, teenus, liige ja alus peavad kokku sobima.
- Kontrollid mõlemal create/update teel: lubatud väljade loend, enumid, tüübid, numbrite piirid, teksti pikkus, serveriaeg, muutumatud ID/omanikuväljad, revisjon. Kasutaja ei saa ise pikendada TTL-i üle poliitika, muuta `computedAt` ega anda endale operaatoriõigust.
- Isiklikku telefoni ei kanta keskuse vaatesse automaatselt; ühing määrab töö-/valvenumbri. Keskusel pole selle töö tõttu ligipääsu sündmuse aruandele ega abivajaja andmetele.
- Õiguse kaotamisel katkestada listener'id ja eemaldada andmed mälust/ekraanilt. Ühendusega kliendil granti listener ning serveri keelamine; taustale jäänud leht kontrollib granti enne taastamist. Juba nähtud või kopeeritud andmeid ei saa tagantjärele kustutada kasutaja mälust/seadmest.

### 8.4 Ühendus ja vahemälu

Veebis hoida keskuse tundlikud kokkuvõtted vaikimisi ainult seansi mälus, mitte püsivas offline Firestore cache'is. Firestore veebipüsivus on vaikimisi välja lülitatud ning lubamise korral ei puhastu cache seansside vahel ise. [Offline andmed](https://firebase.google.com/docs/firestore/manage-data/enable-offline).

Eristada „serveriga ühendatud”, „värskust kontrollitakse”, „ühendus puudub”, „õigus eemaldatud” ja „arvutus aegunud”. Kasutada metadata muutusi, serveri kontrollpäringu tulemust ja viimast edukat serverivastust; `navigator.onLine` üksi pole piisav. Näidata eraldi viimase laadimise, serveriarvutuse ja inimese kinnituse aega. Offline olles jääb viimati laaditud nimekiri selgelt ajalooliseks/halliks; valmiduse kinnitamine on keelatud. Kui õiguse värskust ei saa enam kontrollida, peita privaatsed detailid; serveriga taastamisel teha uus autoriseeritud päring. Mobiilikliendis ei tohi keskuse dokumentidele kogemata rakenduda senine püsicache ilma sama seansipoliitikata.

## 9. Kaardilahenduse valik ja kulud

Kontrollitud 30.09.2026 avalikust ametlikust dokumentatsioonist. Pakettide platvormitugi ei tähenda, et nende iga funktsioon töötaks kõigil platvormidel samamoodi.

| Lahendus | Web / Android / iOS | Litsents ja teenus | Hinnang RespondCrew jaoks |
| --- | --- | --- | --- |
| `flutter_map` | Kõik kolm; puhas Flutter, sobib kohandatud markerite ja tavakaardi jaoks | BSD-3-Clause teek. Paanid/andmed eraldi pakkujalt; teek ise API-võtit ei nõua. | **Soovitatud V1**: üks kood, baaside punktid, nimekiri/paneel, lihtne teenusepakkuja vahetus. [Pakett](https://pub.dev/packages/flutter_map). |
| `maplibre_gl` | Android/iOS native MapLibre, veebis MapLibre GL JS | BSD-3-Clause pakett; vektorstiilid/paanid vajavad eraldi andmeallikat/lepingut, pakkuja võib nõuda võtit. | Hea vektor- ja kihirohkele järgmisele etapile; rohkem platvormierisusi. Kontrollitud versiooni README nõuab Androidis JDK 21, praegune CI Android töö kasutab Java 17; web WebGL2. Ei segata eraldi `maplibre` paketi API-ga. [Pakett](https://pub.dev/packages/maplibre_gl). |
| `google_maps_flutter` | Kõik kolm; platform SDK-de võimalused erinevad | BSD-3-Clause wrapper, Google Mapsi andmed/teenus eraldi tingimustel. API-võti, lubatud SDK-d ja arvelduskonto. | Võimalik, kuid V1 baaside ülevaatele pole Google-spetsiifiline teenus vajalik. Veebi Maps JavaScript API hinnastub eraldi native Maps SDK-st. [Pakett](https://pub.dev/packages/google_maps_flutter), [hinnakiri](https://developers.google.com/maps/billing-and-pricing/pricing). |

Soovitus: `flutter_map` + HTTPS rasterpaanide lepinguline teenus, esimene kandidaat **MapTiler Cloud**. OSM-põhisel aluskaardil näidata nõutud OSM/pakkuja autorivi nähtavalt; kui teenus nõuab logo, säilitada see. Paanide vahemälu ja allalaadimine järgivad pakkuja tingimusi. [Flutter Map paanikiht](https://docs.fleaflet.dev/layers/tile-layer), [MapTileri API](https://docs.maptiler.com/cloud/api/reference/).

`tile.openstreetmap.org` avalik teenus pole piiramatu tasuta tootmisteenus: best-effort, SLA puudub, mahuline eelallalaadimine keelatud ning nõutud on identifitseerimine, attribution ja nõuetekohane cache. Seda ei seata operatiivkeskuse garanteeritud kaarditaustaks. [OSM paanide kasutuspoliitika](https://operations.osmfoundation.org/policies/tiles/).

MapTileri kontrollitud hinnakirjas on Free $0 piiratud testimis-/sobiva mitteärilise kasutuse jaoks ning Flex **$30 kuus + lisaliiklus**. Kolmanda osapoole SDK rasterpaanid arvestatakse päringutena; 512px renderdatud paan loetakse hinnakirjas neljaks päringuks. Tasuta kaardikomponendi olemasolu ei tee paane tasuta. Organisatsiooni kasutusviisi sobivus, kvoot ja vajadus SLA järele kinnitada enne tootmist; hinnad võivad muutuda. [MapTileri hinnakiri](https://www.maptiler.com/cloud/pricing/).

Google'i võrdlus: Dynamic Mapsi hinnakirjas 10 000 tasuta kuus, järgmises astmes $7 / 1000 laadimist; native Maps SDK on samas hinnakirjas eraldi Unlimited tasuta rea all. Sellest ei järeldu, et kõik Google'i API-d oleks tasuta. Näiteks 20 000 veebikaardi laadimist annaks selle astme järgi ligikaudu $70 enne makse/muid teenuseid. [Google'i hinnakiri](https://developers.google.com/maps/billing-and-pricing/pricing).

MapTileri kliendivõti on brauseris nähtav; piirata lubatud origin'eid ja kvoote, kasutada native jaoks eraldi piirangutega võtit ning vaadata tegelikku mobiilipaketi toetust. Serveri haldusvõtmeid kliendile ei anta. Kaardipakkujale lähevad taustapaanide päringud ja võrgu tavainfo, mitte RespondCrew meeskonnaloendid/valmidusdokumendid; operatiivmarkerid joonistatakse kliendis Firebase'i andmetest. [API võtme piiramine](https://docs.maptiler.com/guides/credentials/api-key/).

### 9.1 Firebase'i koormuse ja eelarve ettepanek

Kulud: Hosting ülekanne/salvestus, Firestore lugemised/kirjutused/indeksid, Functions tööaeg/kutsed, Scheduler, audit/säilitus, kaardipaanid. Oma domeeni kulu on vabatahtlik. Kasutada olemasolevat Blaze projekti, kuid praeguse arveldusplaani olekut ei kontrollitud selle ülesande käigus. Kehtivad hinnad/kvoodid võtta [Firebase hinnakirjast](https://firebase.google.com/pricing), mitte vana fikseeritud „tasuta” eeldusest.

Planeerimisnäide, mitte mõõdetud RespondCrew koormus: 100 üksust × 2 teenust × 10 nähtavat seanssi = kuni 2000 algdokumendi lugemist kõigi kaartide avamisel. Kui 200 kokkuvõtet muudetaks iga minuti järel, tekiks 288 000 kirjutust päevas enne keskuse koopiaid ja kliendilugemisi. 5-minutiline heartbeat annab 57 600 kirjutust päevas enne projektsioone. Seetõttu tuleb tähtaegade järjekorda, muutusepõhist avaldamist ja heartbeat'i kulusid mõõta, mitte võtta tasuta mahu sisse mahtumist eelduseks. Reeglite täiendavad sõltuvuslugemised lisanduvad.

Piloodiks kavandada esialgne operatiivkuluvaru **50–150 eurot kuus** (planeerimise eelarve, mitte teenusepakkuja pakkumine; tööjõud ja maksud eraldi). Enne tootmisotsust mõõta päris keskuste seansside/üksuste arv, paanipäringud ja Firestore koormus; vajadusel korrigeerida. Panna kuluteavitused ja tehnilised päringupiirid. Eelarvehoiatus üksi ei peata kulusid. Paaniteenuse katkestus ei tohi võtta ära üksuste nimekirja ja telefonikontakte; näidata „Kaarditaust ei laadinud”.

## 10. Keskuse vaate paigutuskavand

Järgmine on ekraani struktuur, mitte uus kinnitatud visuaalne disain ega tegelike baaside kaart.

```text
┌ RespondCrew · Merevalvekeskus [vaheta konteksti] ─ Kasutaja ─ Välju ┐
│ SAR [Tross ainult vastava õigusega]   ● Ühendatud · laaditud 14.02  │
├───────────────────┬─────────────────────────┬─────────────────────┤
│ Otsi üksust/baasi │                         │ Valitud üksus       │
│ Piirkond, staatus │     EESTI KAART         │ Ühing · päästebaas  │
│ 42 üksust        │                         │ ✓ Valmis reageerima │
│                  │ kinnitatud baaside      │ Väljasõit ≤ 15 min  │
│ ✓ Baas A üksus   │ markerid/klastrid       │ Koosseis 3/3        │
│ kell Baas B      │                         │ Pädevused täidetud  │
│ × Baas C         │                         │ Alus · kasutatav    │
│ ? Baas D         │                         │ Valvekontakt        │
│ Asukoht puudu: 2 │                         │ Kinnitatud 12.00    │
│                  │                         │ Kehtib kuni 00.00   │
├───────────────────┴─────────────────────────┴─────────────────────┤
│ ✓ roheline valmis · kell kollane viivitus · × punane ei saa · ? hall│
│ Arvutus 14.02 · järgmine teadaolev muutus 14.30 · kaardi autorivi   │
└───────────────────────────────────────────────────────────────────┘
```

Nimekirja ja markerite valik sünkroonis; otsing nime/ühingu/baasi järgi. Filtrid: teenus vastavalt õigusele, staatus, piirkond, asukoht puudu. Hall ja puuduvad asukohad ei kao vaikimisi ära. Tühjas tulemuses eristada „Filtrile vastavaid üksusi pole” ja „Andmeid ei õnnestunud laadida”. Detailis näidata põhjuseid, mitte tundlikke liikmete algandmeid.

Arvutis 3 veergu, kitsamal ekraanil kaart+nimekiri vahetamine ja avanev detail. Klaviatuuriga kasutatav nimekiri, tekstiline staatus/ikoon, suurendatud teksti tugi, telefonis vähemalt 48 px tegevuste puutealad. Kaart ei täida kogu kasutajaliidese funktsiooni: ka ilma paanita saab üksust leida. Koordinaadita üksuse valimine ei liiguta kaamerat oletuslikku kohta.

## 11. Järjestatud arendusetapid

Töömaht on esialgne ühe arendaja hinnang: **28–43 arenduspäeva**, lisaks keskuste otsused ja pärisandmete kinnitamine. Etapid on sõltuvuses; hinnang eeldab olemasoleva Firebase/Flutter ülesehituse säilitamist, mitte kogu rakenduse ümberkujundamist.

| Etapp | Töö / peamised failid | Valmimise tingimus | Hinnang |
| --- | --- | --- | --- |
| 0. Reeglite ja sisendite kokkulepe | Kinnitada §13 otsused, baaside/üksuste inventuur, pädevusmaatriks, piloodi kaks teenust | Iga pilootüksuse tegelik koosseis, alus, baas, teenuse siht ja kontakt on tuvastatud; küsimustele vastutajad määratud | 2–3 p |
| 1. Veebi tehniline katse | `main.dart`, AuthGate, router/kontekst, `web/`, Firebase seadistus, platvormiadapterid; Hosting emulaator | Praegune äpp koostub web release'ina; keskuse tühivaade avaneb brauseris sisselogimise järel, reload/back töötab, ei küsita GPS/alarmi õigusi; uut APK-d ei nõuta | 2–3 p |
| 2. Keskuse õigused | Uued grant'id, haldus `platform_management_screen.dart` kaudu, callable'id ja Firestore reeglid, audit | Eri teenustega testkontod, mõlemad õigused, ühinguta konto ja eemaldamine läbivad serveri/reeglite testid | 3–4 p |
| 3. Ühingu asukoht ja sisendandmed | Koordinaadid ühingu seadetes, üks põhiseos, olemasoleva liikmesuse/varustuse kasutamine; pädevuste ja aluse identiteedi sidumine | Ühe baasiga ühing saab alustada eraldi üksust loomata; kordussalvestus ei loo teist baasi; puuduv koordinaat jääb puuduvaks; kattuvate ressursside kaitse | 4–6 p |
| 4. Ühine valmidusmootor | `effective-readiness.js`, ajastaja/index.js, tähtajad, projektsioonid, `ReadinessAvailabilityService`, `CrewReadinessCard` | SAR/Tross sama üksuse eri tulemused; kinnitus/viivitus/sertifikaat/tehnika mõjutavad mõlemat klienti ühtemoodi; tähtaegade tõrkekindlus | 6–9 p |
| 5. Kaart ja nimekiri | `CenterMapScreen`, `UnitReadinessRepository`, detail/legend/otsing/filter, `flutter_map` adapter, paanipakkuja seadistus | Eesti kaart tegelike testbaasidega, koordinaadita üksus ainult nimekirjas; arvuti/telefon/klaviatuur; nimekiri töötab paanirikke korral | 4–6 p |
| 6. Migratsioon ja kooskõla | Ühingu põhiseose üleminek, legacy kirjutuste üleminek, granti tagasivõtt, offline/värskus, mõõdikud | Telefon/keskus sama calculationId ja värv; vanad dokumendid ei crash'i; ühe baasiga ühingul puudub tarbetu üksusevalik; vana klient ei saa uut valmisolekut võltsida | 3–5 p |
| 7. Piloot ja avaldamise ettevalmistus | Reegli-/Functions-/Flutter-/brauseritestid, koormusmõõtmine, web CI, Hosting preview ja tagasipöörde juhis | Allolev maatriks roheline; ühing ja mõlemad keskused kontrollivad piloodi üle; tootmisesse mineku otsus eraldi | 4–7 p |

Uued kavandatud failid koondada seniste `lib/models`, `lib/services`, `lib/screens`, `lib/widgets`, `functions`, `test`, `rules-tests` alla. Olemasolevat õiguste/valmiduse koodi laiendada, mitte luua eraldi veebipõhist äriloogikat. Lisada indeksite fail ja sidumine `firebase.json`-i; tootmisprojekti ID anda juurutamisel selgesõnaliselt.

Tagasipööre: keskuse grant'id/avaldamine välja, veebiversioon eelmisele Hosting versioonile, uus arvutus ainult piloodile. Algandmeid ei kustutata. Kui uus mootor on olnud telefonis aktiivne, ei tohi tagasipööre muuta puudulikku üksust vana lihtsustatud arvutusega põhjendamatult roheliseks: keskuse funktsioon jääb välja, liikmete algstaatused ja senine töövoog säilivad.

## 12. Vastuvõtutestid

| Juhtum | Oodatav tulemus | Kontrollikiht |
| --- | --- | --- |
| Üksusel 1 sobiv reageerija ja alus, SAR miinimum 3/II aste puudu | SAR punane, Tross poliitika täitmisel roheline; üks Trossi reageerija ei lähe automaatselt SAR koosseisu | Functions + ühine UI |
| Hilineja olemas, üksuse kinnitus puudub | Kollast ei teki; puuduv kinnitus annab halli. Kehtiva kinnituse ja ebapiisava, kinnitatud viivituseta koosseisu korral punane | Puhta mootori test |
| Kinnitatud realistlik koosseis ja tulevane väljasõiduaeg | Kollane, täpne aeg; katkine alus või aegunud tõend blokeerib kollase | Functions |
| Hilinemise lubatud aeg saabub ilma uue tegeliku valmisolekuta | Hall „Vajab kinnitust”, mitte automaatne roheline | Võltsitud kell + UI |
| Liige muudab staatust | Mõjutatud üksuse telefon ja lubatud keskused saavad sama calculationId; piloodis ≤30 s | Integratsioon |
| Planeering algab/lõpeb dokumenti muutmata | Koosseis ja valmidus uuenevad; server tavatingimustes ≤90 s, UI värskusvalvur ei jäta aegunud rohelist | Scheduler/clock tests |
| Kordus, nädalapiir, Tallinna suve-/talveaeg | Server ja telefoni ajavaade nõustuvad; pole topelt- ega vahelejäänud ajavahemikku | Functions/Dart regressioon |
| Kohustuslik pädevus aegub | Mõjutab õiget teenust/üksust tähtaja järgi; päevast meeldetuletust ei oodata | Functions |
| Alus broken/outOfService, missing status või needsMaintenance | Rike punane, teadmata seisund hall, hooldus sõltub kinnitatud piirangust; teine sõltumatu üksus ei muutu | Functions |
| Üks liige/paat määratakse paralleelselt kahte üksusse | Üks tehing õnnestub; teine konflikt. Sama kasutaja kahes ühingus ei ole kaks ressurssi | Tehingu-/integratsioonitest |
| Kinnitus aegub, ajastaja seisab | UI hall tähtajal, server salvestab taastudes halli; computedAt uuendamine ei pikenda confirmedAt kehtivust | Tõrketest |
| Koordinaat null/vale/vahetatud | Üksus loendis selge veaga, kaardil puudub. Sama baasi mitu üksust on eraldi valitavad | Mudeli-/widgetitest |
| Ainult SAR grant, otse Trossi URL/doc-ID | Keeld nii serveris kui UI-s; lubatud üksuste hulka ei laiendata | Reeglid/callable/brauser |
| Tavaline liige või platformAdmin ilma keskuse grant'ita | Keskuse operatiivandmed keelatud; oma senised õigused töötavad | Reeglid |
| Ühinguta keskuse kasutaja / mõlema keskuse kasutaja | Sisselogimine ja kontekstivahetus töötavad, ühingu roll ei muutu | Brauser/widget |
| Granti/üksuse avaldamise eemaldamine avatud vaate ajal | Uus read/list/callable kohe keelatud; ühendusega vaade puhastub ja listener lõpeb. Aegunud token ei aita | Emulaator + integratsioon |
| Klient kirjutab computedAt/status/loenduse või enda granti | Create ja update mõlemad keelatud; ei saa muuta teise ühingu üksust ega kinnitada tema valmidust | Negatiivsed reeglitestid |
| Keskus küsib liikmeid/tunnistusi/planeeringute põhjuseid | Keeld; kokkuvõttes on ainult heakskiidetud väljad | Reeglid + projektsiooni skeemitest |
| Võrk kaob / brauser ärkab unest / seadmekell vale | Ühenduse seis ja viimase serverilaadimise aeg nähtavad; vana tulemus ei paista värske; uus kontroll enne taastamist | Brauseri tõrketest |
| Kaardipaanid 429/403/katkestus | Nimekiri, staatusetekstid ja kontakt säilivad; arusaadav kaarditausta viga | Brauser |
| Trigger kordub/saabub hilja/ümberarvutus katkeb | Vana seis ei kirjuta uut üle; audit/teavitus ei dubleeru; retry taastab | Functions |
| Legacy dokumendid / migratsiooni teine käivitus | Null/puuduvad väljad ei crash'i ega anna tõendamata rohelist; uusi baase/üksusi topelt ei teki | Migratsioonitest |

Arenduse lõpus: `flutter analyze`, kõik Flutter testid, uued puhta mootori/ajastaja/ressursitehingute testid, Firestore reeglite emulaatoritestid, `node --check` ja Functions testid, `flutter build web --release`, Chrome/Edge ning Safari/Firefox põhivoo kontroll. Kui Functions lint jääb seniseks tühjaks skriptiks, ei nimetata seda sisuliselt läbitud lintimiseks. Androidi/iOS-i ühiskomponentide regressioon kontrollida ilma APK avaldamiseta; kasutaja senise juhise järgi APK koostamine toimub alles eraldi kokkulepitud lõpus.

Koormuskatse vähemalt kavandatud piloodi 2× üksuste/avatud keskusevaadete arvuga, Scheduler backlog ja katkestuse taastumine. Väljastusvärava nõue: ühtegi teadaolevat õiguste ületamist ega värskuse puudumisel rohelist kuvamist ei jää avatuks.

## 13. Ainult kinnitamist vajavad ärilised valikud

Neid vastuseid koodis ega senistes nõuetes pole; need ei takista plaani valmimist, kuid mõjutavad arenduse etappe 0/3/4.

1. **Pädevusmaatriks:** millised kehtivad tunnistused on SAR-i ja Trossi puhul kohustuslikud ning kellel (nt II aste, aluse juht, raadio)? Kes kinnitab olemasoleva tunnistuse seose pädevusega? Ettepanek: ühingu admin kinnitab tõendid, keskusega kooskõlastatud teenusepoliitika määrab nõuded.
2. **Trossi ja viivituse poliitika:** kas võtta lähteks vähemalt 1 sobiv reageerija + kasutatav alus, tavapärane väljasõidusiht 60 min; milline on kummagi teenuse maksimaalne kinnitatud viivitus? SAR üksuse tavasiht tuleb teada 15/30/45/60 minuti valikuna, ilma igal valvesse märkimisel küsimata.
3. **Kinnituse kehtivus:** kas SAR 12 h, Tross 24 h ja 30 min eelhoiatus sobivad või peab see järgima keskuse vahetuse pikkust? Ettepanek: admin või tema eraldi määratud üksuse operaator kinnitab, II aste üksi uut haldusõigust ei anna.
4. **Avaldamine ja piloot:** kes kinnitab keskuse nimel ühingu teenusesse lubamise ning milliste ühingute ja kasutajakontodega alustame? Ettepanek: ühingu nõusolek + platvormihalduri kontrollitud keskuse kokkulepe; alustuseks ühe baasiga ühingud. Kahe üksusega ühing pole piloodi eeltingimus.
5. **Kaarditeenuse eelarve ja käideldavus:** kas MapTileri tasuline piloot ning esialgne 50–150 €/kuu operatiivkuluvaru on sobiv; kas keskus nõuab lepingulist SLA-d? Ühtegi kontot, tasulist lepingut ega tellimust selle plaaniga ei looda.

## 14. Piiratud õiguste auditi hinnang

Järgmine JSON käsitleb ainult olemasoleva mudeli sobivust kavandatavale keskuse vaatele, mitte kogu RespondCrew turvasertifitseerimist. Vana käsitsi kokkuvõtte usaldamine oleks uue kaardi puhul viga; see ei tähenda, et praegune `evaluateReadiness` seda usaldab.

```json
{
  "score": 3,
  "summary": "Olemasolev organisatsioonipõhine ligipääs on lähtekoht, kuid keskuse õigused ja teenusepõhised privaatsed projektsioonid puuduvad. Vanad kokkuvõtted ei sobi muutmata kujul keskuse kaardi allikaks.",
  "findings": [
    {
      "check": "Authority Source / Update Bypass",
      "severity": "major",
      "issue": "organizationReadinessSummaries create ja update lubavad ühingu adminil kirjutada valmidusolekut ja loendusi; need pole serveri tõendatud valmidus.",
      "recommendation": "Säilitada vajalik seadistus, kuid kirjutada uued üksuse/teenuse kokkuvõtted ainult serverist. Kaart ei loe vana readinessStatus välja."
    },
    {
      "check": "Field-Level vs Identity-Level Security",
      "severity": "moderate",
      "issue": "commands on kõigile sisselogitutele loetav ning Firestore ei peida sama dokumendi üksikuid privaatvälju.",
      "recommendation": "Hoida keskuse kontaktid, õigused ja privaatne koosseis eraldi; väljasta ainult lubatud keskuse projektsioon."
    },
    {
      "check": "Business Logic vs Rules / Type Safety",
      "severity": "moderate",
      "issue": "Praegune arvutus ei kontrolli aluse ega tunnistuse kehtivust; legacy mudelite vaikimisi ok/valid väärtused võivad uue kaardi jaoks olla eksitavad.",
      "recommendation": "Uue mootori toorsisendite valideerimine, teadmata olek, kontrollitud pädevusseosed ja ajapõhised testid."
    },
    {
      "check": "Storage Abuse / Type Safety",
      "severity": "minor",
      "issue": "Vana valmiduskokkuvõtte valideerimine kasutab hasAll ja ei piira kõigi kontakt-/põhjustekstide pikkust ega kõiki lisavälju.",
      "recommendation": "Uutel kirjutusliidestel hasOnly/allowlist, pikkuse- ja massiivipiirid, tüübikontrollid, muutumatud viited ning sama kontroll create/update teel."
    }
  ]
}
```

## 15. Selle ülesande tulemus ja järgmisse etappi jääv töö

Valmis on repositooriumi kontrollil põhinev arendusplaan, andme- ja õiguste mudel, reeglite prioriteedid, staatuse/värskuse lahendus, kaarditeegi võrdlus, paigutuskavand ning teostatavad etapid ja vastuvõtutestid. Rakenduse, Functions'i, turvareeglite, CI ega pilve funktsionaalsust selle ülesande käigus ei muudetud. Dokumenti ei esitata tõendina uute funktsioonide läbitud testidest.

Järgmisesse funktsionaalsesse etappi jäävad keskuse väljakutsete saatmine/vastuvõtmine, sündmuse ressursibroneeringud, sõidu-/saabumisaja arvutus, veebipush ja suurem vektor-/merekaardikihtide lahendus. Need ei ole käesoleva V1 vastuvõtu eeltingimused.
