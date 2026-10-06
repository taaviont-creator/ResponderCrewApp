import '../widgets/app_date_field.dart';
import '../widgets/app_layout.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/statistics_model.dart';
import '../services/statistics_service.dart';
import '../services/activity_service.dart';

class ContributionFormScreen extends StatefulWidget {
  const ContributionFormScreen({
    super.key,
    required this.organizationId,
    required this.currentUid,
    this.members = const [],
    required this.canManage,
    this.initialMemberId,
    this.initialType,
    this.saveContribution,
    this.requestId,
    this.activityService,
  });
  final String organizationId, currentUid;
  final List<MemberContribution> members;
  final bool canManage;
  final String? initialMemberId, initialType;
  final Future<void> Function(Map<String, dynamic>)? saveContribution;
  final String? requestId;
  final ActivityService? activityService;
  @override
  State<ContributionFormScreen> createState() => _ContributionFormScreenState();
}

class _ContributionFormScreenState extends State<ContributionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(), _hours = TextEditingController();
  final _description = TextEditingController();
  String _search = '';
  late final _memberStream = widget.canManage && widget.members.isEmpty
      ? (widget.activityService ?? ActivityService())
            .streamActiveMembers(widget.organizationId)
            .map(
              (members) => members
                  .map(
                    (m) => MemberContribution({
                      'userId': m.id,
                      'name': m.name,
                      'active': true,
                    }),
                  )
                  .toList(),
            )
      : Stream.value(widget.members);
  late final _requestId =
      widget.requestId ??
      FirebaseFirestore.instance.collection('activities').doc().id;
  late final Set<String> _members = {
    if (widget.canManage && widget.initialMemberId != null)
      widget.initialMemberId!,
  };
  DateTime _date = DateTime.now();
  late String _type = widget.initialType ?? 'maintenance';
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _title.dispose();
    _hours.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (widget.saveContribution ?? StatisticsService().record)({
        'organizationId': widget.organizationId,
        'requestId': _requestId,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'type': _type,
        'date': statisticsDate(_date),
        'hours': double.parse(_hours.text.replaceAll(',', '.')),
        'memberIds': widget.canManage && _members.isNotEmpty
            ? _members.toList()
            : [widget.currentUid],
      });
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.canManage
                  ? 'Panus salvestatud ja tunnid kinnitatud.'
                  : 'Panus esitatud adminile kinnitamiseks.',
            ),
          ),
        );
      }
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
      contentMaxWidth: 760,
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
                    ? 'Märgi tehtud vabatahtlik töö. Valitud liikmete tunnid lähevad statistikasse kinnitatuna.'
                    : 'Märgi oma tehtud vabatahtlik töö. Tunnid lähevad statistikasse pärast admini kinnitust.',
              ),
              const SizedBox(height: 8),
              const Text(
                'Juba planeeritud tegevuse või koolituse osalemine kinnitatakse selle tegevuse juures; ära lisa samu tunde uuesti.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Mida tegid?',
                  hintText: 'Nt puhastasin päästepaati',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Sisesta tegevuse nimetus.'
                    : null,
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Kategooria'),
                items: contributionTypes.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, overflow: TextOverflow.ellipsis),
                      ),
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
                  labelText: 'Kulunud tunnid',
                  hintText: 'Näiteks 2,5',
                  suffixText: 'tundi',
                  helperText: 'Iga valitud liikme panus tundides',
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                maxLength: 2000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Kirjeldus (valikuline)',
                  hintText: 'Lühike kirjeldus tehtud tööst…',
                ),
              ),
              if (widget.canManage) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Liikmed · kellele panus lisatakse'),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Otsi liiget',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _search = value.trim().toLowerCase()),
                ),
                StreamBuilder<List<MemberContribution>>(
                  stream: _memberStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Liikmete laadimine ebaõnnestus. Valikuta lisatakse panus sulle.',
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LinearProgressIndicator();
                    }
                    final members = snapshot.data!
                        .where(
                          (m) =>
                              m.active &&
                              m.name.toLowerCase().contains(_search),
                        )
                        .toList();
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (members.isEmpty)
                            const ListTile(title: Text('Liikmeid ei leitud.')),
                          for (final m in members)
                            CheckboxListTile(
                              controlAffinity: ListTileControlAffinity.leading,
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
                      ),
                    );
                  },
                ),
                Text(
                  _members.isEmpty
                      ? 'Kui kedagi ei vali, lisatakse panus ainult sulle.'
                      : 'Valitud liikmeid: ${_members.length}. Sama tundide arv lisatakse igale valitud liikmele.',
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
