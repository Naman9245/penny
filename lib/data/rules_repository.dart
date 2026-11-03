import 'package:drift/drift.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:uuid/uuid.dart';

/// What My needs says, and changes to it. Cleared rules are only marked
/// deleted, like entries, so sync can carry the change later.
class RulesRepository {
  RulesRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _uuid = Uuid();

  Stream<YourRules> watch() {
    final query = _db.select(_db.tagRules)..where((r) => r.deletedAt.isNull());
    return query.watch().map(
      (rows) => YourRules(
        categories: {
          for (final rule in rows)
            if (rule.kind == RuleKind.category) rule.ruleKey: rule.tag,
        },
        shops: {
          for (final rule in rows)
            if (rule.kind == RuleKind.shop) rule.ruleKey: rule.tag,
        },
      ),
    );
  }

  /// Makes [key] always [tag]: a category id, or a shop name as [shopKey]
  /// writes it. Null hands it back to Penny.
  Future<void> set(RuleKind kind, String key, TxnTag? tag) {
    final now = _clock();
    return _db.transaction(() async {
      final live =
          await (_db.select(_db.tagRules)..where(
                (r) =>
                    r.kind.equalsValue(kind) &
                    r.ruleKey.equals(key) &
                    r.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (live == null) {
        if (tag == null) return;
        await _db
            .into(_db.tagRules)
            .insert(
              TagRulesCompanion.insert(
                id: _uuid.v7(),
                kind: kind,
                ruleKey: key,
                tag: tag,
                createdAt: now,
                updatedAt: now,
              ),
            );
        return;
      }
      await (_db.update(
        _db.tagRules,
      )..where((r) => r.id.equals(live.id))).write(
        tag == null
            ? TagRulesCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                dirty: const Value(true),
              )
            : TagRulesCompanion(
                tag: Value(tag),
                updatedAt: Value(now),
                dirty: const Value(true),
              ),
      );
    });
  }
}
