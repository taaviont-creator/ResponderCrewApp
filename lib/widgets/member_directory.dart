import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/membership_model.dart';

class DirectoryMember {
  const DirectoryMember({
    required this.id,
    required this.name,
    required this.role,
    required this.level,
    required this.status,
    this.isSelf = false,
  });
  final String id, name, role, level, status;
  final bool isSelf;
}

String memberDirectoryCsv(List<DirectoryMember> members) {
  String cell(String value) {
    final safe = RegExp(r'^[=+@\-\t\r]').hasMatch(value) ? "'$value" : value;
    return '"${safe.replaceAll('"', '""')}"';
  }

  return [
    ['Nimi', 'Roll', 'Merepäästja aste', 'Valmisolek'],
    for (final member in members)
      [
        member.name,
        MembershipRole.isOrgAdmin(member.role) ? 'Admin' : 'Liige',
        member.level == SeaRescueLevel.level2
            ? 'II aste'
            : member.level == SeaRescueLevel.level1
            ? 'I aste'
            : 'Määramata',
        member.status,
      ],
  ].map((row) => row.map(cell).join(';')).join('\n');
}

class MemberDirectory extends StatefulWidget {
  const MemberDirectory({
    super.key,
    required this.members,
    required this.onOpen,
    required this.onContact,
    this.adminSections = const [],
    this.busyUserId,
  });
  final List<DirectoryMember> members;
  final ValueChanged<String> onOpen;
  final void Function(String, bool) onContact;
  final List<Widget> adminSections;
  final String? busyUserId;
  @override
  State<MemberDirectory> createState() => _MemberDirectoryState();
}

class _MemberDirectoryState extends State<MemberDirectory> {
  String _query = '', _level = 'all', _sort = 'name';
  @override
  Widget build(BuildContext context) {
    final members = widget.members
        .where(
          (m) =>
              m.name.toLowerCase().contains(_query.toLowerCase()) &&
              (_level == 'all' || m.level == _level),
        )
        .toList();
    members.sort((a, b) {
      if (_sort == 'role') {
        final order = (MembershipRole.isOrgAdmin(a.role) ? 0 : 1).compareTo(
          MembershipRole.isOrgAdmin(b.role) ? 0 : 1,
        );
        if (order != 0) return order;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${widget.members.length} ühingu liiget',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: memberDirectoryCsv(members)),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nähtavate liikmete CSV kopeeritud.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Liikmed CSV'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Otsi nime järgi',
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            _level == 'all' && _sort == 'name'
                ? 'Filtrid ja järjestus'
                : 'Filtrid ja järjestus · muudetud',
          ),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DropdownButton<String>(
                  isExpanded: true,
                  itemHeight: null,
                  value: _level,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Kõik astmed')),
                    DropdownMenuItem(
                      value: SeaRescueLevel.none,
                      child: Text('Aste määramata'),
                    ),
                    DropdownMenuItem(
                      value: SeaRescueLevel.level1,
                      child: Text('I aste'),
                    ),
                    DropdownMenuItem(
                      value: SeaRescueLevel.level2,
                      child: Text('II aste'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _level = value!),
                ),
                DropdownButton<String>(
                  isExpanded: true,
                  itemHeight: null,
                  value: _sort,
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('Nime järgi')),
                    DropdownMenuItem(value: 'role', child: Text('Adminid ees')),
                  ],
                  onChanged: (value) => setState(() => _sort = value!),
                ),
              ],
            ),
          ],
        ),
        ...widget.adminSections,
        if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Otsingule vastavaid liikmeid ei leitud.'),
          ),
        for (final member in members) _memberRow(context, member),
      ],
    );
  }

  Widget _memberRow(BuildContext context, DirectoryMember member) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final level = member.level == SeaRescueLevel.level2
        ? 'II aste'
        : member.level == SeaRescueLevel.level1
        ? 'I aste'
        : 'Aste määramata';
    final details = InkWell(
      onTap: () => widget.onOpen(member.id),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${member.name}${member.isSelf ? ' · Mina' : ''}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${MembershipRole.isOrgAdmin(member.role) ? 'Ühingu admin' : 'Liige'} · $level',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(member.status, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
    final actions = member.isSelf
        ? TextButton(
            onPressed: () => widget.onOpen(member.id),
            child: const Text('Minu andmed'),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sms in [false, true])
                IconButton(
                  tooltip: '${sms ? 'SMS' : 'Helista'}: ${member.name}',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: widget.busyUserId != null
                      ? null
                      : () => widget.onContact(member.id, sms),
                  icon: Icon(sms ? Icons.sms_outlined : Icons.phone_outlined),
                ),
            ],
          );
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: details),
                if (!largeText) ...[const SizedBox(width: 4), actions],
              ],
            ),
            if (largeText)
              Align(alignment: Alignment.centerRight, child: actions),
          ],
        ),
      ),
    );
  }
}
