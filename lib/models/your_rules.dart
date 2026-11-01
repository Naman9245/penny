import 'package:flutter/foundation.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';

export 'package:penny/models/rule_kind.dart';

/// The user's standing calls from My needs: whole categories, and single
/// shops, that are always necessary or always wasteful.
@immutable
class YourRules {
  const YourRules({this.categories = const {}, this.shops = const {}});

  static const none = YourRules();

  /// By category id.
  final Map<String, TxnTag> categories;

  /// By shop name, as [shopKey] writes it.
  final Map<String, TxnTag> shops;

  /// The rule for a spend: its shop's, else its category's. Null for income
  /// and for spends no rule covers.
  TxnTag? of(Txn txn) {
    if (txn.type != TxnType.debit) return null;
    final shop = shopKey(txn.merchant);
    return (shop == null ? null : shops[shop]) ?? categories[txn.categoryId];
  }
}

/// A shop name the way rules and groups compare it: trimmed, lower case,
/// single spaces. Null when there's no name.
String? shopKey(String? merchant) {
  final key = merchant?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  return key == null || key.isEmpty ? null : key;
}
