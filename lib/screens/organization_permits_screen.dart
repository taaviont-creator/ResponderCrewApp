import '../widgets/app_date_field.dart';
import '../widgets/app_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Organization-owned documents are separate from member qualifications.
class OrganizationPermitsScreen extends StatelessWidget {
  const OrganizationPermitsScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
  });
  final String organizationId;
  final String currentUid;

  Future<void> _edit(
    BuildContext context, [
    DocumentSnapshot<Map<String, dynamic>>? document,
  ]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _PermitEditor(
          organizationId: organizationId,
          currentUid: currentUid,
          document: document,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Ühingu load ja tunnistused')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _edit(context),
      icon: const Icon(Icons.add),
      label: const Text('Lisa luba'),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('organizationPermits')
          .where('organizationId', isEqualTo: organizationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Lubade laadimine ebaõnnestus.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.toList()
          ..sort(
            (a, b) => (a.data()['title'] as String).compareTo(
              b.data()['title'] as String,
            ),
          );
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Lisa näiteks ühingule väljastatud raadioside luba. Liikmete tunnistused leiad liikme profiilist.',
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            for (final doc in docs)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(doc.data()['title'] as String),
                  subtitle: Text(
                    [
                      doc.data()['number'],
                      doc.data()['issuer'],
                      (doc.data()['expiresAt'] as String).isEmpty
                          ? 'Tähtajatu'
                          : 'Kehtib kuni ${doc.data()['expiresAt']}',
                    ].where((v) => v != '').join('\n'),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(context, doc),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _PermitEditor extends StatefulWidget {
  const _PermitEditor({
    required this.organizationId,
    required this.currentUid,
    this.document,
  });
  final String organizationId;
  final String currentUid;
  final DocumentSnapshot<Map<String, dynamic>>? document;
  @override
  State<_PermitEditor> createState() => _PermitEditorState();
}

class _PermitEditorState extends State<_PermitEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    for (final key in [
      'title',
      'number',
      'issuer',
      'issuedAt',
      'expiresAt',
      'note',
    ])
      key: TextEditingController(
        text: widget.document?.data()?[key] as String? ?? '',
      ),
  };
  bool _saving = false;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final collection = FirebaseFirestore.instance.collection(
        'organizationPermits',
      );
      final document = widget.document == null
          ? collection.doc()
          : collection.doc(widget.document!.id);
      final data = <String, dynamic>{
        'id': document.id,
        'organizationId': widget.organizationId,
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.document == null) {
        data.addAll({
          'createdBy': widget.currentUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await document.set(data);
      } else {
        await document.update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loa salvestamine ebaõnnestus. Proovi uuesti.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(
      title: Text(
        widget.document == null ? 'Lisa ühingu luba' : 'Muuda ühingu luba',
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in const {
            'title': 'Nimetus',
            'number': 'Loa number',
            'issuer': 'Väljastaja',
            'issuedAt': 'Väljastatud',
            'expiresAt': 'Kehtib kuni (tühi = tähtajatu)',
            'note': 'Lisainfo',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: entry.key.endsWith('At')
                  ? AppDateTextField(
                      controller: _fields[entry.key]!,
                      label: entry.value,
                      enabled: !_saving,
                    )
                  : TextFormField(
                      controller: _fields[entry.key],
                      enabled: !_saving,
                      decoration: InputDecoration(labelText: entry.value),
                      maxLength: entry.key == 'note' ? 2000 : 200,
                      validator: (value) =>
                          entry.key == 'title' && (value ?? '').trim().isEmpty
                          ? 'Sisesta nimetus.'
                          : null,
                    ),
            ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvestan…' : 'Salvesta'),
          ),
        ],
      ),
    ),
  );
}
