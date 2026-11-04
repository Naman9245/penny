/// Money out (debit) or in (credit), as banks label it.
enum TxnType { debit, credit }

/// Where an entry came from: typed in, or a bank SMS shared or pasted to
/// Penny. `sms` is kept for reading bank SMS by itself, which comes later.
enum TxnSource { manual, share, sms }

/// Whether a spend was necessary or wasteful: Penny's pick in her report,
/// or the user's own, which always wins.
enum TxnTag { necessary, wasteful }
