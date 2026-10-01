# Keskuse pärisandmete katseetapp: valmiduskinnitus

**Uuem seis:** [keskuste esimese versiooni lõpetamine](center-completion.md). Allpool säilib etapi ajalugu; sealne püsiv rohelise/kollase oleku keeld on uues etapis eemaldatud kontrollitud ressursside jaoks.

30.09.2026. Eelmine näidisandmetega kaart: https://respondcrew--keskused-proov-bkdxq1xk.web.app/.

## Viimane avaldamise seis

30.09.2026 avaldati eraldi autentimist nõudev veebikatse: **https://respondcrew--keskused-katse-aznyqfmn.web.app/**. Hosting kanal `keskused-katse`, aegub 30.10.2026; konfiguratsioon `firebase.web.json`, koostatud `build/web`. Sisselogimisleht kontrolliti brauseris, konsoolis kontrollimise hetkel vigu/hoiatusi ei olnud. Sisselogimist päriskontoga ega keskuste pärisandmete voogu ei kontrollitud. Põhisaidi live-versiooni, Auth lubatud domeene, reegleid ega kasutajate õigusi selle käsuga ei muudetud. APK-d ei koostatud.

**Kõik 14 serverifunktsiooni avaldati 30.09.2026 edukalt.** Pärast kasutaja õigusteseadistuse muutmist lubati täpne avaldamiskäsk käivitada. Firebase kinnitas 14 edukat loomist; sõltumatu funktsioonide nimekirja kontroll näitas kõigil ACTIVE / gcfv2 / nodejs22 / europe-north1. Kõigil on maxInstances=3. Kolm päris lugemisfunktsiooni (getCenterContexts, getCenterReadinessBoard, getOrganizationCenterReadiness) tagastasid sisselogimata päringule HTTP 401 / UNAUTHENTICATED ja lubatud veebikatse CORS-päritolu. Kasutaja grante ega ühingute jagamisi automaatselt ei lisatud. Päriskontoga täielik töövoog on veel kontrollimata. Tõendid: .local-cache/center-confirmation-deploy.log, .local-cache/center-functions-verification.json, .local-cache/center-endpoint-verification.json.

Hosting esimene katse lõppes projekti lugemise veaga. Eraldi lugemiskontroll kinnitas `respondcrew` projekti oleku ACTIVE; järgmine Hosting katse õnnestus. Tõendid: `.local-cache/center-auth-preview-deploy.log` ja `.local-cache/center-authenticated-preview.png`.

## Valmis muudatus

- Sama `loadOrganizationCenterReadiness` projektsioon teenindab keskuse kaarti ja ühingu enda vaadet „Valmidus keskuse kaardil”. Sinna pääseb ühingu valmiduse ning teenuste seadete lehelt.
- Aktiivne liige loeb oma ühingu projektsiooni; ainult sama ühingu aktiivne admin muudab kinnitust. Platvormihaldur ei saa organisatsiooni kinnitust muuta pelgalt platvormirolliga.
- Admin saab eraldi SAR-i/Trossi kinnituse anda, teenuse kättesaamatuks märkida, lisada kuni 60 min kinnitatud viivituse või kinnituse eemaldada. Isiklikku valvesolekut ei muudeta.
- Kasutaja 30.09 täpsustus: uus kinnitus kehtib kuni admin seda muudab (`validityMode=untilChanged`, `validUntil=null`). Vanad 12/24 tunni kinnitused jäävad oma senise tähtajaga kehtima, kuni admin annab uue kinnituse. Puuduv lõppaeg ilma sõnaselge režiimita ei anna tähtajatut kehtivust.
- Kinnituse ning teenuseseadete revisjon kaitseb paralleelse ülekirjutamise eest. Muudetud teenuseseadete puhul vana kinnitus enam ei kehti. Tähtajad põhinevad serverikellal.
- Keskusele nähtav selgitus on eraldi kuni 240 märgi pikkune väli, mitte privaatsete planeeringumärkuste kopeerimine. Kinnituse muutja/aeg ja enne/pärast väärtused auditeeritakse.
- Kavandatud väljasõiduviivituse kontroll välistab ka liikme, kes on selleks ajaks planeeritud mittevalves. Piisav koosseis praegu ei tühista tulevase väljasõiduaja puudujääki.

## Andmed ja turve

Uus serveri hallatav `organizationReadinessConfirmations/{organizationId}_{service}`:

`organizationId`, `service`, `revision`, `settingsRevision`, `confirmedAt`, `validUntil`, `validityMode`, `expectedReadyAt`, `unavailable`, `reason`, `updatedBy`, `updatedAt`.

Ei dubleeri liikmeid, planeeringuid, aluseid ega miinimumkoosseisu. Klient saadab ainult lubatud sisendväljad, mitte arvutatud staatust. Firestore/Storage reeglite sisu selles etapis ei muudeta: olemasolev vaikimisi keeld sulgeb kollektsiooni kõik klientide otsepäringud. Lubatud toimingud käivad autentimist/aktiivset liikmesust nõudvate serveritehingute kaudu. Migratsiooni pole vaja; puuduv kinnitus annab halli oleku.

## Avaldamise täpne ulatus

Projekti `respondcrew` on ette valmistatud ainult järgmised 14 keskuste callable-funktsiooni (`europe-north1`). Need annavad ligipääsu pärisandmetele ja lubavad õigustatud kasutajate tegevusel muuta keskuste õiguseid, ühingu asukohta, teenuseseadeid, jagamist ning kinnitusi. Pelgalt avaldamine ei loo kasutajatele grante, ei avalda ühinguid keskusele ega kirjuta kinnitusi.

1. `getCenterContexts`
2. `getPlatformCenterAccess`
3. `setCenterAccess`
4. `getOrganizationMapLocation`
5. `saveOrganizationMapLocation`
6. `getOrganizationResponseSettings`
7. `saveOrganizationResponseSettings`
8. `getOrganizationCenterSharing`
9. `setOrganizationCenterSharing`
10. `getCenterSharingRequests`
11. `reviewOrganizationCenterSharing`
12. `getCenterReadinessBoard`
13. `getOrganizationCenterReadiness`
14. `setOrganizationReadinessConfirmation`

Olemasolevaid väljakutse/alarmi/e-posti/statistika funktsioone ega Firestore reegleid selle avaldamiskäsuga ei muudeta. Kõige enam 3 instantsi funktsiooni kohta; lugemine ja kasutamine tekitab tavapärast Functions/Firestore kasutuskulu. Varasemad automaatse kontrolli katsed peatati enne käivitumist. Pärast õigusteseadistuse muutmist avaldati kõik 14 edukalt; vt viimane avaldamise seis.

## Teadlikult veel suletud

Varasem avaldamistakistus (hiljem lahendatud, vt ülal): kasutaja vastas „Kinnitan”, kuid automaatne turvakontroll lükkas ka järgmise täpselt 14 funktsiooniga käsu enne käivitumist tagasi, tõlgendades nõusolekut ebausaldusväärse vestlusviite osana. Pilvemuudatusi selle katsega ei tehtud. Kasutajale esitati uuesti konkreetne küsimus kõigi 14 nime, tootmisprojekti ja eraldi autentimist nõudva veebikatse ulatusega. Valmis veebikoostamise ja testide logid kontrolliti uuesti; uusi teste ei olnud muutmata koodi tõttu vaja käivitada.

**Pärisandmete operatiivne roheline/kollane staatus jääb suletuks (`evidenceReady: false`).** Kasutaja 30.09 otsus: SAR-i II astme nõude jaoks piisab admini määratud liikmelisuse astmest; tunnistus ei ole lisatingimus. Aluse ühese identiteedi kinnitamise ning mitme ühingu ressursikattuvuste lahendamise töövoog vajab veel lõpetamist. Uus kontroll näitab nende konkreetseid põhjuseid, kuid ei muuda kontrollimata ressursse valmisoleku tõendiks. Teadaolev puuduv koosseis või alus saab kehtiva kinnituse korral punase staatuse ka enne positiivse tõendi valmimist.

Telefoni senine koosseisu SAR-arvutus ja teavitused säilivad. Ühine uus projektsioon on praegu keskuse kaardi ja ühingu keskusele nähtava kontrollvaate vahel; telefoni põhikaart ja teavitusmootor ei ole veel uue operatiivse tulemuse peale üle viidud. Pärisandmete kaart jääb märgistatud katsevaateks. Värskendamine on päringupõhine, mitte veel sündmustel/ajastatud piiridel hooldatav serverikokkuvõte.

## Eelmise kinnitusetapi kontrollid

- 143 Flutteri testi läbis; uued liikme lugemisvaate, admini salvestuse, 320 px dialoogi ja salvestusvea testid.
- 110 Firestore/Storage ja serveri integratsioonitesti läbis; sisendite whitelist, rollid, võõras ühing, eemaldatud liikmesus, revisjon, audit, tähtaja aegumine, otsepäringu keeld ja kahe vaate sama tulemus.
- 78 Functions'i testi läbis; lisandus tulevase planeeritud mittevalve kontroll kinnitatud viivituse korral.
- JavaScripti süntaksikontroll ja `git diff --check` läbisid.
- Lõplik `flutter analyze --no-pub`: 0 probleemi. Täiendatud kinnituse vaate 3 regressioonitesti läbisid ka pärast viimast tekstimuudatust. Release-veeb ja Wasm-eelkontroll koostusid edukalt; säilib varasem CupertinoIcons fondi hoiatus. APK-d ei koostatud.
- Andmebaasi olemasolev `(default)` väljaanne kontrolliti CLI-ga: STANDARD / FIRESTORE_NATIVE, `europe-north1`. Andmebaasi ei loodud ega migreeritud.

Peamised muudatused: `functions/organization-center-readiness.js`, `functions/center-board.js`, `functions/center-readiness.js`, `functions/index.js`; `lib/screens/organization_center_readiness_screen.dart`, sissepääsud ühingu valmiduse/teenuste vaates ning selgituse väli keskuse kaardil. Testid: `rules-tests/center-confirmation.cases.js`, `test/organization_center_readiness_test.dart`, `functions/center-readiness.test.js`.

## Keskuse päriskonto katsetamine

1. Ava https://respondcrew--keskused-katse-aznyqfmn.web.app/ ja logi sisse äpi kontoga.
2. Platvormihaldur: RespondCrew haldus → Kasutajakontod → vastava konto Keskuste ligipääs → anna vajalik SAR/Trossi õigus.
3. Ühingu admin: määra ühingu kaardiasukoht, teenused/alus/keskusele jagatav kontakt ning esita Keskustega jagamine taotlus.
4. Platvormihaldur kinnitab jagamise pärast kokkuleppe kontrollimist.
5. Keskuse õigusega konto valib Merevalvekeskuse või Trossi keskuse. Uute õiguste järel oota õiguste värskendust või laadi leht uuesti.

Pärisandmete roheline/kollane operatiivstaatus on endiselt suletud; see avaldamine ei kõrvalda allpool kirjeldatud tõendite ja ressursijaotuse piiranguid. APK-d ei tehtud.


## Tähtajatu kinnituse ja ressursikontrolli etapp

30.09.2026 avaldati edukalt neli uuendatud funktsiooni: `getCenterReadinessBoard`, `getOrganizationCenterReadiness`, `setOrganizationReadinessConfirmation`, `sendReadinessChangeNotification`. Sõltumatu nimekirjakontroll kinnitas kõigi oleku ACTIVE, nodejs22, gcfv2, europe-north1, maxInstances=3. Sisselogimata lugemine ja uus tähtajatu kinnituse päring lükati tagasi 401/UNAUTHENTICATED; tootmisandmeid kontrollpäringutega ei kirjutatud.

Valmiduskinnitus ei muuda automaatselt liikme valvesolekut ega ühingu pausi. Miinimumist allapoole langemise olemasolev teavitus on adminil vaikimisi sees; sõnum juhib admini koosseisu kontrollima ja valves jätkamise üle otsustama. Teadlikult säilivad olemasolevad kasutaja teavituseelistused: väljalülitatud teavitust ei saadeta sunniviisiliselt.

Ühine päring kontrollib olemasolevaid memberships/availability/planeeringuid, vesselIdentities ja resourceAllocations andmeid. Tagastatakse vaid kattuvuste arvudega põhjused, mitte võõraste ühingute nimed, liikmete andmed või tunnistused. Sama reageerija samaaegne efektiivne saadavus teises ühingus kontrollitakse nii praegu kui kinnitatud väljasõiduajal. Paus, planeeritud puudumine ja mitteaktiivne liikmesus välistavad kattuvuse. Aluse kontroll tuvastab teise ühingu teenuses valitud sama kinnitatud füüsilise aluse, dubleerivad kirjed ja teise ühingu kehtiva ressursijaotuse. Kinnitamata aluse identiteeti ei oletata registrinumbri ega nime järgi.

Kasutusel on ainult päringu tehingu piires vahemälu. Kaitsepiirid: 100 kontrollitavat reageerijat ühingus, 20 liikmesust kasutaja või identiteedikirjet aluse kohta ning 500 vahemäluta kontrolltoimingut päringus. Piiri ületamisel tagastatakse viga, mitte osaline kindlana näiv tulemus. Tegelik lugemiskulu sõltub seotud ühingute olemasoleva valmiduse laadimisest; see pole lõplik suure mahu kokkuvõttemootor. Andmeid ei migreerita ning Firestore turvareegleid selles etapis ei muudeta.

Kontrollid: **144 Flutteri, 87 Functions'i ja 112 Firestore/Storage/serveri integratsioonitesti läbisid** (343 kokku); `flutter analyze --no-pub` leidis 0 probleemi. Uued kontrollid katavad tähtajatu kinnituse sõnaselge režiimi, vanade tähtaegade säilimise, revisjoni/auditi, tulevased planeeritud puudumised, ühingutevahelise liikme/aluse kattuvuse, privaatsete andmete välistamise ja päringupiirid. Esimese integratsioonijooksu kahe vea põhjuseks oli testandmetest puudunud miinimumkoosseis; parandatud testandmetega kogu teine jooks läbis.

Tõendid: `.local-cache/center-persistent-{flutter,functions,rules,analyze}.log`, `.local-cache/center-persistent-deploy.log`, `.local-cache/center-persistent-cloud.json`, `.local-cache/center-persistent-endpoints.json`. Päriskontoga keskuse kogu töövoog ja teavituse jõudmine telefoni on veel kontrollimata. APK-d ei koostatud.

Veebipaketi lõppkontroll leidis esimesel uuesti avaldamisel puuduva `FontManifest.json` ja teised staatilised failid: leht jäi värskendamisel tühjaks, kuigi koostamiskäsk oli edukas. Uus koostamine eraldi `build/center-web-verified` väljundisse sisaldas kõiki faile; kontrollitud tervik kopeeriti avaldamise `build/web` kausta. `tool/verify-web-build.cjs` kontrollib käivitusfaile, JSON-manifeste ja manifesteeritud fonte; puuduliku paketi negatiivne ning terve paketi positiivne kontroll läbisid. Kontroll on lisatud `firebase.web.json` predeploy-sammu ja veebi töövoogu, et viga enne järgmist avaldamist peatada. See ei muuda rakenduse äriloogikat. Koostamise logi: `.local-cache/center-persistent-web-repair.log`.

Vahemälu parandus: `tool/prepare-web-assets.cjs` annab varadele sisust arvutatud versiooniga URL-i ja lisab Flutteri käivitaja `assetBase` seadistuse. Sama koostamise korduv ettevalmistus annab sama aadressi ega dubleeri seadistust. Hosting kontrollib kõigi nimetamata versiooniga failide värskust (`no-cache`); versioonitud varad väldivad juba brauserisse salvestunud vigase HTML-vastuse korduskasutust. Mõlemad skriptid on Hosting'u ja veebi CI sammudes; korduv ettevalmistus, kontrollskript ning genereeritud käivitaja süntaksikontroll läbisid.

Lõplik veebikatse avaldati edukalt samale `keskused-katse` kanalile (aegub 30.10.2026 kell 19:40:52). Pärast versioonitud varade parandust avanes sisselogimisleht olemasoleva brauserivahelehe tavalisel värskendamisel; sellest laadimisest uusi konsoolivigu ega hoiatusi ei olnud. Tõendid: `.local-cache/center-persistent-hosting-repair.log` ja `.local-cache/center-persistent-preview.png`. Põhisaidi live-kanalit ei avaldatud. Konto sees toimuv pärisandmete katse on endiselt tegemata.
