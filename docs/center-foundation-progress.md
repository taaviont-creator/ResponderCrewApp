# Keskuste veebipõhi: esimene teostusetapp

30.09.2026. Alus: [keskuste arendusplaan](center-readiness-maps-plan.md).

Järgnev teostusetapp: [päästebaasid, üksused ja ressursside jaotus](response-units-progress.md).

## Valmis kohalikus koodis

- Sama Flutteri rakenduse URL-põhine navigeerimine: `/`, `/uhingud`, `/keskus/sar`, `/keskus/tross`. Veebis kasutatakse puhast aadressiteed, mobiilis sama vaatekomponenti.
- Senine Firebase Auth sisselogimine säilib. Keskuse otselingi siht säilib sisselogimise ajal. Tundmatu tee saab selge veavaate.
- Keskuse kontole ei nõuta organisatsiooni liikmesust. Mõlema õigusega kasutaja saab vahetada töökeskkonda; „Minu ühingud” viib senisesse äppi.
- Keskuse vaatel on arvuti ja telefoni paigutus ning selgesõnaline märge, et operatiivandmed pole veel ühendatud. Puuduvad väljamõeldud koordinaadid ja valmidusvärvid.
- Platvormihaldus → Kasutajakontod → konkreetne konto → „Keskuste ligipääs”: SAR ja Tross eraldi sisse/välja. Muudatus salvestatakse kohe; viga jääb nähtavaks. Õigused ei muuda ühingu liikmesust ega `systemRole` väärtust.
- `getCenterContexts`, `getPlatformCenterAccess` ja `setCenterAccess` callable'id. Platvormiõigus loetakse serveritehingus praegusest kasutajast. Muutmise revisjon takistab vana vormi abil uuema õiguse ülekirjutamist. Andmine/eemaldamine jääb `platformAudit` kirjesse.
- Veebis ei registreerita telefoni alarmide taustakäitlejat. Veebi nimi, kirjeldus, keel ja manifest korrastatud.
- Eraldi `firebase.web.json` Hosting SPA konfiguratsioon ning käsitsi käivitatav `web-foundation.yml` kontrolltöövoog. Need ei käivita iseenesest deploy'd ega APK koostamist; olemasoleva MVP töövoo PR-käivitus koostab endiselt APK.

## Selle etapi andmed ja õigused

`centers/merevalvekeskus` lubab teenust `sar`; `centers/tross` teenust `tross`. Keskuse dokument luuakse esimese õiguse andmisega serveris, mitte rakenduse käivitamisel. Juba peatatud keskust õiguse andmine automaatselt ei taasta.

`centerAccess/{uid}/grants/{centerId}` sisaldab `active`, `services`, `validUntil`, `revision`, muutja/andja/aegumise andmeid. API toetab tähtajalist õigust; esialgne haldusnupp annab UI-s kirjeldatud õiguse kuni eemaldamiseni. See ei ole operatiivse valmiduskinnituse kehtivusaeg: SAR 12 h / Tross 24 h ettepanekut pole veel rakendatud.

Klient saab lugeda üksnes oma grant'e, et muudatusest teada saada. Kirjutamine on keelatud ka platvormihalduri otsepäringule; haldus käib kontrollitud callable'i kaudu. `centers`, `centerViews` ja `unitReadiness` on selles etapis kliendile tervikuna suletud. Keskuse kaart ei loe veel operatiivandmeid ega seniseid käsitsi muudetavaid valmisolekukokkuvõtteid.

Kliendi töökeskkondade nimekiri tuleb serverist. Oma grant'i muutus käivitab uue kontrolli; aktiivses rakenduses korratakse kontrolli 20 sekundi järel. Aegumine hinnatakse serveriaja ja monotoonse kella järgi, ühenduse vea või liiga vana kontrolli korral keskuse vaade peidetakse. Taustalt naastes kontrollitakse õigust uuesti. See on kasutajaliidese kaitse: tulevased andmepäringud peavad iga kord eraldi serveris autoriseerima, mitte usaldama seda loendit.

Reeglite muudatus on piiratud prototüüp uute kollektsioonide jaoks; olemasolevaid organisatsiooni õigusi ei laiendatud. Järgmine üksuste lugemisliides vajab enne avaldamist eraldi reeglite ja serveriõiguste ülevaatust.

## Kontrollid

| Kontroll | Tulemus |
| --- | --- |
| `flutter analyze --no-pub` | Puhas, 0 probleemi |
| `flutter test --no-pub` | 119 läbis; nende hulgas 8 uut keskuse mudeli/vaate/ligipääsu testi |
| `node --test functions/*.test.js` | 65 läbis; 2 uut keskuse valideerimise testi |
| Firestore + Storage emulaator, `demo-respondcrew` | 91 läbis; 3 uut keskuste õiguste integratsioonitesti |
| `flutter build web --release --no-pub --no-web-resources-cdn` | Veebiversioon koostub, CanvasKit on kohalikus väljundis |
| Kohalik Hosting ja brauser | SAR/Tross otselingid teenindatakse SPA-na; sisselogimata kasutajale avatakse sisselogimine |

Uued kontrollid katavad õigusteta otselingi, keskuse konto ilma liikmesuseta, mõlemad teenused, aegumise, eemaldamise, keskuse peatamise, platvormirolli eemaldamise, vana revisjoni konflikti, kliendipoolse õiguse võltsimise, vale teenuse ja teise kasutaja õiguste lugemise. Hilinenud kliendipäring ei taasta tühistatud ligipääsu. Paigutust testiti 360 ja 1280 px laiuses.

Veebikoostaja annab olemasolevate sõltuvuste kaudu Cupertino ikoonifondi hoiatuse: paketti `cupertino_icons` pole projektis. Koostamine õnnestub, kontrollitud sisselogimisvaates puuduvate ikoonide viga ei ilmnenud. Täielik iOS-stiiliga brauserikomponentide kontroll jääb platvormide vastuvõtukatsetesse. Rakendus ei viita oma `lib/` koodis otse `CupertinoIcons`-ile.

## Failid

- [AppRouter](../lib/navigation/app_router.dart), URL-strateegia failid samas kaustas, [main.dart](../lib/main.dart), [AuthGate](../lib/auth/auth_gate.dart).
- [Töökeskkondade vaade](../lib/screens/app_context_screen.dart), [keskuse põhi](../lib/screens/center_workspace_screen.dart), [õiguste haldus](../lib/widgets/center_access_dialog.dart), [platvormihaldus](../lib/screens/platform_management_screen.dart).
- [Keskuse mudel](../lib/models/center_context.dart), [ligipääsu teenus](../lib/services/center_access_service.dart), [serverifunktsioonid](../functions/center-access.js), [Functions ekspordid](../functions/index.js), [Firestore reeglid](../firestore.rules).
- [Flutteri testid](../test/center_foundation_test.dart), [Functions testid](../functions/center-access.test.js), [reeglite testid](../rules-tests/center-access.cases.js) ja nende sidumine olemasoleva testikäivitajaga.
- [Hosting](../firebase.web.json), [veebi töövoog](../.github/workflows/web-foundation.yml), `web/index.html`, `web/manifest.json`, `pubspec.yaml` / `pubspec.lock` SDK veebiplugina otsesõltuvuse jaoks.

## Käivitamine ja järgmine etapp

Kohalik veebikoostamine: `flutter pub get`, seejärel `flutter build web --release --no-web-resources-cdn`. Serveeri `firebase emulators:start --only hosting --config firebase.web.json --project demo-respondcrew`; aadress `http://127.0.0.1:5000/keskus/sar` või `/keskus/tross`.

**Hosting emulaator üksi ei isoleeri andmeid.** Tavaline veebikoostis kasutab jätkuvalt olemasoleva `respondcrew` projekti Firebase seadistust. Selles töös brauseris sisse ei logitud ega tootmisandmeid ei muudetud. Serveri ja reeglite testid kasutasid eraldi demo-emulaatorit. Täielik brauseri sisselogimise/õiguste halduse läbiv test tuleb teha eraldi testprojekti või Auth/Functions/Firestore emulaatoritega.

Uued callable'id ja reeglid pole avaldatud. Seetõttu pole nende kasutamine olemasoleva pilveprojekti vastu veel valmis. Firebase CLI olemasolev sisselogimine on aegunud; andmebaasi edition'i uut pilvekinnitust ei õnnestunud saada. Reeglid järgivad olemasoleva repo Firestore dokumendimudelit ja neid kontrolliti emulaatoris. Andmebaasi tüübi/asukoha, Auth domeenide ja Hosting saidi kontroll on enne avaldamist endiselt vajalik; uut andmebaasi ei loodud.

Järgmine arendusetapp: baasid ja reageerivad üksused, kandidaatkoosseis ja ressursside jaotus, teenuse tingimuste seadistus. Seejärel ühine SAR/Tross mootor ning selle tulemuste ühendamine kaardi ja telefoni vaatega. Pädevusmaatriks, teenuste ajapiirid ja valmiduskinnituse kehtivus vajavad plaanis kirjeldatud otsuseid. Keskuste kaart ega operatiivne valmidus ei ole selle esimese etapi lõpetamisega tervikuna valmis.

APK-d, tootmisdeploy'd, PR-i ega push'i selles etapis ei tehtud. Varasemad kohalikud kasutajaliidese muudatused on alles; selle etapi raport ei esita neid keskuste arenduse osana.
