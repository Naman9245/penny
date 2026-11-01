import 'package:drift/drift.dart';
import 'package:penny/models/txn_enums.dart';

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
class Txns extends Table {
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
