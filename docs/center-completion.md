# Keskuste esimese versiooni lõpetamine

30.09.2026. See seis asendab varasemate etappide dokumentides kirjeldatud püsiva rohelise/kollase staatuse keelu. Ulatus on merevalvekeskuse ja Trossi keskuse veebivaade ning olemasoleva ühingu valmidusega ühine serveriarvutus. APK-d ei koostata.

## Keskuste nuppude hilise ilmumise põhjus ja parandus (30.09.2026)

Kasutaja järelkatse näitas, et eelnevad UI parandused ei kõrvaldanud tegelikku esmast põhjust. Otse Firebase Rules API-st loetud aktiivsed Firestore’i reeglid olid 29.09.2026 versioonist ja neis puudus `centerAccess/{userId}/grants/{centerId}` enda õiguste lugemise reegel. Kohalikus failis ja emulaatoritestides oli see olemas, kuid seni avaldamata. Võrdlus kinnitas, et aktiivse ja kohaliku reeglistiku ainus erinevus oli keskuste 20-realine plokk: enda õiguste lugemine ning serveriandmete kliendikeelud.

Rakendus alustas paralleelselt serveri `getCenterContexts` päringut ja Firestore’i õiguste jälgimist. Avaldamata reegli tõttu ebaõnnestunud listener kutsus `invalidate()`, suurendas päringu põlvkonda ja tühistas alles käiva esmase päringu tulemuse arvestamise. UI näitas vahepeal ühinguvaadet ning keskuse valikud ilmusid järgmisel 20 sekundi järel tehtaval kontrollil. See on testiga taastatud põhjus, mitte oletus brauseri vahemälust või lihtsalt serveri külmkäivitusest.

Parandus:

- Jälgimise tõrge ei tühista juba käivat autoriteetset serverikontrolli. Kui kontrolli ei käi, alustatakse seda kohe. Ebaõnnestunud callable endiselt ligipääsu ei anna; õiguse tegelik eemaldamine ja hilinenud vanad vastused on kaitstud.
- Esmane laadimisvaade püsib kuni esimese kontrollitulemuse või tegeliku veani; pooleliolevat kontrolli ei tõlgendata õiguste puudumisena.
- Avaldati puuduv reeglipakett. Kasutaja saab lugeda ainult enda keskuseõiguste kirjeid. Klientide kirjutamine, teiste kasutajate õiguste lugemine ja keskuse operatiivandmete otselugemine jäävad keelatuks.

Kontrollid: kaks uut regressioonitesti ebaõnnestusid vana koodiga ja läbivad parandusega; **157 Flutteri testi ning 118 Firestore/Storage/serveri integratsioonitesti läbivad**. `flutter analyze --no-pub`: 0 probleemi. Testvoo esimeses koondjooksus takistas lõpetamist testis kasutatud ühe kuulajaga voo sulgemine; test kasutab nüüd broadcast-voogu ning täielik kordusjooks lõppes edukalt. Serverifunktsioonide koodi selles paranduses ei muudetud.

Esimene Rules API avaldamiskatse tagastas ajutise 503; sama muutuse korduskatse õnnestus. **30.09.2026 19:48:09 UTC avaldatud reeglid loeti pärast avaldamist uuesti ja nende täpne vastavus kohalikule testitud failile kinnitati.** Ka katsekanal `keskused-katse` uuendati; 19:49:02 UTC kontroll kinnitas avaldatud HTML-i, käivitaja ja Dart JavaScripti sisu vastavuse koostatud paketile. Kohaliku emulaatoritesti läbimist ei kasutatud seekord avaldatud reegli olemasolu tõendina. Päriskontoga käivitumise kestust selles seansis ei mõõdetud; tavaline võrgu- ja sisselogimise laadimisaeg säilib.

Logid ja tõendid: `.local-cache/center-login-{before,targeted,analyze,flutter,rules,rules-deploy-retry,web-build,hosting}.log`, `.local-cache/center-login-{rules,hosting}-verification.json`. Piiratud reegliaudit: `docs/center-login-rules-audit.json`. Muudetud kliendifailid: `lib/services/center_access_service.dart`, `lib/screens/app_context_screen.dart`, `test/auth_context_stability_test.dart`. APK-d ei koostatud.

## Järelkontroll ja salvestusvoo lõpetamine (30.09.2026)

Viimase kasutusvea paranduse järel vaadati üle keskuste vormide salvestamine, sama lehe värskendamine, platvormi jaotiste laadimine ning olemasolevad testimisjuhised. Laiema disainiuuenduse ega keskuse väljakutsete saatmisega ei alustatud: need on varasemas plaanis eraldi etapid pärast kasutajakatset.

Parandatud:

- Aluse registriandmete salvestamine ja aluse määramine/vabastamine uuendavad kohe ühingu kaardivalmiduse näitu samal seadetelehel. Enam ei pea ootama järgmist automaatset päringut või lehelt lahkuma.
- Registriandmete vorm sulgub alles pärast serveri edukat salvestust. Ühenduse vea korral jäävad sisestatud riik ja registrinumber alles ning saab uuesti proovida. Salvestamise ajal ei saa tekitada paralleelseid saatmisi; olemasolev serveri revisjonikontroll säilib.
- Aluste registriandmete sisemine dubleeriv kokkupandav pealkiri eemaldati. Tühja aluste nimekirja selgitus on nähtav.
- Platvormihalduse „Värskenda” uuendab avatud keskuste/jagamistaotluste jaotist või kasutajakontode esimest lehekülge. Kontode korduv laadimine ei tekita duplikaate. Konto muutunud nimi ilmub värskendamisel ning vana kaob. Kui kõiki kontosid pole laaditud, ütleb otsing seda selgelt.
- Tühja jagamisloendi tekst eristab ootel taotluste puudumist üldise loendi puudumisest.
- Repositooriumi avaleht sisaldab nüüd tegelikke arendus- ja testimisjuhiseid ning dokumentide viiteid. Androidi katselehe vana „SMTP seadistus puudub” märge asendati tegeliku kirja kättesaamise kontrolliga. Hosting’u kohalik vahemälu jäetakse Gitist välja.

Muudetud käitumise regressioonid: registriandmete salvestusviga → sisendi säilimine → õnnestunud korduskatse; valmiduse värskendamine ainult eduka muudatuse järel; sama kaardijagamise teise halduri muudetud oleku laadimine; kasutajakontode värskendamine ilma duplikaatideta ja esimeselt leheküljelt. **Kõik 155 Flutteri testi läbivad; `flutter analyze --no-pub` on veatu.** Serverifunktsioone, turvareegleid ega andmemudelit selles järelkontrollis ei muudetud, seega nende eelnevad 93 + 118 läbivat testi ei ole siin uuesti käivitatud testid.

Tõendid: `.local-cache/center-followup-{targeted,analyze,flutter,web-build}.log`. Pärisandmetes ühtegi aluse registrinumbrit, ligipääsu ega jagamise heakskiitu ei muudetud. Need vajavad õigeid admini sisendeid. Päriskonto käsitsi lõppkatset ja telefoni alarmi/GPS-i katset ei märgita automaattestide põhjal läbituks; APK koostamine jääb kasutaja otsuseni ootele. Apple’i paigaldatava versiooni eraldi eeltingimused on `apple-release.md` failis.

Avaldamine: järelparandused on samas `keskused-katse` veebikanalis (kehtivus 30.10.2026). 30.09.2026 kell 19:37:51 UTC võrreldi avaldatud `index.html`, `flutter_bootstrap.js` ja `main.dart.js` faile kontrollitud kohaliku paketiga: kõigi sisu räsi vastas. Veebipaketi tervikluse kontroll läbis; varasem CupertinoIcons hoiatus säilib. Tõendid: `.local-cache/center-followup-hosting.log` ja `.local-cache/center-followup-hosting-verification.json`. See on avaldatud paketi vastavuse kontroll, mitte päriskontoga tehtud käsitsi kasutuskatse. GitHubi PR-i ei avatud, et mitte käivitada kasutaja poolt edasi lükatud APK koostamist.

## Viimane parandus: õige valvearv ja selgem keskuste haldus (30.09.2026)

See jaotis kirjeldab viimast käitumist ja asendab allpool ajalooliselt säilinud liikmete erijaotuse ning koordinaatide lisakinnituse nõude.

- **Valvearv:** kaardi ja Ühingu valmiduse ühine arvutus arvestab liikme selle ühingu aktiivset liikmesust, valvesolekut ning planeeritud mittevalvet. Teise ühingu liikmesus või valvesolek ei vähenda arvu. Vanad `resourceAllocations` liikmekirjed jäävad alles, kuid neid enam arvestuseks ei loeta. Keskuste haldusest eemaldati liikmete määramine/jagamine ning uus serveripäring selleks tagastab selge lõpetatud funktsiooni teate. Aluste registriandmete ja sama füüsilise aluse kaitse säilib.
- **Tegelik põhjus:** Purtse testi andmetes oli kolm valves liiget ja üks II aste, kuid varasem teise ühingu kontroll jättis kaks inimest arvestusest välja. Parandatud arvutus annab samade sisenditega 3/3 ning II aste 1. Aluse kinnitamata registriandmed jätavad teenuse halliks eraldi põhjusel; see ei tohi peita õiget liikmete arvu.
- **Sisselogimine ja vahetamine:** `AuthGate` hoiab üht püsivat auth-voogu, selle asemel et ruuteri ümberjoonistus sisu eemaldaks ja õiguste kontrolli uuesti alustaks. Esimesel laadimisel näidatakse töökeskkondade laadimist, mitte ajutiselt valet ühinguvaadet. Lühike brauserifookuse kaotus ei tühista õiguseid. Taustale mineku, õiguse eemaldamise, tähtaja ja serveripäringu kontrollid säilivad. Päris ühenduse viga ei anna ligipääsu; automaatne korduskatse jätkub.
- **Kaardipunkt:** olemasoleva aktiivse põhibaasi selle ühingu kehtivad koordinaadid on piisavad. Vana `positionVerifiedAt` puudumine punkti ei peida; välja ei võltsita ega migreerita. Puuduvad/vigased või võõra ühingu koordinaadid ei tekita punkti. Kaamera toob saabunud punktid automaatselt nähtavale; nupp „Näita kõiki ühinguid” taastab ülevaate.
- **Platvormihaldus:** avalehe viis selget valikut on Taotlused, Kaardikeskused, Ühingud, Kasutajakontod ja Auditlogi. Taotlused koondab uued ühingud ja ootel kaardile lisamise. Kaardikeskused sisaldab ühingute nähtavust ning otsest kasutajaõiguste valikut; kontod laetakse automaatselt ja on otsitavad. Senised kinnitamis-, peatamis-, õiguste- ja auditeerimisteenused säilivad.

Kontrollid: **153 Flutteri testi + 93 Functions testi + 118 Firestore/Storage/serveri integratsioonitesti = 364 läbivat testi**. `flutter analyze`: 0 probleemi. Uued regressioonid kontrollivad 3/3 arvu vaatamata teise ühingu valvesolekule ja vanale jaotusele, samu telefoni/kaardi tulemusi, liikmete jagamise eemaldamist, vana koordinaadikirje nähtavust, 320 px kaardil asünkroonselt laetud punkti tegelikku nähtavust, sisselogitud vaate püsimist ning platvormihalduse põhiteekondi 360 px ekraanil. Ligipääsu tühistamise ja võõra ühingu testid läbivad.

Põhifailid: `functions/center-readiness-evidence.js`, `functions/center-resources.js`, `functions/center-board.js`, `lib/auth/auth_gate.dart`, `lib/services/center_access_service.dart`, `lib/services/center_board_service.dart`, `lib/screens/app_context_screen.dart`, `lib/screens/center_workspace_screen.dart`, `lib/screens/platform_management_screen.dart`, `lib/screens/center_sharing_screen.dart`, `lib/screens/center_resources_screen.dart`, `lib/screens/organization_center_settings_screen.dart`. Testid: `functions/center-readiness-evidence.test.js`, `rules-tests/center-{board,confirmation,completion}.cases.js`, `test/auth_context_stability_test.dart`, `test/platform_management_navigation_test.dart`, `test/center_board_test.dart`, `test/center_resources_test.dart`.

Firestore/Storage reegleid ega andmemudelit ei muudeta. Keskuse ligipääs ja ühingu jagamise heakskiit jäävad kohustuslikuks; pärisandmetes õiguseid ega jagamisi ei muudeta. APK-d ei koostata. Logid: `.local-cache/center-repair-{analyze,flutter,functions,rules,web-build,functions-deploy}.log`.

Avaldamine lõpetatud: **19 puudutatud funktsiooni on ACTIVE**, Cloud Functions uuenduste ajad 30.09.2026 19:15:52–19:16:08 UTC. Serveri pärast avaldamist salvestatud `organizationOperationalReadiness` kinnitas Purtse testile mõlema teenuse puhul **3 valves, II aste 1** (arvutatud 19:17:03 UTC). Ühingu Merevalvekeskusega jagamine on taotletud ja kinnitatud ning koordinaadid olemas. Aluse registriandmed on endiselt kinnitamata, mistõttu mõlema teenuse üldstaatus on põhjendatult teadmata. Seda pärisandmete seadistust avaldamine ei muutnud.

Sama katseveeb uuendati: https://respondcrew--keskused-katse-aznyqfmn.web.app/ (kanal `keskused-katse`, kehtivus 30.10.2026). Veebipakett `web-bundles/a9d7bf00c44ebb6a7ca4/` läbis failide ja deklareeritud fontide kontrolli; sisselogimisvorm avanes brauseris ning konsooli vealogi oli tühi. Säilib varasem CupertinoIcons koostamishoiatus. Päriskontoga sisselogitud käsitsi kasutuskatset selles seansis ei tehtud; nende voogude kontroll toimus automaatsete UI- ja serveritestidega. Uus telefoni kasutajaliides vajab hilisemat APK-d, mida kasutaja soovi järgi praegu ei koostatud. Täiendavad tõendid: `.local-cache/center-repair-hosting.log`, `.local-cache/center-repair-cloud-summary.json`, `.local-cache/center-repair-live-verification.json`.

## Eelneva admini töövoo lihtsustuse ajalugu (30.09.2026)

Kasutaja tagasiside põhjal on admini ainus kaardiseadete sissepääs **Menüü → Ühingu seaded → Keskuste kaart**. Samal lehel on keskusele arvutatud SAR/Trossi staatus, kogu ühingu valve, asukoht, teenused/alused/kontakt, registriandmed ning jagamise olek. Seniste eraldi lehtede komponendid ja teenused on taaskasutatud; Ühingu valmiduse lehe eraldi „Valmidus keskuse kaardil” link eemaldati. Ühingu valmiduse lehele jääb senine operatiivne ühingu valve juhtimine sama `commands.dutyPaused` välja kaudu.

Tavapärane kaardivalmidus ei vaja enam eraldi positiivset valmiduskinnitust. Server arvutab selle olemasolevast ühingu valveolekust, efektiivsest koosseisust ja kontrollitud kasutatavast alusest. Puuduv koosseis või II aste ei saa käsitsi roheliseks muutuda. Admin saab teenusele määrata viivituse või kättesaamatuse ning taastada automaatse arvestuse. Kogu ühingu valve peatamine on alati punane, ka puuduva/vananenud kinnituse korral; see säilitab olemasoleva valveaja statistika peatamise loogika. Adminile vaikimisi lubatud koosseisu/II astme teavituste soovitus osutab valve ülevaatamisele. Kasutaja varasemaid teavituseelistusi ei kirjutata üle.

Asukoha salvestamine kinnitab sisestatud koordinaadid; lisamärkeruut eemaldati ainult ühingu asukoha vormist. Vanu kinnitamata koordinaate ei kinnitata automaatselt. Kaardiseadetes näeb nii puuduva kaardipunkti põhjust kui ka keskuse jagamistaotluse kinnituse ootelolekut. Platvormihalduri heakskiit ja keskuse ligipääsuõigus jäävad senisteks; tegelikke jagamistaotlusi ei kinnitatud selle paranduse käigus.

Andmemudelit ei dubleeritud ega migreeritud: olemasolevad `organizationReadinessConfirmations` dokumendid jäävad alles, positiivne viivituseta kinnitus pole enam eeltingimus. Vana käsitsi määratud kättesaamatus jääb konservatiivselt punaseks kuni admin eemaldab selle; ajastatud viivitusele jäävad kehtima senised aja/revisjoni kontrollid. Serveri vastus lisab `automatic` ning jagamise vastus `positionReady`. Automaatse oleku puhul ei esitata vana inimkinnituse aega uue kinnitusena. Firestore/Storage reegleid see parandus ei muuda.

Mitme ühingu liikmete erijaotus on vaikimisi suletud ja märgitud valikuliseks; ühe ühingu liikmeid ei pea eraldi jaotama. Dubleeritud arvestuse serverikaitset ei eemaldatud.

Lihtsustuse lõppkontroll: `flutter analyze` veatu; 149 Flutteri testi, 93 Functions testi ning 118 Firestore/Storage/integratsioonitesti läbivad (kokku 360). Kontrollitud automaatne staatus ilma kinnituskirjeta, puuduva II astme/miinimumi mõju, sama tulemus telefonis ja kaardil, ühingu peatamine/taastamine, jagamise kinnituse säilimine, sisemise peatamise põhjuse mittejagamine keskusele, asukoha salvestamine ühe sammuga ning 320 px vormid.

Avaldamine õnnestus: 17 puudutatud funktsiooni uuendatud; sõltumatu Cloud Functions loend kinnitas kõik ACTIVE (30.09.2026, uuenduste aeg 18:55 UTC). Sama `keskused-katse` veebikanal uuendati, kehtivus 30.10.2026. Veebipaketi tervikluse kontroll läbis; avaldatud sisselogimisvaade käivitus ning brauseri vealogi oli tühi. Sisselogitud admini pärisandmetega käsitsi katse ja päristelefoni teavitus jäävad kasutaja katsetamiseks. APK-d ega PR-i ei koostatud.

Logid: `.local-cache/center-simple-{analyze,flutter,functions,rules,web,deploy,hosting}.log`, pilvekinnitus `.local-cache/center-simple-cloud-summary.json`. Varasem 20 funktsiooni avaldamise kirjeldus allpool käib sellele eelnenud lõpetamisetapi kohta.

## Avaldamise tulemus

**20 puudutatud funktsiooni avaldati edukalt ja sõltumatu pilvenimekiri kinnitas kõigi oleku ACTIVE.** Uued kolm haldusliidest tagastasid sisselogimata kontrollpäringule 401/UNAUTHENTICATED. Minutilise uuendaja uue konteineri käivitumine ja ajastatud päring on pilvelogis nähtavad; päristelefoni teavituse kättesaamist sellega ei tõendata.

Veebikatse `keskused-katse` uuendati edukalt samal aadressil, aegub **30.10.2026 kell 20:08:52**. `flutter build web` ja Wasm-eelkontroll läbisid; avaldamiseelsed failide/manifestide kontrollid läbisid. Säilib varasem CupertinoIcons fondi hoiatus. Põhisaidi live-kanalit, keskuste õiguseid, ühingute jagamisi ega kinnitusi avaldamise käigus ei muudetud.

Esimene Functions'i avaldamiskatse peatus uute korduskatsete seadistuse kinnituse juures. Uute üldvärskenduste mitmepäevast kordamist pole vaja: järgnev minutiline kontroll taastab töö. Uued jagatud ressursside ja ühingu üldvärskenduse triggerid kasutavad `retry:false`; avaldamine õnnestus ilma sundavalduse ja pika korduskatsetsüklita.

Tõendid: `.local-cache/center-completion-deploy.log`, `.local-cache/center-completion-cloud-summary.json`, `.local-cache/center-completion-endpoints.json`, `.local-cache/center-completion-scheduler.log`, `.local-cache/center-completion-hosting.log`, `.local-cache/center-completion-web.log`.

## Valmis lahendus

- Üks ühing = üks tavapärane põhibaas. Admin määrab koordinaadid ühingu seadetes; mitme baasi haldamine pole kasutamise eeltingimus. Koordinaatideta ühing jääb loendisse.
- Keskuste õigused on organisatsiooni liikmesusest eraldi. Platvormihaldur annab teenuse ligipääsu. Ühing esitab jagamistaotluse, mille platvormihaldur kinnitab; kumbki üksi ei anna keskusele ligipääsu.
- SAR kasutab olemasolevat miinimumkoosseisu ja admini määratud II astet. Tunnistus pole lisatingimus. Trossi miinimum on eraldi seadistatav (vaikimisi üks); SAR-i aste või miinimum ei laiene Trossile.
- Mõlemad teenused vajavad tegelikult saadaval koosseisu, kasutatavat alust ja ühingu kehtivat kinnitust. Roheline/kollane pole enam kunstlikult suletud.
- Uus kinnitus kehtib kuni admin muudab; vanad tähtajad säilivad kuni uue kinnitamiseni. Teenuseseadete muutus nõuab uut kinnitust. Koosseisupuudust, ühingu pausi ega rikkis alust kinnitus ei tühista.
- Kollane eeldab kinnitatud väljasõiduaega ja selleks ajaks sobivat koosseisu. Kellaliikumine ei nihuta lubatud aega edasi. Hiljem muudetud isiklik viivitus võib lubatud aega ületada ja valmiduse tühistada.
- Puuduv/aegunud kinnitus, kontrollimata alus või vananenud ühendus ei tekita rohelist olekut. Võrguvea korral näidatakse viimase laadimise aega ja halli olekut. Õiguse eemaldamine tühjendab järgmise kontrolliga kaardi andmed.

## Varasema meeskonna ja aluste jaotuse ajalugu (liikmete osa eemaldatud)

Ühingu teenused → **Meeskond ja alused**:

1. Admin kinnitab aluse registririigi ja registrinumbri. Server normaliseerib kirjapildi ja tuletab ühese füüsilise aluse võtme. See on admini vastutusel andmete kinnitus, mitte väide riikliku registri automaatse kontrollimise kohta.
2. Ühe ühingu reageerijatele pole eraldi jaotust vaja. Kui sama liige või alus on samal ajal mitme ühingu koosseisus saadaval, saab admin määrata selle ühe ühingu valmidusse.
3. Jaotus püsib vabastamiseni ega muuda isiklikku valvesolekut. Paralleelsetest määramistest saab õnnestuda ainult üks. Teise ühingu jaotust ei saa üle võtta ega vabastada.
4. Endise liikme või eemaldatud aluse enda ühingu jaotus jääb vabastatavaks, ilma et oleks vaja liikmesust või varustust taastada.

Valmidusarvutus eemaldab teisele ühingule määratud või lahendamata kattuvusega ressursid arvestusest. Kui ülejäänud sõltumatu koosseis ja alus täidavad tingimused, võib ühing olla valmis. Aluse identiteedi puudumine ei muutu oletuslikuks kinnituseks. Keskusele lähevad koondpõhjused, mitte liikmete nimed, UID-d, teise ühingu andmed või planeeringute märkused.

## Ühine arvutus ja ajastamine

`loadOrganizationCenterReadiness` arvutab mõlema teenuse tulemuse. `loadOperationalReadiness` rakendab sama tulemuse telefoni/veebi töölaua ja Ühingu valmiduse serverivastuses ning teavitusmootoris. Liikmete loend ja koosseis järgivad sama ühingupõhist isiklikku valmisolekut; teise ühingu valvesolek seda arvu ei vähenda. Teenuseseadistust veel mitte kasutavate vanade ühingute senine koosseisuarvutus säilib.

Sisendite muutused uuendavad serveri kokkuvõtet: `availability`, `memberships`, `plannedUnavailability`, `plannedUnavailabilityRules`, `organizationReadinessSummaries`, `commands`, `equipment`, `organizationResponseSettings`, `organizationReadinessConfirmations`, `vesselIdentities`, `resourceAllocations`. Jagatud ressursi või ühingu muutus kontrollib mõjutatavaid ühinguid. Ressursi/tehnika muudatuste esimese versiooni töötlus kontrollib kõiki kinnitatud ühinguid, et mitte jätta kaudset seost uuendamata.

Olemasolev minutiline `refreshScheduledReadiness` käsitleb ajast sõltuvaid muutusi ja aegunud vanu kinnitusi. Ühe ühingu viga ei jäta ülejäänuid kontrollimata; osaline ebaõnnestumine raporteeritakse. Päringud arvutavad tulemuse ka värskelt, seega pole ekraani töö sõltuv ainult ajastatud töö õnnestumisest. Veeb küsib 30 sekundi järel; 90 sekundit vanad andmed muutuvad halliks. Need on esimese versiooni mõõdetavad viitepiirid, mitte lubadus nullviivitusest.

Admini miinimumist allapoole langemise teavitus suunab koosseisu kontrollima ja valves jätkamise/pausi üle otsustama. Ühingut automaatselt pausile ei panda. Olemasolevad teavituseelistused säilivad, sh kasutaja sõnaselge väljalülitus.

## Andmed ja turve

| Andmed | Muudatus |
|---|---|
| `vesselIdentities/{equipmentId}` | Olemasoleva mudeli admini haldusliides; `country`, normaliseeritud `registration`, tuletatud `physicalResourceId`, `verificationSource`, `revision` ja auditandmed. |
| `resourceAllocations/{hashedResource}` | Olemasolev globaalne ressursivõti; lisandus `validityMode=untilChanged/released`, revisjon. Vanad ajapiiriga üksuse jaotused jäävad toetatuks. |
| `organizationOperationalReadiness/{org}` | Ainult serveri kirjutatav teenuste kokkuvõte, arvutuse aeg ja värskuse lõpp. Kinnituse aeg on teenuse tulemuses eraldi. |
| `readinessNotificationState` | Ühise teenusearvutuse tulemus teavituste ja olemasoleva uuendusmärguande jaoks. |
| `platformAudit` | Aluse identiteedi ja ressursijaotuse enne/pärast väärtused, muutja ja aeg. |

Selles etapis turvareegleid ei muudeta ega avaldata. Olemasolev vaikimisi keeld sulgeb uued/olemasolevad serverikollektsioonid kliendi otsepäringutele. Callable kontrollib aktiivse ühingu tegelikku adminliikmesust serveritehingus; platvormi- või keskuseõigus seda ei asenda. Samaaegseid ja aegunud vormiga salvestusi kontrollib revisjon. Andmeid ei kustutata ega migreerita.

## Kontrollid

- **147 Flutteri testi läbis**, sealhulgas 320 px aluse kinnitamine, määramine/vabastamine, võõra jaotuse kaitse ning töölaua hall/kollane serveristaatus.
- **90 Functions'i testi läbis**: SAR/Tross, viivitus, tähtajatu/ajaline jaotus, aluse identiteedi normaliseerimine ning olemasolevad alarmi-, e-posti- ja statistika regressioonid.
- **117 Firestore/Storage/serveri integratsioonitesti läbis**: tegelike handler'itega admin/liige/platvorm/center rollid, võõras ühing, samaaegne jaotus, vabastamine pärast eemaldamist, ühe tulemuse kuvamine eri vaadetes, kellast sõltuv planeering, katkine alus, paus, õiguse eemaldamine, audit, klientide otsekirjutamise keeld ja ajastatud teavitussündmus.
- `flutter analyze --no-pub`: **0 probleemi**. `git diff --check` läbis; olemasolevad Windowsi genereeritud failide reavahetuse hoiatused säilivad.
- Esimeses UI jooksus vajasid kaks testi vana poolelioleva etapi teate asemel uue selgituse ootust; parandatud ootustega kõik 147 läbisid.
- Tõendid: `.local-cache/center-completion-{analyze,flutter,functions,rules}.log`.

## Katsetamine

Veeb: https://respondcrew--keskused-katse-aznyqfmn.web.app/

1. Logi sisse olemasoleva kontoga.
2. Platvormihaldur annab testijale keskuse õiguse: RespondCrew haldus → Kaardikeskused → Keskuste kasutajaõigused. Õigusi ei anta avaldamise käigus automaatselt.
3. Ühingu admin avab Menüü → Ühingu seaded → Keskuste kaart ning sisestab asukoha, teenused ja keskuse valvekontakti ning kinnitab aluse registriandmed. Tavapärane staatus tekib ühingu andmete järgi; eraldi valmiduskinnitust pole vaja.
4. Admin lubab samal lehel keskusega jagamise; platvormihaldur kinnitab. Kontekstivalikus saab avada Merevalvekeskuse/Trossi keskuse.
5. Võrdle samu olekuid keskuse kaardil, ühingu enda kontrollvaates ja uue veebiversiooni töölaual. Muuda koosseisu, lisa lühike planeering, märgi alus rikkis ning taasta; proovi Trossi ilma II astmeta ja admini kinnitatud viivitust.

Sisselogitud päriskontodega käsitsi katse ja teavituse jõudmine päristelefoni jäävad kasutaja testietappi. Testides ei loodud tootmises fiktiivseid ühinguid, liikmesusi, õiguseid ega valmiduskinnitusi. Telefoni uue kasutajaliidese jaoks on hiljem vaja uut APK-d; praegu kasutatakse uut veebiversiooni.

## Esimese versiooni piirid ja kulud

- Kaart on lugemisvaade. Keskus ei saada ega võta vastu väljakutseid; sündmuskohale saabumisaega ei arvutata.
- Käsitsi kinnitatud registriandmed ja koordinaadid jäävad admini vastutuseks. Väline registriliidestus pole selle etapi osa.
- Keskuse päringupiir on praegu 25 jagamiskirjet, resource reader'i piir 500 vahemäluta kontrolltoimingut päringus; ületamisel kuvatakse viga, mitte osaline kindlana näiv kaart. Suurema kasutuse eel lisada lehekülgedega laadimine ja koormuskatse.
- Minutiline töö võib seadistatud ühingu kohta kirjutada kaks kokkuvõttedokumenti; lisanduvad sisendite lugemised, muutusesündmused ja 30 s veebipäringud. Jagatud ressursside seosed suurendavad lugemiste arvu. Jälgida Firebase'i kasutuskulu esimese päriskatse ajal; suurem kasutus vajab mõjutatud ühingute täpsemat indekseerimist/vahemälu.
- Esialgne OSM aluskaart säilitab nõutud autoriviite; enne pidevat operatiivkasutust valida sobiva teenustasemega kaardipaanide pakkuja. Teegi tasuta litsents ei taga tasuta piiramatut paaniteenust.
- Kood ja muudatused on olemasolevas tööharus. Varasemaid kohalikuid muudatusi ei kustutatud; APK-d käivitavat PR-töövoogu selles etapis ei käivitatud.

Muudetud põhilised failid: `functions/center-resources.js`, `functions/center-readiness-evidence.js`, `functions/center-readiness.js`, `functions/organization-center-readiness.js`, `functions/operational-readiness.js`, `functions/effective-readiness.js`, `functions/organization-readiness.js`, `functions/readiness-availability.js`, `functions/index.js`, varasema üksuse jaotuse ühilduvuskaitse `functions/response-units.js`; `lib/screens/center_resources_screen.dart`, teenuseseadete ja valmiduse/keskuse ekraanid ning `lib/widgets/crew_readiness_card.dart`. Testid: `functions/center-resources.test.js`, `functions/center-readiness.test.js`, `rules-tests/center-completion.cases.js`, `test/center_resources_test.dart`, vana alusetapi teksti ootuse uuendus `test/center_foundation_test.dart`.

Brauseri lõppkontroll: avaldatud veebiversiooni sisselogimisvaade avanes uuel vahelehel; selle vahelehe konsoolis vigu/hoiatusi ei olnud. In-app brauseri vana vahelehe korduv ekraanipildistus andis tühja kaadri, kuigi vormi ligipääsetavuse puu oli olemas; puhta vahelehe esimene visuaalne kontroll näitas vormi korrektselt. See kontroll ei asenda päriskonto sees tehtavat kasutajakatset.


## Keskusest mitmele ühingule väljakutse edastamine (07.10.2026)

- Uus `dispatchIncidents/{id}` on ühise info allikas. Iga `assignments/{organizationId}` osutab ühele olemasoleva mudeli `callouts/{id}` kirjele; sellel on oma operatiivlogi, vastused, osalejad ja aruanne. Ühe ühingu lõpetamine ei lõpeta teisi.
- Asukoha kirjeldus ja koordinaadid on valikulised. Kohustuslikud on pealkiri ja teadaolev info. Koordinaadid eristavad täpset, hinnangulist ja viimast teadaolevat asukohta; puuduvast infost punkti ei tuletata.
- Keskuse kaart → Väljakutsed → Loo väljakutse (või kaardil valitud ühingu nupp). Korraga saab kaasata kuni 30 ühingut; hiljem lisada uusi. Vorm kogub olukorra, teadaoleva info, valikulise asukohakirjelduse, JRCC sidekanali (`radioChannel`) ja muud teadaolevad reageerijad (`otherResponders`). Ühingupõhiseid taktikalisi ülesandeid ei määrata: need tulevad JRCC raadiosides. Üldinfo muutused jõuavad Firestore'i reaalaja vooga kõigisse seotud ühinguvaadetesse. `callouts.dispatch` ja põhiandmed on serveri hallatav lugemisprojektsioon, mitte teine iseseisvalt muudetav andmeallikas. See säilitab vanemate klientide ja olemasoleva aruande põhiinfo.
- „Lisa infot” vajab ainult uut teadet; olemasolevaid põhiandmeid ei sisestata uuesti. „Muuda põhiinfot” võimaldab parandada olukorda, asukohta, sidekanalit, muid reageerijaid ja sündmuse olekut. Kõik täiendused on ühised. Kaasatud ühingute nimed ja reageerimiskinnitused (`organizations`) uuenevad serverist kõigis seotud väljakutsetes; vastuse ootel ühingut ei esitata kinnitatud reageerijana. Liikmete nimesid ega teiste ühingute logisid see kokkuvõte ei sisalda.
- Saatmine vajab eraldi `centerAccess/{uid}/grants/{centerId}.canDispatch` õigust. Vanadel õigustel vaikimisi false; platvormihaldur saab selle olemasolevas keskuste õiguste dialoogis anda. Õigus ei anna ühingu adminiõigust. Uue sihtühingu puhul kontrollitakse jagamise taotlust/heakskiitu, teenust ja ühingu aktiivsust.
- Ühingu admin või II astme liige märgib „Ühing reageerib” / „Ühing ei saa reageerida” (põhjusega). Eraldi lugemiskinnitust küsitakse ainult oluliseks märgitud täienduselt. Isiklik „Tulen” jääb eraldi. Keskusele projitseeritakse ainult vastuste arvud ja logi etapp, mitte logi tekst ega liikmete profiilid. Kaks minutit vastuseta kuvab keskuses kontaktivõtu hoiatuse; see on esialgne UI hoiatuslävi, mitte automaatne keeldumine ega garanteeritud edastus.
- Algne väljakutse kasutab senist SAR/Trossi alarmi. Lisainfo kasutab `callout_update` teavitust ja avab sama ühingu konkreetse väljakutse. Olulistel täiendustel on eraldi kõrge tähtsusega `dispatch_updates` kanal, ilma uue algalarmi või täisekraanita. Kinnitamata kriitiline info säilib ka järgmise tavateate järel. FCM vastuvõtmist ei esitata inimese kättesaamiskinnitusena.
- Keskuse lõpetamine/tühistamine ei sulge ühingu operatiivlogi ega märgi alust baasi. Ühing saab tagasisõidu ja lõpetamise ise fikseerida. Uusi isiklikke vastuseid keskuse lõpetatud ülesandele ei lubata.
- Telefonikõne varutee jääb Väljakutsete alla ja töölaual teisese nupuna. Loomisel saab märkida keskuse telefonikõne; detailist saab sidumistunnuse. Keskus sisestab ühingu antud tunnuse saajate valiku lisajaotuses. Server kontrollib sama ühingut/keskust/teenust, aktiivsust ja proovitunnust. Olemasolev logi ja callout ID säilivad; uut algalarmi ei saadeta.
- `dispatchRequests` hoiab idempotentsust, `dispatchUpdateEvents` teavituste töid, `updates` ja `platformAudit` muudatuste ajalugu. Ühised täiendused projitseeritakse iga kaasatud ühingu `centerUpdates` ajalukku. Turvareeglid keelavad kõik otsesed kliendikirjutused uutesse keskuse kogudesse. Destruktiivset migratsiooni ega õiguste automaatset jagamist pole.

Kontrollid 07.10.2026: Flutter analyze 0 probleemi; 253 Flutteri testi, 106 Functions'i testi ning 144 Firestore/Storage/serveri integratsioonitesti läbisid. Kontrollitud teadmata asukoht, saajate kinnitus, kiire täiendus ilma põhiandmete kordamiseta, sidekanali ja reageerijate jagamine, sama päringu kordus, samaaegsete muudatuste konflikt, keskuseõiguse eemaldamine, võõra ühingu andmete keeld, telefoniväljakutse sidumine ning eraldi operatiivlogid.

Piirid: ühiste manuste haldus ei ole uues keskuse vormis veel lisatud; senised ühingu aruande manused säilivad. Keskuse ühingute valik tuleb kaardilt laaditud loendist, server kontrollib õigusi saatmisel uuesti. Päristelefonis tuleb katsetada taustal/lukustatud ekraanil SAR-alarm, uue info teavitus, täpse väljakutse avanemine ja võrgu taastumine. Uus telefoni UI vajab hilisemat APK/iOS-versiooni; selles etapis APK-d ei koostata.

## Ühingupõhine kasutuselevõtt ja kiire alarmeerimine (07.10.2026)

Keskuste koostöö algab hilisemas etapis. Tavaline ehitus kasutab `ReleaseFeatures.centers=false`: sisselogimisel avatakse kohe ühing, keskuste õiguste päringuid/pollimist ei alustata ning keskuste kontekstivalik, seadistus, jagamistaotlused ja kasutajaõiguste nupud on peidetud. Ka vana `/keskus/sar` või `/keskus/tross` link avab selles versioonis ühingu. Keskuste kood ja varem sisestatud andmed säilivad. Eraldi arenduspiloodi saab hiljem koostada lipuga `--dart-define=RESPONDCREW_CENTERS_ENABLED=true`; see ei anna kasutajale õigusi ega aktiveeri serverit. Tegelik ligipääs jääb olemasolevate serverikontrollide, aktiivsete keskuste ja kasutajaõiguste taha. See kasutajaliidese väljalaskelipp ei ole turvareegel ega tühista varasemate katsekontode serveriõigusi.

Keskuse uue dispatch-serveriosa avaldamine on kasutaja otsusel edasi lükatud. Varasema PR #52 korduskatsete avaldamisluba ei ole selle ühingupõhise kasutuselevõtu eeltingimus. Selles etapis ei muudeta ega avaldata Functions'it või Firestore'i reegleid ega looda uut andmemudelit.

Ühingu põhivoog: **Loo väljakutse → SAR sündmus / TROSSI mereabi → Alarmeeri meeskond**. Tüüp tuleb teadlikult valida; eraldi teksti, asukohta, prioriteeti ega sihtaega ei pea sisestama. Pealkiri tekib tüübist, SAR-i prioriteet on kõrge, Trossi prioriteet tavaline ja senine Trossi väljasõidu sihtaeg vaikimisi 60 minutit. SAR-i ja Trossi teavituste senised eraldi kanalid säilivad. Lisainfo ja senised kirjelduse kiirvalikud on soovi korral avatavas jaotises. Hilisema keskusepiloodi telefonikõne sidumine säilib sama jaotise valikuna.

Loomine kasutab senist atomaarset väljakutse + ühinguteavitus + operatiivlogi + logi algkirje salvestust ning olemasolevat alarmifunktsiooni. Salvestamise ajal on saatmine blokeeritud. Eduka salvestamise järel avatakse konkreetne aktiivne väljakutse; selle kirjelduse juures on „Täienda sündmuse andmeid”. Peamised infoväljad on muutmisvormis eespool, tüübi ja aegade parandused teises jaotises. Senine `amendCallout` kontrollib ühingu admini/II astme õigust ja muudatuse revisjoni, säilitab auditjälje ning info uueneb liikmete olemasoleva reaalajavoo kaudu. Lisainfo muutmine ei loo uut väljakutset ega uut algalarmi.

Kontrollid: 261 Flutteri testi läbis, sh mõlema tüübi saatmine sisestusvälju avamata, vaikimisi andmed, saatmisnupu lukustus, veajärgne andmete säilimine, 320 px/200% tekst ja keskuste puudumine tavaversioonis. Kõik 145 Firestore/Storage/serveri testi läbisid. Firestore'i test laiendati mõlemale tüübile: tühi asukoht/kirjeldus, neli atomaarset dokumenti, hilisem admini täiendus, liikme lugemisõigus ja auditjälg. APK-d ei koostata. Telefonis rakendub uus kasutusvoog järgmise rakendusevärskendusega, veebis uue veebiversiooni avaldamise järel.

## Väljakutsete vahekaardid ja proovihäire (07.10.2026)

Väljakutsete leht avaneb alati vahekaardil „Aktiivsed”. „Lõpetatud” sisaldab lõpetatud ja tühistatud väljakutseid; nende kaarte ja vastuste päringuid ei ehitata enne selle vahekaardi valimist. Ühingu vahetus lähtestab vahekaardi. Ebaselge „Näita test-/proovisündmusi” lüliti eemaldati: proovisündmused on vastava oleku nimekirjas nähtavad ja selgelt tähistatud. Ka aktiivse proovihäire leiab töölaualt. Päris sündmuse vaikimisi pealkirja ei korrata kaardil topelt.

Proovihäire loomine: „Loo väljakutse” → SAR või Tross → „Proovihäire” → „Saada proovihäire”. Vaikimisi on proovivalik väljas. Valimisel kuvatakse enne saatmist, et tegemist on **päris meeskonnale saadetava häirega**, mis ei lähe sündmuste statistikasse ega liikmete panusesse. Ainult ühe telefoni lokaalne proov jääb teavituste seadete alla. Eelnevalt loodud sündmuse statistikatunnuse parandamine jääb olemasoleva adminiõiguse ja auditeeritud `setCalloutTestStatus` funktsiooni taha; tunnuse parandamine uut häiret ei saada.

Kasutatakse senist `callouts.isTest` tõeväärtust, mis salvestatakse nüüd juba väljakutse loomise atomaarse tehinguga. Uut kogumit, migratsiooni ega turvareeglite muudatust pole. Vanades dokumentides puuduv tunnus tähendab jätkuvalt päris sündmust. Proovitunnuse arvestus statistikas säilib. `sendCalloutAlarmNotification` edastab tunnuse push-teatesse; proov on nimetatud nii Androidi/iOS-i teavituses kui ka uuendatud Androidi lukuekraani häirevaates. Senine SAR/Tross kanal, saajate reeglid, täpne väljakutse link ja dubleeriva saatmise kaitse säilivad. Ühe telefoni kohaliku proovi ja ühingu proovihäire navigeerimine jäävad eraldi.

Avaldamise ulatus: ainult muudetud `sendCalloutAlarmNotification` funktsioon ja kaks olemasolevat katseveebi. Keskuste serveriosa, reegleid ja APK-d selles muudatuses ei avaldata. Telefoni vormi ning lukuekraani uue tähise jaoks on vajalik järgmine rakendusevärskendus; pärisseadme heli/tausta/lukuekraani katse jääb selle järel teha.

Kontrollid: Flutter analyze 0 probleemi, 267 Flutteri testi, 108 Functions'i testi ja lint, 147 Firestore/Storage/serveri testi läbisid. Lisatud regressioonid: aktiivsete/lõpetatute eraldatus, tühistatud sündmuse asukoht, aktiivse proovi nähtavus, ühinguvahetuse lähtestus, suur tekst, SAR/Tross proovivalik enne saatmist, saatmistõrke järel säiliv valik, proovitunnus atomaarse loomise ja hilisema täiendamise järel, tavaliikme loomiskeeld ning proovi teavituse tekst/kanal/täpne siht mõlemal edastusteel.
