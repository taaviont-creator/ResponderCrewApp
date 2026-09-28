# Panuse ja valveaja statistika

Statistika kasutab valitud kuupäevavahemikku (mõlemad kuupäevad kaasa arvatud, kuni 366 päeva). Server arvutab kalendripäevad ja korduvad eemalolekud Europe/Tallinn ajavööndis.

- Valves oldud tunnid on aktiivse liikmesuse ja `onDuty` staatuse kattuv aeg, millest lahutatakse aktiivsed planeeritud eemalolekud. Kattuvaid eemalolekuid ei lahutata mitu korda. `delayed` aeg kuvatakse eraldi.
- Ajalugu algab `statisticsSettings/tracking.startedAt` serveriajast. Varasemaid valvetunde ei oletata; puuduv või veel uuenev ajalugu kuvatakse kriipsuna.
- Nelja lähtekollektsiooni muutused salvestatakse serveris: availability, memberships, plannedUnavailability, plannedUnavailabilityRules. Ajalookirje tunnus sõltub sündmuse ID-st, kordustarne ei tekita duplikaati. Kasutajad ei saa ajalugu ega algusaega lugeda või muuta.
- Tegevuste panus kasutab tegevuse kuupäeva, admini kinnitatud osalemist ja kinnitatud tunde. Hooldus, remont, heakord/niitmine, koolitus, harjutus jm on eraldi kategooriad. Puuduvaid tunde näidatakse eraldi.
- „Lisa panus” loob tavalise tegevuse ja selle osalemised. Admin võib valida mitu aktiivset liiget; liige saab esitada ainult enda panuse, mis vajab admini kinnitust. Sama salvestuse kordus ei loo uut tegevust. Olemasolevat tegevust ei ole vaja uuesti sisestada.
- Väljakutse „reageerin”/„hilinen” vastus on kavatsus, mitte kinnitatud osalemine. Admin kinnitab tegelikud osalejad väljakutse detailis nupuga „Kinnita osalemised”. Tunde võib lisada hiljem; osalemist saab parandada. Tühistatud väljakutsed ei lähe statistikasse.
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
