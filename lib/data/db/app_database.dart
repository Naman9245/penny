import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:penny/data/db/app_database.steps.dart';
import 'package:penny/data/db/tables.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/rule_kind.dart';
import 'package:penny/models/txn_enums.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Txns,
    Insights,
    TagRules,
    Prefs,
    ChatMessages,
    Budgets,
    Goals,
    GoalDeposits,
    GoalPlans,
    SyncCursors,
    PendingCaptures,
    UpcomingPayments,
    OwnMoves,
  ],
  // Edits here always move a row's stamp forward.
  include: {'stamps.drift'},
)
class AppDatabase extends _$AppDatabase {
  /// Tests pass an in-memory executor.
  AppDatabase(super.executor);

  /// Opens `<name>.sqlite` in the app's documents folder: `penny` for the
  /// user's own money, or the demo's.
  AppDatabase.named(String name)
    : super(driftDatabase(name: name, native: nativeOptions));

  /// Penny's hidden copy may be writing while she's open, each with its own
  /// connection: one waits up to 5 seconds for the other, rather than fail.
  static final nativeOptions = DriftNativeOptions(
    setup: (db) => db.execute('PRAGMA busy_timeout = 5000'),
  );

  /// Deletes every row of every table: "Also clear this phone" when the
  /// account is deleted.
  Future<void> wipe() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });

  // To change the schema: bump this, add a step to [migration], then run
  // `dart run drift_dev make-migrations` so the new step gets a test.
  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: stepByStep(
      // v2: fingerprints of imported SMS, unique among live entries.
      from1To2: (m, schema) async {
        await m.addColumn(schema.txns, schema.txns.dedupeKey);
        await m.createIndex(schema.txnsDedupeKey);
      },
      // v3: whether an imported payee is a person, and Penny's reports.
      from2To3: (m, schema) async {
        await m.addColumn(schema.txns, schema.txns.payeeIsPerson);
        await m.createTable(schema.insights);
      },
      // v4: My needs (rules and the note) and the chat with Penny.
      from3To4: (m, schema) async {
        await m.createTable(schema.tagRules);
        await m.createIndex(schema.tagRulesKindRuleKey);
        await m.createTable(schema.prefs);
        await m.createTable(schema.chatMessages);
        await m.createIndex(schema.chatMessagesCreatedAt);
      },
      // v5: the budget, goals with the money put toward them, and Penny's
      // plans for them.
      from4To5: (m, schema) async {
        await m.createTable(schema.budgets);
        await m.createIndex(schema.budgetsBudgetKey);
        await m.createTable(schema.goals);
        await m.createTable(schema.goalDeposits);
        await m.createIndex(schema.goalDepositsGoalId);
        await m.createTable(schema.goalPlans);
      },
      // v6: sync. Every row that can be backed up gets a "needs upload"
      // mark, set on what's already here so a first sync sends it all.
      from5To6: (m, schema) async {
        await m.addColumn(schema.txns, schema.txns.dirty);
        await m.addColumn(schema.tagRules, schema.tagRules.dirty);
        await m.addColumn(schema.prefs, schema.prefs.dirty);
        await m.addColumn(schema.budgets, schema.budgets.dirty);
        await m.addColumn(schema.goals, schema.goals.dirty);
        await m.addColumn(schema.goalDeposits, schema.goalDeposits.dirty);
        await m.createTable(schema.syncCursors);
      },
      // v7: an edit here always moves its row's stamp forward, so a later
      // edit wins even within the same second or with the clock behind.
      from6To7: (m, schema) async {
        for (final trigger in [
          schema.txnsStampForward,
          schema.budgetsStampForward,
          schema.goalsStampForward,
          schema.goalDepositsStampForward,
          schema.tagRulesStampForward,
          schema.prefsStampForward,
        ]) {
          await m.createTrigger(trigger);
        }
      },
      // v8: payments read from notifications, waiting to be checked.
      from7To8: (m, schema) async {
        await m.createTable(schema.pendingCaptures);
      },
      // v9: who sent each payment read, and what it was saved as, so one
      // payment seen from two apps is kept once.
      from8To9: (m, schema) async {
        await m.addColumn(
          schema.pendingCaptures,
          schema.pendingCaptures.sender,
        );
        await m.addColumn(
          schema.pendingCaptures,
          schema.pendingCaptures.savedAs,
        );
      },
      // v10: payments a message said are coming, for Home's Coming up card.
      from9To10: (m, schema) async {
        await m.createTable(schema.upcomingPayments);
      },
      // v11: moves between your own accounts, like PayZapp and the bank, so
      // neither half counts, and the wallet's UPI ID behind a read.
      from10To11: (m, schema) async {
        await m.createTable(schema.ownMoves);
        await m.addColumn(
          schema.pendingCaptures,
          schema.pendingCaptures.walletHandle,
        );
      },
    ),
  );
}
