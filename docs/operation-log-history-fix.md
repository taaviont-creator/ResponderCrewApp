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
