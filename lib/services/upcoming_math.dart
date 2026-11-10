import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';

/// How long after its day a payment still shows, in case it's late.
const upcomingGrace = Duration(days: 3);

/// How far ahead the card looks.
const upcomingAhead = Duration(days: 30);

/// What Home's Coming up card shows on [today], soonest first: what's due
/// from [upcomingGrace] ago to [upcomingAhead] on, unless it looks paid
/// already. A payment looks paid when [txns] has money out of the same
/// amount within [upcomingGrace] of its day.
List<UpcomingPayment> comingUp(
  Iterable<UpcomingPayment> upcoming,
  Iterable<Txn> txns,
  DateTime today,
) {
  final from = today.subtract(upcomingGrace);
  final to = today.add(upcomingAhead);
  bool paid(UpcomingPayment due) => txns.any(
    (txn) =>
        txn.type == TxnType.debit &&
        txn.amountPaise == due.amountPaise &&
        txn.occurredAt.difference(due.dueOn).abs() <=
            upcomingGrace + const Duration(days: 1),
  );
  return [
    for (final due in upcoming)
      if (due.dismissedAt == null &&
          !due.dueOn.isBefore(from) &&
          !due.dueOn.isAfter(to) &&
          !paid(due))
        due,
  ]..sort((a, b) => a.dueOn.compareTo(b.dueOn));
}
