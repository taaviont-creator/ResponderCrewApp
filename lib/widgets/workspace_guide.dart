import 'package:flutter/material.dart';

Future<void> openWorkspaceGuide(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialog) => AlertDialog(
    title: const Text('Kasutusjuhend'),
    scrollable: true,
    content: const Column(mainAxisSize: MainAxisSize.min, children: [
      ExpansionTile(title: Text('Töölauad ja liitumine'), children: [Text('Üks aktiivne liikmesus avab vastava töölaua. Mõlema liikmesusega saad töökeskkonda vahetada. Merepääste liitumiskoodiga esitad taotluse ühingu administraatorile. TRU kutse võtad vastu sama kinnitatud e-postiga kontol.')]),
      ExpansionTile(title: Text('Valve ja planeeritud mittevalved'), children: [Text('Sisesta oma eelseisev mittevalve Valmisoleku lehel. Ühingu valmiduse vaates näed liikmete ajavahemikke Eesti aja järgi. Isiklikud märkused jäävad privaatseks. Ühingu miinimumkoosseis näitab, mitu valves liiget on vähemalt vaja. Lubatud valve üksi ei tähenda, et vajalik meeskond on koos.')]),
      ExpansionTile(title: Text('Ühingu valve peatamine'), children: [Text('Vali „Võta ühing valvest maha“, kirjuta liikmetele nähtav põhjus ja kinnita. Peatamise ajal peatub liikmete valveaja arvestus. Koolituste ja tegevuste panuse arvestus jätkub. Valve jätkamiseks vali „Taasta ühingu valve“.')]),
      ExpansionTile(title: Text('TRU rollid, kutsed ja koolitused'), children: [Text('Platvormihaldur määrab üleriigilise TRU juhi. Juht kutsub koordinaatoreid ja liikmeid. Koordinaator kutsub oma regiooni liikmeid. Enda profiilis saad lisada kontaktandmed, läbitud koolituse ja tunnistuse kehtivusaja. Koolitust saab kinnitada vastava õigusega teine kasutaja.')]),
      ExpansionTile(title: Text('TRU regioonid ja tegevuste jagamine'), children: [Text('Juhi vaates „Kõik“ kuvatakse kõigi regioonide tegevused. Tegevuse loomisel kontrolli välja „Kellele?“. Ühe regiooni õppuse jagamisel teise regiooni liikmetele kinnitab avaldamise vastuvõttev koordinaator.')]),
      ExpansionTile(title: Text('Vajalik liikmete arv ja ajaline katvus'), children: [Text('Märgi, mitu inimest on tegevuseks korraga vaja. Osaleja valib „Osalen“ ja lisab ajavahemiku. Katvus loeb antud hetkel planeeritud osalejaid. Näiteks kui vaja on nelja liiget ja kell 12–14 kattuvad kolme liikme ajad, on selles vahemikus üks liige puudu. Ilma ajavahemikuta vastus katvusse ei lähe.')]),
    ]),
    actions: [TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Sulge'))],
  ),
);
