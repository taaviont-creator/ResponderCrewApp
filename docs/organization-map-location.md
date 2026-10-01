# Ühingu üks päästebaas ja asukoht kaardil

30.09.2026. Kohalik teostus pärast kasutaja täpsustust: üldjuhul on ühingul üks baas ja admin haldab oma ühingut.

## Töövoog

Ühingu admin avab **Ühingu seaded → Ühingu asukoht kaardil**. Vorm näitab olemasolevaid koordinaate ja võimaldab muuta laius-/pikkuskraadi, asukoha lühikirjeldust ning asukoha kontrolli märget. Eraldi baasi nime, üksuse loomist, koosseisu dubleerimist ega aktiveerimist ei küsita. Ühingu valmiduse vaatest eemaldati baaside/üksuste halduse link.

Mõlemad koordinaadid võivad puududa, kuid üksikut koordinaati salvestada ei saa. Komaga kümnendarvud on lubatud. Sisestatakse tegelik WGS84 asukoht; väljaspool Eesti tavapärast piirkonda kuvatakse kontrollimise soovitus. Koordinaadi muutmine võtab varasema kontrollimärke maha. Salvestusvea korral jääb vorm koos sisestusega avatuks, laadimisvea korral tühja ülekirjutamise vormi ei avata. Samaaegse muutmise konflikt nõuab vormi uuesti avamist.

## Andmed ja õigused

- `getOrganizationMapLocation` ja `saveOrganizationMapLocation` kontrollivad tehingus approved ühingut ja selle aktiivset admini liikmesust. Platvormi/keskuse roll üksi õigust ei anna.
- `commands.primaryRescueBaseId` viitab ühele `rescueBases` kirjele. Viite loob server. Klient ei saa seda reeglites otse muuta ega callable'ile suvalist baasi ID-d anda. Koordinaadid on ainult baasikirje `position: GeoPoint|null` väljas.
- Ilma viiteta kasutatakse olemasolevat ainsat baasi; kui kirjeid pole, loob esimene salvestus deterministliku ID-ga kirje. Lugemine ei loo andmeid. Mitu varasemat baasi ilma viiteta annab selge vea, automaatset juhuvalikut ega kustutamist ei tehta. Võõra ühingu või vigane viide lükatakse tagasi.
- Säilivad varasema baasi nimi, aktiivsus ja üksuste seosed. Muudetakse asukohta, kontrolli päritolu ja revisjoni. Sama kontrollitud koordinaadi uuesti salvestamine ei teeskle uut asukohakontrolli.
- Revisjon ja ühingu tehingulukk välistavad samaaegse esimese salvestusega duplikaadid ning vanade andmete vaikiva ülekirjutamise. `platformAudit` sisaldab olulise muudatuse enne/pärast andmeid, tegijat ja aega.
- Selle täpsustuse jaoks Firestore'i reegleid ega indekseid muuta ei tulnud: serveri kaudu haldamine ja uute väljade kliendipoolse kirjutamise keeld olid eelmises etapis juba olemas. Destruktiivset migratsiooni ega tootmisandmete muudatust ei tehtud.

## Edasise kaardi seos

Kaart kasutab hiljem seda päästebaasi tegelikku asukohta ja ühingu kehtivat nime. Puuduvate koordinaatidega ühing jääb nimekirja ilma oletusliku kaardipunktita. Ühingu vaikimisi valmidus peab kasutama olemasolevat liikmesust, isiklikke staatuseid, planeeringuid ja varustust; eraldi üksuse käsitsi loomine ei tohi olla eeltingimus. Mitme baasi tehniline laiendus säilib, kuid seda tavavaates ei pakuta.

**Kaardivaade ja uus ühine SAR/Tross valmidusmootor pole veel nende andmetega ühendatud.** Koordinaatide lisamine ei avalda ühingut automaatselt keskusele ega kinnita reageerimisvalmidust. Keskustele avaldamise kokkulepe, ühised ressursside konfliktid eri ühingutes ja pädevuste seosed jäävad [arendusplaani](center-readiness-maps-plan.md) järgmistesse etappidesse. APK-d ega pilve avaldamist selles etapis ei tehtud.

## Kontrollid

Kontrollitud asukoha tühi algseis, senise baasi taaskasutus, koordinaatide valideerimine, kordussalvestus, tühjendamine, audit, revisjonikonflikt, eri ühingute eraldatus, õiguste ületamise katsed ning 320 px telefoni paigutus.

- `flutter analyze --no-pub`: **0 probleemi**.
- `flutter test --no-pub`: **129 läbis**, sealhulgas 4 uut asukohavormi testi. Testid paljastasid dialoogi taga jätkuva laadimisanimatsiooni; see parandati enne lõplikku kontrolli.
- `node --test functions/*.test.js`: **67 läbis**.
- Firestore/Storage emulaator, `demo-respondcrew`: **100 läbis**, sealhulgas 5 uut organisatsiooni asukoha integratsioonitesti. Oodatud ligipääsukeelud ja kohaliku Java hoiatused ei põhjustanud ebaõnnestunud teste.
- `git diff --check`: läbis; olemasolevate Windowsi genereeritud failide reavahetushoiatustest ei tekkinud sisulisi muudatusi.

Selles täpsustuses veebiversiooni ega APK-d uuesti ei koostatud. Eelmise etapi veebikooste tulemus on ajalooline; uut pilveversiooni ega pärisseadme testi ei väideta.

Peamised failid: `functions/response-units.js`, `lib/services/organization_map_location_service.dart`, `lib/widgets/organization_map_location_control.dart`, ühine `rescue_base_dialog.dart`, sissepääs `home_screen.dart` admini seadetes; testid `test/organization_map_location_test.dart` ja `rules-tests/organization-map-location.cases.js`.
