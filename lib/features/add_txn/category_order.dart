import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';

/// How far back the Add screen counts entries to order its tiles.
const categoryUseDays = 90;

/// How many entries went to each category. Money out and money in count
/// apart, so a friend paying back for Food doesn't lift Food among spends.
class CategoryUses {
  CategoryUses(Iterable<Txn> txns) {
    for (final txn in txns) {
      final key = (txn.type, txn.categoryId);
      _counts[key] = (_counts[key] ?? 0) + 1;
    }
  }

  /// Nothing counted yet: every tile keeps its place.
  static final none = CategoryUses(const []);

  final _counts = <(TxnType, String), int>{};

  /// How many entries went to [category].
  int of(Category category) => _counts[(category.type, category.id)] ?? 0;

  /// How many times money came back for spend [category]: friends paying
  /// their share.
  int paidBack(Category category) =>
      _counts[(TxnType.credit, category.id)] ?? 0;
}

/// [categories] with the ones used most first. Ties, and ones never used,
/// keep the order they came in.
///
/// For [paybacks], what money came back for most goes first, then what was
/// spent on most.
List<Category> mostUsedFirst(
  List<Category> categories,
  CategoryUses uses, {
  bool paybacks = false,
}) {
  final counts = [if (paybacks) uses.paidBack, uses.of];
  // Each tile's place is the last tie-break, since sort alone may shuffle
  // equals.
  final ranked = categories.indexed.toList()
    ..sort((a, b) {
      for (final count in counts) {
        final byUse = count(b.$2).compareTo(count(a.$2));
        if (byUse != 0) return byUse;
      }
      return a.$1.compareTo(b.$1);
    });
  return [for (final (_, category) in ranked) category];
}
