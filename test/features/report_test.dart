import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/insight_repository.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/chat/chat_screen.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:penny/widgets/brutal_chip.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_ai.dart';

void main() {
  final month = monthStart(DateTime.now());
  DateTime at(int minute) => DateTime(month.year, month.month, 1, 9, minute);

  // Swiggy twice, Netflix, rent, a transfer to a friend, and pocket money.
  late String swiggyId;
  Future<void> seedMonth(TxnRepository repo) async {
    swiggyId = await repo.add(
      amountPaise: 30000,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: at(0),
      merchant: 'Swiggy',
    );
    await repo.add(
      amountPaise: 20000,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: at(1),
      merchant: 'Swiggy',
    );
    await repo.add(
      amountPaise: 64900,
      type: TxnType.debit,
      categoryId: 'subscriptions',
      occurredAt: at(2),
      merchant: 'Netflix',
    );
    await repo.add(
      amountPaise: 800000,
      type: TxnType.debit,
      categoryId: 'rent',
      occurredAt: at(3),
    );
    await repo.add(
      amountPaise: 50000,
      type: TxnType.debit,
      categoryId: 'other',
      occurredAt: at(4),
      merchant: 'Asha Rao',
      source: TxnSource.share,
      payeeIsPerson: true,
    );
    await repo.add(
      amountPaise: 1500000,
      type: TxnType.credit,
      categoryId: 'pocket_money',
      occurredAt: at(5),
    );
  }

  MonthInsight pennyAnswer(InsightRequest request) {
    final swiggy = groupId(request, shop: 'Swiggy');
    final netflix = groupId(
      request,
      shop: 'Netflix',
      categoryId: 'subscriptions',
    );
    return MonthInsight(
      tags: {
        swiggy: TxnTag.wasteful,
        netflix: TxnTag.wasteful,
        groupId(request, categoryId: 'rent'): TxnTag.necessary,
        groupId(request, shop: 'Asha Rao', categoryId: 'other'):
            TxnTag.necessary,
      },
      habits: [
        InsightHabit(
          title: 'Late-night delivery',
          groupIds: [swiggy],
          cut: Cut.half,
          tip: 'Cook at home twice a week.',
        ),
        InsightHabit(
          title: 'Streaming you skip',
          groupIds: [netflix],
          cut: Cut.stop,
          tip: 'Pause it for a month.',
        ),
      ],
      summary: 'A cosy month with lots of delivery!',
      incomeNote: 'Your pocket money shows up every month.',
      earnIdeas: const [
        'Tutor juniors in a subject you are good at.',
        'Freelance your design skills.',
      ],
    );
  }

  /// A report saved before the app starts, from [txns] as they were then.
  Future<void> Function(AppDatabase) savedReport({int dropNewest = 0}) {
    return (db) async {
      final txns = await TxnRepository(db)
          .watchBetween(insightHistoryStart(month), nextMonth(month))
          .first;
      final request = buildInsightRequest(
        month: month,
        txns: txns.skip(dropNewest).toList(),
        now: DateTime.now(),
      );
      await InsightRepository(db).save(
        request: request,
        insight: pennyAnswer(request),
        model: 'gemini-3.8-flash',
      );
    };
  }

  Future<void> openReport(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Analysis'));
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('open-report'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
  }

  Finder heroAmount(String amount) => find.descendant(
    of: find.byKey(const ValueKey('report-hero')),
    matching: find.text(amount),
  );

  testWidgets('Ask Penny: habits with savings worked out on the phone', (
    tester,
  ) async {
    final ai = FakeAiClient(answer: pennyAnswer);
    final db = await pumpApp(tester, seed: seedMonth, ai: ai);

    await openReport(tester);
    expect(find.textContaining('Want Penny to look at'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ask-penny')));
    await tester.pumpAndSettle();

    expect(ai.requests, hasLength(1));
    // Half of ₹500 on Swiggy, plus all of Netflix's ₹649.
    expect(heroAmount('₹899'), findsOneWidget);
    expect(find.text('so far this month'), findsOneWidget);
    expect(find.text('Late-night delivery'), findsOneWidget);
    expect(find.text('Save ₹250'), findsOneWidget);
    expect(find.text('Save ₹649'), findsOneWidget);
    expect(find.text('A cosy month with lots of delivery!'), findsOneWidget);
    expect(find.text('Every month'), findsNothing, reason: 'too early');
    expect(find.text('9 more looks today'), findsOneWidget);
    expect(find.text('Earn a little extra'), findsOneWidget);
    expect(find.text('Freelance your design skills.'), findsOneWidget);

    // Back on Analysis, the split now has Penny's tags.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Wasteful report'), findsOneWidget);
    expect(find.text('₹1,149'), findsOneWidget); // Wasteful.
    expect(find.text('₹8,500'), findsOneWidget); // Necessary.
    await closeApp(tester, db);
  });

  testWidgets('"I need this" drops a habit until you undo it', (tester) async {
    final ai = FakeAiClient(answer: pennyAnswer);
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: savedReport(),
      ai: ai,
    );
    await openReport(tester);
    expect(heroAmount('₹899'), findsOneWidget);
    // Nothing changed since Penny looked, so she doesn't look again.
    expect(ai.requests, isEmpty);

    final keep = find.widgetWithText(BrutalChip, 'I need this').first;
    await tester.ensureVisible(keep);
    await tester.pumpAndSettle();
    await tester.tap(keep);
    await tester.pumpAndSettle();

    expect(find.text('Late-night delivery'), findsNothing);
    expect(heroAmount('₹649'), findsOneWidget);
    expect(find.text('Late-night delivery moved to necessary'), findsOneWidget);
    // Tagging isn't a change Penny needs to look at again.
    expect(find.byKey(const ValueKey('report-stale')), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Late-night delivery'), findsOneWidget);
    expect(heroAmount('₹899'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the daily limit is explained and nothing is saved', (
    tester,
  ) async {
    final ai = FakeAiClient(
      failure: const AiException(AiFailure.dailyLimit, limit: 10),
    );
    final db = await pumpApp(tester, seed: seedMonth, ai: ai);
    await openReport(tester);

    await tester.tap(find.byKey(const ValueKey('ask-penny')));
    await tester.pumpAndSettle();

    expect(
      find.text('Penny can look 10 times a day. Try again tomorrow.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('report-hero')), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('a month that changed since Penny looked: she looks again', (
    tester,
  ) async {
    final ai = FakeAiClient(answer: pennyAnswer);
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      // Penny looked before the pocket money came in.
      seedDb: savedReport(dropNewest: 1),
      ai: ai,
    );
    await openReport(tester);

    expect(ai.requests, hasLength(1));
    expect(find.byKey(const ValueKey('report-stale')), findsNothing);
    expect(heroAmount('₹899'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('when that second look fails, Refresh tries again', (
    tester,
  ) async {
    final ai = FakeAiClient(failure: const AiException(AiFailure.slow));
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: savedReport(dropNewest: 1),
      ai: ai,
    );
    await openReport(tester);

    // The old report stays up, with why the new look failed.
    expect(heroAmount('₹899'), findsOneWidget);
    expect(
      find.text('Penny took too long to answer. Try again in a minute.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('report-stale')), findsOneWidget);

    ai
      ..failure = null
      ..answer = pennyAnswer;
    await tester.tap(find.byKey(const ValueKey('refresh-report')));
    await tester.pumpAndSettle();

    expect(ai.requests, hasLength(2));
    expect(find.byKey(const ValueKey('report-stale')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('"See what Penny sends" shows people only as aliases', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      ai: FakeAiClient(answer: pennyAnswer),
    );
    await openReport(tester);

    await tester.tap(find.byKey(const ValueKey('see-what-penny-sends')));
    await tester.pumpAndSettle();

    expect(find.text('What Penny sends'), findsOneWidget);
    expect(find.text('Person 1'), findsOneWidget);
    expect(find.text('Swiggy'), findsOneWidget);
    expect(find.text('Asha Rao'), findsNothing);
    expect(find.text('Pocket money'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('"Ask Penny about this" opens the chat', (tester) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: savedReport(),
      ai: FakeAiClient(answer: pennyAnswer),
    );
    await openReport(tester);

    final chat = find.byKey(const ValueKey('report-chat'));
    await tester.ensureVisible(chat);
    await tester.pumpAndSettle();
    await tester.tap(chat);
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('editing a spend shows Penny\'s pick, and yours wins', (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seed: seedMonth,
      seedDb: savedReport(),
      ai: FakeAiClient(answer: pennyAnswer),
    );
    routerOf(tester).push('/txns/$swiggyId');
    await tester.pumpAndSettle();
    expect(find.text("Penny's pick"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tag-necessary')));
    await tester.pumpAndSettle();
    expect(find.text('Your pick'), findsOneWidget);
    expect(find.text("Use Penny's"), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();

    // Only the other Swiggy order still counts as wasteful.
    routerOf(tester).push(reportLocation(month));
    await tester.pumpAndSettle();
    expect(find.text('Save ₹100'), findsOneWidget);
    expect(heroAmount('₹749'), findsOneWidget);
    await closeApp(tester, db);
  });
}
