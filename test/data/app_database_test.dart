import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';

void main() {
  test('one copy of Penny waits for the other, rather than fail', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: AppDatabase.nativeOptions.setup),
    );
    final row = await db.customSelect('PRAGMA busy_timeout').getSingle();
    expect(row.data.values.single, 5000);
    await db.close();
  });
}
