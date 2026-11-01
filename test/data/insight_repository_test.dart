import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/insight_repository.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/insight_builder.dart';

import '../helpers/txn_factory.dart';

void main() {
  late AppDatabase db;
  late InsightRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = InsightRepository(db, clock: () => DateTime(2026, 11, 2, 10));
  });

  tearDown(() => db.close());

  final request = buildInsightRequest(
    month: DateTime(2026, 10),
    txns: [
      txn(300, DateTime(2026, 10, 2), merchant: 'Swiggy'),
      txn(900, DateTime(2026, 10, 4), categoryId: 'rent'),
      txn(80, DateTime(2026, 10, 5)),
    ],
    now: DateTime(2026, 11, 2),
  );

  MonthInsight answer(String summary) => MonthInsight(
    tags: const {'s1': TxnTag.necessary, 's2': TxnTag.wasteful},
    habits: const [
      InsightHabit(title: 'Delivery', groupIds: ['s2'], cut: Cut.half, tip: ''),
    ],
    summary: summary,
    incomeNote: '',
  );

  test('a saved report comes back for its month only', () async {
    await repo.save(request: request, insight: answer('First'), model: 'm');

    final saved = (await repo.watch(DateTime(2026, 10, 20)).first)!;
    expect(saved.month, DateTime(2026, 10));
    expect(saved.inputHash, request.inputHash);
    expect(saved.groupKeys, request.groupKeys);
    expect(saved.insight.tags['s2'], TxnTag.wasteful);
    expect(saved.insight.habits.single.cut, Cut.half);
    expect(saved.model, 'm');
    expect(saved.createdAt, DateTime(2026, 11, 2, 10));
    expect(await repo.watch(DateTime(2026, 11)).first, isNull);
  });

  test('a new report replaces the old one', () async {
    await repo.save(request: request, insight: answer('First'), model: 'm');
    await repo.save(request: request, insight: answer('Second'), model: 'm');

    final saved = await repo.watch(DateTime(2026, 10)).first;
    expect(saved!.insight.summary, 'Second');
    expect(await db.select(db.insights).get(), hasLength(1));
  });

  test('a report that no longer reads counts as none', () async {
    await repo.save(request: request, insight: answer('First'), model: 'm');
    await (db.update(db.insights))
        .write(const InsightsCompanion(groupKeys: Value('not json')));
    expect(await repo.watch(DateTime(2026, 10)).first, isNull);
  });
}
