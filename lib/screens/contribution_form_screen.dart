import '../widgets/app_date_field.dart';
import '../widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/statistics_model.dart';
import '../services/statistics_service.dart';

class ContributionFormScreen extends StatefulWidget {
  const ContributionFormScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    required this.members,
    required this.canManage,
    this.initialMemberId,
    this.initialType,
  });
  final String organizationId, currentUid;
  final List<MemberContribution> members;
  final bool canManage;
  final String? initialMemberId, initialType;
  @override
  State<ContributionFormScreen> createState() => _ContributionFormScreenState();
}

class _ContributionFormScreenState extends State<ContributionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(), _hours = TextEditingController();
  final _requestId = FirebaseFirestore.instance
      .collection('activities')
      .doc()
      .id;
  late final Set<String> _members = {
    widget.canManage
        ? widget.initialMemberId ?? widget.currentUid
        : widget.currentUid,
  };
  DateTime _date = DateTime.now();
  late String _type = widget.initialType ?? 'maintenance';
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _title.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_members.isEmpty) {
      setState(() => _error = 'Vali vähemalt üks osaleja.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await StatisticsService().record({
        'organizationId': widget.organizationId,
        'requestId': _requestId,
        'title': _title.text.trim(),
        'type': _type,
        'date': statisticsDate(_date),
        'hours': double.parse(_hours.text.replaceAll(',', '.')),
        'memberIds': _members.toList(),
      });
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = e.message ?? 'Salvestamine ebaõnnestus. Proovi uuesti.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Salvestamine ebaõnnestus. Kontrolli ühendust ja proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AppScaffold(
      appBar: AppBar(
        title: Text(
          widget.initialType == 'training'
              ? 'Lisa läbitud koolitus'
              : 'Lisa panus',
        ),
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.canManage
                    ? 'Lisa tehtud töö või koolitus. Osalemine kinnitatakse valitud liikmetele.'
                    : 'Sinu esitatud panus läheb adminile kinnitamiseks. Ära lisa tegevust uuesti, kui see on juba tegevuste nimekirjas.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Mida tegid?'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Sisesta tegevuse nimetus.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tegevuse liik'),
                items: contributionTypes.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              AppDateField(
                label: 'Kuupäev',
                value: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                onChanged: (date) {
                  if (date != null) setState(() => _date = date);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hours,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Tunnid osaleja kohta',
                  hintText: 'Näiteks 1,5',
                ),
                validator: (v) {
                  final hours = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return hours == null ||
                          !hours.isFinite ||
                          hours <= 0 ||
                          hours > 24
                      ? 'Sisesta tundide arv vahemikus 0–24 (üle nulli).'
                      : null;
                },
              ),
              if (widget.canManage) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Osalejad'),
                ),
                for (final m in widget.members.where((m) => m.active))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.name),
                    value: _members.contains(m.userId),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _members.add(m.userId);
                      } else {
                        _members.remove(m.userId);
                      }
                    }),
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Salvesta panus'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
