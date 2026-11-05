import 'package:drift/drift.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/rule_kind.dart';
import 'package:penny/models/txn_enums.dart';

/// A table backed up to the signed-in account's copy.
mixin Synced on Table {
  /// Changed on this phone since it was last sent to the account's copy.
  /// New rows are; rows that came from the copy aren't. Every save sets it.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
}

/// Every money movement.
///
/// Rows are ready for cloud sync from day one: ids are UUIDv7 made on the
/// phone, every change stamps [updatedAt], and deletes only set [deletedAt].
/// Enums are stored by name, so reordering them can't corrupt data.
@DataClassName('Txn')
@TableIndex(name: 'txns_occurred_at', columns: {#occurredAt})
// One live entry per imported SMS. Deleted entries don't count, so an SMS
// can be imported again after its entry is deleted.
@TableIndex.sql(
  'CREATE UNIQUE INDEX txns_dedupe_key ON txns (dedupe_key) '
  'WHERE deleted_at IS NULL',
)
class Txns extends Table with Synced {
  TextColumn get id => text()();
  // Drift reads this getter as a schema description; the self-reference
  // becomes `CHECK (amount_paise > 0)`, not a call.
  IntColumn get amountPaise =>
      // ignore: recursive_getters
      integer().check(amountPaise.isBiggerThanValue(0))();
  TextColumn get type => textEnum<TxnType>()();
  TextColumn get categoryId => text()();
  TextColumn get merchant => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get source => textEnum<TxnSource>()();

  /// The user's own call on a spend: necessary or wasteful. Penny's picks
  /// live in the month's insight, so a new report never overwrites this.
  TextColumn get tag => textEnum<TxnTag>().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Fingerprint of the SMS this entry came from, if any. Stays on the
  /// phone: sync must never upload it.
  TextColumn get dedupeKey => text().nullable()();

  /// Whether the SMS showed the payee is a person rather than a shop. Null
  /// for typed entries and older imports, where Penny can only guess.
  /// People's names never reach the AI either way.
  BoolColumn get payeeIsPerson => boolean().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Penny's look at one month: the analyze-month answer, already cleaned by
/// the server. It is worked out from that month's entries, so it stays on
/// this phone and is never synced.
@DataClassName('InsightRow')
class Insights extends Table {
  /// The month, as "2026-10".
  TextColumn get month => text()();

  /// Fingerprint of the money data that was sent. A different one now means
  /// entries have changed since Penny looked.
  TextColumn get inputHash => text()();

  /// JSON object from the group ids Penny saw ("s1", "i1"…) to this phone's
  /// group keys, which turn the answer back into entries.
  TextColumn get groupKeys => text()();

  /// The cleaned answer, as JSON.
  TextColumn get answer => text()();

  TextColumn get model => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {month};
}

/// What My needs says: a whole category, or one shop, is always necessary
/// or always wasteful. Kept like entries (UUIDv7 ids, soft deletes), ready
/// for sync.
@DataClassName('TagRule')
@TableIndex.sql(
  'CREATE UNIQUE INDEX tag_rules_kind_rule_key ON tag_rules (kind, rule_key) '
  'WHERE deleted_at IS NULL',
)
class TagRules extends Table with Synced {
  TextColumn get id => text()();
  TextColumn get kind => textEnum<RuleKind>()();

  /// A category id, or a shop name as `shopKey` writes it.
  TextColumn get ruleKey => text()();
  TextColumn get tag => textEnum<TxnTag>()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small settings, one text value each. Only the note to Penny is synced.
@DataClassName('Pref')
class Prefs extends Table with Synced {
  TextColumn get name => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}

/// The chat with Penny. It stays on this phone and is never synced.
@DataClassName('ChatMessage')
@TableIndex(name: 'chat_messages_created_at', columns: {#createdAt})
class ChatMessages extends Table {
  TextColumn get id => text()();
  TextColumn get role => textEnum<ChatRole>()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// What the user means to spend on one category each month; the monthly
/// budget is their total. Kept like entries (UUIDv7 ids, soft deletes),
/// ready for sync.
@DataClassName('BudgetRow')
@TableIndex.sql(
  'CREATE UNIQUE INDEX budgets_budget_key ON budgets (budget_key) '
  'WHERE deleted_at IS NULL',
)
class Budgets extends Table with Synced {
  TextColumn get id => text()();

  /// "everyday", or a spend category's id.
  TextColumn get budgetKey => text()();
  IntColumn get amountPaise =>
      // ignore: recursive_getters
      integer().check(amountPaise.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Something the user is saving for. Kept like entries, ready for sync.
@DataClassName('Goal')
class Goals extends Table with Synced {
  TextColumn get id => text()();
  TextColumn get title => text()();
  IntColumn get targetPaise =>
      // ignore: recursive_getters
      integer().check(targetPaise.isBiggerThanValue(0))();

  /// The day it's due, at midnight.
  DateTimeColumn get deadline => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Money put toward a goal, or taken back out as a negative amount. What a
/// goal has saved is their sum, so two phones can't overwrite each other's
/// total once sync arrives. Kept like entries, ready for sync.
@DataClassName('GoalDeposit')
@TableIndex(name: 'goal_deposits_goal_id', columns: {#goalId})
class GoalDeposits extends Table with Synced {
  TextColumn get id => text()();
  TextColumn get goalId => text()();
  IntColumn get amountPaise =>
      // ignore: recursive_getters
      integer().check(amountPaise.equals(0).not())();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// How far this phone has downloaded each synced table from the signed-in
/// account's copy: the last change number it has.
@DataClassName('SyncCursor')
class SyncCursors extends Table {
  /// The synced table, by its name on the server.
  TextColumn get kind => text()();

  /// The account whose copy it is. Another account starts again from 0.
  TextColumn get account => text()();
  IntColumn get seq => integer()();

  @override
  Set<Column<Object>> get primaryKey => {kind};
}

/// Penny's plan for one goal: the plan-goal answer, already cleaned by the
/// server. It is worked out from this phone's entries, so it stays here and
/// is never synced.
@DataClassName('GoalPlanRow')
class GoalPlans extends Table {
  TextColumn get goalId => text()();

  /// The month the plan went by, as "2026-10".
  TextColumn get month => text()();

  /// Fingerprint of the goal as it was: a different one now means its
  /// target, deadline or money changed since Penny planned.
  TextColumn get inputHash => text()();

  /// JSON object from the group ids Penny saw to this phone's group keys.
  TextColumn get groupKeys => text()();

  /// The cleaned answer, as JSON.
  TextColumn get answer => text()();
  TextColumn get model => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {goalId};
}

/// Payments Penny read from notifications, waiting on Home to be added or
/// skipped; and the ones skipped, kept a while so a notification that comes
/// again doesn't bring one back. Never synced: they stay on this phone.
@DataClassName('PendingCapture')
class PendingCaptures extends Table {
  /// The fingerprint of what was read, as its entry would keep it.
  TextColumn get dedupeKey => text()();

  /// Where it was read: "sms", "gpay", "phonepe" or "paytm".
  TextColumn get app => text()();

  /// Who sent it, for an SMS, as the Messages app names them: "JM-HDFCBK",
  /// "HDFC Bank". Tells one payment seen twice from two payments.
  TextColumn get sender => text().nullable()();

  /// The entry it was saved as, once saved. Kept, out of sight, so the same
  /// payment read again from another app is known.
  TextColumn get savedAs => text().nullable()();
  IntColumn get amountPaise => integer()();
  TextColumn get type => textEnum<TxnType>()();
  TextColumn get payee => text().nullable()();
  BoolColumn get payeeIsPerson => boolean()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get suggestedCategoryId => text().nullable()();

  /// What was read, with numbers hidden as on the SMS card.
  TextColumn get preview => text()();

  /// The preview's marked stretches, as JSON: [[start, end, kind], …].
  TextColumn get previewSpans => text()();

  /// An entry it may already be, in words, like "₹250 · Swiggy at 2:10 PM".
  TextColumn get lookalike => text().nullable()();
  DateTimeColumn get capturedAt => dateTime()();

  /// When it was skipped. A skipped one stays out of sight for a while.
  DateTimeColumn get skippedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {dedupeKey};
}
