# RespondCrew MVP käsitsi testimise kontrollnimekiri

See kontrollnimekiri on mõeldud käsitsi suitsutestiks emulaatoris või telefonis. Märgi iga testi juures, kas tulemus vastas ootusele, ja lisa märkustesse seadme, kasutaja või vea detailid.

## Testija juhised

- Testi võimalusel puhta rakenduse seisuga: logi enne rolli vahetamist välja.
- Kasuta eraldi kontosid tavaliikme, ühingu admini ja platvormi halduri jaoks.
- Ära paranda testimise ajal andmeid käsitsi Firestore'is, kui test ei ütle seda eraldi ette.
- Kui samm ebaõnnestub, tee ekraanipilt ja kirjuta märkustesse kasutaja, ühing ja kellaaeg.
- Turvatestides kontrolli, et keelatud tegevus ei õnnestu ning kasutaja saab arusaadava teate või ei näe vastavat nuppu/vaadet.

## Testirollid

- Tavaliige: tavaline ühingu liige ilma admini õigusteta.
- Ühingu admin: ühingu administraator, kes saab hallata liikmeid, varustust, tunnistusi ja väljakutseid.
- Platvormi haldur: platvormi halduri rolliga kasutaja, kes saab kinnitada või tagasi lükata uusi ühinguid.

## Soovitatud testandmed

- Vähemalt 2 ühingut: üks kinnitatud ja üks eraldi ristkontrolliks.
- 3 kasutajat: tavaliige, ühingu admin, platvormi haldur.
- Üks ootel ühing, üks kinnitatud ühing ja üks tagasi lükatud ühing.
- Üks ootel kutse ja üks tühistatud kutse.
- Üks aktiivne väljakutse.
- Vähemalt üks isiklik varustus ja üks ühingu varustus.
- Üks tegevus/koolitus.
- Üks tunnistus: kehtiv, aegumas või aegunud seisundi kontrolliks.

## AUTH

### AUTH-01 - Sisselogimine õnnestub
- ID: AUTH-01
- Roll: Tavaliige
- Eeldused: Kasutajal on olemas konto.
- Sammud:
  1. Ava rakendus.
  2. Sisesta e-post ja parool.
  3. Vajuta "Logi sisse".
- Oodatud tulemus: Kasutaja jõuab avalehele ja näeb oma aktiivse ühingu vaadet või onboarding-vaadet.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### AUTH-02 - Vale parool näitab veateadet
- ID: AUTH-02
- Roll: Tavaliige
- Eeldused: Kasutajal on olemas konto.
- Sammud:
  1. Ava sisselogimise vaade.
  2. Sisesta õige e-post ja vale parool.
  3. Vajuta "Logi sisse".
- Oodatud tulemus: Sisselogimine ei õnnestu ja kuvatakse arusaadav veateade.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### AUTH-03 - Konto loomine
- ID: AUTH-03
- Roll: Tavaliige
- Eeldused: Testimiseks on uus e-posti aadress.
- Sammud:
  1. Ava "Loo konto".
  2. Sisesta nimi, e-post ja parool.
  3. Vajuta "Loo konto".
- Oodatud tulemus: Konto luuakse, kasutaja saab tagasi sisselogimise vaatesse või saab sisse logida. Ühingut ei looda automaatselt.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### AUTH-04 - Väljalogimine
- ID: AUTH-04
- Roll: Tavaliige
- Eeldused: Kasutaja on sisse logitud.
- Sammud:
  1. Ava menüü või toimingud.
  2. Vali väljalogimine.
- Oodatud tulemus: Kasutaja viiakse sisselogimise vaatesse ja kaitstud vaated ei ole enam nähtavad.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## ORG

### ORG-01 - Uue ühingu loomine saadab kinnitamisele
- ID: ORG-01
- Roll: Tavaliige
- Eeldused: Kasutajal ei ole aktiivset ühingut või ta saab luua uue ühingu.
- Sammud:
  1. Ava avalehel ühingu loomise toiming.
  2. Sisesta ühingu nimi.
  3. Kinnita loomine.
- Oodatud tulemus: Rakendus ütleb, et ühing saadeti kinnitamisele. Kasutaja näeb ootel kinnituse seisundit.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### ORG-02 - Platvormi haldur kinnitab ühingu
- ID: ORG-02
- Roll: Platvormi haldur
- Eeldused: On olemas ootel ühing.
- Sammud:
  1. Ava "Ootel ühingud".
  2. Leia testühing.
  3. Vajuta "Kinnita".
- Oodatud tulemus: Ühing muutub kinnitatuks ja looja saab ühingut kasutada.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### ORG-03 - Tagasi lükatud ühingu seisund
- ID: ORG-03
- Roll: Platvormi haldur ja ühingu looja
- Eeldused: On olemas teine ootel ühing.
- Sammud:
  1. Platvormi haldur lükkab ühingu tagasi.
  2. Ühingu looja logib sisse.
- Oodatud tulemus: Looja näeb, et ühingut ei kinnitatud, ja ei saa seda aktiivse ühinguna kasutada.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### ORG-04 - Liitumine liitumiskoodiga
- ID: ORG-04
- Roll: Tavaliige
- Eeldused: Kinnitatud ühingul on liitumiskood.
- Sammud:
  1. Ava "Liitu ühinguga".
  2. Sisesta liitumiskood.
  3. Kinnita.
- Oodatud tulemus: Kasutaja liitub ühinguga ja saab selle aktiivseks valida.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### ORG-05 - Kutse vastuvõtmine
- ID: ORG-05
- Roll: Tavaliige
- Eeldused: Ühingu admin on saatnud kasutaja e-postile kutse.
- Sammud:
  1. Logi kutsutud kasutajana sisse.
  2. Leia ootel kutse.
  3. Vajuta "Võta kutse vastu".
- Oodatud tulemus: Kutse aktsepteeritakse, kasutaja liitub ühinguga ja kutse kaob ootel kutsete hulgast.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### ORG-06 - Tühistatud kutset ei saa vastu võtta
- ID: ORG-06
- Roll: Tavaliige
- Eeldused: Ühingu admin on kutse tühistanud.
- Sammud:
  1. Logi kutsutud kasutajana sisse.
  2. Kontrolli ootel kutseid.
- Oodatud tulemus: Tühistatud kutset ei saa vastu võtta ja see ei anna ligipääsu ühingule.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:


### ORG-07 - Lahkunud liikme uuesti liitumine
- ID: ORG-07
- Roll: Tavaliige
- Eeldused: Kasutaja lahkus varem kinnitatud ühingust ning tema liikmesuse `status` on `removed` ja `isActive` on `false`.
- Sammud:
  1. Logi lahkunud kasutajana sisse.
  2. Ava "Liitu koodiga".
  3. Sisesta sama kinnitatud ühingu liitumiskood.
  4. Kinnita liitumine.
- Oodatud tulemus: Olemasolev eemaldatud liikmesus aktiveeritakse uuesti, kasutaja roll on Liige, merepääste aste on Määramata ja ühing muutub aktiivseks.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## HOME

### HOME-01 - Avalehe kompaktne päis ja aktiivne ühing
- ID: HOME-01
- Roll: Tavaliige
- Eeldused: Kasutajal on aktiivne ühing.
- Sammud:
  1. Ava avaleht.
  2. Kontrolli päist, aktiivset ühingut ja oma valmisoleku olekut.
- Oodatud tulemus: Päis on kompaktne, aktiivne ühing on arusaadav ja oma olekut saab kiiresti näha.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### HOME-02 - Ühingu vahetamine
- ID: HOME-02
- Roll: Tavaliige
- Eeldused: Kasutaja kuulub vähemalt kahte ühingusse.
- Sammud:
  1. Ava ühingu vahetamise toiming.
  2. Vali teine ühing.
- Oodatud tulemus: Aktiivne ühing muutub ja moodulid näitavad valitud ühingu andmeid.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### HOME-03 - Toimingud ja ühingu valmisolek
- ID: HOME-03
- Roll: Ühingu admin
- Eeldused: Adminil on aktiivne ühing.
- Sammud:
  1. Ava avalehel Toimingud või admini kiirtegevused.
  2. Kontrolli "Ühingu valmisolek" kokkuvõtet.
- Oodatud tulemus: Admin näeb valmisoleku kokkuvõtet, miinimumkoosseisu ja vajalikke toiminguid.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## READY

### READY-01 - Valves, Hilinen, Ei ole valves
- ID: READY-01
- Roll: Tavaliige
- Eeldused: Kasutajal on aktiivne ühing.
- Sammud:
  1. Ava Valmisolek.
  2. Määra olekuks "Valves".
  3. Määra olekuks "Hilinen" ja sisesta minutid.
  4. Määra olekuks "Ei ole valves".
- Oodatud tulemus: Iga olek salvestub ja kuvatakse kasutaja profiilis ning ühingu valmisolekus.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### READY-02 - Planeeritud mittevalves aeg
- ID: READY-02
- Roll: Tavaliige
- Eeldused: Kasutajal on aktiivne ühing.
- Sammud:
  1. Lisa planeeritud mittevalves aeg.
  2. Kontrolli, et see ilmub loendis.
  3. Tühista kirje.
- Oodatud tulemus: Kirje lisandub, mõjutab valmisoleku põhjuseid ning tühistamine eemaldab aktiivse mõju.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### READY-03 - Korduv mittevalves reegel
- ID: READY-03
- Roll: Tavaliige
- Eeldused: Kasutajal on aktiivne ühing.
- Sammud:
  1. Lisa korduv mittevalves aeg nädalapäevade ja kellaaegadega.
  2. Kontrolli loendit ja valmisoleku põhjuseid.
  3. Tühista reegel.
- Oodatud tulemus: Reegel salvestub, kuvatakse loendis ja seda saab tühistada.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### READY-04 - Miinimumkoosseis ja II aste
- ID: READY-04
- Roll: Ühingu admin
- Eeldused: Ühingus on vähemalt üks I/II astme liige.
- Sammud:
  1. Ava ühingu valmisoleku seaded.
  2. Muuda miinimumkoosseisu.
  3. Kontrolli valmisoleku kokkuvõtet ja II astme nõude vihjet.
- Oodatud tulemus: Miinimumkoosseis salvestub ning kokkuvõte näitab, kas nõuded on täidetud ja miks mitte.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## MEMBER

### MEMBER-01 - Oma profiil ja kontaktandmed
- ID: MEMBER-01
- Roll: Tavaliige
- Eeldused: Kasutaja on sisse logitud.
- Sammud:
  1. Ava "Minu profiil".
  2. Muuda nime või telefoni.
  3. Salvesta.
- Oodatud tulemus: Muudatus salvestub ja on profiilis nähtav.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### MEMBER-02 - Admin näeb liikme profiili ülevaadet
- ID: MEMBER-02
- Roll: Ühingu admin
- Eeldused: Ühingus on vähemalt üks tavaliige.
- Sammud:
  1. Ava Liikmed.
  2. Ava tavaliikme profiil.
  3. Kontrolli valmisoleku, varustuse, tunnistuste ja tegevuste panuse jaotisi.
- Oodatud tulemus: Admin näeb liikme tööks vajalikku ülevaadet.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### MEMBER-03 - Rolli ja merepääste astme muutmine
- ID: MEMBER-03
- Roll: Ühingu admin
- Eeldused: Ühingus on tavaliige, kelle rolli ja merepääste astet saab muuta.
- Sammud:
  1. Ava liikme profiil.
  2. Muuda merepääste astet.
  3. Muuda rolli.
- Oodatud tulemus: Muudatused salvestuvad. Merepääste aste kuvatakse eraldi tunnistustest.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## CALLOUT

### CALLOUT-01 - Admin loob väljakutse
- ID: CALLOUT-01
- Roll: Ühingu admin
- Eeldused: Adminil on aktiivne ühing.
- Sammud:
  1. Ava Väljakutsed.
  2. Vajuta "Uus väljakutse".
  3. Sisesta pealkiri, kirjeldus, asukoht ja prioriteet.
  4. Salvesta.
- Oodatud tulemus: Väljakutse ilmub aktiivsete väljakutsete alla.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### CALLOUT-02 - Liige vastab väljakutsele
- ID: CALLOUT-02
- Roll: Tavaliige
- Eeldused: Ühingus on aktiivne väljakutse.
- Sammud:
  1. Ava väljakutse.
  2. Vajuta "Tulen".
  3. Muuda vastuseks "Hilinen" ja vali minutid.
  4. Muuda vastuseks "Ei tule".
- Oodatud tulemus: Vastus salvestub, oma vastus on nähtav ja hilinemise minutid kuvatakse.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### CALLOUT-03 - Admini vastuste ülevaade ja II aste
- ID: CALLOUT-03
- Roll: Ühingu admin
- Eeldused: Väljakutsele on vastanud mitu liiget, sh II astmega liige.
- Sammud:
  1. Ava väljakutse detailvaade.
  2. Kontrolli meeskonna vastuste ülevaadet.
  3. Kontrolli II astme reageerija vihjet.
- Oodatud tulemus: Admin näeb vastuste jaotust, II astme infot ja loojat ei loeta automaatselt reageerijaks.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## OPLOG

### OPLOG-01 - Operatsioonilogi avamine väljakutselt
- ID: OPLOG-01
- Roll: Ühingu admin
- Eeldused: On aktiivne väljakutse.
- Sammud:
  1. Ava väljakutse detailvaade.
  2. Ava või loo operatsioonilogi.
- Oodatud tulemus: Operatsioonilogi avaneb sama väljakutse kontekstis.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### OPLOG-02 - Kiirtegevused, märge ja ajajoon
- ID: OPLOG-02
- Roll: Ühingu admin
- Eeldused: Operatsioonilogi on avatud.
- Sammud:
  1. Lisa üks kiirtegevus.
  2. Lisa käsitsi märge.
  3. Kontrolli ajajoont.
- Oodatud tulemus: Sündmused ilmuvad ajajoonele õiges järjekorras.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### OPLOG-03 - Lõpetatud olek ja lõppkokkuvõte
- ID: OPLOG-03
- Roll: Ühingu admin
- Eeldused: Operatsioonilogi on olemas.
- Sammud:
  1. Muuda logi lõpetatud olekusse.
  2. Lisa lõppkokkuvõte ja tulemus.
  3. Proovi sama tavaliikmena.
- Oodatud tulemus: Admin saab kokkuvõtte salvestada. Tavaline liige ei saa lubamatut kokkuvõtet muuta.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## EQUIP

### EQUIP-01 - Isiklik ja ühingu varustus
- ID: EQUIP-01
- Roll: Ühingu admin ja Tavaliige
- Eeldused: Ühingus on liikmeid.
- Sammud:
  1. Lisa isiklik varustus tavaliikmena.
  2. Lisa ühingu varustus adminina.
  3. Kontrolli loendeid.
- Oodatud tulemus: Isiklik varustus on seotud liikmega, ühingu varustus on ühingu all.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### EQUIP-02 - Väljastamine ja tagastamine
- ID: EQUIP-02
- Roll: Ühingu admin
- Eeldused: On olemas saadaval ühingu varustus ja vähemalt üks liige.
- Sammud:
  1. Ava varustus.
  2. Väljasta ese liikmele.
  3. Kontrolli seisundit "Väljastatud".
  4. Märgi ese tagastatuks.
- Oodatud tulemus: Seisund muutub "Saadaval" ja "Väljastatud" vahel ning liikme profiilis on varustus nähtav.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## ACT

### ACT-01 - Tegevuse/koolituse loomine
- ID: ACT-01
- Roll: Ühingu admin
- Eeldused: Adminil on aktiivne ühing.
- Sammud:
  1. Ava Tegevused ja koolitused.
  2. Lisa uus tegevus/koolitus.
- Oodatud tulemus: Tegevus ilmub tulevaste tegevuste loendis.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### ACT-02 - Osalemine ja kinnitatud tunnid
- ID: ACT-02
- Roll: Tavaliige ja Ühingu admin
- Eeldused: On olemas tegevus/koolitus.
- Sammud:
  1. Tavaliige märgib osalemise.
  2. Admin kinnitab osalemise.
  3. Admin sisestab kinnitatud tunnid.
- Oodatud tulemus: Osalemine ja tunnid salvestuvad ning ilmuvad statistikas ja liikme profiili panuses.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## CERT

### CERT-01 - Oma tunnistused
- ID: CERT-01
- Roll: Tavaliige
- Eeldused: Kasutajal on aktiivne ühing.
- Sammud:
  1. Ava Tunnistused.
  2. Kontrolli oma tunnistuste loendit.
- Oodatud tulemus: Liige näeb enda tunnistusi, mitte teiste liikmete privaatseid andmeid.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### CERT-02 - Admini tunnistuste vaade
- ID: CERT-02
- Roll: Ühingu admin
- Eeldused: Ühingus on liikmeid.
- Sammud:
  1. Ava Tunnistused.
  2. Lisa liikmele tunnistus.
  3. Kontrolli kehtivat, aeguvat ja aegunud seisundit.
- Oodatud tulemus: Admin näeb ühingu tunnistusi ja seisundid on arusaadavad.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### CERT-03 - Merepääste aste on eraldi
- ID: CERT-03
- Roll: Ühingu admin
- Eeldused: Liikmel on merepääste aste ja tunnistus.
- Sammud:
  1. Ava liikme profiil.
  2. Ava Tunnistused.
- Oodatud tulemus: Merepääste aste kuvatakse eraldi liikmelisuse all, mitte tunnistusena.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## STAT

### STAT-01 - Admini statistika ja CSV
- ID: STAT-01
- Roll: Ühingu admin
- Eeldused: Ühingus on liikmeid, varustust, tegevusi ja tunnistusi.
- Sammud:
  1. Ava Statistika.
  2. Kontrolli koondandmeid.
  3. Vajuta "Kopeeri CSV lõikelauale".
- Oodatud tulemus: Statistika avaneb ja CSV kopeerimine annab kinnituse.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### STAT-02 - Liikme ligipääs statistikale
- ID: STAT-02
- Roll: Tavaliige ja Ühingu admin
- Eeldused: Admin saab muuta liikmete statistikaõigust.
- Sammud:
  1. Admin lubab liikmetel statistikat vaadata.
  2. Tavaliige avab Statistika.
  3. Admin keelab õiguse.
  4. Tavaliige proovib uuesti.
- Oodatud tulemus: Ligipääs vastab seadele. Kinnitatud osalemiste panus on nähtav, kui andmeid on.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## NOTIF

### NOTIF-01 - Teavituste loend ja loetuks märkimine
- ID: NOTIF-01
- Roll: Tavaliige
- Eeldused: Ühingus on vähemalt üks teavitus.
- Sammud:
  1. Ava Teavitused.
  2. Kontrolli lugemata ja loetud olekuid.
  3. Märgi üks teavitus loetuks.
  4. Vajuta "Märgi kõik loetuks".
- Oodatud tulemus: Lugemisolek muutub ja loend jääb kasutatavaks.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### NOTIF-02 - Sihtkoha vihjed ja avamine
- ID: NOTIF-02
- Roll: Tavaliige või Ühingu admin
- Eeldused: On teavitusi väljakutse, tegevuse, varustuse või tunnistuse kohta.
- Sammud:
  1. Ava Teavitused.
  2. Kontrolli "Avab:" sihtkoha vihjeid.
  3. Ava väljakutse teavitus.
  4. Ava tegevuse, varustuse või tunnistuse teavitus.
- Oodatud tulemus: Väljakutse avab seotud vaate. Muud toetatud sihtkohad avanevad sobivasse moodulisse või näitavad arusaadavat fallback-teadet.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### NOTIF-03 - Alarmivalmiduse kaart ei blokeeri loendit
- ID: NOTIF-03
- Roll: Tavaliige
- Eeldused: Teavituste õigused võivad olla lubatud või keelatud.
- Sammud:
  1. Ava Teavitused.
  2. Kontrolli alarmivalmiduse kaarti.
  3. Keri teavituste loendit.
- Oodatud tulemus: Alarmivalmiduse kaart on nähtav, aga ei takista teavituste vaatamist ega loetuks märkimist.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

## SEC

### SEC-01 - Tavaliige ei näe admini haldusvaateid
- ID: SEC-01
- Roll: Tavaliige
- Eeldused: Kasutaja ei ole ühingu admin.
- Sammud:
  1. Ava Menüü.
  2. Kontrolli liikmete halduse, ühingu seadete, ootel ühingute ja admini toimingute nähtavust.
- Oodatud tulemus: Tavaliige ei näe admin-only toiminguid või ei saa neid avada.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### SEC-02 - Tavaliige ei saa muuta rolle ega merepääste astet
- ID: SEC-02
- Roll: Tavaliige
- Eeldused: Ühingus on teisi liikmeid.
- Sammud:
  1. Ava liikmete või profiili vaated, kui need on nähtavad.
  2. Proovi leida rolli või merepääste astme muutmise toiming.
- Oodatud tulemus: Tavaliige ei saa rolle ega merepääste astet muuta.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### SEC-03 - Tavaliige ei saa hallata ühingu varustust
- ID: SEC-03
- Roll: Tavaliige
- Eeldused: Ühingus on ühingu varustus.
- Sammud:
  1. Ava Varustus.
  2. Proovi lisada, väljastada või tagastada ühingu varustust.
- Oodatud tulemus: Tavaliige saab hallata ainult lubatud isiklikku varustust, mitte ühingu varustust.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### SEC-04 - Privaatsed andmed ja ristühingu andmed
- ID: SEC-04
- Roll: Tavaliige
- Eeldused: On kaks ühingut ja kasutaja kuulub ainult ühte.
- Sammud:
  1. Kontrolli liikmete, varustuse, väljakutsete, tunnistuste ja teavituste loendeid.
  2. Vaheta teise kasutajaga ja kontrolli sama.
- Oodatud tulemus: Teise ühingu andmeid ei kuvata. Tavaliige ei näe teise liikme privaatseid andmeid väljaspool lubatud ülevaateid.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:

### SEC-05 - Admin ei saa oma rolli ise muuta
- ID: SEC-05
- Roll: Ühingu admin
- Eeldused: Admin on ühingus aktiivne.
- Sammud:
  1. Ava oma liikme profiil.
  2. Proovi muuta enda rolli.
- Oodatud tulemus: Enda rolli muutmine ei ole võimalik või salvestamine ei õnnestu.
- Tulemus: [ ] Läbis / [ ] Ei läbinud
- Märkused:
