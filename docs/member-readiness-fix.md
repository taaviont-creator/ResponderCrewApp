# Liikme valmisoleku nähtavuse parandus — 29.09.2026

Põhjus: avalehe ühine meeskonnakaart luges kõigi liikmete privaatseid planeeritud puudumisi. Turvareeglid lubavad neid lugeda ainult omanikul/adminil. Päringu viga peitis valmisoleku ning ka valvepausi teate. Valmisoleku lehe eraldi arvutus käsitles sama päringu viga ekslikult tühja puudumiste loendina.

Parandus: olemasolevatest puudumisandmetest koostab server ainult hetkel mittevalves olevate kasutajate tunnused. Aktiivne sama ühingu liige saab seda tulemust lugeda; märkused, tulevased ajad ja kordumise mustrid vastuses puuduvad. UI uuendab tulemust kuni 30-sekundilise intervalliga. Käsitsi valve muutused ja ühingu valvepaus tulevad olemasolevast Firestore reaalajavoost.

Avaleht ja valmisoleku leht kasutavad sama kaarti/arvutust. Valmisoleku lehel säilib ka mittevalves liikmete loend. Valvepausi põhjus kuvatakse ka siis, kui mõni meeskonna päring ebaõnnestub. Ebaõnnestunud päringu ajal ei näidata tõendamata valmisolekut; taastunud päring eemaldab veateate. Ühingu vahetus tühjendab vana ühingu andmed.

Firestore/Storage reegleid ei muudeta. Ühingu valve juhtimine jääb adminile. Platvormiroll üksi ei anna uue päringu õigust.

Kontroll: 88 Flutteri, 51 Functions'i ja 72 reeglite/integratsioonitesti läbivad. Analüüs vigadeta. Uued testid katavad liikme vaate, pause koos veaga, ühenduse taastumise, ühingu vahetuse, puudumise ajapiirid, Tallinna suve-/talveaja ning privaatandmete ja muutmisõiguse piirangu.

Parandus vajab uut rakenduse APK-d; serveriparandus üksi vana rakenduse keelatud päringut ümber ei suuna. Pärast paigaldamist andmete tavamuutused APK uuendust ei vaja.
