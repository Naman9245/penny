import 'package:drift/drift.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/autopay_math.dart';
import 'package:uuid/uuid.dart';

/// Autopays: payments that go out by themselves, found from messages or
/// added by the user. Synced like entries: UUIDv7 ids, stamps and soft
/// deletes.
class AutopayRepository {
  AutopayRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  $AutopaysTable get _rows => _db.autopays;

  /// Every autopay not deleted, by name.
  Stream<List<Autopay>> watchAll() =>
      (_db.select(_rows)
            ..where((a) => a.deletedAt.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .watch();

  Future<List<Autopay>> all() =>
      (_db.select(_rows)..where((a) => a.deletedAt.isNull())).get();

  Future<Autopay?> findById(String id) => (_db.select(
    _rows,
  )..where((a) => a.id.equals(id) & a.deletedAt.isNull())).getSingleOrNull();

  /// The autopay to [name], an ended one included. Null when there's none.
  Future<Autopay?> findByName(String name) async {
    for (final autopay in await all()) {
      if (sameAutopay(autopay.name, name)) return autopay;
    }
    return null;
  }

  Future<String> add({
    required String name,
    required int amountPaise,
    AutopayEvery every = AutopayEvery.monthly,
    DateTime? nextOn,
    DateTime? lastPaidOn,
    String? categoryId,
    bool fromMessage = false,
  }) async {
    final id = _uuid.v7();
    final now = _clock();
    await _db
        .into(_rows)
        .insert(
          AutopaysCompanion.insert(
            id: id,
            name: name.trim(),
            amountPaise: amountPaise,
            every: every,
            categoryId: Value(categoryId),
            nextOn: Value(nextOn == null ? null : dayStart(nextOn)),
            lastPaidOn: Value(lastPaidOn == null ? null : dayStart(lastPaidOn)),
            fromMessage: Value(fromMessage),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Changes what's given of [id]; the rest stays as it is.
  Future<void> edit(
    String id, {
    String? name,
    int? amountPaise,
    AutopayEvery? every,
    Value<DateTime?> nextOn = const Value.absent(),
    Value<DateTime?> lastPaidOn = const Value.absent(),
    Value<DateTime?> endedAt = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    bool? paused,
  }) {
    Value<DateTime?> day(Value<DateTime?> value) =>
        value.present && value.value != null
        ? Value(dayStart(value.value!))
        : value;
    return (_db.update(_rows)..where((a) => a.id.equals(id))).write(
      AutopaysCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        amountPaise: amountPaise == null
            ? const Value.absent()
            : Value(amountPaise),
        every: every == null ? const Value.absent() : Value(every),
        nextOn: day(nextOn),
        lastPaidOn: day(lastPaidOn),
        endedAt: endedAt,
        categoryId: categoryId,
        paused: paused == null ? const Value.absent() : Value(paused),
        updatedAt: Value(_clock()),
        dirty: const Value(true),
      ),
    );
  }

  Future<void> delete(String id) => _setDeletedAt(id, _clock());

  Future<void> restore(String id) => _setDeletedAt(id, null);

  Future<void> _setDeletedAt(String id, DateTime? at) =>
      (_db.update(_rows)..where((a) => a.id.equals(id))).write(
        AutopaysCompanion(
          deletedAt: Value(at),
          updatedAt: Value(_clock()),
          dirty: const Value(true),
        ),
      );

  // What messages say.

  /// One set up, like "UPI mandate to SPOTIFY … has been created": added,
  /// or one cancelled before brought back. Null when there's no amount to
  /// add one with.
  Future<String?> noteSetUp({
    required String name,
    int? amountPaise,
    String? categoryId,
  }) async {
    final known = await findByName(name);
    if (known != null) {
      await edit(
        known.id,
        amountPaise: amountPaise,
        endedAt: const Value(null),
        paused: false,
      );
      return known.id;
    }
    if (amountPaise == null || amountPaise <= 0) return null;
    return add(
      name: name,
      amountPaise: amountPaise,
      categoryId: categoryId,
      fromMessage: true,
    );
  }

  /// One cancelled: it ends. Null when Penny didn't know it.
  Future<String?> noteEnded(String name, DateTime at) async {
    final known = await findByName(name);
    if (known == null) return null;
    await edit(known.id, endedAt: Value(at));
    return known.id;
  }

  /// One paused. Null when Penny didn't know it.
  Future<String?> notePaused(String name) async {
    final known = await findByName(name);
    if (known == null) return null;
    await edit(known.id, paused: true);
    return known.id;
  }

  /// The day one goes out, from the bank's note a day or so before.
  Future<void> noteDue({
    required String name,
    required int amountPaise,
    required DateTime dueOn,
    String? categoryId,
  }) async {
    final known = await findByName(name);
    if (known == null) {
      await add(
        name: name,
        amountPaise: amountPaise,
        nextOn: dueOn,
        categoryId: categoryId,
        fromMessage: true,
      );
      return;
    }
    await edit(
      known.id,
      amountPaise: amountPaise,
      nextOn: Value(dueOn),
      endedAt: const Value(null),
      paused: false,
    );
  }

  /// One that went out on [on]: its next day moves on.
  Future<void> notePaid({
    required String name,
    required int amountPaise,
    required DateTime on,
    String? categoryId,
  }) async {
    final known = await findByName(name);
    if (known == null) {
      await add(
        name: name,
        amountPaise: amountPaise,
        lastPaidOn: on,
        nextOn: nextAfter(dayStart(on), AutopayEvery.monthly),
        categoryId: categoryId,
        fromMessage: true,
      );
      return;
    }
    await edit(
      known.id,
      amountPaise: amountPaise,
      lastPaidOn: Value(on),
      nextOn: Value(nextAfter(dayStart(on), known.every)),
      endedAt: const Value(null),
    );
  }
}
