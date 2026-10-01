# RespondCrew

Flutteri rakendus vabatahtlike merepäästeühingute liikmetele, ühingu administraatoritele ning Merevalvekeskusele ja Trossi keskusele. Telefonirakendus ja veebiversioon kasutavad sama Firebase’i projekti `respondcrew`. Ühingu liikmesus, keskuse ligipääs ning platvormihalduri roll on eraldi õigused.

## Praegune tööseis

Ajakohane ülevaatus ja allesjäänud tööd: [väljalaske töökindluse ülevaatus](docs/release-readiness-review.md).

Keskuste uusim lahendus ja kontrollid: [keskuste lõpetamise kokkuvõte](docs/center-completion.md). See asendab varasemates etapikirjeldustes säilinud liikmete erijaotuse ja korduva positiivse valmiduskinnituse nõuded.

Katseveeb: https://respondcrew--keskused-katse-aznyqfmn.web.app/ (ajutine Hosting-kanal `keskused-katse`). See kasutab päris Firebase’i andmeid ja nõuab sisselogimist. Näidisandmetega proovivaade on eraldi `lib/main_center_demo.dart`.

- Ühingu admin: **Menüü → Ühingu seaded → Keskuste kaart**.
- Platvormihaldur: **RespondCrew haldus → Taotlused / Kaardikeskused / Ühingud / Kasutajakontod / Auditlogi**.
- Keskuse õigus ei anna ühingu adminiõigust. Kaardile jõudmiseks peavad ühingu jagamistaotlus ja platvormi heakskiit olemas olema.

PR-i kontrollid käivitavad Flutteri analüüsi ja testid, Functions’i testid, Firestore/Storage’i reeglitestid, veebikoostamise ning iOS-i simulaatori koostamise. APK-d PR-i käigus ei koostata. APK saab luua ainult `RespondCrew MVP CI` käsitsi käivitamisel, märkides valiku `build_android_apk` (vaikimisi väljas). `web-foundation.yml` kontrollib veebi nii PR-is kui ka käsitsi käivitamisel. Avaldamine Firebase’i on eraldi samm.

## Kohalik arendus ja kontrollid

Vaja on Flutteri SDK-d, Node.js-i ning reeglitestidele sobivat Java versiooni. Konkreetseid sõltuvusi kirjeldavad `pubspec.lock`, `functions/package-lock.json` ja `rules-tests/package.json`. Functions kasutab Node.js 22.

```sh
flutter pub get
flutter analyze
flutter test
npm ci --prefix functions
node --test functions/*.test.js
npm install --prefix rules-tests
npm test --prefix rules-tests
```

Reeglitestid kasutavad Firestore’i ja Storage’i emulaatoreid projektiga `demo-respondcrew`; need ei ole tootmisandmete testimiseks. Ärge kirjutage testandmeid päris projekti.

Veebipaketi kontroll:

```sh
flutter build web --release
node tool/verify-web-build.cjs
```

Katsekanali avaldamine kasutab `firebase.web.json` faili, mis kontrollib paketti ja versioonib varad enne avaldamist. Firebase’i CLI peab olema sisse logitud. Avaldamine on eraldi samm; vaikimisi live-kanalit ei asendata.

```sh
npx -y firebase-tools@latest hosting:channel:deploy keskused-katse --expires 30d --no-authorized-domains --project respondcrew --config firebase.web.json
```

Ärge lisage SMTP salasõnu, ligipääsutokeneid ega teenusekonto võtmeid repositooriumi. Kohalikud logid ja koostamisfailid ei ole rakenduse lähtekood.

## Testimine ja üleandmine

- [Androidi pärisseadme kontrollnimekiri](docs/android-final-device-checklist.md)
- [Apple’i väljalaske eeltingimused](docs/apple-release.md)
- [Sündmuse aruanne, manused ja väljalaske piirid](docs/2026-09-release-completion.md)
- [E-posti seadistus ja saatmise olekud](docs/transactional-email.md)
- [Telefonitesti paketid 2 ja 3](docs/phone-test-packs-2-3.md)

Pärisseadme alarmi/taustatöö kontroll, tegeliku kirja postkasti jõudmine ning Apple’i allkirjastamine, APNs ja TestFlight on eraldi kontrollid. Läbitud automaattestid ei tõenda nende läbimist.

UX/UI korrastuse ülevaade ja kontrollid: [UX/UI audit](docs/ux-ui-audit.md).
