# Liitumistaotluste märguanded

Admini avaleht ja Teavitused kuvavad aktiivse ühingu ootel taotluste arvu.
Märguanne avab liikmete kinnitamise vaate ning kaob pärast viimase taotluse
lahendamist. See töötab ka enne uuendust esitatud taotlustega.

`sendMemberRequestNotification` jälgib liikmesuse loomist ja muutmist piirkonnas
`europe-north1`. Uus tavalise liikme pending-taotlus, sealhulgas eemaldatud
liikme taasliitumine, saadab tavalise push-teavituse sama ühingu aktiivsetele
adminidele. Ühingu loomine, ootel taotluse muutmine ja kinnitamine/tagasilükkamine
push'i ei tekita. Vanadele taotlustele tagasiulatuvat push'i ei saadeta.

Push kasutab `member_requests` kanalit, mitte väljakutse alarmikanalit.
Teavituse avamine kontrollib praegust admini liikmesust, valib õige ühingu ja
avab liikmete vaate. Äpi eesplaani, tausta ja külmkäivituse teavitused kasutavad
sama sihtühingut. SMTP seadistust pole vaja.

Sündmuse serveripoolne saatmiskanne väldib sama sündmuse korduvast töötlusest
tulenevaid topeltteavitusi. Kanne tehakse enne FCM-i saatmist; ebaselge
saatmisvea järel automaatset kordussaatmist ei tehta. Äpi reaalajas taotluste
loend säilib ka siis, kui telefon push'i ei saa. Saatmisarvud ja vead on
Functions'i logides. Telefoni jõudmist kinnitab ainult seadmetest.

## Päris-seadme katse (tegemata)

1. Paigalda uus äpiversioon admini telefoni ja luba teavitused. Ava äpp vähemalt
   korra, et registreerida seade ja uus teavituskanal.
2. Esita teiselt testkontolt ühingu A liitumistaotlus. A admin näeb märguannet
   avalehel ja Teavitused vaates; tavaliige ning ainult B admin seda ei näe.
3. Korda uue testtaotlusega äpi eesplaanil, taustal ja lukustatud telefoniga.
   Saabub üks tavaline teavitus; väljakutse alarmi ei kasutata.
4. Hoia adminil aktiivsena ühing B, vajuta A teavitusele. Avaneb A liikmete
   kinnitamise vaade. Kontrolli ka tavapäraselt suletud äpist avamist.
5. Kinnita või lükka tagasi taotlus. Ootel arv väheneb kõigis avatud vaadetes.
   Viimase taotluse lahendamisel märguanne kaob.
6. Eemaldatud testliikme uus taotlus annab uue märguande. Korduv katse juba
   ootel taotlusega ei tekita uut push'i. Vana teavitus pärast admini õiguse
   eemaldamist ei ava kinnitamise vaadet.

Automaattestid katavad adminide valiku ja ühingute eraldatuse, sündmuste
kordused, taasliitumise, vahepeal lahendatud taotlused, seadmeteta saajad,
FCM-i partiipiiri ning teavituse sihtühingu kodeerimise.
