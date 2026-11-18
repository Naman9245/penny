/// Money out (debit) or in (credit), as banks label it.
enum TxnType { debit, credit }

/// Where an entry came from: typed in, or a bank SMS shared or pasted to
/// Penny. `sms` is kept for reading bank SMS by itself, which comes later.
enum TxnSource { manual, share, sms }

/// Which side of a move between your own accounts a message tells: the
/// wallet's (money into or out of it) or the bank's.
enum MoveSide { wallet, bank }

/// Whether a spend was necessary or wasteful: Penny's pick in her report,
/// or the user's own, which always wins.
enum TxnTag { necessary, wasteful }
