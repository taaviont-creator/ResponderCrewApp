# Tunnistused ja varustus

- Liikmed → vali liige → Tunnistused → Ava. Liige näeb enda tunnistusi, ühingu admin saab lisada ja uuendada oma ühingu liikmete tunnistusi.
- Ühingu seaded → Ühingu load ja tunnistused. Admin saab salvestada loa nimetuse, numbri, väljastaja, kuupäevad ja lisainfo. Tühi kehtivusaeg tähendab tähtajatut luba. Ühingu load ei ole liikme pädevused.
- Varustus: ühiskasutuses esemed, ladu, mulle väljastatud/isiklik varustus ja liikmetele väljastatud varustuse ülevaade. Senised ühingu esemed jäävad ühiskasutusse; admin saab need menüüst lattu tõsta. Väljastatud ese kaob laost ja ilmub saaja profiili ning liikmete varustusse. Tagastamine viib selle lattu. Seisukord ei muutu väljastamise/tagastamise tõttu.

## Tunnistuste aegumise teated

`sendCertificateExpiryReminders` käivitub iga päev kell 09:00 Europe/Tallinn. 30 päeva enne lõppu (või esimese kontrolli ajal, kui aega on vähem) salvestatakse liikmele ja sama ühingu aktiivsetele adminidele privaatne teade ning saadetakse tavaline push. Aegumisele järgneval päeval saadetakse eraldi aegumise teade. Liige peab olema aktiivne ja ühing kinnitatud. Puuduvaks märgitud tunnistusi ei teavitata. Uue tähtajaga tunnistus saab uue teate; sama tähtaja sama etappi ei saadeta iga päev uuesti.

Push vajab seadmes lubatud teavitusi ja registreeritud seadmetokenit. Äpi teavituste kirje on alles ka siis, kui push ei jõua seadmesse. Ebaselge FCM saatmisvea järel automaatselt uuesti ei saadeta, et vältida korduvaid teateid; tõrked logitakse. Teatele vajutamine avab asjaomase liikme tunnistused ja kontrollib kehtivaid liikmeõigusi.

Ühingu lubade vaade talletab andmed; 30 päeva automaatteavitus käsitleb liikmete tunnistusi.

## Päris-seadme kontroll

1. Admin: ava teise liikme profiil, lisa tunnistus, ava uuesti ja uuenda kehtivusaega. Liige: näe enda tunnistust; teise liikme tunnistuste muutmine pole lubatud.
2. Admin: salvesta raadioside luba numbri ja väljastajaga; ava uuesti, muuda andmeid; kontrolli tähtajatut luba.
3. Lisa lattu ese, vali seisukord, väljasta aktiivsele liikmele. Kontrolli saaja profiili, „Minu varustus” ja „Liikmete varustus” vaadet. Tagasta ja kontrolli, et ese ilmub lattu sama seisukorraga.
4. Testühingus kasuta kontrollpäevast 30 päeva pärast aeguvat tunnistust. Pärast järgmist 09:00 käivitust kontrolli liikme ja admini teavitusi ning kolmanda liikme teate puudumist. Kontrolli push'i äpi eesplaanil, taustal ja lukustatud ekraanil ning puudutusega avanevat õiget liiget. Järgmisel päeval ei tohi sama hoiatus korduda.
5. Kui muuta tunnistuse lõppkuupäeva, kontrolli uue kuupäevaga meeldetuletust. 31 päeva pärast aeguv tunnistus ei tohi veel teadet tekitada.

Automaatseid kutse- ja platvormiadmini e-kirju see muudatus ei aktiveeri; need vajavad e-posti teenuse/SMTP/API saladuse seadistust.
