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
    ['Nimi', 'Roll', 'Merepääste aste', 'Valmisolek'],
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DropdownButton<String>(isExpanded: true, itemHeight: null,
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
            DropdownButton<String>(isExpanded: true, itemHeight: null,
              value: _sort,
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Nime järgi')),
                DropdownMenuItem(value: 'role', child: Text('Adminid ees')),
              ],
              onChanged: (value) => setState(() => _sort = value!),
            ),
          ],
        ),
        ...widget.adminSections,
        if (members.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Otsingule vastavaid liikmeid ei leitud.'),
          ),
        for (final member in members)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => widget.onOpen(member.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          child: Text(
                            member.name.trim().isEmpty
                                ? '?'
                                : member.name
                                      .trim()
                                      .substring(0, 1)
                                      .toUpperCase(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${member.name}${member.isSelf ? ' · Mina' : ''}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                MembershipRole.isOrgAdmin(member.role)
                                    ? 'Ühingu admin'
                                    : 'Liige',
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${member.level == SeaRescueLevel.level2
                          ? 'II aste'
                          : member.level == SeaRescueLevel.level1
                          ? 'I aste'
                          : 'Aste määramata'} · ${member.status}',
                    ),
                    if (member.isSelf)
                      TextButton.icon(
                        onPressed: () => widget.onOpen(member.id),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Minu andmed'),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Helista: ${member.name}',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: widget.busyUserId != null
                                ? null
                                : () => widget.onContact(member.id, false),
                            icon: const Icon(Icons.phone_outlined),
                          ),
                          IconButton(
                            tooltip: 'SMS: ${member.name}',
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: widget.busyUserId != null
                                ? null
                                : () => widget.onContact(member.id, true),
                            icon: const Icon(Icons.sms_outlined),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
