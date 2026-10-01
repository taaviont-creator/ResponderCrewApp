# Keskuste kaardivaate katsetamine

**Uuem pärisandmete testijuhend ja seis:** [keskuste esimese versiooni lõpetamine](center-completion.md). Allpool kirjeldatakse varasemaid näidis-/katseetappe; püsiv rohelise/kollase keeld enam ei kehti.

Seis 30.09.2026. Jätk plaanile [center-readiness-maps-plan.md](center-readiness-maps-plan.md). Kaardi kasutajaliides on nüüd katsetatav; operatiivse pärisandmete valmiduse tervik pole veel valmis.

Viimane etapp: [ühingu valmiduskinnitus ja sama keskuse projektsiooni kontrollvaade](center-confirmation-progress.md). Kõik 14 serveriliidest on avaldatud; seejärel uuendati nelja funktsiooni tähtajatu kinnituse, ressursikattuvuse kontrolli ja admini teavituse selgitusega. Viimases kontrollis läbis 343 testi (144 Flutter + 87 Functions + 112 reegli-/integratsioonitesti), analüüsis 0 probleemi. Allolevad varasemad testiarvud kirjeldavad esimest kaardietappi.

## Ava proovivaade

**Avalik proovilingi aadress:** https://respondcrew--keskused-proov-bkdxq1xk.web.app/ — Firebase Hosting kanal `keskused-proov`, avaldatud 30.09.2026 ja aegub 30.10.2026. Avaneb ka teisest arvutist/telefonist. Ainult sünteetilised näidisandmed; põhisaidi live-versiooni, Auth lubatud domeene, Functions'it ega andmebaasi selle avaldamisega ei muudetud.

**Sisselogimisega veebikatse:** https://respondcrew--keskused-katse-aznyqfmn.web.app/ — eraldi kanal `keskused-katse`, avaldatud 30.09.2026, aegub 30.10.2026. Brauseris kontrolliti sisselogimislehe avanemist. Kasutab sama Firebase projekti ja kontosid nagu äpp, mitte sünteetilisi andmeid. **Kõik 14 keskuste serverifunktsiooni on 30.09.2026 avaldatud ja olekus ACTIVE.** Kolm lugemisfunktsiooni lükkasid sisselogimata päringu tagasi (401/UNAUTHENTICATED). Päriskontoga õigused ja ühingu jagamine vajavad veel läbikatsetamist; roheline/kollane operatiivstaatus jääb tõendite kontrolli lõpetamiseni suletuks. Täpne seis: [valmiduskinnituse etapp](center-confirmation-progress.md#viimane-avaldamise-seis).

„Katse: tavapärane valmidus” ja teised olukorrad on ainult prooviversiooni abivahendid. Tootmise keskusevaates neid ei ole: seal tulevad sisendid ühingute andmetest.

Selles arvutis: **http://127.0.0.1:8765/**. Kohalik server peab töötama. Telefonist ega teisest arvutist see aadress ei avane. APK-d ei tehta.

Pärast arvuti taaskäivitust käivita repositooriumist `./tool/start-center-demo.ps1`. Server teenindab ainult ehitatud prooviversiooni ja kuulab ainult loopback-aadressil. Logid/PID on `.local-cache/center-demo-server*`. Avaldati eraldi Hosting eelvaatekanal (vt ülal), mitte põhisaidi live-väljalase. 30.09.2026 uuendati hiljem Firebase CLI sisselogimine edukalt ja kontrolliti lugemisega ligipääsu aktiivsele `respondcrew` projektile. Varasema ühendusvea põhjus oli Node TLS sertifikaadiahel: selle arvuti CLI-käskudel tuleb kasutada protsessi seadistust `$env:NODE_OPTIONS = '--use-system-ca'` (Node 24), mis kasutab Windowsi usaldatud sertifikaate ega lülita TLS kontrolli välja. Sisselogimise parandamine ei avaldanud rakendust ega muutnud pilveandmeid.

Prooviversiooni uuesti koostamine:

```powershell
node tool/generate-center-demo.cjs
flutter build web --release --target lib/main_center_demo.dart --output build/center-demo --no-web-resources-cdn
./tool/start-center-demo.ps1
```

`firebase.center-demo.json` on eraldi proovivaate avaldamise konfiguratsioon. Käsk: `npx -y firebase-tools@latest hosting:channel:deploy keskused-proov --expires 30d --no-authorized-domains --project respondcrew --config firebase.center-demo.json --non-interactive`. Seda ei tohi avaldada senise telefoniäpi veebiväljalaske asemele ilma sihtsaidi ülevaatuseta. Proovirežiim on eraldi sisenemispunkt: see ei initsialiseeri Firebase'i, ei ava sisselogimisest möödapääsu tootmise marsruuteris ega muuda pärisandmeid. Näidisandmed genereeritakse samade JS-arvutusfunktsioonidega; nimed, asukohad ja kontakt on selgelt väljamõeldud.

## Katseta neid vooge

1. Vaheta Merevalvekeskuse ja Trossi keskuse vahel. „Näidis · Läänerannik” on SAR-is punane (üks reageerija, II aste puudub), Trossis roheline.
2. Vajuta ühingule või kaardipunktile. Kontrolli põhjuseid, koosseisu, alust, väljasõidu sihtaega ja arvutuse/kinnituse eraldi aegu.
3. Otsi ühingut ja kasuta staatusefiltreid. „Asukoht lisamata” on loendis, aga ei tekita oletuslikku kaardipunkti.
4. Vaheta ülemist stsenaariumi: planeeritud mittevalve, kinnitatud viivitus, ühingu paus, katkine alus või aegunud kinnitus. Muutub ainult „Näidis · Põhjarannik”.
5. Vajuta „Katkesta ühendus”. Viimased andmed jäävad nähtavale koos laadimisajaga, kuid kõik staatused muutuvad halliks. Taasta ühendus sama nupuga.
6. Kontrolli kitsast akent: kaart ja ühingud on üksteise all, lai arvutivaade kuvab loendi, kaardi ja detailpaneeli kõrvuti.

Ajad kuvatakse seadme ajavööndis. Kollane tähendab kinnitatud väljasõiduviivitust; see ei ole sündmuskohale saabumise prognoos. Aluskaardi laadimisvea korral säilivad nimekiri ja punktid ning kuvatakse korduskatse nupp.

## Pärisandmete piloodi liides

Senine üks ühing = üks põhibaas jääb alles. Admin kasutab ühingu asukohta ja teenuseseadeid, mitte uut baaside haldamise kohustust. Uus jagamisvoog asub „Ühingu teenused” → „Keskustega jagamine”. Admin esitab SAR-i/Trossi jagamissoovi eraldi; platvormihaldur kinnitab selle halduse jagamisnupust. Keskuse kasutaja sõltumatu grant on lisaks kohustuslik. Platvormiõigus ega ühingu adminiõigus ei anna automaatselt keskuse lugemisõigust.

Uus serveri hallatav kollektsioon `organizationCenterPublication/{organizationId}_{centerId}` sisaldab ainult jagamistaotluse ja platvormi kinnituse olekut, revisjoni ning muutja/aega. Admini iga muudatus tühistab varasema kinnituse. Mõlemad toimingud auditeeritakse. Kliendi otsekirjutamine/lugemine on olemasoleva vaikimisi reegliga keelatud; käesolev etapp reeglite sisu ei muuda.

Callable `getCenterReadinessBoard` kontrollib värsket keskuse õigust tehingu alguses ja enne vastuse tagastamist. Tagastatakse ainult approved ühingu mõlemalt poolt lubatud ja sisse lülitatud teenus. Ühingule kuuluv kinnitatud baas määrab koordinaadid. Lubatud vastus sisaldab ühingu nime, koondarve, teenuse seadeid, seotud aluste nime/seisundit ja spetsiaalselt keskusele määratud kontakti. Liikmete UID-sid, nimesid, planeeringute märkusi ega privaatset pausi põhjust ei väljastata.

Piirangud on praegu 25 jagamiskirjet keskuse päringus (ka peatatud kirjed loevad piiridesse) ja 100 jagamistaotlust haldusnimekirjas. Ületamine annab selge vea, mitte näiliselt täieliku pooliku kaardi. Andmebaasikirjutused kontrolliti kohalikus emulaatoris; 14 callable-funktsiooni avaldati 30.09.2026 pilve. Päriskontoga kirjutuste täielik töövoog on veel kontrollimata.

Piloot arvutab päringul, veeb värskendab 30 sekundi järel. Üle 90 sekundi vana vastus, aegunud kinnitus või kadunud ühendus annab halli. Õiguse eemaldamise järgmine kontroll eemaldab vaate/andmed; võrguühenduseta varem loetud infot pole võimalik serverist tagasi võtta. Keskuste vahetamine loob uue teenuse, vana päringu vastus ei taasta hiljem eemaldatud õigust.

## Operatiivse kasutuse eel veel vajalik

**Pärisandmete roheline/kollane staatus on endiselt suletud (`evidenceReady: false`).** Kehtiva kinnituse korral annab teadaolev koosseisu või kasutatava aluse puudumine punase staatuse; puuduvad tõendid annavad halli. Roheline/kollane näidisversioonis ei tõenda pärisühingu valmisolekut. Katsevaade ei ole veel operatiivseks kasutuseks valmis.

- SAR-i II astme jaoks piisab kasutaja otsusel admini määratud astmest. Lõpetada aluse identiteedi kinnitamise ja sama liikme/aluse mitme ühingu vahelise kattuvuse lahendamise töövoog; tuvastus ja privaatsed koondpõhjused on lisatud.
- Admini kinnitus/viivitus on rakendatud. Uus kinnitus kehtib kasutaja otsusel kuni muutmiseni; vana tähtajaline kinnitus säilitab tähtaja. Kinnitus ei asenda kohustuslikku koosseisu, II astet ega alust.
- Kinnitatud väljasõidu viivituse puhul arvestatakse tulevasi planeeritud puudumisi. Ressursikattuvust kontrollitakse ka kinnitatud väljasõiduajal; kehtiv jaotus piirab andmete värskusaja oma lõppajaga.
- Luua ühine serverikokkuvõte koos sisendite muutuste ning ajastatud piiride uuendustega. Aja möödumine üksi ei käivita Firestore triggerit. Ühendada sama tulemus telefoni ühingu valmiduse vaatesse.
- Lõpetada indeksi/mahu/päringukulude hinnang; kontrollida avaldatud veebikatses päriskontode õiguseid ning pärisandmete värskust.

Senise telefoni SAR-valmiduse arvutus ja teavituste valikureeglid säilivad. Admini koosseisupuudujäägi teavituse tekst suunab nüüd admini otsustama valves jätkamise või ühingu pausi üle; teavituseelistused säilivad. Väljakutsete saatmine, vastuvõtmine ja saabumisaja arvutus jäävad plaani kohaselt järgmisse etappi.

## Kaart ja kulud

Kasutusel `flutter_map` 8.3.2 (BSD-3-Clause; Flutter Web/Android/iOS) ja `latlong2`. [Paketi ametlik leht](https://pub.dev/packages/flutter_map). Väikese käsitsi katse aluskaart kasutab OpenStreetMap standardpaanide teenust, nähtava autoriviite ja brauseri Refereriga, ilma massallalaadimise/offline eellaadimiseta. [OSM paaniteenuse tingimused](https://operations.osmfoundation.org/policies/tiles/) ei anna piiramatut tasuta tootmisteenust ega käideldavusgarantiid. Enne operatiivset kasutust valida lepinguga sobiv pakkuja.

Teenuse vahetamiseks on koostamisel `CENTER_MAP_TILE_URL`, `CENTER_MAP_ATTRIBUTION`, `CENTER_MAP_ATTRIBUTION_URL`. Brauseris nähtav võti peab olema avalikuks kliendikasutuseks sobiv ja päritolupiiranguga. Firebase'i piloodi kuluks on korduvad callable-päringud ja Firestore lugemised; praegune tehingupõhine koondamine pole suurmahu lõplik lahendus. Prooviversioon Firebase'i ei kasuta.

## Kontrollid ja failid

- Flutter: 140 testi läbis, sh uued vigaste koordinaatide, aegumise, võrguvea, õiguse eemaldamise, hilinenud vastuse, SAR/Tross vahetuse ja 320/1366 px paigutuse kontrollid.
- Functions: 77 testi läbis. Ühine planeeritud mittevalve alusloogika, SAR/Tross erinevus, kohustuslik kinnitus, alus, paus, viivitus ja genereeritud näidised.
- Firestore/Storage emulaator: 107 testi läbis. Jagamise mõlema poole kinnitus, võõra ühingu baas, tundlike andmete välistamine, eemaldatud/aegunud/vale teenuse õigus, revisjon, otsepäringute keeld ja audit.
- Brauseris käsitsi kontrollitud tegelik OSM kaart, ühingu valik/põhjused, SAR/Tross erinevus, võrgu katkestamisel hallid staatused.
- `flutter analyze --no-pub`: 0 probleemi. Mõlema sisenemispunkti release-veebikoostamine läbis (proovivaade ja tavarakendus), samuti Wasm-eelkontroll. Säilib olemasolev CupertinoIcons fondi hoiatus; kaardivaates kasutatakse kontrollitud Material-ikoone. APK-d ei koostatud.
- `git diff --check` läbis; Windowsi genereeritud failidel säilivad reavahetuse hoiatused. Brauseri konsoolis kontrolli ajal vigu/hoiatusi ei olnud. Pilve ja pärisseadme end-to-end kontrolli pole tehtud.

Peamised uued failid: `functions/center-board.js`, `functions/center-readiness.js`, `lib/models/center_board.dart`, `lib/services/center_board_service.dart`, `lib/screens/center_workspace_screen.dart`, `lib/screens/center_sharing_screen.dart`, `lib/main_center_demo.dart`, `assets/center-demo.json`, `tool/generate-center-demo.cjs`, `tool/serve-center-demo.py`, `tool/start-center-demo.ps1`. Seosed olemasolevate teenuseseadete, platvormihalduse ja keskuse kontekstivahetusega. Repositooriumi varasemad pooleliolevad muudatused säilivad.
