# RespondCrew – minimaalne Androidi päris-seadme lõppkatse

Versioon: kasuta testiks valitud värsket main-versiooni ning märgi paigaldatud APK täpne commit. Esialgne 27.09 haruviide ei ole enam testimise alus. APK koostamine toimub ainult kasutaja eraldi tellimusel.
Koostatud: 27.09.2026. Olek: **ette valmistatud, seadmel läbi tegemata**.
Täielik lõppkatse algab pärast Firestore rules ja Functions deploy ning pilves kontrollimist.

## Ettevalmistus

- Paigalda sellest commit'ist ehitatud APK päris Androidi seadmesse; märgi telefoni mudel, Androidi versioon ja APK versioon.
- Kasuta eraldi testühinguid A ja B ning testkontosid: admin ja mõlema ühingu liige. Alarmikatse saajad peavad olema testist teadlikud.
- Valmisoleku jaoks sea teadaolev miinimumkoosseis ja vähemalt üks II astme merepäästja. Vajaduse korral kasuta lisaks testliikmeid.
- Luba telefoni teavitused, alarmikanali heli/vibratsioon ja asukoht. Märgi aku säästmise ning „Mitte segada” olek. Admin saab väljakutseid luua teisest seadmest.
- Kinnita enne testi pilves: `sendCalloutAlarmNotification` on aktiivne; käiviti vastab andmebaasile `(default)` ja dokumendi `callouts/{calloutId}` loomisele; Firestore'i reeglid vastavad kokkulepitud versioonile.

## Test

| # | Tegevus | Läbimise tingimus | Tulemus |
|---|---|---|---|
| 1 | Logi liikmena sisse. Proovi ka vigast parooli. | Õige kontoga avaneb õige ühing. Vigane parool annab arusaadava teate; ei kuvata tehnilist veateksti. | Tegemata |
| 1a | Liitu uue kontoga koodi abil; proovi enne kinnitust ühingut avada. Admin kinnitab taotluse liikmete vaates. Korda teise kontoga tagasilükkamist ning eemaldatud liikme taasliitumist. | Enne kinnitust puudub ligipääs. Admin näeb taotlust, kinnituse järel saab ühingu valida. Tagasilükatud taotlus ei anna ligipääsu; eemaldatud liige vajab uut kinnitust. Teise ühingu olemasolev liikmesus säilib. | Tegemata |
| 2 | Vaheta A → B → A; ava avaleht, valmisolek, liikmed ja väljakutsed. | Ühingu nimi, roll, loendid ja arvud vahetuvad koos. Eelmise ühingu infot ei jää uude vaatesse. | Tegemata |
| 3 | Sea miinimumkoosseis valvesse koos II astme liikmega. Seejärel võta II astme liige valvest maha; lõpuks vähenda koosseis alla miinimumi. | „Valmis” ainult siis, kui mõlemad tingimused on täidetud. Admini avaleht ja valmisolekuvaade näitavad samu arve ja staatust. | Tegemata |
| 4 | Valves liikmele lisa praegu kehtiv planeeritud puudumine. Kontrolli liikme avalehte/profiili ning admini liikmete, valmisoleku ja statistika vaateid. Tühista puudumine; proovi ka lühikese perioodi algust/lõppu ja korduvat puudumist. | Kehtiv puudumine muudab tegeliku valmisoleku mittevalves olekuks kõigis vastava õigusega vaadetes. Tulevane puudumine ei mõju enne algust. Perioodi lõppedes või tühistamisel rakendub taas baasolek; selle kontrolliks ära muuda käsitsi valvesolekut. | Tegemata |
| 5 | Loo kolm eraldi TEST-väljakutset: äpp eesplaanil, taustal ja telefon lukustatud. Märgi loomise ning teavituse saabumise kellaaeg. | Igas olekus saabub väljakutse push ja kokkulepitud alarmiheli/vibratsioon. Ühe väljakutse kohta ei teki topeltalarme. Teise ühingu mitteliige alarmi ei saa. | Tegemata |
| 6 | Vajuta igas eelmises olekus teavitusele. Korda, kui äpis on aktiivne B, aga väljakutse kuulub A-le, ning pärast äpi tavapärast sulgemist. | Avaneb täpselt teavituse väljakutse detail õiges ühingus. Kontrolli pealkirja ja admini salvestatud väljakutse ID-d; ei avane lihtsalt nimekiri ega mõni teine väljakutse. | Tegemata |
| 7 | Vasta väljakutsele: reageerin → hilinen koos minutitega → ei saa. Ava detail uuesti ja kontrolli admini vaadet. Sulge väljakutse. | Vastus ja hilinemise minutid säilivad ning kajastuvad adminile õigesti; vastus ei dubleeru ega lähe teise väljakutse alla. Suletud väljakutsele uut vastust ei salvestata. | Tegemata |
| 8 | Alusta operatsioonilogi, lisa GPS-iga sündmus/märkus ning läbi lubatud staatused. Hoia logivaade avatuna telefoni ekraani kustumise tavalisest ajast kauem. Keela korra GPS/asukohaluba ja taasta see. | Sündmuse kellaaeg ja asukoht on õiged, salvestatu säilib uuesti avamisel. Aktiivne logivaade hoiab ekraani ärkvel; pärast lahkumist töötab tavapärane ekraani kustumine. Puuduv asukoht annab selge tulemuse ega tekita näilist GPS-punkti või krahhi. Staatused ei liigu tagasi lubamatusse olekusse. | Tegemata |
| 9 | Vajuta liikme helistamisnuppu. Seejärel sulge äpp tavapäraselt ja ava uuesti; taaskäivita ka telefon. | Avaneb telefoni numbrivalija õige numbriga; testkõnet pole vaja käivitada. Sisselogimine säilib, õige konto ja aktiivne ühing taastuvad ning vaated laadivad värske info. Väljalogimine lõpetab sessiooni. | Tegemata |

Taustal olemine ja tavapärane sulgemine ei tähenda Androidi seadete „Sundpeata” kasutamist. Alarmikatsetes märgi tegelik rakenduse ja telefoni olek.

## Tulemuse fikseerimine

Iga ebaõnnestumise juurde: sammu number, telefon/Android, kellaaeg ja ajavöönd, ühing, väljakutse ID (kui asjakohane), oodatud ja tegelik tulemus. Lisa võimalusel ekraanipilt. Ära jaga paroole ega seadme FCM-tokenit.

Alarmikatse ajal kontrolli Functions'i logidest sama väljakutse tulemust: `Callout alarm push send finished`, `successCount`, `failureCount` ning päringu-/õigusevigu. FCM-i edukas saatmine üksi ei tõesta heli või lukuekraani toimimist; need kinnitab seade.

Läbitud on ainult katse, mille kõik sammud on päriselt kontrollitud. Ebaõnnestunud samm parandatakse ja korratakse koos sellest sõltuvate sammudega.

## E-posti järelkontroll

Varasem SMTP seadistamise takistus on lahendatud: saatmisvood ning saladuse seadistus on kirjeldatud [e-posti juhendis](transactional-email.md) ja [väljalaske kokkuvõttes](2026-09-release-completion.md). Kontrolli uue päriskutse ja uue ühingutaotlusega kirja tegelikku jõudmist õigesse postkasti. SMTP serveri vastuvõtmise kinnitus ei tõenda postkasti jõudmist.

Seadmetestid jäävad kuni tegeliku läbimiseni märgituks „Tegemata”. Telefoni alarmi, heli, GPS-i ja taustakäitumist ei loeta veebikatse või automaattestidega kinnitatuks.

## SAR-häire seadistuse täiendus (06.10.2026)

Teavituste seadetes kuvatakse telefoni tegelik teavitusluba, SAR-kanali heli,
helitugevus, kanali „Mitte segada“ erand ja Androidi täisekraanihäire luba.
Read avavad vastava süsteemiseade; rakendusse naastes loetakse olek uuesti.
DND-erand avab SAR-kanali seaded, mitte üldise loa, mida võiks ekslikult pidada
heli lubamise kinnituseks. Olemasolevat `sar_alarm_v2` kanalit ega kasutaja
valitud heli/erandeid ei lähtestata. Helitugevus vastab kanali tegelikule
helivoole (olemasoleval kanalil tavaliselt teavituste, mitte äratuskella tugevus).

Androidi lukustuskuva häire näitab ainult üldist SAR-teadet. Väljakutse andmed
avanevad olemasoleva õiguste kontrolliga pärast telefoni avamist. Trossi
teavitus ei kasuta täisekraanihäiret. Android otsustab tegeliku esitusviisi;
luba ei tõesta, et seade igas aku-, võrgu- või DND-olukorras häiret esitab.
Google Play levitamise eel tuleb täisekraanihäire kasutus deklareerida ja
kontrollida selle vastavust poe nõuetele; luba ei ole kõikidel seadmetel vaikimisi olemas.

Proovihäire ajastatakse operatsioonisüsteemis umbes 10 sekundi pärast ning seda
saab tühistada. Android kasutab ebatäpset lubatud taustaajastust: täpsete alarmide
luba ei küsita ja süsteem võib saabumist edasi lükata. Proov ei testi FCM-i ega
loo ühingusse sündmust. Telefoni taaskäivituse järel lühiajalist proovi ei taastata.

iPhone'is on teavituste ja heli olek ning süsteemiseadete otsetee. Kriitiliste
häirete Apple'i entitlement pole lisatud; vaikset režiimi ega Focus't ei ületata.

### Server ja ühilduvus

- `userDeviceTokens.nativeSarAlarm` on vabatahtlik boolean. `true` lubatakse
  ainult Androidi seadmekirjel; ainult selle omanik võib välja kirjutada.
- `sendCalloutAlarmNotification` jagab saajad võimekuse järgi. Uus Android saab
  kõrge prioriteediga data-only SAR-teate, mille kuvab ka taustaisolaadi käitleja.
  Selle eluiga FCM-is on 5 minutit. Teised kliendid ja Tross säilitavad senise
  süsteemiteavituse. Ühele saajale ei saadeta mõlemat varianti.
- Eri sündmustel on eri stabiilsed teavituse ID-d, et PendingIntent ei suunaks
  varasema sündmuse teavitust viimati saabunud sündmusele.
- Avaldamise järjekord: testitud reeglid → Functions → uus telefoniversioon.
  Vana versiooni taastamisel tuleb selle seadme võimekuslipp eemaldada või
  seade uuesti registreerida; vana äpp ei tunne uut data-only SAR-teadet.
- APK-d selle muudatuse käigus ei koostata. Androidi kood kompileeritakse
  eraldi ilma APK pakendamiseta; iOS-i kontroll teeb CI.

### Pärisseadme vastuvõtt — veel tegemata

1. Keela/luba teavitused, SAR-kanal, heli ja DND-erand. Naase rakendusse:
   näidatav olek peab vastama telefonile, mitte jääma vanaks.
2. Kontrolli Android 14+ täisekraaniloa puudumist ja olemasolu. Lukusta telefon,
   käivita viivitusega proov; ilma loata peab säilima lubatud tavateavitus.
3. Lukustuskuval ei tohi nähtavale ilmuda ühingu ega sündmuse isikuandmed.
   „Ava väljakutse“ peab vajadusel küsima telefoni avamist, mitte sellest mööduma.
4. Loo proovühingus SAR äpi eesplaanil, taustal ja pärast protsessi tavalist
   sulgumist. Kontrolli üht teadet, heli ja täpset sündmuse detaili. Androidi
   sundpeatatud äpp ei ole toetatud taustaolek.
5. Saada kaks eri prooviväljakutset ja ava esimese teavitus pärast teise saabumist.
   Avanema peab esimene sündmus. Korda teises ühingus.
6. Kontrolli vana Androidi versiooni, iPhone'i ja Trossi tavateate säilimist.
7. Kontrolli proovihäire tühistamist ning lukustamist enne selle saabumist;
   võrguühendust ei ole kohaliku proovi kuvamiseks vaja pärast ajastamist.

## Asukohapõhise valmisoleku telefonikatse

Vajab uut native rakenduse versiooni; veebist paigaldatud PWA ei sobi taustapiirkondade testiks. APK-d selle muudatuse käigus ei koostata.

1. Admin määrab olemasoleva baasi asukoha ja lubab ühingu seadetes piirkonnaautomaatika. Liige annab Valmisolekus selgesõnalise nõusoleku ja täpse asukoha loa „Alati“. Androidil kontrollida energiasäästu; iOS-il taustavärskendust.
2. Märgi end valvesse ja lülita automaatika sisse: valvesoleku raadiuses jääb staatus valvesse. Käsitsi mittevalvest või aktiivse planeeritud mittevalve ajal käivitamine peab olema keelatud. Tagasituleku teavitus avab õige ühingu Valmisoleku; „Kinnitan: olen valves“ teeb uue asukohakontrolli.
3. Väljuda valvesoleku raadiusest hilinemisega valve alasse ning seejärel ka kaugemast raadiusest välja: hilinemisega → mitte valves. Korrata lukustatud ekraaniga ja taustal; mõõta tegelik viivitus, mitte eeldada kohest üleminekut.
4. Naastes ei teki automaatset rohelist staatust. Vajalik on kinnitus. Kiire edasi-tagasi liikumine ja ebatäpne GPS ei tohi anda põhjendamatut valvesolekut.
5. Käsitsi mittevalve ja planeeritud/korduv mittevalve ei kao piirkonnavahetuse tõttu. Aktiivsel väljakutsel reageerides baasist lahkumine ei tohi muuta vastust ega automaatselt maha võtta; automaatika peatub ning vajab pärast väljakutset uut sisselülitamist.
6. Proovida loa eemaldamist, asukohateenuse sulgemist, võrgu katkemist, telefoni taaskäivitust ja rakenduse sunnitud peatamist. Vaates näidatakse viimast kinnitust; puuduv uus info ei pikenda 24-tunnist kehtivust. Aegumine eemaldab automaatse valveaja ja saadab isikliku teate.
7. Teises telefonis sisselülitamine muudab vana seansi kehtetuks. Teise kasutajaga sisselogimine ei tohi vana kasutaja staatust muuta. Ühingu seadete/asukoha muutmine peatab senise seansi.
8. Kontrollida sama staatust isiklikus vaates, ühingu valmiduses, keskuste kaardil ja valveaja statistikas. Serverisse ei tohi ilmuda liikme koordinaate ega teekonda.

Automatiseeritud kontrollid ei asenda neid Androidi/iPhone'i pärisseadme kontrolle.

Geofence’i prioriteedikatse: lisa aktiivne ühekordne ja seejärel korduv mittevalve. Liigu mõlemast raadiusest läbi: efektiivne staatus peab jääma mittevalvesse ning geofence ei tohi muuta aluseks olevat staatust ega pakkuda valvesse kinnitamist. Plaani lõppedes tee värske asukohakontroll; väljaspool raadiust peab tulema mitte valves, tagasitulek nõuab kinnitust. 24 tunni aegumispiir jääb kehtima ka planeeritud mittevalve ajal.
