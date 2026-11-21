import 'package:flutter_test/flutter_test.dart';
import 'package:life_tracker_pro/core/bulk_classes.dart';
import 'package:life_tracker_pro/models.dart';

void main() {
  final labib = Student(id: 'a', name: 'Labib');
  final marium = Student(id: 'b', name: 'Marium');

  test('month header then student line', () {
    final r = parseBulkClasses('Jan_26:\n\nLabib -3,5,8,16,17,)***(19,28,31,', [labib, marium], (_) => []);
    expect(r.single.student, labib);
    expect(r.single.year, 2026);
    expect(r.single.month, 1);
    expect(r.single.days, [3, 5, 8, 16, 17, 19, 28, 31]);
  });

  test('one line, several months, bad days, duplicates', () {
    final r = parseBulkClasses(
        'Feb 2026: Labib - 1, 30, 5\nMar_26\nMarium: 2,2',
        [labib, marium],
        (id) => id == 'a' ? [DateTime(2026, 2, 5)] : []);
    expect(r[0].days, [1]);
    expect(r[0].skipped, [5]);
    expect(r[0].invalid, [30]);
    expect(r[1].student, marium); // "Marium" is a name, not March
    expect(r[1].month, 3);
  });

  realWorldNotes();
  test('unknown student is reported', () {
    final r = parseBulkClasses('Jan_26: Zed - 1', [labib], (_) => []);
    expect(r.single.matched, isFalse);
  });
}

void realWorldNotes() {
  final students = [Student(id: 'l', name: 'Labib'), Student(id: 'm', name: 'Maliha')];
  test('real notes: money lines ignored, groups split, symbols ignored', () {
    const t = '''
Jan_26:

 Labib -3,5,8,16,17,)***(19,28,31,
 Done - 12
Amount - 12000

 Sara,farin,rifat&neyama - 1,3,5,
Done - 12
Amount - 18000+6000

Mymuna - 1,3,
Done - 16
Amount - 11000+ 500 for ifftar

Tanim - 17d,

Sept_26 :
  Maliha - 14,16,
  Done - 8
Sara & farin - 5,8,
   Done - 6
   Amount - farin -1500,
   sara -3k
''';
    final r = parseBulkClasses(t, students, (_) => []);
    final names = r.map((e) => '${e.name}@${e.month}').toList();
    expect(names, ['Labib@1', 'Sara@1', 'Farin@1', 'Rifat@1', 'Neyama@1', 'Mymuna@1', 'Tanim@1', 'Maliha@9', 'Sara@9', 'Farin@9']);
    expect(r.first.days, [3, 5, 8, 16, 17, 19, 28, 31]);
    expect(r[1].days, [1, 3, 5]);
    expect(r.firstWhere((e) => e.name == 'Tanim').days, [17]);
    expect(r.last.days, [5, 8]);
  });
}
