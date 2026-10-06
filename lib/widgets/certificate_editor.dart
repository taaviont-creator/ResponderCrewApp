import 'package:flutter/material.dart';
import '../models/certificate_model.dart';
import 'app_date_field.dart';

class CertificateDraft {
  const CertificateDraft({
    required this.title,
    required this.issuer,
    required this.issuedAt,
    required this.expiresAt,
    required this.number,
    required this.note,
    required this.type,
    required this.status,
    required this.noExpiry,
  });
  final String title, issuer, issuedAt, expiresAt, number, note, type, status;
  final bool noExpiry;
}

class CertificateEditor extends StatefulWidget {
  const CertificateEditor({super.key, this.existing, required this.save});
  final CertificateModel? existing;
  final Future<void> Function(CertificateDraft) save;
  @override
  State<CertificateEditor> createState() => _CertificateEditorState();
}

class _CertificateEditorState extends State<CertificateEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _issuer = TextEditingController(text: widget.existing?.issuer);
  late final _number = TextEditingController(text: widget.existing?.number);
  late final _note = TextEditingController(text: widget.existing?.note);
  late DateTime? _issued = parseCalendarDate(widget.existing?.issuedAt ?? '');
  late DateTime? _expires = parseCalendarDate(widget.existing?.expiresAt ?? '');
  late bool _noExpiry = widget.existing?.noExpiry ?? false;
  late String _type = CertificateType.values.contains(widget.existing?.type)
      ? widget.existing!.type
      : CertificateType.other;
  late String _status =
      CertificateStatus.values.contains(widget.existing?.status)
      ? widget.existing!.status
      : CertificateStatus.valid;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _issuer, _number, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(
        CertificateDraft(
          title: _title.text.trim(),
          issuer: _issuer.text.trim(),
          issuedAt: calendarDateIso(_issued!),
          expiresAt: _noExpiry ? '' : calendarDateIso(_expires!),
          number: _number.text.trim(),
          note: _note.text.trim(),
          type: _type,
          status: _status,
          noExpiry: _noExpiry,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tunnistust ei saanud salvestada. Sisestatud andmed on alles; proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Row(
        children: [
          const Icon(Icons.school_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.existing == null ? 'Lisa tunnistus' : 'Muuda tunnistust',
            ),
          ),
          IconButton(
            tooltip: 'Sulge',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      scrollable: true,
      content: SizedBox(
        width: 620,
        child: Form(
          key: _form,
          child: AbsorbPointer(
            absorbing: _saving,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Tunnistuse nimetus *',
                    hintText: 'nt Väikelaevajuhi tunnistus',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Sisesta tunnistuse nimetus.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _issuer,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Väljaandja',
                    hintText: 'nt Transpordiamet',
                  ),
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final fields = [
                      AppDateField(
                        label: 'Väljastamise kuupäev *',
                        value: _issued,
                        lastDate: DateTime.now(),
                        onChanged: (v) => setState(() => _issued = v),
                        validator: (v) =>
                            v == null ? 'Vali väljastamise kuupäev.' : null,
                      ),
                      AppDateField(
                        label: 'Kehtib kuni',
                        value: _noExpiry ? null : _expires,
                        enabled: !_noExpiry,
                        emptyLabel: _noExpiry ? 'Tähtajatu' : 'Vali kuupäev',
                        onChanged: (v) => setState(() => _expires = v),
                        validator: (v) => _noExpiry
                            ? null
                            : v == null
                            ? 'Vali kuupäev või märgi tähtajatuks.'
                            : _issued != null && v.isBefore(_issued!)
                            ? 'Lõpp ei saa olla väljastamisest varasem.'
                            : null,
                      ),
                    ];
                    return MediaQuery.sizeOf(context).width >= 620 &&
                            MediaQuery.textScalerOf(context).scale(16) < 24
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: fields[0]),
                              const SizedBox(width: 16),
                              Expanded(child: fields[1]),
                            ],
                          )
                        : Column(
                            children: [
                              fields[0],
                              const SizedBox(height: 16),
                              fields[1],
                            ],
                          );
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tähtajatu tunnistus'),
                  value: _noExpiry,
                  onChanged: (v) => setState(() => _noExpiry = v ?? false),
                ),
                TextFormField(
                  controller: _number,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Tunnistuse number',
                    hintText: 'nt ABC-12345',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Märkused',
                    hintText: 'Lisainfo',
                  ),
                ),
                ExpansionTile(
                  title: const Text('Liigitus ja olek'),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: CertificateType.values.contains(_type)
                          ? _type
                          : CertificateType.other,
                      decoration: const InputDecoration(
                        labelText: 'Tunnistuse liik',
                      ),
                      items:
                          const {
                                'other': 'Muu',
                                'firstAid': 'Esmaabi',
                                'seaRescue': 'Merepääste',
                                'radio': 'Raadioside',
                                'navigation': 'Navigatsioon',
                                'boatOperator': 'Väikelaevajuht',
                                'safety': 'Ohutus',
                              }.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                      onChanged: (v) =>
                          setState(() => _type = v ?? CertificateType.other),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Oleku märge',
                      ),
                      items:
                          const {
                                'valid': 'Kehtiv',
                                'expiringSoon': 'Aegumas',
                                'expired': 'Aegunud',
                                'missing': 'Puudub',
                              }.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                      onChanged: (v) => setState(
                        () => _status = v ?? CertificateStatus.valid,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Aegumist arvestatakse kuupäeva järgi. Merepääste aste määratakse profiilis eraldi.',
                      ),
                    ),
                  ],
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Salvestan…'
                  : widget.existing == null
                  ? 'Lisa tunnistus'
                  : 'Salvesta muudatused',
            ),
          ),
        ),
      ],
    ),
  );
}
