# Valmisoleku vaadete täpsustus

Kasutaja viimane täpsustus on määrav: töölaud säilitab minu staatuse,
ühingu valmisoleku koos valves/hilinemisega liikmete nimede ja kontaktidega,
kiirtegevused, lähiaja tegevused/koolitused ning aluste/varustuse seisukorra.

## Muudatused

- Olemasolev isiklik/meeskonna jaotus säilib. Isiklik Valmisolek kasutab ainult
  enda planeeringuid; eraldi organisatsiooni vaade kasutab sama olemasolevat
  meeskonna ja jagatud planeeringute andmeallikat.
- Ühtne nimetus: Ühingu reageerimisvalmidus, ka navigatsioonis, seadetes ja
  teavituse kanali nimes. Vana Planeerimine navigatsioonikirjet ei ole.
- SAR-seis sisaldab valvesolijate/miinimumi suhet, II astme arvu ning puudujääke.
  Ühingu peatamise põhjus jääb nähtavaks; meeskonnanimed säilivad.
- Töölaua kokkuvõttest viib Vaata täpsemalt meeskonna vaatesse. Liikme profiili,
  kõne ja SMS-i tegevused säilivad oma õigustega.
- Miinimumkoosseis ja valve peatamine/taastamine ning tehnika/kontaktide seadete
  link on meeskonna vaate adminsektsioonis. Paralleelne seadete menüülink eemaldati.
- Enda aktiivset ühekordset või korduvat planeeringut saab olemasoleva vormiga
  muuta. Sama dokumendi ID säilib; tühistatud planeeringut ei taasaktiveerita.
- Teavitusest avaneb vastavalt kas isiklik või ühingu vaade.

## Andmed ja õigused

Uusi kollektsioone ega seadistusvälju ei lisatud, migratsiooni pole.
Firestore reeglid lubavad aktiivsel liikmel muuta ainult oma aktiivse planeeringu
ajakava ja märkust. Organisatsiooni, omanikku, staatust, loojaandmeid või rolli ei
saa muuta. Märkus on kuni 2000 märki. Korduva planeeringu HH:mm ja minutite väärtus
peavad klappima; muutmine toimub kliendis transaktsioonina. Teise liikme,
teise ühingu ja tühistatud planeeringu muutmine on keelatud. Admin ei saa selle
liidese kaudu muuta teise liikme isiklikku planeeringut. Jagatud planeeringute
vaade ei avalda isiklikke märkusi.

Tootmise reeglikompilaator tagastas ühise tingimusliku muutmisharu korral 503, kuigi emulatori testid läbisid. Ühekordse ja korduva planeeringu muutmisharud eraldati; tootmise kompilaatori kontroll läbib. Õigused ega salvestusmudel ei muutunud.

Cloud Functionsis muutus ainult valmidusteate varupealkirja sõnastus.
Storage'i reegleid ega ärilist SAR/Trossi valmisolekuarvutust ei muudetud.

## Kontroll

- Flutter analyze: puhas.
- Kõik Flutteri testid: 110/110; pärast töölaua täpsustust 4 asjakohast testi uuesti edukad.
- Firestore/Storage ja serveri põhivood: 88/88.
- Cloud Functions: 63/63.
- Uued widget-testid: SAR-i mõlemad tingimused, profiili avamine, nimede ja
  kontaktinuppude säilimine, peatatud ühingu otsetee, 320 px suurendatud tekstiga navigatsioon.
- Uued reeglitestid: enda mõlema planeeringutüübi muutmine; teise liikme/admini/
  kõrvalise kasutaja katsed; identiteedi/ühingu/rolli võltsimine; vigased ajad;
  vastuolulised kordusajad; liiga pikk märkus; tühistatu muutmise ja taastamise keeld.

GitHubi lõppkontrolli, avaldamise ja APK tõendid lisatakse kasutajale antavasse raportisse.
Telefonis tuleb kontrollida oma ühekordse/korduva planeeringu muutmist ja tühistamist,
töölaua nimest profiili avamist, Vaata täpsemalt otseteed ning admini seadete salvestamist.

Reeglite kontroll kasutas Firebase'i ametlikke [arvuteisenduse](https://firebase.google.com/docs/reference/rules/rules.Integer)
ja [stringitöötluse](https://firebase.google.com/docs/reference/rules/rules.String) kirjeldusi.

## 06.10.2026 — isiklik valmisolek ja ühine mittevalve planeerimine

- Katseveebis kinnitatud kuvamisviga: staatuse valik kasutab `LayoutBuilder`-it,
  kuid senine `AppSectionCard` küsis sellelt `IntrinsicHeight` kaudu sisemist
  kõrgust. Nupud lõigati kaardi serva taha. Isikliku valmisoleku kaardid kasutavad
  nüüd tavalist sisule vastava kõrgusega paigutust; jagatud kaardikomponent ei muutu.
- „Minu staatus“ kuvab otse kolm staatuse valikut. Korduv selgituskast eemaldati;
  aktiivse mittevalve korral kuvatakse lühike põhjus ja valvesse märkimine on blokeeritud.
- Ühekordsed ja iganädalased mittevalved on ühes „Minu mittevalved“ nimekirjas,
  järjestatud alguse / järgmise korduse järgi. Mõlemal säilivad muutmine ja tühistamine.
- Üks „Lisa aeg“ avab vormi, kus „Kordumine“ on „Ei kordu“ või „Igal nädalal“.
  Ühekordsel valitakse kuupäev ja kellaaeg kalendrist; kordusel nädalapäevad ja kellaajad.
  Ajad sisestatakse ja kuvatakse Eesti ajas, nagu serveri valmisolekuarvutuses.
- Vorm säilitab andmed salvestusvea korral ning takistab topeltsalvestust ja sulgemist
  poolelioleva salvestuse ajal. Laadimisviga ei näita ekslikku tühja nimekirja ega staatust.
- Andmevood seotakse ühinguga ning neid ei looda iga kella-/filtrimuudatuse korral uuesti.
  Ühingu vahetamisel eemaldatakse eelmise ühingu vaateandmed.

Andmemudel, Firestore/Storage reeglid, Functions ja õigused ei muutu; migratsiooni pole.
Olemasolevad `plannedUnavailability` ja `plannedUnavailabilityRules` jäävad andmeallikateks.
Olemasoleva planeeringu muutmine säilitab tüübi ja dokumendi ID. Tüübi vahetamiseks saab
vana planeeringu tühistada ja lisada uue. Iganädalane üle südaöö ajavahemik jääb senise
mudeli piiranguks; selles muudatuses öiseid kordusi ega uut kordusmudelit ei lisatud.

Kontroll: 209 Flutteri testi, neist 13 uut regressioonitesti; 320 px vaade ja suurendatud
tekst, aktiivse mittevalve mõju, mõlema tüübi loomine/muutmine, vigased ajad,
salvestusveast taastumine, topeltsalvestuse tõkestamine, ühinguvahetus ja laadimisvead.
APK-d selles muudatuses ei koostata.
