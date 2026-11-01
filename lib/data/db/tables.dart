import 'package:drift/drift.dart';
import 'package:penny/models/txn_enums.dart';

/// Every money movement.
///
/// Rows are ready for cloud sync from day one: ids are UUIDv7 made on the
/// phone, every change stamps [updatedAt], and deletes only set [deletedAt].
/// Enums are stored by name, so reordering them can't corrupt data.
@DataClassName('Txn')
@TableIndex(name: 'txns_occurred_at', columns: {#occurredAt})
class Txns extends Table {
  TextColumn get id => text()();
  // Drift reads this getter as a schema description; the self-reference
  // becomes `CHECK (amount_paise > 0)`, not a call.
  // ignore: recursive_getters
  IntColumn get amountPaise => integer().check(amountPaise.isBiggerThanValue(0))();
  TextColumn get type => textEnum<TxnType>()();
  TextColumn get categoryId => text()();
  TextColumn get merchant => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get source => textEnum<TxnSource>()();
  TextColumn get tag => textEnum<TxnTag>().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
