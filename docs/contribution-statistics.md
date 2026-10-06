# Panuse ja valveaja statistika

Statistika kasutab valitud kuupäevavahemikku (mõlemad kuupäevad kaasa arvatud, kuni 366 päeva). Server arvutab kalendripäevad ja korduvad eemalolekud Europe/Tallinn ajavööndis.

- Valves oldud tunnid on aktiivse liikmesuse ja `onDuty` staatuse kattuv aeg, millest lahutatakse aktiivsed planeeritud eemalolekud. Kattuvaid eemalolekuid ei lahutata mitu korda. `delayed` aeg kuvatakse eraldi.
- Ajalugu algab `statisticsSettings/tracking.startedAt` serveriajast. Varasemaid valvetunde ei oletata; puuduv või veel uuenev ajalugu kuvatakse kriipsuna.
- Nelja lähtekollektsiooni muutused salvestatakse serveris: availability, memberships, plannedUnavailability, plannedUnavailabilityRules. Ajalookirje tunnus sõltub sündmuse ID-st, kordustarne ei tekita duplikaati. Kasutajad ei saa ajalugu ega algusaega lugeda või muuta.
- Tegevuste panus kasutab tegevuse kuupäeva, admini kinnitatud osalemist ja kinnitatud tunde. Hooldus, remont, heakord/niitmine, koolitus, harjutus jm on eraldi kategooriad. Puuduvaid tunde näidatakse eraldi.
- Menüü → **Panus** avab tehtud töö ülevaate; kõrval olev **Lisa panus** avab vormi ühe vajutusega. Vormis on nimetus, kategooria, kalendrikuupäev, tunnid ja valikuline kirjeldus. Admin valib liikmed linnukestega; valikuta läheb panus sisestajale. Liige saab esitada ainult enda panuse ka siis, kui tal puudub tegevuste planeerimise või ühingu statistika vaatamise õigus. Need õigused ei laiene.
- Liikme panus jääb olekusse „Ootab admini kinnitust”. Admin näeb kõiki ühingu panuseid ja ootel filtrit, kinnitab tegeliku osalemise ning saab tunde parandada. Admini sisestatud töö kinnitatakse kohe. Liige näeb Panuse vaates enda kirjeid. Statistikasse lähevad kinnitatud tunnid; tagasilükatud/mittekinnitatud osalemist ei loeta kinnitatud panuseks.
- Panus kasutab samu `activities` ja `activityParticipants` dokumente ning olemasolevat statistika arvutust. Server lisab tegevusele `entryKind: contribution`; vana `contribution_` ID algusega kirje tuntakse ära ilma migratsioonita. Tavalise tegevuse vaikimisi liik on `scheduled`. Panused ei ilmu planeeritud tegevuste kalendrisse, lähiaja nimekirja ega RSVP valikutesse. Varem planeeritud tegevuse osalemine tuleb kinnitada selle tegevuse juures, mitte uuesti panusena lisada. Sama salvestuse kordus ei loo uut tegevust.
- Panuse koostamine käib `recordMemberContribution` serverifunktsiooni kaudu (aktiivne liikmesus, kuni 50 osalejat, üle 0 kuni 24 t osaleja kohta, mitte tulevikus, kirjeldus kuni 2000 märki). Klient ei saa võltsida panuse liigitust ega panusele RSVP-ga ise lisanduda; liikme enda kinnitamine ja teise ühingu muutmine on keelatud. Admini olemasolev osalemiskinnitamise õigus säilib. `getContributionStatistics` tagastab panuse lisamise ja planeerimise õigused eraldi.
- Väljakutse „reageerin”/„hilinen” vastus on kavatsus, mitte kinnitatud osalemine. Admin või sama ühingu aktiivne II astme liige kinnitab tegelikud osalejad väljakutse detailis nupuga „Kinnita osalemised”. Tunde võib lisada hiljem; osalemist saab parandada. Tühistatud väljakutsed ei lähe statistikasse.
- Valvetunnid ei liitu panuse tundidega. Panuse tunnid on kinnitatud tegevuste ja väljakutsete osalemistunnid; mitu liiget samal tegevusel tähendab mitut osalemist.
- CSV sisaldab perioodi, valveajaloo algust, liikmete koondit ja kuupäevadega alusandmeid.

## Avaldamise järjekord

Avalda Firestore reeglid ning seitse uut funktsiooni: getContributionStatistics, recordMemberContribution, saveCalloutAttendance, recordAvailabilityHistory, recordMembershipHistory, recordAbsenceHistory, recordAbsenceRuleHistory. Kontrolli, et kõik neli ajaloo salvestajat on ACTIVE ja retry lubatud.

Alles seejärel loo serveri ajatempli abil `statisticsSettings/tracking.startedAt`, kui dokumenti veel ei ole. Kasuta create-only eeltingimust (exists=false). Olemasolevat algusaega ei tohi uuesti seadistada: see lõikaks varasema ajaloo statistikast välja. Algusaeg ei muuda liikmete staatuseid ega tegevusi.

## Telefoni kontroll

1. Vali valves, oota mõni minut; statistikas peab suurenema valveaeg. Lisa selle sisse planeeritud eemalolek ning kontrolli, et selle kattuv osa ei kogune valvetundideks. Hilinemisega olek peab kogunema eraldi.
2. Lisa „Heakord / niitmine”, 1,5 t. Admini kinnitusel peab see ilmuma õige liikme kategoorias ja kuupäevaga tööde loetelus. Tavaliikme esitatud panus peab enne kinnitamist jääma ootele.
3. Vasta väljakutsele „reageerin”: kinnitatud väljakutsete arv ei tohi veel kasvada. Kinnita adminina osalemine ja 2 t; arv ja tunnid peavad kasvama ühe korra. Märgi „Ei osalenud” ning kontrolli parandust.
4. Vaheta perioodi ja ühingut; koond ja CSV peavad näitama valitud perioodi/ühingut. Teise ühingu andmeid ei tohi kaasa tulla.

Telefonis tehtud katset ei asenda automaattestid. Varasemad väljakutsed vajavad tegeliku osalemise tagantjärele kinnitamist; varasemad kinnitatud tegevused on kuupäeva järgi arvestuses olemas.

## Osalejad operatsioonilogis

Väljakutsega seotud logis on osalejate nimekiri ja „Muuda osalejaid”. See kasutab sama calloutAttendance kirjet nagu väljakutse detail ja statistika; teist nimekirja ei teki. Admin ja aktiivne II astme liige saavad osalemist ning tunde muuta aktiivsel või lõppenud väljakutsel. Osalejad on sama ühingu aktiivsetele liikmetele logis nähtavad.

Iga tegelik muudatus salvestub serveris callouts/{calloutId}/attendanceHistory alla koos eelmise/uue väärtuse, muutja ja serveriajaga. Sama väärtuse kordussalvestus auditit ei dubleeri. Klient ei saa auditikirjeid kirjutada ega üle kirjutada. Logi väljavõte sisaldab osalejaid ning muudatuste ajalugu.

II astme liikme logi alustamise/täiendamise õigus ei sõltu üldisest tavaliikmete logiõiguse lülitist. Tavalistele liikmetele varem antud lülitiõigus säilib. See ei anna tavaliikmele osalemiskinnitamise õigust.

„Lisa märge või täiendus” võimaldab „Lisa tagantjärele” valikuga määrata tegeliku sündmuse kuupäeva ja kellaaja. Ajajoon järjestab selle tegeliku aja järgi ning näitab eraldi salvestamise aega ja autorit. Algseid sündmusi ei kirjutata ümber. Lõppkokkuvõtet saab pärast lõpetamist muuta; iga salvestus säilitab kokkuvõtte teksti ajalookandes. Võrguvea korral jäävad märkus ja kokkuvõte avatud vormi alles. Väljavõte saab värskendatud kokkuvõtte reaalajas.
