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
