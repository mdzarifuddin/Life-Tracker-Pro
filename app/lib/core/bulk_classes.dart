// Parses typed text such as
//   Jan_26:
//   Labib - 3,5,8,16,17,19,28,31
// into class dates for students. Pure Dart so it can be unit-tested.
import '../models.dart';

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

class BulkEntry {
  BulkEntry({required this.name, required this.year, required this.month,
      required this.days, this.student, this.skipped = const [], this.invalid = const []});
  final String name;
  final int year, month;
  /// Days that will be added.
  final List<int> days;
  final Student? student;
  /// Days that already have a class logged (not added again).
  final List<int> skipped;
  /// Numbers that are not a day of that month.
  final List<int> invalid;
  bool get matched => student != null;
}

/// [existing] returns the dates already logged for a student id (to avoid duplicates).
List<BulkEntry> parseBulkClasses(
  String text,
  List<Student> students,
  List<DateTime> Function(String studentId) existing, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  var year = today.year, month = today.month;
  final out = <BulkEntry>[];
  final head = RegExp(r'^\s*([A-Za-z]{3,9})[\s_\-/.,]*(\d{2,4})?\s*(?::\s*(.*))?$');

  Student? find(String name) {
    final n = name.toLowerCase().trim();
    if (n.isEmpty) return null;
    for (final s in students) {
      if (s.name.toLowerCase().trim() == n) return s;
    }
    final starts = students.where((s) => s.name.toLowerCase().startsWith(n)).toList();
    if (starts.length == 1) return starts.first;
    final has = students.where((s) => s.name.toLowerCase().contains(n)).toList();
    return has.length == 1 ? has.first : null;
  }

  final seen = <String, Set<int>>{}; // days already taken in this text, per student+month

  void studentLine(String line) {
    // "Done - 12", "Amount - 12000", "sara -3k" are money notes, not class days.
    if (RegExp(r'^\W*(done|amount|due|total|paid|note)\b', caseSensitive: false).hasMatch(line)) return;
    if (RegExp(r'\d\s*k\b', caseSensitive: false).hasMatch(line)) return;
    final m = RegExp(r'^\s*([^\d]*?)\s*[-–—:=]?\s*([\d].*)$').firstMatch(line);
    if (m == null) return;
    final nums = RegExp(r'\d{1,2}').allMatches(m.group(2)!).map((x) => int.parse(x.group(0)!)).toList();
    final last = DateTime(year, month + 1, 0).day;
    final valid = <int>{}, bad = <int>[];
    for (final d in nums) {
      if (d >= 1 && d <= last) {
        valid.add(d);
      } else {
        bad.add(d);
      }
    }
    // "Sara, farin & rifat - 1,3,5": the same days for each name.
    final names = m.group(1)!
        .split(RegExp(r'[,&+/]|\band\b', caseSensitive: false))
        .map((n) => n.replaceAll(RegExp(r'[^\p{L}\p{N} .]', unicode: true), '').trim())
        .where((n) => n.isNotEmpty);
    for (final name in names) {
      final st = find(name);
      final shown = st?.name ?? '${name[0].toUpperCase()}${name.substring(1)}';
      final key = '${shown.toLowerCase()}|$year-$month';
      final taken = seen.putIfAbsent(key, () => <int>{});
      final have = st == null
          ? <int>{}
          : existing(st.id).where((d) => d.year == year && d.month == month).map((d) => d.day).toSet();
      final days = valid.where((d) => !have.contains(d) && !taken.contains(d)).toList()..sort();
      taken.addAll(days);
      out.add(BulkEntry(
          name: shown, year: year, month: month, days: days, student: st,
          skipped: valid.where(have.contains).toList()..sort(), invalid: bad));
    }
  }

  for (final raw in text.split(RegExp(r'[\n\r;]+'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final h = head.firstMatch(line);
    if (h != null && _monthOf(h.group(1)!) != null) {
      month = _monthOf(h.group(1)!)!;
      final y = h.group(2);
      if (y != null) {
        final v = int.parse(y);
        year = v < 100 ? 2000 + v : v;
      }
      final rest = (h.group(3) ?? '').trim();
      if (rest.isNotEmpty) studentLine(rest);
      continue;
    }
    studentLine(line);
  }
  return out;
}

const _full = ['january', 'february', 'march', 'april', 'may', 'june', 'july',
  'august', 'september', 'october', 'november', 'december'];

/// 1..12 if [w] is exactly a month name or its 3-letter short form (Jan, Sept…), else null.
int? _monthOf(String w) {
  final l = w.toLowerCase();
  if (l == 'sept') return 9;
  final i = _full.indexOf(l);
  if (i >= 0) return i + 1;
  return l.length == 3 ? _months[l] : null;
}
