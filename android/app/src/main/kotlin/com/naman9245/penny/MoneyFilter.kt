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

    /**
     * A money brand's name, as the Messages app may show a bank's sender
     * saved as a contact. Must match _moneyBrand in
     * lib/services/sms_parser.dart.
     */
    private val MONEY_BRAND = Regex(
        """\b(?:bank|wallet|cards?|payments?|pay|upi|mf|amc|mutual\s*funds?|securities|broking|finserv|finance|capital""" +
            """|sbi|hdfc|icici|axis|kotak|indusind|idfc|idbi|baroda|bob|pnb|canara|federal|rbl|equitas|ujjivan|bandhan|dbs|hsbc|citi|amex""" +
            """|payzapp|paytm|phonepe|gpay|mobikwik|freecharge|cred|bhim|onecard|slice|groww|zerodha|upstox|kuvera|indmoney|cams|kfintech|nsdl|cdsl""" +
            """|super\.money|angel\s*one|jio\s*money|airtel\s*money|et\s*money)\b""",
        RegexOption.IGNORE_CASE,
    )

    /**
     * An account or card number shown masked, as only a bank's own message
     * does: "A/c XX4821", "card *4455", "card ending 4455". Must match
     * _maskedAccount in lib/services/sms_parser.dart.
     */
    private val MASKED_ACCOUNT = Regex(
        """\b(?:a/?c|acct|account|card)(?:\s*no\.?)?[\s:.]*(?:[x*•.]+\d{2,}|ending(?:\s*with)?[\s:.]*[x*•]*\d{3,})""",
        RegexOption.IGNORE_CASE,
    )

    /**
     * Whether an SMS from [sender] saying [body] may be a bank's, a wallet's
     * or an investment's: from a sender code (not a phone number) or a money
     * brand's name, or showing a masked account or card number. A friend's
     * SMS isn't kept, even one that says "account" or "wallet".
     */
    fun fromMoneySender(sender: String, body: String): Boolean {
        val name = sender.trim()
        return SENDER_CODE.matches(name.uppercase()) && name.any { it.isLetter() } ||
            MONEY_BRAND.containsMatchIn(name) ||
            MASKED_ACCOUNT.containsMatchIn(body)
    }
}
