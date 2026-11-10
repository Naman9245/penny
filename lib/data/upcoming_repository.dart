import 'package:drift/drift.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/services/sms_parser.dart';

/// Payments a message said are coming, for Home's Coming up card. They stay
/// on this phone and are never synced.
class UpcomingRepository {
  UpcomingRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Keeps [read], unless the same message was kept before.
  Future<void> keep(UpcomingRead read) => _db
      .into(_db.upcomingPayments)
      .insert(
        UpcomingPaymentsCompanion.insert(
          dedupeKey: read.dedupeKey,
          amountPaise: read.amountPaise,
          payee: Value(read.payee),
          categoryId: Value(read.categoryId),
          dueOn: read.dueOn,
          readAt: _clock(),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// The ones due on or after [from] that weren't taken off the card,
  /// soonest first.
  Stream<List<UpcomingPayment>> watchFrom(DateTime from) {
    final query = _db.select(_db.upcomingPayments)
      ..where(
        (u) => u.dismissedAt.isNull() & u.dueOn.isBiggerOrEqualValue(from),
      )
      ..orderBy([(u) => OrderingTerm.asc(u.dueOn)]);
    return query.watch();
  }

  /// Takes one off the card.
  Future<void> dismiss(String dedupeKey) =>
      (_db.update(_db.upcomingPayments)
            ..where((u) => u.dedupeKey.equals(dedupeKey)))
          .write(UpcomingPaymentsCompanion(dismissedAt: Value(_clock())));
}
