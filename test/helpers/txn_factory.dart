import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';

var _next = 0;

/// An entry built in memory, for tests that don't need a database.
Txn txn(
  int rupees,
  DateTime at, {
  TxnType type = TxnType.debit,
  String categoryId = 'food',
  String? merchant,
  TxnTag? tag,
  bool? payeeIsPerson,
  TxnSource source = TxnSource.manual,
}) {
  _next++;
  return Txn(
    id: 'txn-$_next',
    amountPaise: rupees * 100,
    type: type,
    categoryId: categoryId,
    merchant: merchant,
    occurredAt: at,
    source: source,
    tag: tag,
    createdAt: at,
    updatedAt: at,
    payeeIsPerson: payeeIsPerson,
  );
}
