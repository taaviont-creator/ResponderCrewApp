# Päästebaasid, üksused ja ressursside jaotus

30.09.2026. Järg [keskuste veebipõhja etapile](center-foundation-progress.md) ja [arendusplaanile](center-readiness-maps-plan.md).

## Valmis kohalikus koodis

**Hilisem täpsustus:** tavapärane töövoog on nüüd **Ühingu seaded → Ühingu asukoht kaardil**. Link „Päästebaasid ja üksused” eemaldati ühingu valmiduse vaatest. Admin ei pea looma üksust ega haldama baaside nimekirja. Allolev kirjeldab varem lisatud tehnilist laiendusvõimalust; see ei ole tavakasutuse eeltingimus. Uus töövoog, testid ja piirid on [ühingu asukoha raportis](organization-map-location.md). Keskuse ega platvormihalduri roll üksi ei anna selle ühingu asukoha muutmise õigust.

- Päästebaasi lisamine ja muutmine: nimi, aadress/kirjeldus, tegelikud WGS84 koordinaadid, asukoha kontroll ja kasutusel/peatatud olek. Mõlemad koordinaadid võivad puududa; puudumist ei asendata oletusliku punktiga. Komaga kümnendarvud sisestuses on toetatud. Väljaspool Eesti tavapärast piirkonda olev sisestus saab hoiatuse.
- Üksuse lisamine ja muutmine: sama ühingu aktiivne baas, nimi, SAR/Tross teenused, keskusele jagamiseks sobiv valvekontakt, võimalik liikmete ja aluste koosseis ning kasutusel/peatatud olek.
- Võimalik koosseis on eraldi aktiivsest ressursside jaotusest. Admin valib, millised liikmed ja alused määrata üksuse kasutusse ning kui kauaks. Liikme isiklik valvesolek, kvalifikatsioon ja ühingu senine valmidusarvutus sellest ei muutu.
- Jaotus on tähtajaline, kuni 24 h; UI valikud 1/4/8/12/24 h. See on ressursi kasutusaja tehniline piir, **mitte** kinnitatud SAR/Tross valmiduse kehtivus ega väljasõidusiht. Jaotuse saab vabastada. Teise üksuse kehtivat jaotust ei saa üle võtta.
- Salvestusvea korral säilivad sama päringu andmed ja kirje ID uuesti proovimiseks. Vana revisjoni korral küsib server andmete uuesti laadimist. Kui vastus kadus pärast edukat salvestust, tuleb värskendades kontrollida tegelikku seisu; kordus ei loo uut ID-d.
- Aktiivse üksusega baasi ei saa peatada. Kehtiva jaotusega üksusest ei saa eraldatud ressurssi eemaldada ega üksust peatada enne jaotuse vabastamist.

## Andmemudel ja õigused

| Andmed | Teostus |
| --- | --- |
| Päästebaas | `rescueBases/{id}`: `organizationId`, nimi/aadress, `position: GeoPoint|null`, asukoha allikas ja kontrolli aeg/tegija, aktiivsus, revisjon |
| Üksus | `responseUnits/{id}`: organisatsioon, baas, nimi, teenused, valvekontakt, aktiivsus, revisjon |
| Võimalik koosseis | `unitRoster` ja `unitEquipment`, deterministlikud seose-ID-d; ei kopeerita liikme rolli, tunnistusi ega aluse seisundit |
| Aktiivne jaotus | `resourceAllocations/{hash}`: üksus, organisatsioon, ressursiviide, kehtivuse lõpp ja muutja/aeg |
| Aluse ühine identiteet | `vesselIdentities/{equipmentId}`: ainult serverile avatud kontrollitud seos füüsilise aluse ühise tunnusega; kontrollitakse organisatsiooni viidet |
| Audit | `platformAudit`: baasi/üksuse olulised muudatused ja ressursside jaotus, enne/pärast, kes/millal |

Uued funktsioonid on `getOrganizationUnits`, `saveRescueBase`, `saveResponseUnit`, `setUnitAllocation`. Kõik kontrollivad **tehingu sees** praegust aktiivset ühingu admini liikmesust ja approved organisatsiooni. Organisatsiooni viidet, ressursse, revisjoni ja sisendi lubatud välju kontrollitakse serveris. Klient ei saa kirjutada oma `ready`/rolli/õiguse välju ega teha kollektsioonides otsekirjutusi. Nende uute kollektsioonide otselugemine on samuti suletud; admin saab callable'ist piiratud haldusvaate andmed.

`commands.unitManagementRevision` on organisatsioonisisene tehingulukk baasi/üksuse samaaegsete muudatuste jaoks. Ressursi globaalset jaotust kontrollitakse ja muudetakse samas tehingus. Sama liikme Firebase UID ühine võti väldib samaaegset jaotust ka eri ühingutes. Ressurssi ei anta automaatselt järgmisele üksusele pärast aegumist; vajalik on uus selgesõnaline määramine.

Kõik uued andmed on lisanduvad. Vanu dokumente ei migreeritud, olemasolevaid ühinguid automaatselt üksusteks ei teisendatud ega keskustele avaldatud. Puuduv vana varustuse kategooria ei muutu automaatselt aluseks.

## Täpsed piirid ja allesjäänud töö

**Keskuse kaart ja uus valmidusarvutus pole veel ühendatud.** Haldusvaade ütleb seda selgelt. Praegune ühingu SAR-kokkuvõte töötab jätkuvalt senise loogikaga. Üksuse teenuse märkimine ei võrdu keskusele avaldamise ega valmiduse kinnitamisega.

Sama varustuskirjet ei saa jaotada korraga kahele üksusele. Kontrollitud `physicalResourceId` korral blokeeritakse ka eri varustuskirjetena sisestatud sama aluse topeltjaotus. **Kontrollimata alusekirjete puhul ei saa tarkvara veel tõendada, et eri kirjed ei tähista sama päris paati.** Nende jaotused märgitakse `identityVerified=false`; kasutajale näidatakse kontrollimise vajadust. Need ei tohi järgmises valmidusmootoris olla kinnitatud rohelise alus. Aluste ühiste tunnuste kontrollitud sidumise haldusliides ja kuivmigratsioon on järgmise etapi kohustuslik osa enne keskusele avaldamist. Klient ei saa kontrollitud tunnust ise kirjutada.

Jaotuse aegumist arvestatakse serveri lugemisel ja järgmisel määramisel; aegunud dokument võib auditiks alles jääda. Kaardile avaldamise ajastajat selles etapis ei lisatud: järgnev ühine valmidusmootor peab lisama `validUntil` oma järgmiste tähtaegade hulka. Haldusvaate kuvatud jaotused on laadimishetke seis ja näitavad lõppaega; värskendamine loeb hetkeolukorra uuesti.

Esimese haldusvaate piirid: kuni 100 baasi ja 100 üksust ühingus, kuni 50 võimalikku liiget ja 10 alust üksuses. Ühingu liikmete/varustuse päringud on piiratud 300 kirjega iga legacy/uue organisatsiooniviite päringu kohta. Ületamisel tagastatakse selge mahupiiri viga, mitte vaikimisi poolik koosseis; suuremate ühingute jaoks lisada lehekülgedega laadimine enne piiride tõstmist. Mobiili valikuloendite otsing on samuti suurema koosseisu järgmine kasutatavuse täiendus.

## Kontrollid

- Kõik Flutteri testid: **125 läbis**; 6 uut testi baasi koordinaatide, teenuse valimise, eraldi ressursside jaotuse, vea järel sama ID-ga uuesti salvestamise ning 320 px telefonivaate kohta.
- Functions testid: **67 läbis**; lisatud koordinaatide ja globaalsete ressursivõtmete testid.
- Firestore/Storage emulaator: **95 testi**; neli uut integratsioonistsenaariumi katavad kõik uued haldustoimingud, õiguste eraldamise, keelatud otsepäringud, võõra ühingu ressursid, vale kategooria, revisjonikonflikti, samaaegsed määramised, vabastamise/aegumise, ühise alusetunnuse ja eri ühingute sama liikme.
- `flutter analyze --no-pub`: **0 probleemi**. `flutter build web --release --no-pub --no-web-resources-cdn`: **õnnestus**. Säilib esimeses etapis dokumenteeritud sõltuvuste Cupertino ikoonifondi hoiatus; see ei takistanud koostamist.

Testid kasutavad `demo-respondcrew` emulaatorit, mitte tootmisandmeid. Päris kasutaja sisselogimisega uut haldusvoogu pilves ei katsetatud: funktsioonid ja reeglid pole veel avaldatud ning Firebase CLI sisselogimine on endiselt taastamata.

## Peamised failid

- [Serveri haldustoimingud](../functions/response-units.js), [Functions ekspordid](../functions/index.js), [Firestore reeglid](../firestore.rules).
- [Üksuste haldusvaade](../lib/screens/response_units_screen.dart), [ühingu valmiduse sissepääs](../lib/screens/organization_readiness_screen.dart), [andmeteenus](../lib/services/response_unit_service.dart).
- [Baasi vorm](../lib/widgets/rescue_base_dialog.dart), [üksuse vorm](../lib/widgets/response_unit_dialog.dart), [ressursside jaotuse vorm](../lib/widgets/unit_allocation_dialog.dart).
- [Flutteri testid](../test/response_units_test.dart), [Functions testid](../functions/response-units.test.js), [serveri/reeglite integratsioonitestid](../rules-tests/response-units.cases.js).

Järgmine samm: füüsiliste aluste identiteedi kontrollitud haldus ning teenusepõhised valmidustingimused; seejärel ühine SAR/Tross arvutus ja selle ajastamine. Pädevusmaatriks ning valmiduskinnituse kehtivuse ärilised piirid on endiselt arendusplaanis kinnitamist vajavad valikud.

APK-d, deploy'd, push'i ega PR-i selles etapis ei tehta. Varasemad kohalikud muudatused säilivad.
