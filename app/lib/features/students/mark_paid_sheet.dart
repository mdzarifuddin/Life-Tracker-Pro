import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models.dart';

/// Colour used for classes whose payment is done.
const paidClassColor = Color(0xFFF472B6); // pink: stands out on the blue background

/// Mark a student's classes as paid: "payment done till a date", or tick single days.
/// Payments are recorded in the student's records only (never in Finance).
Future<void> showMarkPaidSheet(BuildContext context, Repo repo, Student s) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MarkPaidSheet(repo: repo, student: s),
  );
}

class _MarkPaidSheet extends StatefulWidget {
  const _MarkPaidSheet({required this.repo, required this.student});
  final Repo repo;
  final Student student;
  @override
  State<_MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends State<_MarkPaidSheet> {
  DateTime _till = DateTime.now();
  bool _busy = false;

  List<ClassLog> get _logs => widget.repo.logsFor(widget.student.id)
    ..sort((a, b) => b.date.compareTo(a.date));

  Future<void> _run(Future<void> Function() job, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    await job();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo, s = widget.student;
    final hint = Theme.of(context).hintColor;
    return AnimatedBuilder(
      animation: Listenable.merge([repo.logsL, repo.paymentsL]),
      builder: (context, _) {
        final logs = _logs;
        final end = DateTime(_till.year, _till.month, _till.day, 23, 59, 59);
        final toPay = logs.where((l) => !l.isPaid && !l.date.isAfter(end)).toList();
        final fee = s.perClassFee;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s.name} · mark classes paid', style: Theme.of(context).textTheme.titleLarge),
                    Gap.s,
                    Text('Payment done till…', style: TextStyle(color: hint, fontSize: 12)),
                    Gap.s,
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(fullDate(_till)),
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context, initialDate: _till,
                            firstDate: DateTime(2020), lastDate: DateTime(2100));
                        if (d != null) setState(() => _till = d);
                      },
                    ),
                    Gap.s,
                    FilledButton(
                      onPressed: toPay.isEmpty || _busy
                          ? null
                          : () => _run(() => repo.setLogsPaid(s, toPay, true),
                              '${toPay.length} classes marked paid'),
                      child: Text(toPay.isEmpty
                          ? 'Nothing to mark up to ${fullDate(_till)}'
                          : 'Mark ${toPay.length} ${toPay.length == 1 ? 'class' : 'classes'} paid · ${taka(toPay.length * fee)}'),
                    ),
                    Gap.s,
                    Text('Or tap single days below. Tap a paid day again to undo.',
                        style: TextStyle(color: hint, fontSize: 12)),
                  ]),
                ),
                Flexible(
                  child: logs.isEmpty
                      ? const Padding(padding: EdgeInsets.all(24), child: Text('No classes logged yet.'))
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                          children: [
                            for (final l in logs)
                              ListTile(
                                dense: true,
                                leading: Icon(
                                  l.isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: l.isPaid ? paidClassColor : hint,
                                ),
                                title: Text(fullDate(l.date),
                                    style: TextStyle(fontWeight: FontWeight.w600,
                                        color: l.isPaid ? readableOn(context, paidClassColor) : null)),
                                subtitle: Text(l.isPaid ? 'Paid' : 'Not paid yet'),
                                trailing: Text(taka(fee), style: TextStyle(color: hint)),
                                onTap: _busy
                                    ? null
                                    : () => _run(() => repo.setLogPaid(s, l, !l.isPaid),
                                        l.isPaid ? 'Payment undone' : 'Marked paid'),
                              ),
                          ],
                        ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
