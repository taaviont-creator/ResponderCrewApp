# Tunnistused ja varustus

## Tehnika, varustus ja hooldusajalugu (07.10.2026)

Varustuse vaates on viis valikut: **Ühingu tehnika**, **Ühingu varustus**, **Ladu**, **Liikmete varustus** ja **Minu varustus**. Tehnika hõlmab ühiskasutuses aluseid, mootoreid, haagiseid, sõidukeid, muud tehnikat ning side- ja navigatsioonivahendeid. Isikukaitse- ja päästevarustus jäävad varustuse alla. Lao ja väljastamise olemasolevat loogikat ei dubleerita. Telefonis valikud murtakse ridadele; suurel ekraanil kuvatakse esemed kahes veerus. Otsing, kategooria ja tähelepanu filter töötavad valitud vaates.

Eseme juures saab avada **Ülevaade ja ajalugu**. Admin saab otse kaardilt või detailvaatest valida **Muuda olekut** ning lisada põhjuse. Olemasolevad andmebaasi väärtused säilivad: `ok` = Korras, `needsMaintenance` = Vajab hooldust, `broken` = Katki / vajab remonti, `outOfService` = Hoolduses / kasutusest väljas. Probleemi puhul on selgitus kohustuslik. Samaaegse olekumuudatuse korral ei kirjutata teise kasutaja muudatust vaikimisi üle. Laos/ühiskasutuses paiknemise muutmine uuendab ainult paiknemise välju, mitte vahepeal muutunud seisukorda.

Alus kasutab endiselt sama `equipment.status` välja: olemasolevad töölaua hoiatused ja valmidusloogika loevad seda. Aruande tehnika kategooriaid ega reageerimisreegleid ei muudeta. Hoolduspanuse lisamine ei muuda aluse olekut automaatselt; pärast remonti määrab admin selle eraldi.

### Andmed ja õigused

- `setEquipmentCondition`: aktiivse ühingu admin muudab ühingu vara; isiklikku eset saab muuta ka omanik. Kontroll toimub serveri tehingus, sealhulgas ühingu staatus ja tegelik liikmelisus. Platvormihalduri tunnus üksi ei anna haldusõigust.
- `recordEquipmentHistory`: autentimiskontekstiga Firestore trigger salvestab oleku, selgituse, hooldustähtaja ja väljastamise/paiknemise muutused `equipment/{id}/history/{eventHash}` alla. Kirjes on muutunud väljad, eelmine ja uus väärtus, muutja ning aeg. Sündmuse korduv tarne ei loo duplikaati. Ajalugu algab selle funktsiooni avaldamisest; varem salvestamata muudatusi ei taastata ega oletata.
- `recordMemberContribution` võtab hoolduse/remondi puhul valikulise `equipmentId`. Tehing kontrollib sama ühingu vara ja loob serveri kaitstud seose `equipmentWorkLinks/{activityId}`. Tegevus ja inimtunnid jäävad senistesse `activities` ja `activityParticipants` dokumentidesse. Liige lisab enda kinnitamist ootava panuse; admin saab kinnitada või sisestada olemasolevate õiguste järgi. Korduv salvestuspäring säilitab algse seose.
- `getEquipmentCare` tagastab lubatud eseme ajaloo ja seotud tööd. Ühingu vara ajalugu loeb aktiivne sama ühingu liige; isiklikku ajalugu omanik või admin. Kinnitatud inimtunnid arvutatakse algsetest osalemiskirjetest, seega hilisem kinnitus/parandus kajastub uuesti avamisel. Puuduvad tunnid ja kinnitamata osalemised eristatakse nullist. Ajalugu on lehekülgedena, 50 kirjet korraga. Töid kuvatakse kuni 500 seose ulatuses; piiri ületamisel näidatakse osalise koondi teadet.
- Firestore Security Rules ei muutu: uued ajaloo- ja seosekogud on kliendile olemasoleva vaikimisi keeluga suletud. Ligipääs toimub kontrollitud serverifunktsiooni kaudu. Andmete migratsiooni ei ole; vana varustus jääb kasutatavaks ka tühja ajaloo või seostamata panustega.

### Kontrollid

Flutteri analüüs on puhas; täielik 311 testi komplekt läbis. Lisaks korrati pärast filtrite tihendamist seotud vidina- ja visuaalseid teste (12). Functions: 116 testi ja lint läbisid. Turvareeglite täielik 152 testi komplekt läbis; seejärel läbis 8 varustuse emulaatoritesti, sh uus tervikvoog: admin muudab olekut → server salvestab ajaloo → liige lisab seotud remondipanuse → admin kinnitab osalemise → samas detailvaates kajastub 2,5 kinnitatud inimtundi, olek jääb katkisele alusele muutmata. Testitud on ka vale ühing, isikliku vara piirang, õiguse eemaldamine, kliendi ajaloo võltsimise keeld, kordustarne, null/poolikud tunnid ja samaaegne olekumuudatus. Tegelikud Flutteri vaated renderdati 360 ja 1100 piksli laiusega.

Katsetamiseks: ava testühingu alus, muuda olek koos põhjusega, vaata töölaua hoiatust ja ajalugu. Liikme kontolt lisa sama aluse juures remondipanus, kinnita see adminina panuste vaates ning ava aluse „Hooldus ja remont” uuesti. Kontrolli ka lao väljastamist/tagastamist ning „Minu varustus” vaadet. Uue funktsionaalsuse telefonis kasutamiseks tuleb hiljem paigaldada uus APK; selles töös APK-d ei koostata.

Serveris avaldati sihitult `setEquipmentCondition`, `getEquipmentCare`, `recordEquipmentHistory` ja uuendatud `recordMemberContribution`. Järelkontroll kinnitas kõigil oleku ACTIVE, Node.js 22 ja piirkonna europe-north1; kutsutavad funktsioonid keeldusid sisselogimata päringust (401). Ajaloo trigger kasutab tegeliku muutja autentimiskonteksti ning korduskatseid. Firestore/Storage reegleid ega teisi funktsioone selle avaldamise käigus ei avaldatud.

- Liikmed → vali liige (või Menüü → Minu profiil). Profiili jaotised on kohe avatud: kontaktid, staaž, valvegraafik, merepääste aste, varustus, tunnistused, koolitused ja panused. Aktiivne liige saab enda profiilil tunnistusi lisada ning enda sisestatud tunnistusi muuta ja arhiveerida. Admini sisestatud tunnistust saab liige lugeda; selle muutmine jääb adminile. Ühingu admin saab lisada ja uuendada oma ühingu liikmete tunnistusi. Sama õiguste loogika kehtib teavitusest avanevas tunnistuste vaates.
- Tunnistuse lisamine ei muuda liikmelisuse merepäästeastet ega rolli. Firestore kontrollib aktiivset liikmelisust, tunnistuse omanikku, ühingut ja algset koostajat; liige ei saa andmeid teisele omanikule või ühingule üle kanda. Enda lisatud tunnistus kasutab sama andmemudelit ja aegumise meeldetuletusi nagu admini lisatud tunnistus; uut kogu ega migratsiooni ei ole.
- Ühingu seaded → Ühingu load ja tunnistused. Admin saab salvestada loa nimetuse, numbri, väljastaja, kuupäevad ja lisainfo. Tühi kehtivusaeg tähendab tähtajatut luba. Ühingu load ei ole liikme pädevused.
- Varustus: ühiskasutuses esemed, ladu, mulle väljastatud/isiklik varustus ja liikmetele väljastatud varustuse ülevaade. Senised ühingu esemed jäävad ühiskasutusse; admin saab need menüüst lattu tõsta. Väljastatud ese kaob laost ja ilmub saaja profiili ning liikmete varustusse. Tagastamine viib selle lattu. Seisukord ei muutu väljastamise/tagastamise tõttu.

## Tunnistuste aegumise teated

Kuupäevadel on ühine kalendrivalik ning kuvatakse `pp.kk.aaaa`; kuupäevapõhised väljad jäävad andmebaasis kujule `AAAA-KK-PP`, ilma ajavööndinihketa. Sama valikut kasutavad tunnistused, varustuse hooldus, ühingu load, liitumiskuupäev, panused, tegevuste ja mittevalvete ajavalik ning sündmuste/logi kuupäevad.

Tunnistuse uued valikulised väljad on `number`, `noExpiry` ja `archived`. Tähtajatus märgitakse sõnaselgelt; vanade kirjete puuduv tähtaeg jääb teadmata tähtajaks. Profiilist eemaldamine arhiveerib kirje pärast kinnitamist, mitte ei kustuta dokumenti. Arhiveeritud ja tähtajatutele tunnistustele aegumise meeldetuletust ei saadeta. Migreerimist ei ole vaja. Omaniku, ühingu, koostaja ja haldusõiguste piirangud säilivad.

14 päeva kalender eristab planeeritud mittevalvega päevi; päeva vajutamisel näeb vastavaid intervalle ja kordumisi. See on praeguse staatuse ja olemasolevate planeeringute ülevaade, mitte tulevase valve lubadus. Isiklikke mittevalve märkusi kalender ei kuva. Panuste koond kasutab olemasolevat aasta statistikat ning selle õigusi; kui koondstatistika pole lubatud, kuvatakse olemasolevad kinnitatud tegevustes osalemised. Punkte ei arvutata väljamõeldud valemi põhjal ning teiste ühingute isikuandmeid ei ühendata.

`sendCertificateExpiryReminders` asub `europe-west1` piirkonnas ([Cloud Scheduleri toetatud piirkonnad](https://docs.cloud.google.com/scheduler/docs/locations)) ja käivitub iga päev kell 09:00 Europe/Tallinn. 30 päeva enne lõppu (või esimese kontrolli ajal, kui aega on vähem) salvestatakse liikmele ja sama ühingu aktiivsetele adminidele privaatne teade ning saadetakse tavaline push. Aegumisele järgneval päeval saadetakse eraldi aegumise teade. Liige peab olema aktiivne ja ühing kinnitatud. Puuduvaks märgitud tunnistusi ei teavitata. Uue tähtajaga tunnistus saab uue teate; sama tähtaja sama etappi ei saadeta iga päev uuesti.

Push vajab seadmes lubatud teavitusi ja registreeritud seadmetokenit. Äpi teavituste kirje on alles ka siis, kui push ei jõua seadmesse. Ebaselge FCM saatmisvea järel automaatselt uuesti ei saadeta, et vältida korduvaid teateid; tõrked logitakse. Teatele vajutamine avab asjaomase liikme tunnistused ja kontrollib kehtivaid liikmeõigusi.

Ühingu lubade vaade talletab andmed; 30 päeva automaatteavitus käsitleb liikmete tunnistusi.

## Päris-seadme kontroll

### Liikme iseteeninduse parandus (07.10.2026)

- Klient: versioon `1.0.2+20261009`; telefonis on vaja uuendada APK-d, sest vana versioon peidab lisamisnupu.
- Kontrollitud: Flutter analyze (puhas), kõik 286 Flutter testi ning kõik 151 Firestore/Storage reeglite ja töövoogude testi. Lisatud neli kliendi õigustesti ja neli Firestore iseteeninduse regressioonitesti. Avaldatava reeglifaili vastu läbisid eraldi ka kõik kuus tunnistustega seotud reeglitesti.
- Firebase `respondcrew` Firestore reeglite versioon `68f9977a-2f3d-4176-a510-d02b12f28ec2` avaldati ja loeti serverist tagasi; sisu vastas täpselt testitud failile (SHA-256 `8d0a8dcbb0bb94d7f246a11e40aeeed64896fd125938d9a499b59b7514022387`). CLI tagastas lõpus 409, kuid järelkontroll kinnitas avaldamise õnnestumist.
- Avaldati ainult tunnistuse loomise ja muutmise õiguste muudatused varasema serveriversiooni peale. Repos juba olemasolevad, serveris seni avaldamata keskuste väljakutsete reeglid jäid sellest avaldamisest välja. Järgmise täieliku rules-deploy eel tuleb see erinevus arvesse võtta. Functions ja Storage reegleid ei muudetud.
- Allolev päris-seadme kontroll tuleb teha liikme kontoga; emulaatoritestid ei asenda telefoni kasutustesti.

1. Liige: ava enda profiil, lisa tunnistus koos kalendrist valitud kuupäevadega, ava uuesti ning paranda number või tähtaeg. Kontrolli ka tunnistuste teavituse kaudu avanevat vaadet. Admin: näe liikme sisestatud tunnistust, muuda seda ja lisa teine tunnistus liikmele. Liige saab admini sisestatud tunnistust lugeda, kuid mitte muuta. Teise liikme tunnistuse lisamine ja muutmine ning enda merepäästeastme tõstmine ei ole lubatud. Arhiveerimine küsib kinnitust.
2. Admin: salvesta raadioside luba numbri ja väljastajaga; ava uuesti, muuda andmeid; kontrolli tähtajatut luba.
3. Lisa lattu ese, vali seisukord, väljasta aktiivsele liikmele. Kontrolli saaja profiili, „Minu varustus” ja „Liikmete varustus” vaadet. Tagasta ja kontrolli, et ese ilmub lattu sama seisukorraga.
4. Testühingus kasuta kontrollpäevast 30 päeva pärast aeguvat tunnistust. Pärast järgmist 09:00 käivitust kontrolli liikme ja admini teavitusi ning kolmanda liikme teate puudumist. Kontrolli push'i äpi eesplaanil, taustal ja lukustatud ekraanil ning puudutusega avanevat õiget liiget. Järgmisel päeval ei tohi sama hoiatus korduda.
5. Kui muuta tunnistuse lõppkuupäeva, kontrolli uue kuupäevaga meeldetuletust. 31 päeva pärast aeguv tunnistus ei tohi veel teadet tekitada.

Automaatseid kutse- ja platvormiadmini e-kirju see muudatus ei aktiveeri; need vajavad e-posti teenuse/SMTP/API saladuse seadistust.

## Varustuse omand, kinnitamine ja kustutamine (08.10.2026)

- „Minu varustus → Lisa varustus” küsib, kas ese on isiklik või ühingu oma liikme käes. Isiklik ese salvestub senise `scope: personal` mudeliga kohe. Isiklikud kirjed on endiselt ühingupõhised; nende puudumine „Liikmete varustus” loendist tuleneb omandi filtrist, mitte globaalsest isiklikust laost.
- Ühingu eseme sisestab liige ise, kuid admin kinnitab selle. Kuni kinnitamiseni on kirje serveri hallatavas `equipmentRequests` kogumis, mitte aktiivses varustuses, aruande valikutes ega valmidusarvestuses. Liige saab oma ootel taotluse tühistada. Admin saab vaadata detaile, kinnitada või tagasi lükata. Admini enda sisestus kinnitatakse kohe.
- Kinnitamine loob ühe `equipment` kirje olemasolevate `scope: organization`, `assignedToUserId`, `assignedToName`, `issuedBy` ja `issuedAt` väljadega. See ilmub „Minu varustus” ja „Liikmete varustus” vaadetesse ning liikme profiili seniste päringute kaudu. Korduspäring ei dubleeri eset. Enne kinnitamist palutakse kontrollida, et sama ese pole juba arvel; automaatset samanimeliste esemete ühendamist ei tehta.
- Kinnitamise taotlus ja tulemus lisatakse asjaomase kasutaja rakendusesisesesse teavituste loendisse. See ei lisa eraldi push-häiret.
- Eseme toimingumenüüs on „Kustuta varustus”. Enda isiklikku eset saab kustutada omanik või ühingu admin; ühingu eset ainult sama ühingu aktiivne admin. Pelk platvormihalduri roll õigust ei anna. Kinnitusdialoog selgitab mõju, sealhulgas väljastatud esemele ja alusele.
- Kustutamine viib hetkeseisu serveri hallatavasse `equipmentArchive/{id}` dokumenti ning eemaldab aktiivse `equipment/{id}` dokumendi ühe tehinguna. See eemaldab eseme ka vanade klientide nimekirjadest. Hooldusajalugu ja panuste seosed säilivad. Aruandesse varem seotud arhiveeritud tehnika on endiselt loetav ja aruanne parandatav, kuid seda ei saa uue aruande jaoks valida. Arhiivi taastamise kasutajaliidest selles muudatuses ei lisatud.
- Kinnitamise otsused säilitavad tegija ja aja taotluses, kustutamine arhiveerija/aja ning kustutamiskirje eseme ajaloos. Kliendid ei saa kirjutada ega lugeda taotluste või arhiivi kogumeid otse. Neid teenindab `manageEquipment` callable tegeliku aktiivse liikmelisuse kontrolliga. Firestore reegleid, olemasolevate dokumentide vormingut ega keskuste avaldamise seadeid ei muudeta; migratsiooni pole vaja.

Kontroll: Flutter analyze puhas; 361 Flutter testi; 116 Functions testi ja lint; 156 Firestore/Storage/serveri testi. Uued regressioonid katavad omandivaliku, kustutamise kinnituse ja tõrke, taotluse tühistamise, admini otsuse tõrke, serveripoolsed rolli- ja ühingupiirid, idempotentsuse, konkureerivad otsused, arhiveeritud isikliku varustuse privaatsuse ja aruande säilimise.

Telefonis katsetada uuendatud APK-ga: isikliku eseme lisamine/kustutamine; ühingu eseme esitamine liikmena, kinnitamine teise kontoga, ilmumine mõlemasse loendisse; juba väljastatud eseme ja aluse kustutamise hoiatus. Varasem APK 1.0.4 neid uusi sisestus- ja kustutamisnuppe ei sisalda.

Lisakontroll: praegu avaldatud reeglite koopiaga läbisid 146 testi (keskuste avaldamata väljakutsete testid jäid sellest kontrollist välja). Tegeliku Flutteri renderdusega kontrolliti varustuse vaadet 360 ja 1100 pikslil. Veebikoost õnnestus, keskused on endiselt peidetud.
