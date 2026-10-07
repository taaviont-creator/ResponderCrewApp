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
- Väljavõte koostatakse valitud andmelaua jaotise ja filtrite järgi. CSV on üks päistega tabel; periood on failinimes. PDF sisaldab lisaks ühingut, perioodi ja filtreid. Kõik filtrile vastavad read eksporditakse, mitte ainult nähtav tabelileht.

## Statistika andmelaud (07.10.2026)

Ühes vaates on jaotised **Ühing**, **Minu statistika**, **Liikmed**, **Sündmused**, **Panused** ja **Tunnistused**. Ühingu ülevaates on valveaja ja kinnitatud panuse võrdlused, väljakutsete SAR/Trossi jaotus ning viimased panused. Punktikaale ei mõelda välja. Võrdlusest liikmele vajutamine avab tema filtreeritud statistika. Isiklikust vaatest panuste loendisse liikumine säilitab liikme valiku.

- Aastavalik, „See kuu” ja kalendriga kuupäevavahemik uuendavad sama serveriarvutust. Liikme-, liigi-, oleku- ja tekstifiltrid töötavad samas vaates; filtri tühjendamine on selge eraldi tegevus.
- Sündmused: SAR/Tross, olek, kinnitatud osaleja ja pealkirja/ID otsing. Detail näitab tegelikku kinnitatud meeskonda. Sündmuste eksport sisaldab kogu meeskonda; osalemiste CSV sisaldab valitud liikmefilteri korral ainult tema osalemisi. Puuduv `eventDetails` vanast serverist kuvatakse andmete puudumisena, mitte null sündmusena.
- Panused: liige, kategooria, kinnitatud/ootel ja tekst. Ootel tunnid ei suurenda kinnitatud koondit. Varasema tegevuse osalemisi ei kopeerita uueks panuseks.
- Tunnistused: liik, liige, tekst, aegunud / 30 päeva jooksul aeguvad / kehtivad / tähtajatud / teadmata kehtivusega kirjed. Vaikimisi näidatakse hetkeseisu sõltumata tegevuste perioodist. Valikuliselt saab perioodi rakendada väljastamise või aegumise kuupäevale. See ei ole ajaloolise tunnistusseisu rekonstruktsioon. Puuduv tunnistuse dokument ei tähenda automaatselt puuduvat pädevust; „Puudub” näitab vastava olekuga olemasolevaid kirjeid.
- Adminil on **Ekspordi → CSV tabel / PDF kokkuvõte**, sündmustel ka **Osalemised CSV**. Veebis algab faili allalaadimine, töölaual saab valida salvestuskoha, Androidis/iOS-is kasutatakse failiga süsteemset jagamis-/salvestusvaadet. CSV kasutab UTF-8 BOM-i, semikoolonit, jutumärkide kaitset ja valemilaadse kasutajateksti neutraliseerimist. Tühjad tunnid erinevad nullist.
- Telefonis kuvatakse tabeli read loetavate kirjetena, arvutis tabelina; lehel on kuni 15 rida, eksport sisaldab kõiki tulemusi. Põhivõrdlustes kuvatakse kuni kaheksa liiget, täielik nimekiri on „Liikmed” jaotises.

Õigused säilivad: statistika lugemine järgib olemasolevat ühingu õigust. Tavaliige alustab isiklikust vaatest, näeb oma tunnistusi ja panuseid ning lubatud ühingu/liikmete koondit, kuid mitte admini sündmuste väljavõtteid ega eksporti. Tunnistuste organisatsioonipäring kasutab olemasolevat `CertificateService` päringut ja Firestore'i admini lugemisõigust. Rolli või ühingu vahetamisel tühjendatakse valik ja laaditud tunnistused. Firestore'i skeemi, Security Rules'i ja Cloud Functions'i see andmelaua uuendus ei muuda.

Kontroll: 306 Flutteri testi läbivad; `flutter analyze` puhas. Regressioonid katavad filtrite ja ekspordi vastavust, kõigi 20 rea eksporti 15-realise lehekülje korral, PDF-i pikki meeskonnanimekirju ja täpitähti, tunnistuste aegumise piire, tundmatuid väärtusi, CSV kaitset, rolli/ühingu vahetust, veaseisu ning 320-pikslist vaadet suurendatud kirjaga. Tegelikud Flutteri vaated renderdati telefoni ja arvuti mõõtmetes. Päris telefoni faili jagamisvaate kontroll jääb APK seadmekatsesse.

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
