// Pure text helpers for receipts, reminders and statements.
import 'package:intl/intl.dart';

import '../models.dart';
import 'fees.dart';

String _money(num v) => '৳${NumberFormat('#,##0.##', 'en_US').format(v)}';
String _date(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// Replaces {placeholders} in [template]. Unknown ones are left as typed.
String renderTemplate(String template, Map<String, String> values) =>
    template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m[1]] ?? m[0]!);

/// WhatsApp wants an international number without + (Bangladesh: 01xxx → 8801xxx).
String waNumber(String phone) {
  var n = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (n.startsWith('+')) n = n.substring(1);
  if (n.startsWith('0')) n = '88$n';
  return n;
}

/// First phone number to contact about fees: a guardian, else the student.
String feeContactPhone(Student s) {
  for (final g in s.guardians) {
    if (g.phone.trim().isNotEmpty) return g.phone.trim();
  }
  return s.phone.trim();
}

String feeContactName(Student s) {
  for (final g in s.guardians) {
    if (g.phone.trim().isNotEmpty && g.name.trim().isNotEmpty) return g.name.trim();
  }
  return 'Guardian';
}

/// The reminder message for what [acct] owes right now.
String reminderText(Student s, FeeAccount acct, FeeSettings cfg) {
  final over = acct.isOverdue;
  final cycle = acct.unpaid.isEmpty ? acct.current : acct.unpaid.first;
  final amount = acct.owed;
  final overdue = over ? ' (overdue by ${acct.overdueDays} ${acct.overdueDays == 1 ? 'day' : 'days'})' : '';
  return renderTemplate(cfg.reminderTemplate, {
    'guardian': feeContactName(s),
    'student': s.name,
    'amount': _money(amount),
    'month': cycle == null ? '' : DateFormat('MMMM yyyy').format(cycle.month),
    'due_date': cycle == null ? '' : _date(cycle.dueDate),
    'overdue': overdue,
    'tutor': cfg.tutorName,
  });
}

/// A plain-text receipt for one payment.
String receiptText(Student s, Payment p, PayInstallment i, FeeSettings cfg, double balanceAfter) {
  final b = StringBuffer();
  if (cfg.receiptHeader.trim().isNotEmpty) b.writeln(cfg.receiptHeader.trim());
  b.writeln('PAYMENT RECEIPT${i.receiptNo > 0 ? ' #${i.receiptNo.toString().padLeft(4, '0')}' : ''}');
  b.writeln('Student: ${s.name}');
  b.writeln('For: ${DateFormat('MMMM yyyy').format(DateTime.parse('${p.month}-01'))}');
  b.writeln('Date: ${_date(i.date)}');
  b.writeln('Amount: ${_money(i.amount)}');
  final m = cfg.methodById(i.method);
  if (m != null) b.writeln('Method: ${m.name}');
  if (i.ref.isNotEmpty) b.writeln('Ref: ${i.ref}');
  if (i.note.isNotEmpty) b.writeln('Note: ${i.note}');
  b.writeln(balanceAfter > 0.5
      ? 'Balance due: ${_money(balanceAfter)}'
      : balanceAfter < -0.5 ? 'Advance credit: ${_money(-balanceAfter)}' : 'Fully paid');
  if (cfg.tutorName.trim().isNotEmpty) b.writeln('Received by: ${cfg.tutorName.trim()}');
  if (cfg.receiptFooter.trim().isNotEmpty) b.writeln(cfg.receiptFooter.trim());
  return b.toString().trimRight();
}

/// A statement of everything charged and paid.
String statementText(Student s, FeeAccount a, FeeSettings cfg) {
  final b = StringBuffer();
  if (cfg.receiptHeader.trim().isNotEmpty) b.writeln(cfg.receiptHeader.trim());
  b.writeln('FEE STATEMENT – ${s.name}');
  b.writeln('As of ${_date(DateTime.now())}');
  b.writeln('');
  for (final e in a.ledger()) {
    final sign = e.amount < 0 ? '−' : '+';
    b.writeln('${_date(e.date)}  ${e.label}  $sign${_money(e.amount.abs())}  = ${_money(e.running)}');
  }
  b.writeln('');
  b.writeln(a.owed > 0 ? 'Balance due: ${_money(a.owed)}' : a.credit > 0 ? 'Advance credit: ${_money(a.credit)}' : 'All clear');
  return b.toString().trimRight();
}
