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

Põhimenüü: Töölaud, Väljakutsed, Liikmed, Varustus, Veel. Teavitused on töölaua ülaribal ja Veel all; valmisoleku planeerimine ja statistika Veel all. Väga kitsa ekraani või suurendatud teksti korral saab alumist menüüd horisontaalselt kerida, et nimetusi ei kärbitaks. Peamised tegevusnupud kasvavad tekstiga kaasa.

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
