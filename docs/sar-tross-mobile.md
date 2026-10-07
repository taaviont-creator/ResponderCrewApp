# SAR ja TROSS ning mobiilivaate uuendus

## Käitumine
- `calloutType` on eraldi `sar` / `tross` väli. Vanad tüübita kirjed loetakse SAR-iks. Pealkiri ei määra reegleid.
- Tüübi valik eeltäidab pealkirja kuni kasutaja seda muudab. Kirjelduse kiirvalikud lisavad teksti ühekordselt ning säilitavad käsitsi sisestatu.
- TROSSI `responseTargetMinutes` on täisarv 1–60, vaikimisi 60. SAR-il seda välja ei seadistata: väljasõiduaeg on ühingu kokkulepe.
- Liikme olemasolev `responseMinutes` jääb isiklikuks saabumishinnanguks. Üldine valmisolek, reageerimine ja pardalolek ei ole samad andmed.
- Rakenduses ei olnud varem SAR-i aktiveerimist blokeerivat koosseisu/II astme kontrolli. Olemasolev SAR-i valmisoleku arvutus (ühingu miinimumkoosseis + II aste) säilib. TROSS ei lisa uusi blokeerivaid koosseisunõudeid.
- Aktiveerimine loob aktiivse väljakutse ja avatud logi, mitte väljasõidu. Tegelik väljasõit tuleb logi esimesest `enRoute` (ka vana `departed`) staatusekandest. Sihtaega mõõdetakse serveri loodud aktiveerimisajast. Ületamine on info, mitte automaatne staatusemuutus.
- Õigused säilivad: väljakutse loob ühingu admin, teiste liikmete vastuste detailid on endiselt adminile.

## Mobiilivaade ja logi
Stitchi mereline tume palett on kohandatud selgete läbipaistmatute kaartidega. Töölaud alustab aktiivse väljakutsega ning selle kaart avab täpse väljakutse. Valmisoleku juures kuvatakse salvestuse ootel olek; vigased/laadimata allikad ei esine kinnitatud valmisolekuna. Aluste kokkuvõte kasutab päris varustuskirjeid ja ilmub ainult olemasolevate aluste korral.

Põhimenüü: Töölaud, Väljakutsed, Liikmed, Varustus, Veel. Teavitused on töölaua ülaribal ja Veel all; valmisoleku planeerimine ja statistika Veel all. Alumises menüüs jäävad kõik viis sihtkohta nähtavaks; kitsa ekraani või suurendatud teksti korral murravad nimetused mitmele reale. Peamised tegevusnupud kasvavad tekstiga kaasa.

Logi staatuse muutus nõuab kinnitamist; ajajoon ja väljavõte näitavad autorit (nimi või olemasoleva kande kasutaja ID). Side ja pukseerimine on eraldi valitavad tegevused, mitte automaatsed etapid. Muudatus ei loo näidisandmeid, aluse/meeskonna määranguid ega väliste ühenduste nuppe.

## Kontrollid
- Flutteri mudeli- ja vormitestid: teksti säilimine, tüübivahetus, salvestusviga, 320 px ekraan 200% tekstiga, sihtaeg ja tegelik väljasõit.
- Firestore emulaator: üks SAR-astmeta admin ja null vastust; TROSS 1/60 lubatud, 0/61/murdarv/string keelatud; vana SAR; muutmatu tüüp; liikme loomiskeeld; väljakutse + teavitus + avatud logi + esimene kanne ühes salvestuses; võltsitud aktiveerimisaja keeld.
- Olemasolevad SAR-i valmisoleku, planeeritud puudumiste, liitumise, logi ajaloo ja õiguste testid jäävad testipakki.

## Androidi vastuvõtukatse päris seadmel (vajab tegemist)
1. Paigalda uuest mainist ehitatud APK. Kontrolli sisselogimist, ühinguvahetust ja püsimist pärast sulgemist.
2. Admin: loo SAR, muuda pealkirja, lisa mitu kiirvalikut ja vabatekst; vaheta tüüpi ja tagasi. Tekst peab säilima. SAR-i sihtaega ei küsita.
3. Loo TROSS ühe astmeta liikmega ja ilma kinnitatud reageerijateta. Vaikimisi sihtaeg 60, lubatud 1–60. Ava uuesti ja kontrolli tüüpi ning teksti.
4. Teises telefonis kontrolli push/alarm esiplaanil, taustal ja lukus ekraanil; vajutus peab avama täpselt sama väljakutse. Anna vastus ja isiklik saabumisaeg.
5. Kontrolli üldist valmisolekut ning planeeritud puudumist. Ilma ühenduseta ei tohi kuvada edukat kinnitust.
6. Ava sama väljakutse logi, kinnita väljasõit, lisa side või vajadusel pukseerimine, registreeri tagasitulek ja kokkuvõte. Ava ajajoon ja väljavõte uuesti: tegelik aeg, autor ning GPS või selge puudumise märge.
7. Kontrolli logi ekraani ärkvel hoidmist, telefoninumbri avamist helistajas, kitsast kuva ja suurt teksti.

Päris-seadme alarmi, GPS-i, ärkvelhoidmise ja helistaja tulemust ei saa asendada automatiseeritud testidega. Varustuse kontrollnimekirjad, statistika laiendused ja välised ühendused jäävad eraldi etappidesse. Automaatne e-posti kutse ning uue ühingu platvormiadmini e-kiri vajavad endiselt e-posti teenuse/SMTP/API saladuse seadistust.

## Androidi SAR-heli parandus 2026-10-07 (1.0.1)

Eelmise optimeeritud APK kontroll leidis, et `sar_alarm.wav` oli ressursi vähendamisel eemaldatud. `res/raw/keep.xml` säilitab nüüd Dartist nime järgi kasutatava helifaili ja teavitusikooni. APK üleandmisel tuleb käivitada `python tool/verify_apk_alarm.py <apk>`; kontroll võrdleb pakitud heli räsi originaaliga ja tuvastas vea ka eelmises APK-s.

SAR kasutab kliendis kanalit `sar_alarm_v3` ja `AudioAttributesUsage.alarm`. Vana kanali helikasutust ei saa kohapeal muuta. Migratsioon säilitab kasutaja vaigistuse, kanali blokeerimise, valitud muu heli, vibratsiooni ja olemasoleva DND-erandi. Rakenduse vana numbrilise heliviite asendab stabiilne `android.resource://com.example.respondcrew_app/raw/sar_alarm` viide. Olemasolevat v3 kanalit ei lähtestata. Esiplaani, tausta andmesõnum ning kohalik proov kasutavad sama kanalit. Vanemate klientide serverisüsteemiteavitus jääb v2 kanalile; serveri payload ega õigused ei muutu.

Telefoni seadetes kuvatakse alarmi tegelik helitugevus. DND eriligipääsu järel saab kasutaja eraldi nupuga lubada SAR-erandi; tulemus loetakse süsteemist tagasi. Kui Android ei luba kanalit rakendusest muuta, avatakse kanali seaded. Rakendus ei muuda üldist DND-režiimi ega tõsta helitugevust. Kohe kuulatav proov kasutab sama heli kui saabuv SAR. Telefoniseaded ei sõltu enam ühingu teavituseelistuste võrguvastusest. Menüüs kuvatakse paigaldatud Androidi paketi versioon.

Väljakutsete „Aktiivsed“ ja „Lõpetatud“ valikud jäävad nähtavaks ka laadimisel ja laadimisvea korral, viimasel juhul lisandub uuesti proovimine. Need valikud olid olemas juba eelmise APK lähtekoodis; kasutaja Xiaomi 14 / Android 16 telefonis kirjeldatud kadumist ei ole pärisseadmes reprodutseeritud. Muudetud laadimis- ja veavaated ning 320 px suure tekstiga paigutus on kaetud widget-testidega.

Kontroll: 282 Flutteri testi läbisid; eraldi kaetud kanali migratsioon, vanade heliviidete parandamine, vaigistuse säilitamine, DND keeld/luba, versiooninäit ning kahe valiku püsimine laadimisel ja vea korral. Pärisseadmes vajavad kontrolli tavaline ja vaikne režiim, DND, lukustatud ekraan, pooleliolev kõne ja serverist saabuv prooviväljakutse. Alarmikanal ei taga heli, kui alarmi helitugevus on null, teavitused/kanal keelatud või Android/tootja heli piirab. Kõne ajal helifookus võib olla lukustatud. Android 7-l puuduvad teavituskanalid; v3 alarmihelitee eeldab Android 8 või uuemat.

Allikad: https://developer.android.com/reference/android/app/NotificationChannel ja https://developer.android.com/media/optimize/audio-focus .
