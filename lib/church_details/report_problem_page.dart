import 'dart:async';

import 'package:flutter/material.dart';
import 'package:miserend/api/api_result.dart';
import 'package:miserend/api/problem_type.dart';
import 'package:miserend/church_details/problem_report_sender.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reports a problem with one church's data to miserend.hu (CONTEXT.md,
/// „Hibajelentés"; spec 0009, „Hibajelentés: az oldal"). A full page rather
/// than a dialog, so the keyboard does not squeeze the form.
class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({
    super.key,
    required this.churchId,
    required this.churchName,
    required this.dataAsOf,
    this.sender,
  });

  final int churchId;

  /// Shown above the form, so it is plain which church the report is about.
  final String churchName;

  /// The day of the data the details page showed; sent as `dbdate`.
  final DateTime dataAsOf;

  /// Injected by tests; the page builds its own otherwise.
  final ProblemReportSender? sender;

  @visibleForTesting
  static const Key textKey = Key('report-text');

  @visibleForTesting
  static const Key emailKey = Key('report-email');

  /// Where the address of the last sent report is kept, so the user does not
  /// type it again for every report.
  @visibleForTesting
  static const String emailPreferenceKey = 'REPORT_EMAIL';

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  /// Deliberately loose: it catches a slip of the thumb, not every address the
  /// RFC would refuse. miserend.hu only uses it to write back.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final ProblemReportSender _sender =
      widget.sender ?? ProblemReportSender();

  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _emailController = TextEditingController();

  ProblemType? _type;

  /// Set while a report is on its way; the button does nothing meanwhile, so
  /// a report goes out once.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  @override
  void dispose() {
    _textController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ReportProblemPage.emailPreferenceKey);
    // Whatever the user has typed in the meantime wins.
    if (!mounted || saved == null || _emailController.text.isNotEmpty) return;
    _emailController.text = saved;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Hibajelentés')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.churchName, style: textTheme.titleMedium),
            const SizedBox(height: 24),
            Text('Milyen hibát jelentesz?', style: textTheme.titleSmall),
            _typeField(),
            const SizedBox(height: 24),
            TextFormField(
              key: ReportProblemPage.textKey,
              controller: _textController,
              minLines: 4,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Leírás',
                hintText:
                    'Például: vasárnap 10-kor kezdődik a mise, nem 9-kor.',
                alignLabelWithHint: true,
              ),
              // Required for every type, not only where the API asks for it:
              // the stewards cannot tell what to fix without it.
              validator:
                  (value) =>
                      (value ?? '').trim().isEmpty
                          ? 'Írd le, mi a hiba.'
                          : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: ReportProblemPage.emailKey,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-mail cím (nem kötelező)',
                helperText: 'Kérdés esetén ide írhatunk neked.',
              ),
              validator: (value) {
                final email = (value ?? '').trim();
                return email.isEmpty || _emailPattern.hasMatch(email)
                    ? null
                    : 'Ez nem e-mail cím.';
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _sending ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child:
                  _sending
                      ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Küldés'),
            ),
          ],
        ),
      ),
    );
  }

  /// The three types, none chosen at first: a default would get sent by
  /// users who never looked at it.
  Widget _typeField() {
    return FormField<ProblemType>(
      validator:
          (_) => _type == null ? 'Válaszd ki, milyen hibát jelentesz.' : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<ProblemType>(
              groupValue: _type,
              onChanged: (type) {
                setState(() => _type = type);
                field.didChange(type);
              },
              child: Column(
                children: [
                  for (final type in ProblemType.values)
                    RadioListTile<ProblemType>(
                      value: type,
                      title: Text(_label(type)),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (field.errorText case final error?)
              Text(
                error,
                style: Theme.of(context).textTheme.bodySmall?.apply(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        );
      },
    );
  }

  String _label(ProblemType type) => switch (type) {
    ProblemType.wrongPosition => 'Rossz pozíció',
    ProblemType.wrongMassTime => 'Rossz miseidőpont',
    ProblemType.other => 'Egyéb',
  };

  Future<void> _submit() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    final email = _emailController.text.trim();
    final result = await _sender.send(
      churchId: widget.churchId,
      type: _type!,
      text: _textController.text,
      email: email.isEmpty ? null : email,
      dataAsOf: widget.dataAsOf,
    );
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case ApiSuccess():
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Hibajelentés elküldve')),
        );
        // After the page has closed: the report is already in, and a slow or
        // failing write must not hold that back.
        unawaited(_rememberEmail(email));
      case ApiFailed(:final failure):
        setState(() => _sending = false);
        messenger.showSnackBar(SnackBar(content: Text(_failureText(failure))));
    }
  }

  /// An empty [email] is kept as well: the user cleared it on purpose.
  Future<void> _rememberEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ReportProblemPage.emailPreferenceKey, email);
    } catch (e) {
      // A convenience only: the report went out, and the worst outcome is
      // typing the address again next time (B3).
      debugPrint('Report email not remembered: ${e.runtimeType}');
    }
  }

  /// The server's own `text` is never shown: it is meant for developers, and
  /// may come in English.
  String _failureText(ApiFailure failure) => switch (failure) {
    ApiFailure.noConnection =>
      'Nincs kapcsolat, a hibajelentés nem ment el. '
          'Próbáld újra, ha lesz térerő.',
    ApiFailure.serverError =>
      'A miserend.hu most nem fogadta a hibajelentést. '
          'Próbáld újra később.',
  };
}
