import 'package:flutter/foundation.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/money_kinds.dart';

// Every number on the report, worked out on the phone from the entries as
// they are now. Penny's answer only says which groups are which, so an edit,
// a tag or a My needs rule shows up in the numbers straight away.

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
  TxnTag? of(Txn txn) => txn.isSpend ? _byKey[groupKeyOf(txn)] : null;
}

/// What a spend counts as. In order: the user's tag on the entry, their My
/// needs rule for its shop or category, Penny's pick, else not sorted yet
/// (null). Income never has one.
TxnTag? effectiveTag(
  Txn txn,
  PennyTags penny, [
  YourRules rules = YourRules.none,
]) => txn.isSpend ? txn.tag ?? rules.of(txn) ?? penny.of(txn) : null;

/// A month's spending split into necessary, wasteful and not sorted yet,
/// as it was paid, with what came back since.
@immutable
class TagSplit {
  const TagSplit({
    required this.necessaryPaise,
    required this.wastefulPaise,
    required this.unsortedPaise,
    this.cameBackPaise = 0,
  });

  final int necessaryPaise;
  final int wastefulPaise;
  final int unsortedPaise;

  /// Paid back by friends: not part of the split.
  final int cameBackPaise;

  int get totalPaise => necessaryPaise + wastefulPaise + unsortedPaise;
}

TagSplit splitByTag(
  Iterable<Txn> monthTxns,
  SavedInsight? saved, {
  YourRules rules = YourRules.none,
}) {
  final penny = PennyTags(saved);
  var necessary = 0, wasteful = 0, unsorted = 0, cameBack = 0;
  for (final txn in monthTxns) {
    if (txn.kind == MoneyKind.paidBack) cameBack += txn.amountPaise;
    if (!txn.isSpend) continue;
    switch (effectiveTag(txn, penny, rules)) {
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
    cameBackPaise: cameBack,
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
/// A habit whose entries were all marked necessary, by tag or by rule,
/// drops out.
List<HabitView> habitViews(
  Iterable<Txn> monthTxns,
  SavedInsight saved, {
  YourRules rules = YourRules.none,
}) {
  final penny = PennyTags(saved);
  final spends = monthTxns.where((t) => t.isSpend).toList();
  final views = <HabitView>[];
  for (final habit in saved.insight.habits) {
    final keys = {for (final id in habit.groupIds) ...?saved.groupKeys[id]};
    final members = spends.where((t) => keys.contains(groupKeyOf(t))).toList();
    final wasteful = [
      for (final txn in members)
        if (effectiveTag(txn, penny, rules) == TxnTag.wasteful) txn,
    ];
    if (wasteful.isEmpty) continue;
    views.add(
      HabitView(habit: habit, names: namesOf(members), wasteful: wasteful),
    );
  }
  return views;
}

/// One thing that counts as wasteful this month: a group Penny looked at,
/// or a shop (or category) tagged wasteful since, with its entries that
/// still count as wasteful.
@immutable
class WastefulItem {
  const WastefulItem({
    required this.id,
    required this.names,
    required this.wasteful,
    required this.reason,
  });

  /// Penny's group id, or the entries' own group when she didn't see it.
  final String id;

  /// The shops (or categories) in it, as the user knows them.
  final List<String> names;
  final List<Txn> wasteful;

  /// Penny's sentence on why; empty when she gave none.
  final String reason;

  int get spentPaise => wasteful.fold(0, (sum, txn) => sum + txn.amountPaise);

  int get count => wasteful.length;

  int get averagePaise => count == 0 ? 0 : spentPaise ~/ count;
}

/// Everything that counts as wasteful in [monthTxns], biggest first: by
/// the user's own tag, a My needs rule, or Penny's pick in [saved].
List<WastefulItem> wastefulItems(
  Iterable<Txn> monthTxns,
  SavedInsight? saved, {
  YourRules rules = YourRules.none,
}) {
  final penny = PennyTags(saved);
  final idOfKey = {
    if (saved != null)
      for (final MapEntry(key: id, value: keys) in saved.groupKeys.entries)
        for (final key in keys) key: id,
  };
  final byId = <String, List<Txn>>{};
  for (final txn in monthTxns) {
    if (effectiveTag(txn, penny, rules) != TxnTag.wasteful) continue;
    final key = groupKeyOf(txn);
    (byId[idOfKey[key] ?? key] ??= []).add(txn);
  }
  final items = [
    for (final MapEntry(key: id, value: txns) in byId.entries)
      WastefulItem(
        id: id,
        names: namesOf(txns),
        wasteful: txns,
        reason: saved?.insight.reasons[id] ?? '',
      ),
  ];
  return items..sort((a, b) => b.spentPaise.compareTo(a.spentPaise));
}

/// What every habit together would have saved.
int totalSavingPaise(Iterable<HabitView> habits) =>
    habits.fold(0, (sum, habit) => sum + habit.savePaise);

/// Each spend group's tag in [request], when all of its entries in
/// [monthTxns] count the same way. This is what the chat tells Penny.
Map<String, TxnTag> groupTags(
  InsightRequest request,
  Iterable<Txn> monthTxns,
  SavedInsight? saved, {
  YourRules rules = YourRules.none,
}) {
  final penny = PennyTags(saved);
  final byKey = <String, Set<TxnTag?>>{};
  for (final txn in monthTxns) {
    if (!txn.isSpend) continue;
    (byKey[groupKeyOf(txn)] ??= {}).add(effectiveTag(txn, penny, rules));
  }
  final tags = <String, TxnTag>{};
  for (final spend in request.spends) {
    final id = spend['id']! as String;
    final seen = {for (final key in request.groupKeys[id]!) ...?byKey[key]};
    if (seen.length == 1 && seen.single != null) tags[id] = seen.single!;
  }
  return tags;
}

/// Shop names, biggest spend first; entries without one go by category.
/// The shops (or categories, for entries with no shop) of [txns], as the
/// user knows them, biggest first.
List<String> namesOf(List<Txn> txns) {
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
