import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_section_card.dart';

class SelfProfileScreen extends StatefulWidget {
  const SelfProfileScreen({
    super.key,
    required this.currentUid,
  });

  final String currentUid;

  @override
  State<SelfProfileScreen> createState() => _SelfProfileScreenState();
}

class _SelfProfileScreenState extends State<SelfProfileScreen> {
  final _userService = UserService();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loadedInitialData = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _setInitialData(Map<String, dynamic> data) {
    if (_loadedInitialData) return;

    _nameController.text = (data['name'] as String?)?.trim() ?? '';
    _phoneController.text = (data['phone'] as String?)?.trim() ?? '';
    _loadedInitialData = true;
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Nimi on kohustuslik.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await _userService.updateOwnBasicProfile(
        uid: widget.currentUid,
        name: name,
        phone: _phoneController.text,
      );

      if (!mounted) return;
      _showMessage('Profiil salvestatud.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Profiili ei saanud salvestada.');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minu profiil')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data?.data() == null) {
            return const Center(
              child: Text('Profiili ei saanud laadida.'),
            );
          }

          final data = snapshot.data!.data()!;
          _setInitialData(data);
          final email = (data['email'] as String?)?.trim();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            children: [
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Põhiandmed',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.itemSpacing),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nimi',
                      ),
                    ),
                    const SizedBox(height: AppTheme.itemSpacing),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Telefon',
                        hintText: 'Valikuline',
                      ),
                      onSubmitted: (_) => _saving ? null : _saveProfile(),
                    ),
                    const SizedBox(height: AppTheme.itemSpacing),
                    Text(
                      'E-post',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email?.isNotEmpty == true ? email! : 'E-post puudub',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppTheme.sectionSpacing),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Salvesta'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
