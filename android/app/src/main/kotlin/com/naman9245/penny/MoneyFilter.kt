package com.naman9245.penny

/**
 * The first look at a notification or SMS: whether it may be about money,
 * so it's kept for Penny to read. Everything else is ignored as it comes.
 */
object MoneyFilter {
    /** ₹, Rs or INR next to a number, either way round. */
    private val CURRENCY = Regex(
        """(?:₹|\brs\.?|\binr)\s*\d|\d\s*(?:₹|rs\b|inr\b)""",
        RegexOption.IGNORE_CASE,
    )

    /** An amount with paise, like "641.00", standing on its own. */
    private val PLAIN_AMOUNT = Regex("""(?<![\d.,])\d[\d,]*\.\d{2}(?![\d.])""")

    /** Words that come with money moving. */
    private val MONEY_WORD = Regex(
        """\b(?:transaction|txn|debited|credited|reversed|reversal|refund|refunded|paid|received|deducted|sent|spent|withdrawn)\b""",
        RegexOption.IGNORE_CASE,
    )

    /**
     * Whether [text] has an amount: one with ₹, Rs or INR, or one with paise
     * next to a word of money moving ("transaction of 641.00 … reversed").
     */
    fun looksLikeMoney(text: String): Boolean =
        CURRENCY.containsMatchIn(text) ||
            (PLAIN_AMOUNT.containsMatchIn(text) && MONEY_WORD.containsMatchIn(text))

    /** A bank's sender code, with or without its route: "JM-HDFCBK-S", "HDFCBK". */
    private val SENDER_CODE = Regex("""^(?:[A-Z]{2}-)?[A-Z0-9]{5,9}(?:-[A-Z])?$""")

    /** An account, card, wallet or UPI Lite named in the message. */
    private val MONEY_PLACE = Regex(
        """\b(?:a/?c|acct|account|card|wallet|upi\s*lite|folio|demat)\b""",
        RegexOption.IGNORE_CASE,
    )

    /**
     * Whether an SMS from [sender] saying [body] may be a bank's, a wallet's
     * or an investment's: a sender code, not a phone number, or a message
     * naming an account, card or wallet. A friend's SMS isn't kept.
     */
    fun fromMoneySender(sender: String, body: String): Boolean =
        SENDER_CODE.matches(sender.trim().uppercase()) && sender.any { it.isLetter() } ||
            MONEY_PLACE.containsMatchIn(body)
}
