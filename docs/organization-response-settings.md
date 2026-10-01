# Ühingu SAR-i ja Trossi teenuste seadistus

30.09.2026. Järg [ühingu asukoha etapile](organization-map-location.md), [keskuste arendusplaani](center-readiness-maps-plan.md) sisendandmete etapp. Teostus kohalikus koodis; pilve ega APK-d ei avaldata.

## Valmis töövoog

Ühingu admin avab **Ühingu seaded → Ühingu teenused**. Tavaliikme menüüs seda seadistust ei ole ja server nõuab sama ühingu aktiivset admini liikmesust. Keskuse ega platvormi roll üksi õigust ei anna.

- SAR ja Trossi mereabi lülitatakse eraldi sisse. Vanal või seadistamata ühingul ei eeldata vaikimisi kummagi teenuse pakkumist.
- Mõlemale saab määrata väljasõiduvalmiduse aja 1–60 minutit, aktiveerimisest väljasõiduvalmiduseni. See ei ole sõiduaeg sündmuskohale. Trossi sisselülitamisel pakub vorm 60 minutit, kuid admin saab seda muuta. SAR-il ettevalitud aega pole.
- SAR näitab olemasolevat `organizationReadinessSummaries.minimumCrewRequired` ja II astme nõuet. Uut SAR miinimumi välja ei teki ja seda siin muuta ei saa; senine miinimumkoosseisu muutmine jääb Ühingu valmiduse lehele.
- Trossi minimaalne reageerijate arv on eraldi 1–50, esialgne vormiväärtus 1. SAR-i II astme nõuet automaatselt ei lisata. Need on seadistatavad sisendid, mitte veel kasutusse võetud uue valmidusarvutuse tulemus.
- Teenuse juurde valitakse kuni 10 ühingu olemasolevat ühiskasutuses olevat alust. Sisselülitatud teenus vajab vähemalt üht valikut. Aluse nimi ja seisund tulevad varustusest; neid ei kopeerita seadistusse. Mõlemale teenusele võib valida sama aluse: see kirjeldab sobivust, mitte samaaegset topeltressursi lubadust.
- Varustuse kategooria peab olema `vessel`. Teise ühingu, isiklikku, liikmele väljastatud või kategooriata kirjet alusena kasutada ei saa. Legacy `commandId` ja puuduva scope'iga tegelikku ühingu alust saab kasutada; puuduvat seisundit näidatakse teadmata seisundina.
- Rikkis/hooldust vajavat alust võib säilitada teenuse seadistuses. Valik ei kinnita kasutatavust. Seisund kuvatakse nime kõrval laadimishetke andmetest; tulevane valmidusmootor peab lugema hetkeandmed varustusest.
- Keskusele jagamiseks saab sisestada valvekontakti nimetuse ja telefoni. Isiklikke kontakte ega ühingu profiili kontaktandmeid automaatselt ei kopeerita. Jagamise nõusolek ja keskuses avaldamine on eraldi tulevane toiming.
- Eraldi baasi, üksuse ega liikmete kandidaatnimekirja loomist ei küsita. Varem valitud kustutatud/väljastatud aluse saab eemaldada ka välja lülitatud teenuse alt.

## Andmed ja server

Uus dokument `organizationResponseSettings/{organizationId}`:

```text
schemaVersion: 1
revision: int
services:
  sar:   { enabled, departureMinutes: int|null, vesselIds: [equipmentId] }
  tross: { enabled, departureMinutes: int|null, vesselIds: [equipmentId], minimumResponders }
contactName, contactPhone
createdAt/By, updatedAt/By
```

See on ühe baasiga ühingu teenuseseadistuse ainus allikas. Varasem `responseUnits`/`unitRoster`/`unitEquipment` prototüüp jääb erandliku mitme üksuse laienduse jaoks ning tavavoo salvestus neisse ei kirjuta ega neist teenuseid automaatselt sisse lülita. Seda uut organisatsioonipõhist seadistust ei tohi hiljem dubleerida automaatselt loodud üksuse poliitikasse. Ühingu põhiasukoht jääb `primaryRescueBaseId` kaudu senisesse asukohakirjesse.

`getOrganizationResponseSettings` ja `saveOrganizationResponseSettings` on autentimist nõudvad callable'id. Iga päring kontrollib tehingus approved organisatsiooni ning selle aktiivset admini. Salvestamisel kontrollitakse kõiki aluseviiteid värsketest varustuskirjetest samas tehingus. Lugemine ei loo dokumenti.

Klient ei saa saata arvutatud valmidust, kinnitust, SAR miinimumi ülekirjutust, kvalifikatsiooninõude eemaldamist ega rolli. Revisjon kaitseb samaaegse ülekirjutamise eest. Salvestatakse audit `organization.responseSettings`: ühing, tegija, aeg ja seadete enne/pärast sisu.

Kõik kliendi otsepäringud uude kollektsiooni on olemasolevate reeglite vaikimisi keelu tõttu suletud. Selle etapi jaoks Security Rules'i sisu ega indekseid ei muudetud; keeldu kontrolliti emulaatoris eraldi. Päringud piirduvad kuni 300 varustuskirjega iga modern/legacy ühinguviite kohta; ületamisel tuleb selge mahupiiri viga, mitte poolik nimekiri.

Pilve andmebaasi väljaande korduskontroll ebaõnnestus aegunud Firebase CLI sisselogimise tõttu. Jätkati repositooriumi olemasoleva dokumendimudeli ja kohaliku emulaatoriga; andmebaasi ei loodud, migreeritud ega pilves muudetud.

## Kontrollid

Uued testid katavad teenuste eraldatuse, vaikeoleku, pärimise, keelatud väljad, aluseviited, puuduvad legacy andmed, revisjonikonflikti, rollide ja ühingute eraldatuse, õiguse eemaldamise, salvestusvea korduskatse ning 320 px telefoni paigutuse.

- `flutter analyze --no-pub`: **0 probleemi**.
- `flutter test --no-pub`: **135 läbis**, sh 6 uut kasutajaliidese testi.
- `node --test functions/*.test.js`: **71 läbis**, sh 4 uut seadistusreeglite testi.
- Firestore/Storage emulaator `demo-respondcrew`: **104 läbis**, sh 4 uut serveri/reeglite integratsioonistsenaariumi.
- `git diff --check`: läbis; säilivad varasemad genereeritud Windowsi failide reavahetuse hoiatused.

Veebi uut väljalaset ega APK-d ei koostatud. Päris kasutajaga pilvevoogu ei testitud, sest uued callable'id on veel avaldamata. Kõik uued andmebaasikirjutused testiti emulaatoris.

Peamised failid: `functions/organization-response-settings.js`, eksport `functions/index.js`, `lib/screens/organization_response_settings_screen.dart`, `lib/services/organization_response_settings_service.dart` ja admini sissepääs `lib/screens/home_screen.dart`. Testid: `functions/organization-response-settings.test.js`, `rules-tests/organization-response-settings.cases.js`, `test/organization_response_settings_test.dart`.

## Järgmine etapp ja avaldamise piir

See etapp valmis **sisendandmete seadistuse**, mitte valmis keskuse kaarti. Praegune SAR-arvutus ja teavitused ei loe veel uusi teenuseseadeid; telefoni senine valvesolek, planeeringud, miinimum ja paus säilivad. Ei saadeta uut pushi ega anta keskusele ühtegi uut õigust.

Järgmine etapp ühendab need sisendid olemasoleva `evaluateReadiness` loogikaga, lisab aluste kasutatavuse ja kontrollitud pädevuse kehtivuse, valmiduskinnituse/viivituse aegumise ning ühise serverikokkuvõtte. Kontrollimata aluse identiteet ja lahendamata multi-org ressursside konflikt ei tohi anda tõendamata rohelist. Tähtajalise kinnituse ärilised piirid ja pädevustõendite täpne vastavus tuleb lahendada enne operatiivse kaardivärvi kasutusse võtmist.

Seejärel: ühingu nõusolek ja kontrollitud keskuses avaldamine, ühise tulemuse ühendamine telefoni ning keskuse kaardi/nimekirjaga. Puuduva koordinaadiga ühing peab jääma loendisse ilma oletusliku punktita. Uut kasutajale nähtavat rohelist „reageerimisvalmis” olekut ei lisatud üksnes teenuse sisselülitamise põhjal.
