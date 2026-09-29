# Telefonitesti paketid 2 ja 3

## Lähtekoht ja kontroll enne muudatusi

Alus: main `d03550837f269509fe8479e2a3d8a560dc07344f` (PR #32, pakett 1).
Firebase: olemasolev `respondcrew/(default)`, Standard, europe-north1.

Olemas: organisatsioonipõhised aktiivsed liikmesused ja admini/II astme õigused;
isiklik käsitsi staatus ning ühekordsed ja korduvad planeeringud; tühistamine
olekuga; ühingu valve peatamise serveritoiming ja ajalooline valveaja arvestus;
SAR/TROSS struktureeritud `calloutType`; miinimumkoosseis ja efektiivne II aste;
operatiivlogi, osalejad, aruande tehnika ID-seosed, PDF; SMTP ja taotluse push;
platvormi ülevaate serveriliides ning organisatsiooni kinnitamine.

Osaliselt olemas: valmiduse ja planeerimise vaated on segunenud; tühistatud
planeeringud on vaikimisi nähtavad; varustuse kategooriad pole aruandes
rühmitatud; profiili muutmine on üldnupu taga; taotluse teavituskanalid ja
platvormi märguanded vajavad täiendamist. Paketi 1 teavituslingi parandust ei
tehta uuesti.

Puudu: teavituste kasutajapõhised eelistused ja serveri koondatud valmiduse
muutuse teated; testväljakutse ametlikust statistikast eraldamine; sisselogimise
juhend/üldinfo seadistus; kõigile aktiivsetele liikmetele ohutu planeeringute
ülevaade (isiklikke põhjendusi ei jagata).

## Teostuse põhimõtted

- Kasutada olemasolevaid andmeallikaid; logi, osalejaid ega tehnikat aruandesse
  ei kopeerita. Planeeringute algdokumendid jäävad seniste õigustega.
- Admini valmiduse juhtimine kasutab sama `organizationReadinessSummaries`
  miinimumi ja `setOrganizationDuty` toimingut.
- Testtunnus on admini auditeeritud serverimuudatus; vana dokument tähendab
  `isTest == false`. Statistika välistab testid enne liikmete panuse arvutust.
- E-post jääb profiilis loetavaks: Authi kinnituse ja kordusautentimiseta ei
  muudeta Firestore'i e-posti eraldi.
- Kategooriata/tundmatu varustus kuvatakse „Muu”; nimetuse järgi ei arvata.
- Teavitused arvestavad konkreetse ühingu liikmesust; platvormiroll ei anna
  organisatsioonis adminiõigusi. Androidi DND/helivalikuid ei eirata.
- Täielik Stitchi visuaalne ümberkujundamine ja automaatne testversioonide
  jagamine jäävad kasutaja määratud järgmisesse etappi.

## Valmis funktsioonid

| Nõuded | Tulemus |
| --- | --- |
| 1 | Kompaktne sisselogimine, juhendi/üldinfo nupud ja kontakt. Avaliku juhendi sisu/HTTPS-aadress on muudetav Firestore'is. |
| 2 | Üheksa organisatsioonipõhist isiklikku teavituseelistust, admini valmiduse teated vaikimisi sees. Ühe muutuse põhjused ja enda planeeringu muutus koondatakse üheks teateks. |
| 3 | Liikmetaotluse serveripoolne personaalne rakendusesisene teade, push ja e-post ühingu aktiivsetele adminidele. Kasutatakse olemasolevat SMTP-d. |
| 4–7 | Isiklik Valmisolek ning Ühingu valmidus eraldi. Kompaktne töölaua kokkuvõte. Admini miinimum ja valve peatamine muudavad samu olemasolevaid väärtusi. Kõigi liikmete planeeringute ajad ja nimed on nähtavad; privaatsed märkused ei ole. Tühistamine säilitab ajaloo. Avatuks jäetud isikliku vaate aeg värskeneb 30 sekundi järel. |
| 8–9 | Nime ja telefoni juures eraldi muutmisikoon; merepäästeaste selgelt nähtav ja seniste adminiõigustega muudetav. E-post on autentimiskonto info, mitte eraldi muudetav koopia. |
| 10–11 | Platvormi ühingud on oleku järgi rühmitatud. Ootel taotluste arv uueneb reaalajas; lisatud push ja platvormi personaalsete taotluseteadete loend. |
| 12–14 | Struktureeritud varustuse kategooriad, ohutu Muu-varuvariant. Aruanne ja PDF näitavad ainult tegelikult kasutatud kategooriaid. Kuivülikonna kategooria on Isikukaitsevarustus, mitte tehnika. |
| 15 | Admini auditeeritav testtunnus, vaikimisi peidetud testväljakutsed; testid välistatakse sündmuste ja liikmete panuse statistikast. Testaruandes on selge mitteametlik märge. |
| 16–17 | Olemasolev calloutType säilib; SAR/Trossi kiirvalikuid täiendati. SAR nõuab miinimumkoosseisu ja efektiivset II astet. Trossi loomine ja reageerimine on võimalik ka SAR-valmiduseta. |
| 18 | SAR-i uus Androidi kõrge tähtsusega kanal ja eristuv kahetooniline heli; Tross, valmidus ja info eraldi kanalites. Täpne väljakutse ID säilib teavitusest avamisel. Telefoni seadete lingid ja juhis. |
| 19–20, 25 | Puudutatud vaadete ruumikasutus ja nimetused korrastatud. Täielikku Stitchi ümberkujundamist ei tehtud. |
| 21–24, 26 | Organisatsiooni piirid ning kasutaja/admini/II astme/platvormi õigused jõustatud serveris ja reeglites, vanad andmed toetatud, regressioonitestid lisatud. |

## Andmemudel ja turvareeglid

Olemasolevad `commands`, `memberships`, `availability`, planeeringud,
`organizationReadinessSummaries`, `callouts`, osalejad ja aruande seosed jäävad
põhiallikateks. Operatiivlogi ega varustust aruandesse ei kopeerita.

- `callouts.isTest`: puudumisel false. Muudatus ainult `setCalloutTestStatus`
  kaudu, kontrollitud eelnev väärtus, callout'i `changeHistory` ja `platformAudit`.
- `equipment.category`: lisandusid `trailer`, `vehicle`, `machinery`;
  olemasolevad väärtused säilivad, puuduv/tundmatu väärtus kuvatakse Muuna.
- `notificationPreferences/{uid}_{org}`: organisatsioon, kasutaja, bool-eelistuste
  kaart ja uuendusaeg. Omanik loeb, valideeritud serveritoiming kirjutab.
- `userNotifications/{hash}`: serveri kirjutatud personaalne teade ning pushi
  tulemus. Lugemiseks nõutakse adressaati ja aktiivset liikmesust; platvormi
  teadete puhul platvormirolli. Senised ühisteated ja lugemiskinnitused säilivad.
- `readinessNotificationState/{org}` ja `readinessNotificationEvents/{id}`:
  arvutatud seis ja muutuste järjekord. Seisu võib lugeda ainult aktiivne sama
  ühingu liige; kirjutamine ja muutuste järjekord on serveri hallata.
- `memberApplicationEmailDeliveries/{hash}`: olemasoleva idempotentse meilisaatmise
  tarneolek. Klient sellele ligi ei pääse.
- `publicAppInfo/login`: ainus avalikult loetav juhendidokument. Kogu kogumi
  loetlemine ja kliendist kirjutamine pole lubatud. Hoida ainult avalikku sisu.

Firestore'i muudatused: varustuse lubatud kategooriad, ülaltoodud piiratud
lugemisreeglid ning personaalsete teadete lugemiskinnituste valideerimine.
Storage'i reeglid ei muutunud. Liikme ega platvormihalduri operatiivseid
muutmisõigusi ei laiendatud. Kvalifikatsiooni muutmise ja ainsa admini kaitsed säilivad.

## Cloud Functions ja teavituste töö

`effective-readiness.js` arvutus teenindab nii UI päringut kui serveri muutuse
teavitust. Seis loetakse ja võrreldakse tehingus, vältides korduvate või vales
järjekorras Firestore'i sündmuste põhjustatud tagasipöördeid. Andmete muutused
käivitavad arvutuse ning minutiline ajastatud kontroll arvestab planeeringute
ajalist algust/lõppu. Ajastatud funktsioon on `europe-west1`, nagu olemasolev
tunnistuste meeldetuletus: projekti Cloud Scheduler ei toeta `europe-north1`
asukohta ([Google Cloudi piirkonnad](https://docs.cloud.google.com/scheduler/docs/locations)). Firestore ja muud uued funktsioonid jäävad `europe-north1`. Esmane seis loob vaikse algpunkti, mitte tagantjärele häiret.

Uued serveriliidesed: `getOrganizationReadinessPlanning`, `setCalloutTestStatus`,
`setNotificationPreference`. Uued käivitajad: `sendMemberApplicationEmail`,
`sendOrganizationApplicationNotification`, kuus `updateReadiness_*` funktsiooni,
`refreshScheduledReadiness`, `sendReadinessChangeNotification`.

Muudetud: `getOrganizationReadinessAvailability`, `sendMemberRequestNotification`,
`sendCalloutAlarmNotification`, `sendCertificateExpiryReminders`,
`getContributionStatistics`, `getPlatformOverview`.

Saatmise eel kontrollitakse värsket adressaadi liikmesust/rolli ja eelistusi.
Korduv sama serverisündmus ei loo uut teadet. Ebamäärast pushi või SMTP tulemust
ei saadeta pimesi uuesti; rakendusesisene kirje jääb alles. Aegunud valmiduse
muutust, mille järel seis juba muutus, ei saadeta hilinenult.

Admini kriitilised valmiduse teated on vaikimisi sees, kuid selle paketi
kokkuleppe järgi on isiklik eelistus muudetav. Liikmetaotluste menetlemise teated
on rollipõhised. Push ei asenda sündmuse olemasolu ega garanteeri kättesaamist.

## Tagasiühilduvus ja konfiguratsioon

2026-09-29 kontrolliti tootmise varustuse kategooriaid lugemisõigusega päringuga:
kolm kirjet, neist kaks `rescue` ja üks `vessel`. Kategooriata kirjeid ei olnud.
Andmeid ei kirjutatud ümber. Kategooriata/tundmatute kirjete varuvariant on
siiski testitud ning admin saab kategooriat tavapärasest vormist muuta.

Uut `incidentType` paralleelvälja ei lisatud: kasutatakse olemasolevat
`calloutType` väärtustega `sar`/`tross`; puuduv/vigane tüüp loetakse SAR-iks.
Puuduvad eelistused kasutavad rolli vaikimisi valikuid. Puuduv testtunnus on false.
Vanad planeeringud ja ajaloolised logid säilivad. Eraldi migratsioon pole vajalik.

Juhendi avaldamiseks saab administraatori töövahendiga määrata
`publicAppInfo/login` dokumenti `guideText` ja `infoText` või `guideUrl` ja
`infoUrl` (ainult kehtiv HTTPS-aadress). Sisu ega aadressi pole välja mõeldud;
seadistamata nupul on arusaadav teade ja kontakt. Sisu hilisem uuendamine ei vaja APK-d.

## Kontrollid

Kohalikud tulemused 2026-09-29:

- `flutter analyze --no-pub`: vigadeta.
- Kõik Flutteri testid: **106/106**.
- Firestore'i/Storage'i emulatori ja serveri põhivoogude testid: **86/86**.
- Cloud Functions Node-testid: **62/62**; `node --check functions/index.js` läbib.
- `npm run lint --prefix functions` käivitatud; projektis on see teadlikult
  olemasolev „No lint configured” käsk, seega eraldi lintimise katvust ei väideta.
- Androidi debug-APK ehitus õnnestus.

Testitud: SAR miinimum/II aste/planeering/paus; Trossi loomine ja liikme vastus
ilma SAR-valmiduseta; teavituste koondamine/eelistused/idempotentsus;
liikmetaotluse minimaalse sisuga e-post; platvormi adressaadid; vanade andmete
varuvariandid; kategooriate rühmitus; testväljakutse välistamine panusest;
admini testtunnuse audit; võõra ühingu, eemaldatud liikme ja platvormi õiguste
piirid; telefoni 320-piksline sisselogimine ja aruande komponendid.

Uued regressioonid on `functions/phone-pack23.test.js`,
`test/phone_pack23_test.dart` ja `rules-tests/firestore.rules.test.js` lõpus.
Täiendatud on ka statistika, olemasolevate teadete ja navigatsiooni teste.
CI ja tootmise avaldamise tulemused lisatakse üleantavasse väljalaskeraportisse.

## Telefonitest ja teadlikud piirid

Uue UI, helifaili ja Androidi kanalite kasutamiseks **on vaja uut APK-d**.
Serveri Functions ja reeglite muudatused avaldatakse eraldi. Kanal `sar_alarm_v2`
on uus, et vana kanali muutmatu heli ei takistaks uue heli kasutamist.
Androidi kasutaja heli, DND-erandid ja aku piirangud jäävad kasutaja kontrollida.
Täisekraani häiret ega DND-st omavolilist möödumist ei lisatud.

Füüsilisel telefonil kontrollida:

1. Sisselogimine ja püsimine pärast sulgemist; kahe ühingu vahetus.
2. Isiklik staatus/ühekordne/korduv mittevalve; algus/lõpp ja tühistamine;
   Ühingu valmiduses sama efektiivne seis ja meeskond.
3. Admini miinimum/ühingu paus; tavaliige näeb seisu, juhtnuppe ei näe.
4. Üks koondatud valmiduse teade; vabatahtlik valik väljas; taastumise teade.
5. SAR foreground/background/lukustuskuva, eristuv heli ja teavitusest täpselt
   sama väljakutse detaili avamine; Trossi tavalisem heli ja reageerimine.
6. Liikmetaotluse rakendusesisene teade/push/e-post; platvormi taotluse arv ja teade.
7. Nime/telefoni muutmine; tavaliige ei muuda astet; admin saab astet muuta.
8. Testväljakutse filter/statistika; kasutatud varustuse kategooriad aruandes/PDF-is.
9. Operatiivlogi lisamine, GPS ja ekraani ärkvelhoidmine, hilisem kokkuvõte,
   osalejad, helistaja/SMS avamine.

Pärisseadme pushi/heli/DND toimimist ega tegelikku uue taotluse e-kirja saabumist
siin automaattestidega tõendatuks ei nimetata; need katsed teeb kasutaja.
E-posti parooli uuesti ei vajata: kasutatakse varem seadistatud SMTP secret'it.

Teadlikult järgmisse etappi jäävad täielik Stitchi disainisüsteem ja automaatne
telefonitestide levitamine. Androidi ehitus teavitab Gradle/AGP/Kotlini tulevase
uuendamise vajadusest; töötavat tööriistaahelat selles funktsioonipaketis ei uuendatud.
E-posti muutmise eraldi kordusautentimise töövoogu ega uut SAR sihtaega ei lisatud.

Androidi käitumise alus:
[teavituskanalid](https://developer.android.com/develop/ui/compose/notifications/channels),
[kanali kasutaja seadistused](https://developer.android.com/reference/android/app/NotificationChannel),
[FCM-i prioriteet](https://firebase.google.com/docs/cloud-messaging/android-message-priority),
[teavitusest avamine Flutteris](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

## Muudetud failid

- `android/app/src/main/kotlin/com/example/respondcrew_app/MainActivity.kt`
- `android/app/src/main/res/raw/sar_alarm.wav`
- `docs/phone-test-packs-2-3.md`
- `firestore.rules`
- `functions/application-notifications.js`
- `functions/callout-alarm-delivery.js`
- `functions/callout-notification-payload.js`
- `functions/callout-test-status.js`
- `functions/certificate-reminders.js`
- `functions/certificate-reminders.test.js`
- `functions/contribution-statistics.js`
- `functions/contribution-statistics.test.js`
- `functions/effective-readiness.js`
- `functions/index.js`
- `functions/member-request-notification.js`
- `functions/member-request-notification.test.js`
- `functions/notification-preferences.js`
- `functions/organization-management.js`
- `functions/organization-readiness.js`
- `functions/personal-notifications.js`
- `functions/phone-pack23.test.js`
- `functions/readiness-availability.js`
- `functions/readiness-planning.js`
- `functions/test-helpers/memory-db.js`
- `lib/models/callout_model.dart`
- `lib/models/equipment_model.dart`
- `lib/models/information_notification_open.dart`
- `lib/models/notification_preferences.dart`
- `lib/models/operation_log_model.dart`
- `lib/screens/admin_home_dashboard.dart`
- `lib/screens/availability_screen.dart`
- `lib/screens/callout_detail_screen.dart`
- `lib/screens/callout_report_screen.dart`
- `lib/screens/callouts_screen.dart`
- `lib/screens/equipment_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/login_screen.dart`
- `lib/screens/main_navigation_shell.dart`
- `lib/screens/member_home_dashboard.dart`
- `lib/screens/member_profile_screen.dart`
- `lib/screens/menu_screen.dart`
- `lib/screens/notification_settings_screen.dart`
- `lib/screens/notifications_screen.dart`
- `lib/screens/operation_log_screen.dart`
- `lib/screens/platform_management_screen.dart`
- `lib/services/availability_service.dart`
- `lib/services/callout_alarm_notification_service.dart`
- `lib/services/callout_report_pdf.dart`
- `lib/services/notification_service.dart`
- `lib/services/operation_log_service.dart`
- `lib/services/readiness_availability_service.dart`
- `lib/services/user_service.dart`
- `lib/widgets/active_callouts_card.dart`
- `lib/widgets/callout_test_status_control.dart`
- `lib/widgets/crew_readiness_card.dart`
- `lib/widgets/login_information.dart`
- `lib/widgets/minimum_crew_control.dart`
- `lib/widgets/operation_log_actions.dart`
- `lib/widgets/operation_note_dialog.dart`
- `lib/widgets/organization_planning.dart`
- `lib/widgets/own_profile_editor.dart`
- `lib/widgets/platform_application_notices.dart`
- `lib/widgets/platform_pending_badge.dart`
- `rules-tests/firestore.rules.test.js`
- `test/callout_creation_test.dart`
- `test/main_navigation_shell_test.dart`
- `test/member_readiness_visibility_test.dart`
- `test/operation_log_actions_test.dart`
- `test/phone_pack23_test.dart`
