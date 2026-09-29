# RespondCrew e-post

Saatja on RespondCrew <respondercrew@purtsesar.ee>. Saatmine kasutab Zone'i smtp.zone.eu porti 587, kohustuslikku STARTTLS-i ning sertifikaadi kontrolli. SMTP kasutajanimi on saatja aadress. Salasõna on Firebase projekti respondcrew Secret Manageri saladuses RESPONDCREW_SMTP_PASSWORD ja seotud ainult kahe e-posti funktsiooniga. Salasõna ei kuulu reposse, äppi ega logidesse.

## Käivitajad

- `sendOrganizationInviteEmail`: uue `organizationInvites/{inviteId}` dokumendi loomine. Kontrollib uuesti kutse kehtivust, pending-olekut, liikmerolli, kinnitatud ühingut ja kutsuja aktiivset sama ühingu admini liikmelisust. Kutse olemasolev vastuvõtmise protsess ei muutu. Aegunud kutse ei takista uue kutse loomist. Platvormiroll üksi ei anna kutsumisõigust.
- `sendOrganizationApplicationEmail`: uue pending `commands/{organizationId}` dokumendi loomine. Saajad tulevad users.systemRole väärtustest platformAdmin/platformOwner. Aadress võetakse lubatud Firebase Auth kontost, mitte taotleja kontaktprofiilist. Teade ei anna haldusõigust ega kinnita aadressi omandit; otsustamine nõuab endiselt platvormihaldurina äppi sisselogimist. Juba üle vaadatud taotlust ei saadeta.

Varasemaid kutseid ja taotlusi ei saadeta automaatselt tagantjärele. E-kirjad ei sisalda liitumise kinnitamise otseteed: otsus tehakse endiselt äpis olemasolevate õigustega.

## Saatmise olek ja kordussaatmine

Kutse olek asub `organizationInvites/{inviteId}/emailDelivery/status`. Ainult sama ühingu aktiivne admin saab seda dokumenti lugeda. Klient ei saa seda luua, muuta ega kustutada. Platvormi teadete saatmised asuvad serverile reserveeritud `organizationApplicationEmailDeliveries/{organizationId}/recipients/{uid}` dokumentides.

Saatmine hõivab dokumendi atomaarse create-operatsiooniga enne SMTP pöördumist. Paralleelsed käivitused ja Firestore sündmuse kordused ei saada sama kirja uuesti. Salvestatakse startedAt, updatedAt ja staatus:

- sending: saatmine käib; protsessi ootamatu lõpp võib jätta selle oleku alles;
- accepted: SMTP server kinnitas vastuvõtmise; see ei kinnita postkasti jõudmist;
- failed: teadaolev ühenduse/autentimise/saaja viga või saaja tagasilükkamine;
- unknown: saatmise tulemust ei saa kindlalt määrata.

SMTP-l puudub garanteeritud idempotentsus. Pärast saatmise algust ei korrata katset automaatselt, ka aegumise või teadmata tulemuse puhul. Admin saab jagada olemasolevat kutseteksti või tühistada kutse ning luua uue. Enne saatmise algust tekkinud ajutist andmebaasiviga saab sündmuse korduskäivitus ohutult korrata. Äpi ootel taotluste nimekiri jääb esmaseks andmeallikaks ka e-posti tõrke korral.

## Seadistus ja avaldamine

1. Lisa SMTP salasõna Secret Manageris nimega RESPONDCREW_SMTP_PASSWORD. Ära pane seda käsurea argumenti ega vestlusse.
2. Avalda ainult uued funktsioonid ja reeglid: `firebase deploy --project respondcrew --only functions:sendOrganizationInviteEmail,functions:sendOrganizationApplicationEmail,firestore:rules`.
3. Parooli vahetamisel lisa uus secret-versioon ja avalda mõlemad funktsioonid uuesti; varasem versioon ära eemalda enne uuenduse kontrollimist.
4. Kontrolli uue kutse ja uue ühingu tegelikku kirja, rämpspostikausta ning saatja SPF/DKIM/DMARC tulemusi vastuvõtja postkastis.

29.09.2026: domeeni SPF lubab Zone'i saatmist. SMTP autentimine ja TLS läbisid kohaliku ühenduskatse. Windowsi Avast asendas pordi 465 sertifikaadi usaldamatu sertifikaadiga; Zone'i toetatud pordi 587 STARTTLS ühendus läbis täieliku kontrolli. Avastit ega sertifikaadi kontrolli ei lülitatud välja. Kohalikku CA-faili serverisse ei lisatud.

## Kontrollid

- Functions: kutse kehtivus ja õigus, ühingu staatus, saajate piirang, paralleelsed käivitused, SMTP vead ja teadmata tulemus, saladuse puudumine logides, kohustuslik TLS.
- Firestore emulaator: oleku lugemise organisatsioonipiir, kliendikirjutamise/kustutamise keeld, päris andmebaasiga saatmiskäivituse kordus.
- Flutter: saatmise oleku aus sõnastus, olemasolev käsitsi jagamise võimalus, kogu analüüs ja testikomplekt.
- Kohalik tulemus: 45 Functions-, 66 Firestore/emulaatori- ja 85 Flutteri testi läbivad; analyze puhas.

Päris e-kirja kohalejõudmine vajab eraldi vastuvõtja kinnitust. SMTP accepted olek ja automaattestid ei asenda seda kontrolli.
