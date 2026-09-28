# iPhone ja iPad: valmidus ning avaldamine

## Praegune seis

Flutteri ühine kasutajaliides ja Firebase'i iOS-i rakenduse identifikaator on olemas. Xcode'i Runner sihib nii iPhone'i kui ka iPadi (TARGETED_DEVICE_FAMILY 1,2; iOS 13). See ei kinnita veel, et rakendus on Apple'i seadmel kasutusvalmis.

Apple'i tõuketeavituste registreerimine ootab APNs-i võtit enne FCM-i võtme küsimist. Ooteaeg on piiratud ning rakenduse esiplaanile tulekul saab registreerimine uuesti proovida. Android ei oota APNs-i võtit.

CI-s on eraldi Maci töö, mis kontrollib Swift/Xcode'i olemasolu ja ehitab iOS-i simulaatori rakenduse. Sõltuvused lisab Flutter Swift Package Manageri kaudu. Simulaatori ehitus ei ole allkirjastatud iPhone'i paigaldusfail ega kinnita tõuketeavituste saabumist pärisseadmes.

Apple'i käivitus kasutab Flutteri UIScene elutsüklit. Lisatud on kohalike teavituste delegate, taustateavituste deklaratsioon ja APNs entitlement (Debug: development, Release/Profile: production). Operatsioonilogi olemasoleval respondcrew/wakelock kanalil on iOS-i teostus; see hoiab nähtava rakenduse ekraani ärkvel, mitte ei käivita logi taustal. Nimi seadmes on RespondCrew.

## Enne iOS-i kasutusvalmiduse kinnitamist

- Kontrollida Maci CI tegelikku tulemust ja lahendada ehitusvead.
- Kontrollida tel/sms avamist iPhone'il ning puuduvat helistamisvõimalust iPadil.
- Kontrollida Firebase'i Apple'i konfiguratsiooni vastavust allkirjastatava rakenduse bundle ID-le. Praegune registreeritud ID on com.example.respondcrewApp; lõplikku Apple'i rakenduse identiteeti ei ole selles töös muudetud.
- Seadistada Apple Developer meeskond, allkirjastamine ja Firebase'i APNs authentication key. Privaatseid võtmeid ei lisata repositooriumisse.
- Jagada allkirjastatud rakendus TestFlightiga ja läbida allolev seadmekatse.

## iPhone'i ja iPadi lõppkatse

1. Sisselogimine, äpi sulgemine/taasavamine ja püsiv sisselogimine.
2. Ühingu vahetamine: profiil, valmisolek, liikmed, logi ja statistika näitavad valitud ühingut.
3. Valves / Hilinemisega / Mitte valves; planeeritud valvevälise aja mõju.
4. Väljakutse teade esiplaanil, taustal ja lukustatud ekraanil. Puudutus avab täpse väljakutse ka teisest ühingust ning külmkäivitusel. Korduste puudumine.
5. Teavituste keelamine ja hilisem lubamine seadetes; APNs/FCM registreerimise taastumine.
6. Reageerimisvastus, osalejate kinnitamine admini ja II astme liikmena, logi tagantjärele täiendamine ning väljavõte.
7. GPS-i luba lubatud/keelatud; logi peab jääma kasutatavaks ka asukohata. Logi avatuna ekraan ei lukustu, lahkumisel taastub tavakäitumine.
8. Helistamine ja SMS iPhone'il; iPadil arusaadav tulemus, kui vastavat teenust ei ole.
9. iPad püst-/rõhtasendis ja suurendatud tekst: vormid, dialoogid ja tabelid mahuvad ekraanile.

Heliga tavaline teavitus ei võrdu hääletust režiimist ja Focusest läbi tuleva alarmiga. Critical Alerts vajab Apple'i eraldi heakskiidetud õigust ning kasutaja luba. Seda õigust ei ole praegu taotletud ega lubatud. Seadme jõuga suletud rakenduse ja võrguühenduseta oleku piiranguid tuleb samuti pärisseadmel hinnata.

Macile eraldi töölauarakendust ei ole veel lisatud; selle vajadus tuleb kasutajaga täpsustada.

Allikad:
- https://docs.flutter.dev/deployment/ios
- https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers
- https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- https://developer.apple.com/design/human-interface-guidelines/managing-notifications
