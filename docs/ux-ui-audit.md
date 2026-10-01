# RespondCrew UX/UI korrastus · 01.10.2026

## Kontrolli alus ja piirid

Kohalik olemasolev lahendus: `lib/screens/` kõik 37 vaatefaili, nende navigatsioon ja seotud vidinad, `app_theme.dart`, HomeScreeni õiguste jaotus. Töö jätkab olemasolevaid kohalikke keskuste muudatusi. Serveri teenuseid, andmemudelit ja turvareegleid selle UX-etapi jaoks ei muudeta. APK-d ei koostata.

## Auditi leid → otsus

| Valdkond / olemasolevad vaated | Leid ja korrastus |
| --- | --- |
| Sisselogimine, konto loomine, töökeskkonna valik | Laias brauseris vorm venib. Konto loomisel ei saa klaviatuuri eest kerida. Piirata vormi laiust ja lubada kerimine. Õiguste laadimise värav säilitada. |
| Põhinavigatsioon, Menüü | Viis põhisihti on loogilised, kuid arvutis pole eraldi paigutust. Menüü pikk võrdselt rõhutatud kaartide jada. Telefonis säilitada alumine riba, arvutis külgnavigatsioon; menüüsse teemade kaupa kompaktsed read. Kontrollida salvestamata muudatustega lehelt väljumist. |
| Admini ja liikme töölaud | Meeskond ja varustuse hoiatused võivad kasvada piiramatult; rollidel erinev järjestus. Näidata aktiivset väljakutset, enda staatust, valmidust ja piiratud meeskonna eelvaadet; tegevused ja alused/hoiatused teises plokis. Kõikide kirjeteni nähtav otsetee. Arvutis kaks sisulist veergu. |
| Valmisolek, Ühingu valmidus | Isiklik ja meeskonna vaade juba lahus. Säilitada täielik meeskond koos kontaktidega, planeeritud mittevalved ja admini inline miinimumkoosseis. Mitte tuua keskuste seadistusi operatiivvaatesse tagasi. |
| Ühingu seaded | Kontakt, kood, load, kaart, miinimum ja õigused ühel pikal lehel. Rühmitada ühingu andmed; reageerimine/keskuste kaart; liikmed/õigused; teavitused. Olemasolevad salvestused ja kontrollid säilitada. |
| Liikmed, oma/liikme profiil, tunnistused | Otsing, rollipõhine haldus ja väljale vajutades muutmine on olemas. Säilitada; tunnistusi mitte taastada eraldi üldmenüüsse. Ühtne lehe laius ja profiili sektsioonid. |
| Väljakutsed, detail, osalejad | Aktiivsed enne ajalugu; detailis vastamine, logi, aruanne ja osalejad olemas. Logi avamise eel korduv selgitus ja suur kaart. Muuta logi tegevus kompaktseks ning säilitada väljasõidu ajainfo. |
| Operatiivlogi, logi väljavõte | Suured kiirnupud, ajajoon, lõpetamise kinnitus ja hilisem täiendamine juba olemas. Säilitada, kuna need sobivad operatiivkasutuseks. Iseseisev logiarhiiv jääb menüüsse: kõik vanad logid pole väljakutsega seotud. |
| Sündmuse aruanne ja manused | Andmed automaatsed, kaitstud isikuandmed, mustand ja PDF olemas. Pika vormi salvestus ainult lõpus. Tuua salvestamine püsivasse tegevusribasse, säilitada mustandi/lõpetamise tingimused ning lahkumiskinnitus. |
| Tegevused ja koolitused | Tulevased ja kogu ajalugu samas pikas loendis. Lisada selgelt valitavad Tulemas/Toimunud vaated; säilitada osalemine ja tundide kinnitamine. Töölaua eelvaade juba piiratud kolme sündmusega. |
| Varustus, ühingu load | Varustuse vaated ja filtrid juba olemas, märgised telefonis mahuvad mähitavasse ritta. Säilitada kategooriad, väljastamine, hooldus ja õigused. Lisamisnupud sõnastada nähtavalt. |
| Panus ja statistika | Periood, usaldusväärne valveajalugu ja osalemised olemas. Arvutus jääb samaks; piirata lugemisala laiust, säilitada arvestuse aluste selgitus. |
| Teavitused ja teavituste seaded | Isiklikud eelistused ja telefoni juhised samas vaates. Eristada isiklikke eelistusi ja seadme häire seadistust, veebis mitte pakkuda telefonis heli proovimise nuppu. |
| Keskuste kaart ja admini kaardiseaded | Kaart juba kohanduv koos nimekirja/detailidega, värskus ja legend olemas. Täislaiuses kaart säilitada. Admini üks seadistuskoht säilitada; taotlused, ligipääsud ja staatus jäävad sama serverikontrolli taha. |
| RespondCrew haldus, ootel ühingud, vanad valmidusseaded ja üksuste vaade | Halduses viis temaatilist sissepääsu juba olemas. Vanad üksuste/platvormivalmiduse vaated pole tavamenüüs; neid sinna ei lisata. Säilitada tehnilised andmed ainult haldurile. |

## Rakendatud infoarhitektuur

- Põhinavigatsioon: **Töölaud · Väljakutsed · Valmisolek · Ühingu valmidus · Menüü**.
- Menüü **Ühingu töö**: tegevused/koolitused, liikmed, varustus, logiarhiiv, panus/statistika vastavalt õigustele.
- Menüü **Minu konto**: profiil, teavitused, isiklikud teavituste seaded, ühingu vahetamine.
- Menüü **Haldus**: ühingu seaded ainult selle ühingu adminile; RespondCrew haldus eraldi platvormiõigusega.
- Ühingu seaded: teemade kaupa avatavad sektsioonid, olemasolevate kontrollidega; kaart ühes kohas.
- Sündmuse detail ühendab vastamise, logi, osalejad ja aruande. Aruanne ei dubleeri andmeid ega logi.

## Säilitatavad piirid

Puuteala vähemalt 48 px, logi operatiivnuppe ei kahandata. Heledad pinnad, tume tekst; punane/roheline koos tekstiga. Ühingu andmeid ei ühendata ega muudeta õiguste nähtavust laiendades. Kustutamise/lõpetamise kinnitused ja serveri kontrollid jäävad alles. Rakenduse üldiste seadete alla ei lisata väljamõeldud funktsioone.

## Kontrollid

Rakendamisel lisada kitsas/lai ekraan, suur tekst, põhisihtide ja tagasinavigatsiooni kontroll, salvestamata vormi kaitse, piiratud eelvaate täielikud koondarvud ning valitud sektsioonide oleku säilimine. Käivitada Flutter analyze ja kogu Flutter testipakett. Serverit ja reegleid muutmata ei ole vaja neid uuesti avaldada. Avaldada kontrollitud veebiversioon olemasolevale katsekanalile; telefonitest on kasutaja käes.


## Tehtud muudatused ja olulisemad failid

- `lib/widgets/app_layout.dart`: ühine lehe sisuala (1120 px; sisselogimisvorm 560 px; töölaud 1280 px), kohanduvad kahe veeruga sektsioonid, seadete grupid, sektsiooni otsetee ja statistika mõõdikud. Kaart säilitab täislaiuse.
- `lib/screens/main_navigation_shell.dart`: arvutis külgnavigatsioon, telefonis samad viis põhisihti alumisel ribal; detailvaade säilib ekraani suuruse muutmisel. Kasutaja navigeerimine austab vormi lahkumiskaitset.
- `lib/screens/menu_screen.dart`: Ühingu töö / Haldus / Minu konto, reaalsed rollipiirangud, otsesed sissepääsud ilma iga tegevuse suure kaardita. Platvormiõigus ei ava ühinguadmini valikuid.
- `lib/screens/home_screen.dart`: ühingu seaded nelja temaatilise grupina. Nime/andmete realt avatakse olemasolev valideeritud muutmisvorm; ühingu nimi uueneb samal lehel andmevoost. Õigused ja miinimumkoosseis kasutavad seniseid salvestusi.
- `admin_home_dashboard.dart`, `member_home_dashboard.dart`, `crew_readiness_card.dart`, `vessel_status_card.dart`, `dashboard_quick_actions.dart`: ühtne operatiivne järjestus, arvutis kaks veergu, kuni kolm meeskonnaliiget ja kolm alust/hoiatust; loendist väljajääjate arv ja otseteed. Valmiduse arvud kasutavad täielikku koosseisu. Kõik aktiivsed väljakutsed jäävad nähtavaks. Kiirtegevuste välimus on rollidel sama, nähtavus lähtub õigustest.
- `activities_screen.dart`: Tulemas/Toimunud valik, kogu ajalugu ei pikenda vaikimisi tulevaste tegevuste lehte.
- `callout_detail_screen.dart`: logi avamine kompaktsem, väljasõidu ajainfo säilib.
- `callout_report_screen.dart`: püsiv salvestusriba, salvestusviga tegevuse kõrval, koostaja/juhi valikute selged vahed. Mustandi ja valmis aruande serveritingimused, andmekonflikti kontroll ja tundlike isikuandmete eraldatus säilivad.
- `member_profile_screen.dart`: kontaktandmed ja liikmelisus grupeeritud, üksikute väärtuste pesastatud kaardid eemaldatud; välja vajutamise muutmisõigused endised.
- `statistics_screen.dart`: mõõdikud lähtuvad sisuala laiusest; suure tekstiga üks veerg. Arvutusi ei muudeta.
- `equipment_screen.dart`: nimekirja lisamistegevus mahub kitsal ekraanil järgmisele reale.
- `register_screen.dart`: vorm kerib klaviatuuri eest ära. `notification_settings_screen.dart`: veebis selge suunamine telefoni SAR-häire seadistusele, seal ei kuvata töötamatut kohalikku heliproovi.
- Ülejäänud vaadetes rakendatud ühine lehe raam ja teema, säilitades olemasolevad tegevused. Lisamise ujuvnupud on tekstiga. `app_theme.dart`: ühtsed 48 px puutealad, kompaktsemad loendiread, vormid, kaardid ja dialoogid.

## Kontrollitud tulemus

- `flutter analyze --no-pub`: **0 probleemi**.
- `flutter test --no-pub`: **169 testi läbivad** (157 varasemat + 12 uut regressioonitesti).
- Uus `test/ux_navigation_layout_test.dart`: rollimenüü kolmes rollis; mobiil/arvuti navigatsioon; avatud detaili säilimine; salvestamata vormi lahkumiskaitse; täielikud valmidusarvud lühendatud eelvaates; seadete sisendi säilimine; aruande salvestusnupu kättesaadavus; suur tekst; klaviatuuriga registreerimisvorm; väga lai statistika.
- Olemasolev statistika kasutajateekonna test ootab nüüd kerimise paigutuse valmimist enne rea vajutamist.
- Kohalik visuaalne kontroll näidisandmetega: menüü arvutis/telefonis, töölaua komponendid, seadete grupid, aruande vorm. Testirenderduse font ei ole täielik pärisbrauseri fondikontroll.
- `flutter build web --release --no-pub --output build/ux-review`: edukas, samuti WebAssembly sobivuse eelkatsed. Olemasolev CupertinoIcons fondihoiatus säilib; veebipaki deklareeritud failide/fondide kontroll läbib.
- Firestore mudel, Security Rules ja Cloud Functions: **selles UX-etapis muutmata**, migratsioone ei ole; neid ei avaldata uuesti.
- APK-d ei koostatud. Päristelefoni operatiivkatse ja välitingimustes loetavus jäävad kasutaja telefonitesti osaks.

## Avaldamine ja tegeliku brauseri kontroll

- Avaldatud olemasolevale `keskused-katse` kanalile: https://respondcrew--keskused-katse-aznyqfmn.web.app/ (kanal kehtib kuni 31.10.2026). Avalikku põhiveebi ei asendatud.
- 01.10.2026 kell 09:57 UTC kontrolliti `index.html`, `flutter_bootstrap.js` ja `main.dart.js` vastust: HTTP 200 ning iga faili SHA-256 vastab kohalikule avaldatud versioonile. Masinkontroll `.local-cache/ux-hosting-verification.json`.
- Chrome'i olemasoleva sisselogimisega avati töölaud, menüü, ühingu seaded ja reageerimise seadete grupp; andmeid ei salvestatud ega muudetud. Ühingu koond oli 3/3 valves ja üks II aste.
- Kontrollitud 390 × 844 telefonilaiusega seadete vaade, miinimumkoosseisu otsetee ja alumine navigatsioon. Ajutine brauserilaius taastati.
- Brauser leidis esialgse välise raamivaate laiusepiirangu keskuste õigusega kontol. Parandatud `app_context_screen.dart`: väline kontekstiraam ei piira kaarti ega külgnavigatsiooni sisaldavat sisu. Lisatud regressioon `auth_context_stability_test.dart`; lõplikus avaldatud versioonis kontrollitud kaheveeruline töölaud.
- Tegelikus brauseris kontrolliti ühinguadmini sessiooni. Tavaliikme ja platvormihalduri menüüpiirangud kontrolliti widget-testides; nende eraldi päriskontodega käsitsi sisselogimist ei väideta tehtuks.
- UX-etapi lõpus olid muudatused arendusharus ja katseveebis. Järgnevas main-harusse viimise etapis on APK koostamine muudetud ainult käsitsi valitavaks (`build_android_apk`, vaikimisi väljas). PR kontrollib Flutterit, serverit, turvareegleid, veebipakki ja iOS-i koostamist.
