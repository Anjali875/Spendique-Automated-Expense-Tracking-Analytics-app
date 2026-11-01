import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'transaction.dart';
import 'transactions_provider.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _sms = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _sms.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ImportResult> Function() job) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final r = await job();
      if (!mounted) return;
      setState(() {
        _message = r.summary;
        _isError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = apiError(e);
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

    Future<void> _pickCsv() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (files.isEmpty) return; // user cancelled
    final file = files.first;
    final bytes = await file.readAsBytes();
    await _run(() =>
        ref.read(transactionsProvider.notifier).importCsv(bytes, file.name));
  }

  Future<void> _importSms() async {
    final text = _sms.text.trim();
    if (text.isEmpty) return;
    await _run(() => ref.read(transactionsProvider.notifier).importSms(text));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import'),
          bottom: const TabBar(tabs: [Tab(text: 'Bank CSV'), Tab(text: 'Paste SMS')]),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Upload a statement CSV exported from your bank. '
                            'Re-uploading the same file won\'t create duplicates.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _busy ? null : _pickCsv,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Choose CSV file'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Paste bank SMS. Separate messages with a blank line.'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sms,
                        minLines: 6,
                        maxLines: 12,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : _importSms,
                        child: const Text('Import SMS'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _isError ? Theme.of(context).colorScheme.error : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}