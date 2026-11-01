import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/insight_math.dart';

import '../helpers/txn_factory.dart';

void main() {
  final day = DateTime(2026, 10, 10);

  // Swiggy twice, Netflix, rent and a transfer to a friend.
  final swiggyA = txn(300, day, merchant: 'Swiggy');
  final swiggyB = txn(200, day, merchant: 'Swiggy');
  final netflix = txn(
    649,
    day,
    merchant: 'Netflix',
    categoryId: 'subscriptions',
  );
  final rent = txn(8000, day, categoryId: 'rent');
  final friend = txn(
    500,
    day,
    merchant: 'Asha Rao',
    categoryId: 'other',
    payeeIsPerson: true,
  );
  final pay = txn(15000, day, type: TxnType.credit, categoryId: 'salary');
  final month = [swiggyA, swiggyB, netflix, rent, friend, pay];

  SavedInsight report({Map<String, TxnTag>? tags, List<InsightHabit>? habits}) {
    final request = buildInsightRequest(
      month: DateTime(2026, 10),
      txns: month,
      now: DateTime(2026, 11, 2),
    );
    String idOf(String key) =>
        request.groupKeys.entries.firstWhere((e) => e.value.contains(key)).key;
    final swiggy = idOf('shop|food|swiggy');
    final stream = idOf('shop|subscriptions|netflix');
    return SavedInsight(
      month: DateTime(2026, 10),
      inputHash: request.inputHash,
      groupKeys: request.groupKeys,
      insight: MonthInsight(
        tags:
            tags ??
            {
              swiggy: TxnTag.wasteful,
              stream: TxnTag.wasteful,
              idOf('cat|rent'): TxnTag.necessary,
              idOf('shop|other|asha rao'): TxnTag.necessary,
            },
        habits:
            habits ??
            [
              InsightHabit(
                title: 'Late-night delivery',
                groupIds: [swiggy],
                cut: Cut.half,
                tip: 'Cook twice a week.',
              ),
              InsightHabit(
                title: '',
                groupIds: [stream],
                cut: Cut.stop,
                tip: '',
              ),
            ],
        summary: 'Busy month!',
        incomeNote: '',
      ),
      model: 'gemini-3.8-flash',
      createdAt: DateTime(2026, 11, 2),
    );
  }

  test('the split counts each spend by its tag', () {
    final split = splitByTag(month, report());
    expect(split.wastefulPaise, (300 + 200 + 649) * 100);
    expect(split.necessaryPaise, (8000 + 500) * 100);
    expect(split.unsortedPaise, 0);
    expect(split.totalPaise, 9649 * 100);
  });

  test('with no report every spend is not sorted yet', () {
    final split = splitByTag(month, null);
    expect(split.unsortedPaise, 9649 * 100);
    expect(split.necessaryPaise + split.wastefulPaise, 0);
  });

  test('your own tag beats Penny\'s, and income never has one', () {
    final penny = PennyTags(report());
    expect(effectiveTag(swiggyA, penny), TxnTag.wasteful);
    final yours = swiggyA.copyWith(tag: const Value(TxnTag.necessary));
    expect(effectiveTag(yours, penny), TxnTag.necessary);
    expect(effectiveTag(pay, penny), isNull);
    // A shop Penny never saw stays unsorted.
    expect(effectiveTag(txn(90, day, merchant: 'Zepto'), penny), isNull);
  });

  test('a habit saves its wasteful spend times the cut', () {
    final views = habitViews(month, report());

    expect(views.map((v) => [v.title, v.spentPaise, v.savePaise]), [
      ['Late-night delivery', 50000, 25000],
      ['Netflix', 64900, 64900],
    ]);
    expect(totalSavingPaise(views), 89900);
  });

  test('savings are whole rupees', () {
    final odd = txn(333, day, merchant: 'Swiggy');
    final views = habitViews([odd, netflix], report());
    // Half of ₹333 is ₹166.50, shown as ₹167.
    expect(views.first.savePaise, 16700);
  });

  test('"I need this" on every entry drops the habit', () {
    Txn needed(Txn t) => t.copyWith(tag: const Value(TxnTag.necessary));
    final views = habitViews([
      needed(swiggyA),
      needed(swiggyB),
      netflix,
    ], report());
    expect(views.map((v) => v.title), ['Netflix']);

    // Only some entries: the habit stays, counting the rest.
    final partly = habitViews([needed(swiggyA), swiggyB, netflix], report());
    expect(partly.first.spentPaise, 20000);
  });

  test('habit names are the ones on your phone, people included', () {
    final request = buildInsightRequest(
      month: DateTime(2026, 10),
      txns: month,
      now: DateTime(2026, 11, 2),
    );
    final friendId = request.groupKeys.entries
        .firstWhere((e) => e.value.contains('shop|other|asha rao'))
        .key;
    final saved = report(
      tags: {friendId: TxnTag.wasteful},
      habits: [
        InsightHabit(
          title: '',
          groupIds: [friendId],
          cut: Cut.quarter,
          tip: '',
        ),
      ],
    );
    final view = habitViews(month, saved).single;
    expect(view.names, ['Asha Rao']);
    expect(view.savePaise, 12500);
  });
}
