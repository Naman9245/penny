import 'package:flutter/foundation.dart';
import 'package:penny/models/txn_enums.dart';

/// How much of a habit Penny suggests cutting.
enum Cut {
  stop('stop', 4, 'Stop it', 'Stop it'),
  threeQuarters('three_quarters', 3, 'Cut three quarters', 'Cut ¾'),
  half('half', 2, 'Halve it', 'Halve it'),
  quarter('quarter', 1, 'Cut a quarter', 'Cut ¼');

  const Cut(this.wire, this.quarters, this.label, this.short);

  /// The name the server uses.
  final String wire;

  /// How many quarters of the spending it saves.
  final int quarters;

  /// In words, for screen readers.
  final String label;

  /// What the pill shows.
  final String short;

  static Cut? fromWire(Object? value) {
    for (final cut in values) {
      if (cut.wire == value) return cut;
    }
    return null;
  }
}

/// How steady an income source has been. Worked out on the phone, then sent
/// so Penny can describe it.
enum Steadiness {
  steady('steady', 'Every month'),
  mostMonths('most_months', 'Most months'),
  nowAndThen('now_and_then', 'Now and then'),
  tooEarly('too_early', 'Too early to tell');

  const Steadiness(this.wire, this.label);

  final String wire;
  final String label;

  static Steadiness? fromWire(Object? value) {
    for (final steadiness in values) {
      if (steadiness.wire == value) return steadiness;
    }
    return null;
  }
}

/// A wasteful habit Penny picked out, or a cut in her plan for a goal:
/// which groups, how much to cut, and a tip. The amounts are worked out on
/// the phone, never by Penny.
@immutable
class InsightHabit {
  const InsightHabit({
    required this.title,
    required this.groupIds,
    required this.cut,
    required this.tip,
  });

  /// Can be empty, when the server dropped it; the report then names the
  /// shops instead.
  final String title;
  final List<String> groupIds;
  final Cut cut;
  final String tip;

  /// The habits in [raw] that make sense: known cuts, with groups among
  /// [groupIds] when given.
  static List<InsightHabit> listFromJson(Object? raw, {Set<String>? groupIds}) {
    if (raw is! List) return const [];
    final habits = <InsightHabit>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final cut = Cut.fromWire(item['cut']);
      final groups = [
        if (item['groups'] case final List ids)
          for (final id in ids)
            if (id is String && (groupIds == null || groupIds.contains(id))) id,
      ];
      if (cut == null || groups.isEmpty) continue;
      habits.add(
        InsightHabit(
          title: _text(item['title']),
          groupIds: groups,
          cut: cut,
          tip: _text(item['tip']),
        ),
      );
    }
    return habits;
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'groups': groupIds,
    'cut': cut.wire,
    'tip': tip,
  };
}

/// Penny's answer for a month, as the server cleaned it. Group ids ("s1"…)
/// are the ones the phone sent.
@immutable
class MonthInsight {
  const MonthInsight({
    required this.tags,
    required this.habits,
    required this.summary,
    required this.incomeNote,
    this.earnIdeas = const [],
    this.reasons = const {},
  });

  final Map<String, TxnTag> tags;
  final List<InsightHabit> habits;
  final String summary;
  final String incomeNote;

  /// Up to three ways to earn a little extra. Reports from before Penny gave
  /// these have none.
  final List<String> earnIdeas;

  /// Why each wasteful group is wasteful, in a sentence, by group id.
  /// Reports from before Penny gave these have none.
  final Map<String, String> reasons;

  /// Reads an answer, keeping only what makes sense: tags and habits for
  /// [groupIds] when given, known tags and cuts, and text. Null when [json]
  /// isn't an answer at all.
  static MonthInsight? fromJson(Object? json, {Set<String>? groupIds}) {
    if (json is! Map) return null;
    bool known(Object? id) =>
        id is String && (groupIds == null || groupIds.contains(id));

    final tags = <String, TxnTag>{};
    if (json['tags'] case final Map raw) {
      for (final MapEntry(:key, :value) in raw.entries) {
        final tag = TxnTag.values.asNameMap()[value];
        if (known(key) && tag != null) tags[key as String] = tag;
      }
    }

    return MonthInsight(
      tags: tags,
      habits: InsightHabit.listFromJson(json['habits'], groupIds: groupIds),
      summary: _text(json['summary']),
      incomeNote: _text(json['incomeNote']),
      earnIdeas: [
        if (json['earnIdeas'] case final List ideas)
          for (final idea in ideas.take(3))
            if (_text(idea).isNotEmpty) _text(idea),
      ],
      reasons: {
        if (json['reasons'] case final Map raw)
          for (final MapEntry(:key, :value) in raw.entries)
            if (known(key) && _text(value).isNotEmpty)
              key as String: _text(value),
      },
    );
  }

  Map<String, Object?> toJson() => {
    'tags': {
      for (final MapEntry(:key, :value) in tags.entries) key: value.name,
    },
    'habits': [for (final habit in habits) habit.toJson()],
    'summary': summary,
    'incomeNote': incomeNote,
    'earnIdeas': earnIdeas,
    if (reasons.isNotEmpty) 'reasons': reasons,
  };
}

String _text(Object? value) => value is String ? value.trim() : '';

/// A report kept on the phone for one month.
@immutable
class SavedInsight {
  const SavedInsight({
    required this.month,
    required this.inputHash,
    required this.groupKeys,
    required this.insight,
    required this.model,
    required this.createdAt,
  });

  final DateTime month;

  /// Fingerprint of the money data Penny saw.
  final String inputHash;

  /// The local groups behind each id Penny saw. Never leaves the phone.
  final Map<String, List<String>> groupKeys;
  final MonthInsight insight;
  final String model;
  final DateTime createdAt;
}
