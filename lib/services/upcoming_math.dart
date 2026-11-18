import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/autopay_math.dart';

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

/// One row of Home's Coming up card: a payment a message said is coming, or
/// an autopay's next day. [autopayId] is the autopay's, for one.
typedef DueItem = ({
  String key,
  String? name,
  int amountPaise,
  DateTime dueOn,
  String? categoryId,
  String? autopayId,
});

/// What Home's Coming up card shows on [today], soonest first: [comingUp]'s
/// payments, and the next day of each of [autopays] within
/// [upcomingAhead], unless a message about it is shown already or it looks
/// paid.
List<DueItem> dueSoon({
  required Iterable<UpcomingPayment> upcoming,
  required Iterable<Autopay> autopays,
  required Iterable<Txn> txns,
  required DateTime today,
}) {
  final said = comingUp(upcoming, txns, today);
  final items = <DueItem>[
    for (final due in said)
      (
        key: due.dedupeKey,
        name: due.payee,
        amountPaise: due.amountPaise,
        dueOn: due.dueOn,
        categoryId: due.categoryId,
        autopayId: null,
      ),
  ];
  final to = today.add(upcomingAhead);
  bool near(DateTime a, DateTime b) =>
      dayStart(a).difference(dayStart(b)).abs() <= autopayGrace;
  for (final autopay in autopays.where(isActive)) {
    final due = dueOn(autopay, today);
    if (due == null || due.isAfter(to)) continue;
    final told = said.any(
      (s) =>
          s.payee != null &&
          sameAutopay(s.payee!, autopay.name) &&
          near(s.dueOn, due),
    );
    final paid =
        (autopay.lastPaidOn != null && near(autopay.lastPaidOn!, due)) ||
        txns.any(
          (txn) =>
              txn.type == TxnType.debit &&
              txn.amountPaise == autopay.amountPaise &&
              near(txn.occurredAt, due),
        );
    if (told || paid) continue;
    items.add((
      key: 'autopay-${autopay.id}',
      name: autopay.name,
      amountPaise: autopay.amountPaise,
      dueOn: due,
      categoryId: autopay.categoryId,
      autopayId: autopay.id,
    ));
  }
  return items..sort((a, b) => a.dueOn.compareTo(b.dueOn));
}
