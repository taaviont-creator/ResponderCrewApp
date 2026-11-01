# TRU · esimene prooviversioon

Eraldi Flutteri rakendus samas repositooriumis. RespondCrew käivitusfailid,
Firebase'i seadistus, Androidi identifikaator ja andmed jäävad puutumata.
Aluseks on RespondCrew kujundus (`lib/theme/app_theme.dart`) ja Eesti aja
valideerimine (`lib/models/activity_schedule.dart`), lähteversioon
`fb12c647278ff648238e40b29376326d215f6520`.

## Käivitamine

Vaja on Flutteri stable SDK-d koos Dart >= 3.10.7-ga.

```sh
cd apps/tru
flutter pub get
flutter run -d chrome
```

Kontrollid ja veebipakett:

```sh
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

GitHub Actionsi `TRU prototype` kontrollib analüüsi, teste ja veebikoostamist.
Pärast edukat jooksu on töövoo lehel allalaaditav `TRU-prototype-web` pakett.
Seda saab serveerida HTTP serveriga; otse file:// kaudu Flutteri veeb ei tööta.
Avalikku katseveebi ega telefoni APK-d selles etapis ei avaldata.

## Mida proovida

- Töölaud ja ajaliselt järjestatud tegevuste loend.
- Sündmuste, koolituste ja õppuste loomine.
- Regioonifilter (Kõik tähendab ülevaadet kõigist regioonidest).
- Osalemisvastuse muutmine, mitme ajavahemiku lisamine ja eemaldamine.
- Ööpäeva piiri ületav ning hiljem algav osalemine.
- Sündmuse pikendamine ja lõpetamine.
- Tegeliku kohaloleku märkimine planeeritud osalemisest eraldi.
- Meeskonna plaan ning 8-tunniste kontrollpunktide katvus. See ei ole täielik
  vahetuste planeerija: kontrollpunktide vahel võib katvus olla erinev.
- Kogu TRU varustus, seisukorra muutmine ja üleandmine regioonile või sündmusele.
- Püsiasukoha ja kuuluvuse säilimine, vastuvõtja ja liikumisajalugu.
- Regioonile või kõigile mõeldud teate loomine ja lugemise kinnitus.
- Näidisjuhend infolehel.

## Prooviversiooni piirid

Kõik andmed on väljamõeldud ja hoitakse ainult mälus. Brauserilehe uuendamine
lähtestab muudatused. Kasutaja on üks näidisliige; loomise ja haldamise nupud on
proovimiseks kõigile nähtavad. Regioonifilter EI OLE ligipääsukontroll.
Üleandmine registreerib sisestatud vastuvõtja, mitte tema isikliku digitaalse
kinnituse. Telefoniteavitusi, autentimist, taustatööd ega Firebase'i ühendust ei ole.

Liikmete register, kontaktid, pädevused/tunnistused, pärisfailid, koolituste
läbimise kinnitamine, täpne kalender ja rollipõhised õigused on järgmine etapp.

## Ühendamine päris TRU keskkonnaga

1. Luua TRU eraldi Firebase'i projekt ja registreerida oma rakendused.
2. Määrata üksuse ja regioonide rollid ning andmete nähtavus.
3. Asendada DemoStore autentitud andmekihiga; kontrollida õigusi serveris.
4. Salvestada osalemisajad UTC-s; kuvada Europe/Tallinn ajavööndis.
5. Teha varustuse üleandmised tehinguna koos muutmatu ajalooga,
   kinnitaja ja vajadusel vastuvõtja kinnitusega.
6. Lisada teavituste serveripoolne adressaatide valik ja saatmine.
7. Lisada püsiv auditlogi, offline- ning pärisseadme testid.

Olemasolevad RespondCrew tegevuste, varustuse ja teadete teenused sõltuvad
merepääste organisatsioonide õigustest ja andmekogudest. Neid ei tohi suunata
TRU andmetele ilma skeemi ja õiguste kohandamiseta.
