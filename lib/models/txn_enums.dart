/// Money out (debit) or in (credit), as banks label it.
enum TxnType { debit, credit }

/// Where an entry came from. Shared and read SMS arrive in Milestone 2.
enum TxnSource { manual, share, sms }

/// The analysis label proposed in Milestone 3, which the user can override.
enum TxnTag { necessary, wasteful }
