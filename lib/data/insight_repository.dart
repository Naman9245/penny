import 'dart:convert';

import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/services/insight_builder.dart';

/// Penny's saved reports, one per month. They stay on this phone.
class InsightRepository {
  InsightRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// The report for the month containing [month], or null when there is
  /// none (or it can't be read any more).
  Stream<SavedInsight?> watch(DateTime month) {
    final start = monthStart(month);
    final query = _db.select(_db.insights)
      ..where((t) => t.month.equals(monthKey(start)));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _read(row, start),
    );
  }

  /// Keeps [insight] as the report for [request]'s month, replacing any
  /// earlier one.
  Future<void> save({
    required InsightRequest request,
    required MonthInsight insight,
    required String model,
  }) {
    return _db
        .into(_db.insights)
        .insertOnConflictUpdate(
          InsightsCompanion.insert(
            month: monthKey(request.month),
            inputHash: request.inputHash,
            groupKeys: jsonEncode(request.groupKeys),
            answer: jsonEncode(insight.toJson()),
            model: model,
            createdAt: _clock(),
          ),
        );
  }

  static SavedInsight? _read(InsightRow row, DateTime month) {
    try {
      final groupKeys = {
        for (final MapEntry(:key, :value)
            in (jsonDecode(row.groupKeys) as Map<String, dynamic>).entries)
          key: (value as List).cast<String>(),
      };
      final insight = MonthInsight.fromJson(
        jsonDecode(row.answer),
        groupIds: groupKeys.keys.toSet(),
      );
      if (insight == null) return null;
      return SavedInsight(
        month: month,
        inputHash: row.inputHash,
        groupKeys: groupKeys,
        insight: insight,
        model: row.model,
        createdAt: row.createdAt,
      );
    } on Object {
      // A report from an older version that no longer reads: ask again.
      return null;
    }
  }
}
