import 'dart:convert';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class CalloutAttachments extends StatefulWidget {
  const CalloutAttachments({
    super.key,
    required this.organizationId,
    required this.calloutId,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });
  final String organizationId, calloutId;
  final List<Map<String, dynamic>> items;
  final Future<void> Function() onChanged;
  final bool enabled;
  @override
  State<CalloutAttachments> createState() => _CalloutAttachmentsState();
}

class _CalloutAttachmentsState extends State<CalloutAttachments> {
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _pending;
  late final _functions = FirebaseFunctions.instanceFor(region: 'europe-north1');
  Map<String, dynamic> get _scope => {
    'organizationId': widget.organizationId,
    'calloutId': widget.calloutId,
  };
  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_pending == null) {
        final file = await openFile(
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'Fotod ja dokumendid',
              extensions: [
                'pdf',
                'jpg',
                'jpeg',
                'png',
                'heic',
                'mp4',
                'mov',
                'txt',
                'docx',
              ],
              uniformTypeIdentifiers: [
                'public.image',
                'public.movie',
                'public.plain-text',
                'com.adobe.pdf',
                'org.openxmlformats.wordprocessingml.document',
              ],
            ),
          ],
        );
        if (file == null) return;
        if (await file.length() > 8 * 1024 * 1024) {
          throw StateError('Fail võib olla kuni 8 MB.');
        }
        final bytes = await file.readAsBytes();
        _pending = {
          ..._scope,
          'name': file.name,
          'base64': base64Encode(bytes),
          'requestId': List.generate(
            24,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join(),
        };
      }
      await _functions
          .httpsCallable(
            'uploadCalloutAttachment',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          )
          .call(_pending);
      _pending = null;
      await widget.onChanged();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(
          () => _error =
              e.message ?? 'Manuse lisamine ebaõnnestus. Proovi uuesti.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message
              : 'Manuse lisamine ebaõnnestus. Proovi uuesti.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(Map<String, dynamic> item) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _functions
          .httpsCallable(
            'downloadCalloutAttachment',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          )
          .call({..._scope, 'attachmentId': item['id']});
      final data = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              base64Decode(data['base64']),
              mimeType: data['contentType'],
            ),
          ],
          fileNameOverrides: [data['name'] as String],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Manuse avamine ebaõnnestus. Proovi uuesti.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Manused · piiratud ligipääs',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const Text(
        'Nähtavad ühingu adminile ja II astme merepäästjale. Kuni 30 faili, igaüks kuni 8 MB.',
      ),
      for (final item in widget.items)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file),
          title: Text(item['name'] as String),
          subtitle: Text('${((item['size'] as num? ?? 0) / 1024).ceil()} KB'),
          trailing: const Icon(Icons.download_outlined),
          onTap: _busy || !widget.enabled ? null : () => _download(item),
        ),
      if (_error != null)
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      OutlinedButton.icon(
        onPressed: _busy || !widget.enabled ? null : _upload,
        icon: const Icon(Icons.upload_file),
        label: Text(
          _pending == null ? 'Lisa foto või fail' : 'Proovi sama faili uuesti',
        ),
      ),
      if (_busy) const LinearProgressIndicator(),
    ],
  );
}
