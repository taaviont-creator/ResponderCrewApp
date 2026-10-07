# Tunnistused ja varustus

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
