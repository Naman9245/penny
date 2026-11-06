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
}
