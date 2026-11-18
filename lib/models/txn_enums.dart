/// Money out (debit) or in (credit), as banks label it.
enum TxnType { debit, credit }

/// Where an entry came from: typed in, or a bank SMS shared or pasted to
/// Penny. `sms` is kept for reading bank SMS by itself, which comes later.
enum TxnSource { manual, share, sms }

/// Which side of a move between your own accounts a message tells: the
/// wallet's (money into or out of it) or the bank's.
enum MoveSide { wallet, bank }

/// How often an autopay goes out.
enum AutopayEvery {
  weekly('every week', 'a week'),
  monthly('every month', 'a month'),
  quarterly('every 3 months', 'every 3 months'),
  yearly('every year', 'a year');

  const AutopayEvery(this.label, this.per);

  /// "every month".
  final String label;

  /// "a month", as in "₹139 a month".
  final String per;
}

/// Whether a spend was necessary or wasteful: Penny's pick in her report,
/// or the user's own, which always wins.
enum TxnTag { necessary, wasteful }
