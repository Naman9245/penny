import 'package:flutter/foundation.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/insight_builder.dart';

// Every number on the report, worked out on the phone from the entries as
// they are now. Penny's answer only says which groups are which, so an edit
// or a tag shows up in the numbers straight away.

/// Penny's tags from a saved report, looked up by entry.
class PennyTags {
  PennyTags(SavedInsight? saved)
    : _byKey = {
        if (saved != null)
          for (final MapEntry(key: id, value: keys) in saved.groupKeys.entries)
            if (saved.insight.tags[id] case final tag?)
              for (final key in keys) key: tag,
      };

  final Map<String, TxnTag> _byKey;

  /// Null for income, and for spends the report didn't cover.
  TxnTag? of(Txn txn) =>
      txn.type == TxnType.debit ? _byKey[groupKeyOf(txn)] : null;
}

/// What a spend counts as: the user's own tag, else Penny's, else not
/// sorted yet (null). Income never has one.
TxnTag? effectiveTag(Txn txn, PennyTags penny) =>
    txn.type == TxnType.debit ? txn.tag ?? penny.of(txn) : null;

/// A month's spending split into necessary, wasteful and not sorted yet.
@immutable
class TagSplit {
  const TagSplit({
    required this.necessaryPaise,
    required this.wastefulPaise,
    required this.unsortedPaise,
  });

  final int necessaryPaise;
  final int wastefulPaise;
  final int unsortedPaise;

  int get totalPaise => necessaryPaise + wastefulPaise + unsortedPaise;
}

TagSplit splitByTag(Iterable<Txn> monthTxns, SavedInsight? saved) {
  final penny = PennyTags(saved);
  var necessary = 0, wasteful = 0, unsorted = 0;
  for (final txn in monthTxns) {
    if (txn.type != TxnType.debit) continue;
    switch (effectiveTag(txn, penny)) {
      case TxnTag.necessary:
        necessary += txn.amountPaise;
      case TxnTag.wasteful:
        wasteful += txn.amountPaise;
      case null:
        unsorted += txn.amountPaise;
    }
  }
  return TagSplit(
    necessaryPaise: necessary,
    wastefulPaise: wasteful,
    unsortedPaise: unsorted,
  );
}

/// One of Penny's habits with this month's numbers.
@immutable
class HabitView {
  const HabitView({
    required this.habit,
    required this.names,
    required this.wasteful,
  });

  final InsightHabit habit;

  /// The shops (or categories) in the habit, as the user knows them.
  final List<String> names;

  /// This month's entries in the habit that still count as wasteful.
  final List<Txn> wasteful;

  String get title => habit.title.isNotEmpty ? habit.title : names.join(' & ');

  int get spentPaise => wasteful.fold(0, (sum, txn) => sum + txn.amountPaise);

  /// What cutting it would have saved, in whole rupees.
  int get savePaise => (spentPaise * habit.cut.quarters / 400).round() * 100;
}

/// The saved report's habits that still have wasteful spending this month.
/// A habit whose entries were all marked necessary drops out.
List<HabitView> habitViews(Iterable<Txn> monthTxns, SavedInsight saved) {
  final penny = PennyTags(saved);
  final spends = monthTxns.where((t) => t.type == TxnType.debit).toList();
  final views = <HabitView>[];
  for (final habit in saved.insight.habits) {
    final keys = {for (final id in habit.groupIds) ...?saved.groupKeys[id]};
    final members = spends.where((t) => keys.contains(groupKeyOf(t))).toList();
    final wasteful = [
      for (final txn in members)
        if (effectiveTag(txn, penny) == TxnTag.wasteful) txn,
    ];
    if (wasteful.isEmpty) continue;
    views.add(
      HabitView(habit: habit, names: _namesOf(members), wasteful: wasteful),
    );
  }
  return views;
}

/// What every habit together would have saved.
int totalSavingPaise(Iterable<HabitView> habits) =>
    habits.fold(0, (sum, habit) => sum + habit.savePaise);

/// Shop names, biggest spend first; entries without one go by category.
List<String> _namesOf(List<Txn> txns) {
  final totals = <String, int>{};
  for (final txn in txns) {
    final name = txn.merchant?.trim();
    final shown = name == null || name.isEmpty
        ? categoryById(txn.categoryId).label
        : name;
    totals[shown] = (totals[shown] ?? 0) + txn.amountPaise;
  }
  return totals.keys.toList()..sort((a, b) => totals[b]!.compareTo(totals[a]!));
}
