# Operatsioonilogi ajaloo ja väljavõtte parandus

Sündmused salvestati `operationLogs/{logId}/events` alla koos serveri kellaaja
ja võimalusel GPS-koordinaatidega. Ajaloo päringul puudus ühingufilter, kuigi
Firestore'i reeglid lubavad tavakasutajal lugeda ainult oma ühingu sündmusi.
Seetõttu võis kirjutamine õnnestuda, kuid ajajoon ei avanenud. Emulaatoritest
taasesitab vana päringu keeldumise ja parandatud päringu õnnestumise.

Päring kasutab nüüd sama organizationId/commandId filtrit nagu ülejäänud
ühingu vaated. Olemasolevad edukalt salvestatud sündmused muutuvad loetavaks;
andmeid ei migreerita ega kirjutata ümber. Puuduvat GPS-i ei saa tagantjärele
taastada ja seda ei oletata mõne teise sündmuse asukoha järgi.

Logikaardi avamisel on nupp **Vaata väljavõtet**. Väljavõte sisaldab kuupäeva,
kellaaega sekunditega, tegevusi ja märkusi ajalises järjestuses, salvestatud
GPS-i koos täpsusega ning sisestatud lõppkokkuvõtet ja tulemust. Kogu teksti
saab kopeerida. Puuduv asukoht või kellaaeg on selgelt märgitud. Lugemisviga
ei kuvata tühja eduka väljavõttena.

Lõppkokkuvõtte sisestamine ja muutmine on lubatud ka pärast **Baasis**
vajutamist. Muutub ainult lubatud lõppolekute hulk; senine kirjutamisõigus,
ühingu eraldatus ja muutumatud väljad säilivad. Kontrollitud on lubatud
kokkuvõtte/auditikirje atomaarne salvestus ja keelatud kasutajate katsed.
See on kitsas olemasolevate reeglite parandus, mitte kogu reeglistiku audit.

## Telefonis kontrollimiseks

1. Ava varem täidetud logi, laienda kaart ja vali **Vaata väljavõtet**.
2. Kontrolli olemasolevate tegevuste kellaaegu ja GPS-i; võrdle ajajoonega.
3. Lisa testlogile märge asukohaloaga ja teine ilma asukohata. Sulge ning ava
   logi uuesti. Mõlemad märkmed peavad säilima, puuduv GPS olema selgelt märgitud.
4. Lõpeta testoperatsioon ja vajuta **Baasis**. Lisa lõppkokkuvõte ning tulemus.
   Ava logi uuesti ja kontrolli, et need koos ajalooga väljavõttes säilivad.
5. Kopeeri väljavõte ning veendu, et tekst sisaldab kõiki salvestatud sündmusi
   üks kord. Kontrolli teise ühingu kontoga ligipääsu puudumist.

Päris-seadme kontroll jääb pärast uue äpi paigaldamist tegemiseks.

## 06.10.2026 — korduv avamine ja aruande varustuse juhtumid

Logikaart hoidis ühekordse tellimusega õiguste andmevoogu alles ka pärast
kokkupanemist. Uuesti avamine proovis sama voogu uuesti kuulata. Õiguste paneel
omab nüüd andmevoogu ainult avatud paneeli eluea jooksul; uus avamine loob uue
tellimuse. Õiguste vead jäävad suletuks, logi lugemisõigus ei laiene.

Aruande uute kasutatud varustuse seoste valik piirdub kategooriatega `vessel`,
`engine`, `trailer`, `vehicle`, `machinery`. Sama piirang kehtib serveris.
Varem seotud muu/kategooriata varustus säilib vana aruande ajaloona ja selle
seose saab eemaldada. Uusi kategooriata kirjeid ei oletata tehnikaks.

`calloutReports.equipmentIncidents` on valikuline nimekiri (kuni 50 kirjet):
`name` (kuni 200), `status` (`damaged` / `lost`), `description` (kuni 2000).
Sisestada võib ka registrisse kandmata või isikliku varustuse juhtumi.
Need on aruande faktid, mitte varustuse registri automaatsed olekumuudatused.
Kirjed kuvatakse aruandes ja PDF-is. Senine revision-kontroll, reportHistory
ja platformAudit jäävad kasutusse; muuta saavad ühingu admin ja II aste,
lugeda aktiivne liige. Vana klient, mis uut välja ei saada, ei kustuta kirjeid.
Firestore reegleid ega olemasolevaid dokumente ei migreerita.

Regressioonid: esimese ja korduva avamise 360 px paigutus; tehnika valik;
kaotatud raadio sisestamine ja salvestamine; liikme lugemisvaade; serveri
õigused, kategooriad, vigane sisend, audit ja vanema kliendi ühilduvus.
Telefonis kontrollida sama logi mitu korda avamist/sulgemist ning juhtumi
salvestamist, uuesti avamist ja PDF-i. APK-d selles etapis ei koostata.
