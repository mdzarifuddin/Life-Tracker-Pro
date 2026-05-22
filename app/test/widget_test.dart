// Mentora smoke test.
import 'package:flutter_test/flutter_test.dart';
import 'package:mentora/models.dart';

void main() {
  test('Student serializes round-trip', () {
    final s = Student(id: '1', name: 'Rahim', monthlyFee: 5000, subjects: ['Math']);
    final back = Student.fromMap(s.toMap());
    expect(back.name, 'Rahim');
    expect(back.monthlyFee, 5000);
    expect(back.subjects, ['Math']);
  });
}
